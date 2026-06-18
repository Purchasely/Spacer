//
//  StoreKitPurchaser.swift
//  Spacer
//
//  App-side StoreKit 2 billing, used ONLY in Observer mode (in Full mode Purchasely
//  runs the purchase itself). The app must finish the transaction itself —
//  Purchasely.synchronize() re-pulls the receipt but does not finish StoreKit's
//  transaction queue, so an unfinished transaction would be re-delivered every launch.
//

import StoreKit

enum StoreKitPurchaser {
    enum Outcome {
        case purchased
        case cancelledOrPending   // user backed out or Ask-to-Buy — not an error
        case failed
    }

    /// Buys `productId` via StoreKit 2 and finishes the verified transaction.
    static func purchase(productId: String) async -> Outcome {
        do {
            guard let product = try await Product.products(for: [productId]).first else {
                print("[Spacer] StoreKit: product '\(productId)' not found")
                return .failed
            }
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()   // REQUIRED — synchronize() doesn't finish for us
                print("[Spacer] StoreKit: purchased \(productId)")
                return .purchased
            case .success(.unverified):
                print("[Spacer] StoreKit: transaction failed verification")
                return .failed
            case .pending, .userCancelled:
                return .cancelledOrPending
            @unknown default:
                return .failed
            }
        } catch {
            print("[Spacer] StoreKit purchase error: \(error.localizedDescription)")
            return .failed
        }
    }

    /// Restores via the App Store (prompts sign-in if needed).
    static func restore() async -> Bool {
        do {
            try await AppStore.sync()
            print("[Spacer] StoreKit: AppStore.sync() completed")
            return true
        } catch {
            print("[Spacer] StoreKit restore error: \(error.localizedDescription)")
            return false
        }
    }
}
