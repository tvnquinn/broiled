import XCTest

final class BroiledUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Fresh in-memory store per launch, and skips the HealthKit/notification system
        // permission prompts - see BROiledApp.swift / RootView.swift.
        app.launchArguments = ["UI-TESTING"]
    }

    // MARK: - Onboarding

    func testOnboardingLeadsToHomeCountdown() throws {
        app.launch()

        let startButton = app.buttons["Start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        XCTAssertTrue(app.staticTexts["Workout in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["I've locked in today"].exists)
    }

    // MARK: - Logging a workout

    func testLoggingWorkoutShowsGutCheckThenLockedInState() throws {
        app.launch()
        app.buttons["Start"].tap()

        let lockedInButton = app.buttons["I've locked in today"]
        XCTAssertTrue(lockedInButton.waitForExistence(timeout: 5))
        lockedInButton.tap()

        let yesButton = app.buttons["yes!"]
        XCTAssertTrue(yesButton.waitForExistence(timeout: 5), "gut-check sheet should appear")
        yesButton.tap()

        let doneButton = app.buttons["Locked in ✓"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        XCTAssertFalse(doneButton.isEnabled, "should be disabled after logging today")
    }

    func testGutCheckNoReturnsToCountdownWithoutLogging() throws {
        app.launch()
        app.buttons["Start"].tap()

        app.buttons["I've locked in today"].tap()

        let noButton = app.buttons["...no I lied"]
        XCTAssertTrue(noButton.waitForExistence(timeout: 5))
        noButton.tap()

        // Declining the gut-check should leave the countdown running, not log a success.
        XCTAssertTrue(app.staticTexts["Workout in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["I've locked in today"].exists)
    }

    // MARK: - Settings

    func testSettingsOpensAndCloses() throws {
        app.launch()
        app.buttons["Start"].tap()

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        app.buttons["closeSettingsButton"].tap()

        XCTAssertTrue(app.staticTexts["Workout in"].waitForExistence(timeout: 5), "closing Settings should return to Home")
    }

    func testScheduleEditorOpensFromSettingsAndSaves() throws {
        app.launch()
        app.buttons["Start"].tap()

        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["scheduleRowButton"].waitForExistence(timeout: 5))
        app.buttons["scheduleRowButton"].tap()

        XCTAssertTrue(app.staticTexts["Edit schedule"].waitForExistence(timeout: 5))

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        // Back on the Settings screen after saving.
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
