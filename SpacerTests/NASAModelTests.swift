//
//  NASAModelTests.swift
//  SpacerTests
//
//  Decoding gotchas: the EPIC archive-URL builder and APOD optional/video fields.
//

import Testing
import Foundation
@testable import Spacer

struct EPICURLTests {
    private func makeImage(date: String, image: String) -> EPICImage {
        EPICImage(identifier: "id", caption: "Earth", image: image, date: date)
    }

    @Test func buildsArchiveURLFromTimestamp() {
        let image = makeImage(date: "2019-05-30 00:00:00", image: "epic_1b_20190530011359")
        #expect(image.imageURL?.absoluteString ==
                "https://epic.gsfc.nasa.gov/archive/natural/2019/05/30/png/epic_1b_20190530011359.png")
        #expect(image.thumbnailURL?.absoluteString ==
                "https://epic.gsfc.nasa.gov/archive/natural/2019/05/30/thumbs/epic_1b_20190530011359.jpg")
    }

    @Test func archiveURLHasNoAPIKey() {
        let image = makeImage(date: "2026-06-16 12:00:00", image: "epic_test")
        #expect(image.imageURL?.query == nil)
    }

    @Test func displayDateStripsTime() {
        let image = makeImage(date: "2026-06-16 12:00:00", image: "epic_test")
        #expect(image.displayDate == "2026-06-16")
    }
}

struct APODModelTests {
    @Test func decodesOptionalFieldsAndVideo() throws {
        let json = """
        {"date":"2026-06-16","title":"A Video","explanation":"x",
         "media_type":"video","url":"https://youtube.com/embed/abc"}
        """.data(using: .utf8)!
        let apod = try JSONDecoder().decode(APOD.self, from: json)
        #expect(apod.isVideo == true)
        #expect(apod.hdurl == nil)
        #expect(apod.copyright == nil)
    }

    @Test func decodesImageWithHDAndCopyright() throws {
        let json = """
        {"date":"2026-06-16","title":"Nebula","explanation":"A story.",
         "media_type":"image","url":"https://apod.nasa.gov/i.jpg",
         "hdurl":"https://apod.nasa.gov/hd.jpg","copyright":"Someone"}
        """.data(using: .utf8)!
        let apod = try JSONDecoder().decode(APOD.self, from: json)
        #expect(apod.isVideo == false)
        #expect(apod.hdurl != nil)
        #expect(apod.copyright == "Someone")
    }
}
