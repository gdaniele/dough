import XCTest
@testable import DoughCore

final class RulesTests: XCTestCase {
    func testHostsComeOutOfWhatAnAddressBarShows() {
        XCTAssertEqual(Sites.host(of: "https://www.YouTube.com:443/watch?v=1"), "youtube.com")
        XCTAssertEqual(Sites.host(of: "m.youtube.com/shorts"), "m.youtube.com")
        XCTAssertEqual(Sites.host(of: "https://user@example.com/"), "example.com")
        XCTAssertNil(Sites.host(of: "how to bake cornetti"))
        XCTAssertNil(Sites.host(of: "about:blank"))
        XCTAssertNil(Sites.host(of: "chrome://newtab"))
        XCTAssertNil(Sites.host(of: "file:///Users/me/x.html"))
        XCTAssertNil(Sites.host(of: "cornetti"))
    }

    func testOffAllowsEverything() {
        XCTAssertTrue(BlockRules().allowsSite("youtube.com"))
        XCTAssertTrue(BlockRules().allowsApp("com.tinyspeck.slackmacgap"))
    }

    func testDenyListTakesASiteAndItsSubdomainsOnly() {
        let rules = BlockRules(siteMode: .block, sites: ["youtube.com", "reddit.com"])
        XCTAssertFalse(rules.allowsSite("https://www.youtube.com/watch"))
        XCTAssertFalse(rules.allowsSite("m.youtube.com"))
        XCTAssertFalse(rules.allowsSite("old.reddit.com/r/x"))
        XCTAssertTrue(rules.allowsSite("notyoutube.com"))
        XCTAssertTrue(rules.allowsSite("wikipedia.org"))
        XCTAssertTrue(rules.allowsSite("youtube"), "still being typed")
    }

    func testAllowListLetsNothingElseThrough() {
        let rules = BlockRules(siteMode: .only, sites: ["docs.swift.org"])
        XCTAssertTrue(rules.allowsSite("https://docs.swift.org/swift-book"))
        XCTAssertFalse(rules.allowsSite("google.com/search?q=x"))
        XCTAssertFalse(rules.allowsSite("swift.org"))
        XCTAssertTrue(rules.allowsSite("about:blank"))
    }

    func testAppLists() {
        let deny = BlockRules(appMode: .block, apps: ["com.tinyspeck.slackmacgap"])
        XCTAssertFalse(deny.allowsApp("com.tinyspeck.slackmacgap"))
        XCTAssertTrue(deny.allowsApp("com.apple.Notes"))

        let allow = BlockRules(appMode: .only, apps: ["com.apple.Notes"])
        XCTAssertTrue(allow.allowsApp("com.apple.Notes"))
        XCTAssertFalse(allow.allowsApp("com.tinyspeck.slackmacgap"))
    }

    func testTheSystemIsNeverBlocked() {
        let allow = BlockRules(appMode: .only, apps: [])
        XCTAssertTrue(allow.allowsApp("com.apple.finder"))
        XCTAssertTrue(allow.allowsApp("com.apple.loginwindow"))
        XCTAssertTrue(allow.allowsApp(nil))
        XCTAssertTrue(BlockRules(appMode: .block, apps: ["com.apple.finder"]).allowsApp("com.apple.finder"))
    }

    func testTextBoxParsesToHosts() {
        XCTAssertEqual(Sites.parse("https://www.youtube.com/, reddit.com\n  \nnot a site reddit.com"), ["youtube.com", "reddit.com"])
    }
}
