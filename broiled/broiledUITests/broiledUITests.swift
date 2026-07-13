import XCTest

final class BroiledUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // A leftover landscape orientation from a prior run once made the onboarding
        // Start button unreachable (content overflows in landscape). The app is now
        // portrait-only, but pin the device too so tests never inherit stale state.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        // Fresh in-memory store per launch, and skips the HealthKit/notification system
        // permission prompts - see BROiledApp.swift / RootView.swift.
        app.launchArguments = ["UI-TESTING"]
    }

    // MARK: - Onboarding

    func testOnboardingLeadsToHomeCountdown() throws {
        app.launch()

        let startButton = app.buttons["Start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 12))
        startButton.tap()

        XCTAssertTrue(app.staticTexts["Workout in"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["I've locked in today"].exists)
    }

    // MARK: - Logging a workout

    func testLoggingWorkoutShowsGutCheckThenLockedInState() throws {
        app.launch()
        app.buttons["Start"].tap()

        let lockedInButton = app.buttons["I've locked in today"]
        XCTAssertTrue(lockedInButton.waitForExistence(timeout: 12))
        lockedInButton.tap()

        let yesButton = app.buttons["yes!"]
        XCTAssertTrue(yesButton.waitForExistence(timeout: 12), "gut-check sheet should appear")
        yesButton.tap()

        let doneButton = app.buttons["Locked in ✓"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 12))
        XCTAssertFalse(doneButton.isEnabled, "should be disabled after logging today")
    }

    func testGutCheckNoReturnsToCountdownWithoutLogging() throws {
        app.launch()
        app.buttons["Start"].tap()

        app.buttons["I've locked in today"].tap()

        let noButton = app.buttons["...no I lied"]
        XCTAssertTrue(noButton.waitForExistence(timeout: 12))
        noButton.tap()

        // Declining the gut-check should leave the countdown running, not log a success.
        XCTAssertTrue(app.staticTexts["Workout in"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["I've locked in today"].exists)
    }

    // MARK: - Settings

    func testSettingsOpensAndCloses() throws {
        app.launch()
        app.buttons["Start"].tap()

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 12))
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 12))

        app.buttons["closeSettingsButton"].tap()

        XCTAssertTrue(app.staticTexts["Workout in"].waitForExistence(timeout: 12), "closing Settings should return to Home")
    }

    func testScheduleEditorOpensFromSettingsAndSaves() throws {
        app.launch()
        app.buttons["Start"].tap()

        // Wait for Home to render before tapping - tapping immediately raced the
        // onboarding->Home transition on a loaded simulator.
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 12))
        settingsButton.tap()
        XCTAssertTrue(app.buttons["scheduleRowButton"].waitForExistence(timeout: 12))
        app.buttons["scheduleRowButton"].tap()

        XCTAssertTrue(app.staticTexts["Edit schedule"].waitForExistence(timeout: 12))

        let saveButton = app.buttons["Save"]
        // waitForExistence, not .exists - the sheet's content can register in the
        // accessibility tree a beat after its title on a loaded simulator.
        XCTAssertTrue(saveButton.waitForExistence(timeout: 12))
        saveButton.tap()

        // Back on the Settings screen after saving.
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 12))
    }

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - v0.2 snooze sheet redesign

    /// Rest-day-tomorrow branch: push to tomorrow shows the extra insult + "do it",
    /// confirming dismisses the sheet back to Home with the countdown still running.
    func testSnoozeSheetPushToTomorrowRestDay() throws {
        app.launchArguments += ["UI-TESTING-OPEN-SNOOZE", "UI-TESTING-TOMORROW-REST"]
        app.launch()
        app.buttons["Start"].tap()

        XCTAssertTrue(app.staticTexts["push it back?"].waitForExistence(timeout: 12), "snooze sheet should open via test hook")
        XCTAssertTrue(app.buttons["snoozeConfirmButton"].exists)
        XCTAssertTrue(app.datePickers.count >= 1, "v0.2: real time picker, not fixed +30min steps")

        let tomorrowButton = app.buttons["pushToTomorrowButton"]
        XCTAssertTrue(tomorrowButton.exists)
        tomorrowButton.tap()

        let doIt = app.buttons["do it"]
        XCTAssertTrue(doIt.waitForExistence(timeout: 12), "rest-day branch should offer 'do it'")
        doIt.tap()

        XCTAssertTrue(app.staticTexts["Workout in"].waitForExistence(timeout: 12), "sheet should dismiss back to Home")
    }

    /// Scheduled-tomorrow branch: pushing onto an already-scheduled day warns that today
    /// just becomes a miss, and backing out returns to the sheet without recording anything.
    func testSnoozeSheetPushToTomorrowScheduledWarnsAndCancels() throws {
        app.launchArguments += ["UI-TESTING-OPEN-SNOOZE", "UI-TESTING-TOMORROW-SCHEDULED"]
        app.launch()
        app.buttons["Start"].tap()

        XCTAssertTrue(app.staticTexts["push it back?"].waitForExistence(timeout: 12))
        app.buttons["pushToTomorrowButton"].tap()

        let takeMiss = app.buttons["take the miss"]
        XCTAssertTrue(takeMiss.waitForExistence(timeout: 12), "scheduled branch should warn with 'take the miss'")

        let cancel = app.buttons["nvm, I'll work out"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 12))
        cancel.tap()
        // Generous timeout: the collapse back to the default sheet state re-renders the
        // whole sheet, which can take seconds on a loaded simulator.
        XCTAssertTrue(app.buttons["pushToTomorrowButton"].waitForExistence(timeout: 12), "cancel should return to the sheet")
    }

    /// "take the miss" routes through the quit path and dismisses the sheet.
    func testSnoozeSheetTakeTheMissDismisses() throws {
        app.launchArguments += ["UI-TESTING-OPEN-SNOOZE", "UI-TESTING-TOMORROW-SCHEDULED"]
        app.launch()
        app.buttons["Start"].tap()

        XCTAssertTrue(app.staticTexts["push it back?"].waitForExistence(timeout: 12))
        app.buttons["pushToTomorrowButton"].tap()

        let takeMiss = app.buttons["take the miss"]
        XCTAssertTrue(takeMiss.waitForExistence(timeout: 12))
        takeMiss.tap()

        XCTAssertTrue(app.staticTexts["Workout in"].waitForExistence(timeout: 12), "sheet should dismiss back to Home after taking the miss")
    }
}
