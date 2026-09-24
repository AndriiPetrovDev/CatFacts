import XCTest

@MainActor
final class CatFactsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSearchAndFiltersPersistWhenReturningFromSelectedFact() {
        let app = launch()
        search(for: "purr", in: app)
        assertFacts(["recent-verified", "old-verified", "recent-unverified"], in: app)

        app.buttons["facts.filter.verified"].tap()
        assertFacts(["recent-verified", "old-verified"], in: app)

        app.buttons["facts.filter.new"].tap()
        assertFacts(["recent-verified"], in: app)
        let selectedFact = fact("recent-verified", in: app)
        XCTAssertEqual(selectedFact.value as? String, "New, Verified")
        selectedFact.tap()

        assertDetails(text: "Cats purr to communicate.", isNew: true, isVerified: true, in: app)

        app.navigationBars["Fact Details"].buttons.firstMatch.tap()

        assertFacts(["recent-verified"], in: app)
        waitUntil("Search is available after returning from details") {
            app.searchFields["facts.search"].isHittable
        }
        XCTAssertEqual(app.searchFields["facts.search"].value as? String, "purr")
        XCTAssertTrue(app.buttons["facts.filter.verified"].isSelected)
        XCTAssertTrue(app.buttons["facts.filter.new"].isSelected)
    }

    func testClearingNoMatchesRestoresFactsWithoutResettingFilters() {
        let app = launch()
        app.buttons["facts.filter.verified"].tap()
        app.buttons["facts.filter.new"].tap()
        search(for: "no matching keyword", in: app)

        let message = app.staticTexts["No facts found."]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Try Again"].exists)

        let searchField = app.searchFields["facts.search"]
        searchField.tap()
        let clearButton = searchField.buttons["Clear text"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.tap()

        assertFacts(["recent-verified", "other-topic"], in: app)
        XCTAssertFalse(message.exists)
        XCTAssertTrue(app.buttons["facts.filter.verified"].isSelected)
        XCTAssertTrue(app.buttons["facts.filter.new"].isSelected)
    }

    func testRetryAfterOfflineErrorLoadsFactsAndOpensDetails() {
        let app = launch(scenario: "offlineThenSuccess")
        let retryButton = app.buttons["Try Again"]
        let message = app.staticTexts["You're offline. Check your internet connection and try again."]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
        XCTAssertTrue(message.exists)

        retryButton.tap()

        let recoveredFact = fact("old-verified", in: app)
        XCTAssertTrue(recoveredFact.waitForExistence(timeout: 5))
        XCTAssertFalse(retryButton.exists)
        XCTAssertFalse(message.exists)
        XCTAssertEqual(recoveredFact.value as? String, "Verified")
        recoveredFact.tap()

        assertDetails(text: "Some cats purr softly.", isNew: false, isVerified: true, in: app)
    }

    func testScrollingHidesAndRestoresSearchWithoutLosingQueryOrFilter() {
        let app = launch(scenario: "scrolling")
        search(for: "purr", in: app)
        let verifiedFilter = app.buttons["facts.filter.verified"]
        verifiedFilter.tap()
        let searchField = app.searchFields["facts.search"]
        let list = app.collectionViews["facts.list"]

        list.swipeUp()

        waitUntil("Scrolling down hides search and filters") {
            let searchHidden = !searchField.exists || !searchField.isHittable
            let filtersHidden = !verifiedFilter.exists || !verifiedFilter.isHittable
            return searchHidden && filtersHidden
        }
        let contentTop = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        let contentBottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        contentTop.press(forDuration: 0.05, thenDragTo: contentBottom)

        waitUntil("Scrolling up restores search and filters") {
            searchField.exists && verifiedFilter.exists
                && searchField.isHittable && verifiedFilter.isHittable
        }
        XCTAssertEqual(searchField.value as? String, "purr")
        XCTAssertTrue(verifiedFilter.isSelected)
        XCTAssertFalse(fact("other-topic", in: app).exists)
        XCTAssertFalse(fact("recent-unverified", in: app).exists)
    }

    private func launch(scenario: String = "facts") -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
        if scenario != "offlineThenSuccess" {
            XCTAssertTrue(fact("recent-verified", in: app).waitForExistence(timeout: 5))
            waitUntil("Search and filters are ready") {
                app.searchFields["facts.search"].isHittable && app.buttons["facts.filter.new"].isHittable
            }
        }
        return app
    }

    private func search(for query: String, in app: XCUIApplication) {
        let searchField = app.searchFields["facts.search"]
        searchField.tap()
        searchField.typeText(query + "\n")
        waitUntil("The keyboard is dismissed after submitting search") {
            app.keyboards.count == 0
        }
    }

    private func fact(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.collectionViews["facts.list"].descendants(matching: .any)["facts.item.\(id)"]
    }

    private func assertFacts(_ ids: [String], in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let items = app.collectionViews["facts.list"]
            .descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "facts.item."))
        let expectedIDs = ids.map { "facts.item.\($0)" }
        waitUntil("Expected facts: \(ids)", file: file, line: line) {
            items.allElementsBoundByIndex.map(\.identifier) == expectedIDs
        }
    }

    private func assertDetails(
        text: String,
        isNew: Bool,
        isVerified: Bool,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let details = app.staticTexts["facts.details.text"]
        XCTAssertTrue(details.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(details.label, text, file: file, line: line)
        XCTAssertEqual(app.staticTexts["fact.status.new"].exists, isNew, "New status", file: file, line: line)
        XCTAssertEqual(app.staticTexts["fact.status.verified"].exists, isVerified, "Verified status", file: file, line: line)
    }

    private func waitUntil(_ message: String, file: StaticString = #filePath, line: UInt = #line, condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, message, file: file, line: line)
    }
}
