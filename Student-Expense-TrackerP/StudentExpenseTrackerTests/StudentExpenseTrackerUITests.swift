import XCTest

final class StudentExpenseTrackerUITests: XCTestCase {
    func testAppLaunchesToDashboard() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Dashboard"].exists || app.staticTexts["Ready to go?"].exists)
    }
} 