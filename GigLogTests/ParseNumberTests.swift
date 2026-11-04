import Foundation
import Testing
@testable import GigLog

@Suite("Reading typed and pasted numbers")
struct ParseNumberTests {
    private let us = Locale(identifier: "en_US")
    private let germany = Locale(identifier: "de_DE")

    @Test(arguments: [
        ("12.5", 12.5), ("1,206.25", 1206.25), ("1,200", 1200), ("$6.00", 6), (" 42 ", 42), ("0", 0)
    ])
    func usFormat(text: String, expected: Double) {
        #expect(parseNumber(text, locale: us) == expected)
    }

    @Test(arguments: [("12,5", 12.5), ("1.206,25", 1206.25)])
    func germanFormat(text: String, expected: Double) {
        #expect(parseNumber(text, locale: germany) == expected)
    }

    @Test(arguments: ["", "   ", "abc", "$"])
    func notANumber(text: String) {
        #expect(parseNumber(text, locale: us) == nil)
    }
}
