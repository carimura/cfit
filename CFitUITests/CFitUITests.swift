import XCTest

final class CFitUITests: XCTestCase {
    @MainActor
    func testAutomaticWorkRestAndNextMovement() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["settings"].tap()
        let work = app.steppers["workInterval"]
        let rest = app.steppers["restInterval"]
        let workSteps = (try intervalSeconds(work) - 10) / 5
        let restSteps = (try intervalSeconds(rest) - 5) / 5
        for _ in 0..<workSteps { work.buttons["workInterval-Decrement"].tap() }
        for _ in 0..<restSteps { rest.buttons["restInterval-Decrement"].tap() }
        app.buttons["Done"].tap()
        // A 10-minute workout starts directly with the conditioning circuit.
        app.buttons["workoutMinutes"].tap()
        app.buttons["10 min"].tap()
        app.buttons["startWorkout"].tap()
        app.swipeUp()
        app.buttons["skipWarmup"].tap()
        let firstMovement = app.staticTexts["currentMovement"].label
        let restState = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Rest'"), object: app.staticTexts["currentMovement"])
        XCTAssertEqual(XCTWaiter.wait(for: [restState], timeout: 13), .completed)
        capture("Rest", app: app)
        let workState = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != 'Rest'"), object: app.staticTexts["currentMovement"])
        XCTAssertEqual(XCTWaiter.wait(for: [workState], timeout: 8), .completed)
        XCTAssertNotEqual(app.staticTexts["currentMovement"].label, firstMovement)
        app.buttons["End workout"].tap()
        XCTAssertTrue(app.buttons["confirmEndWorkout"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["confirmEndWorkout"].firstMatch.tap()
        XCTAssertTrue(app.buttons["pauseResume"].waitForNonExistence(timeout: 5))
        app.buttons["settings"].tap()
        for _ in 0..<workSteps { work.buttons["workInterval-Increment"].tap() }
        for _ in 0..<restSteps { rest.buttons["restInterval-Increment"].tap() }
        XCTAssertEqual(try intervalSeconds(work), 10 + workSteps * 5)
        XCTAssertEqual(try intervalSeconds(rest), 5 + restSteps * 5)
        app.buttons["Done"].tap()
        app.buttons["workoutMinutes"].tap()
        app.buttons["20 min"].tap()
    }

    @MainActor
    func testWorkoutPauseVideoAndBackground() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["startWorkout"].waitForExistence(timeout: 10))
        capture("Home", app: app)
        app.buttons["startWorkout"].tap()
        XCTAssertTrue(app.buttons["pauseResume"].waitForExistence(timeout: 5))
        capture("Warmup", app: app)
        app.buttons["pauseResume"].tap()
        XCTAssertEqual(app.buttons["pauseResume"].label, "RESUME")
        let paused = app.staticTexts["intervalCountdown"].label
        sleep(2)
        XCTAssertEqual(app.staticTexts["intervalCountdown"].label, paused)
        app.buttons["pauseResume"].tap()
        let guide = app.buttons["workoutGuide"]
        app.swipeUp()
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        guide.tap()
        XCTAssertTrue(app.buttons["watchVideo"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["pauseResume"].label, "RESUME")
        app.buttons["pauseResume"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertEqual(app.buttons["pauseResume"].label, "RESUME")
        sleep(1)
        app.buttons["End workout"].tap()
        XCTAssertTrue(app.buttons["confirmEndWorkout"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["confirmEndWorkout"].firstMatch.tap()
        XCTAssertTrue(app.buttons["pauseResume"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["startWorkout"].waitForExistence(timeout: 5))
        app.buttons["settings"].tap()
        XCTAssertTrue(app.switches["equipment.wall"].waitForExistence(timeout: 5))
        capture("Settings", app: app)
    }

    @MainActor
    private func intervalSeconds(_ stepper: XCUIElement) throws -> Int {
        let labels = [stepper.label] + stepper.staticTexts.allElementsBoundByIndex.map(\.label)
        return try XCTUnwrap(labels.flatMap { $0.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) } }.first)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
