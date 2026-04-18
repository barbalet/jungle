import XCTest
import JungleShared

final class JungleTimingPlannerTests: XCTestCase {
    func testPlannerAppliesSingleStepAtTargetRate() {
        let policy = JungleTimingPolicy.default

        let plan = JungleTimingPlanner.makePlan(
            policy: policy,
            currentLagSeconds: 0,
            elapsedSeconds: policy.fixedStepSeconds
        )

        XCTAssertEqual(plan.appliedSteps, 1)
        XCTAssertEqual(plan.appliedSimulationSeconds, policy.fixedStepSeconds, accuracy: 0.000_000_1)
        XCTAssertEqual(plan.remainingLagSeconds, 0, accuracy: 0.000_001)
    }

    func testPlannerAccumulatesLagAcrossShortFrames() {
        let policy = JungleTimingPolicy.default

        let firstPlan = JungleTimingPlanner.makePlan(
            policy: policy,
            currentLagSeconds: 0,
            elapsedSeconds: policy.fixedStepSeconds * 0.5
        )

        XCTAssertEqual(firstPlan.appliedSteps, 0)
        XCTAssertEqual(firstPlan.remainingLagSeconds, policy.fixedStepSeconds * 0.5, accuracy: 0.000_000_1)

        let secondPlan = JungleTimingPlanner.makePlan(
            policy: policy,
            currentLagSeconds: firstPlan.remainingLagSeconds,
            elapsedSeconds: policy.fixedStepSeconds * 0.5
        )

        XCTAssertEqual(secondPlan.appliedSteps, 1)
        XCTAssertEqual(secondPlan.remainingLagSeconds, 0, accuracy: 0.000_001)
    }

    func testPlannerClampsCatchUpWorkAndDropsExcessLag() {
        let policy = JungleTimingPolicy(
            targetFramesPerSecond: 60,
            fixedStepSeconds: 1.0 / 60.0,
            maximumFrameDeltaSeconds: 0.1,
            maximumCatchUpSteps: 3
        )

        let plan = JungleTimingPlanner.makePlan(
            policy: policy,
            currentLagSeconds: 0,
            elapsedSeconds: 0.2
        )

        XCTAssertEqual(plan.clampedFrameDeltaSeconds, 0.1, accuracy: 0.000_000_1)
        XCTAssertEqual(plan.appliedSteps, 3)
        XCTAssertEqual(plan.remainingLagSeconds, policy.maximumRetainedLagSeconds, accuracy: 0.000_001)
        XCTAssertGreaterThan(plan.discardedLagSeconds, 0)
    }
}
