//
//  ZoomTransition.swift
//  Spacer
//
//  Availability-gated helpers for the iOS 18 zoom transition (a grid thumbnail
//  expands into its detail). On iOS 17 these are no-ops — the detail simply
//  presents without the matched zoom.
//

import SwiftUI

extension View {
    /// Marks this view as the source of a zoom transition.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Applies the matching zoom transition to a presented destination.
    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
