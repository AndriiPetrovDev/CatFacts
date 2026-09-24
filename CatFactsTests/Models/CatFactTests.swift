import XCTest
@testable import CatFacts

final class CatFactTests: XCTestCase {
    func testIsNewComparesUTCCreationDateInClientTimeZones() throws {
        let utcClientNow = "2024-06-30T00:30:00Z"
        let utcPlus14ClientNow = "2024-06-30T14:30:00+14:00"
        let utcMinus10ClientNow = "2024-06-29T14:30:00-10:00"
        let utcPlus5Hours45MinutesClientNow = "2024-06-30T06:15:00+05:45"
        let losAngelesClientNow = "2024-06-29T17:30:00-07:00"
        let clientTimes = [
            utcClientNow,
            utcPlus14ClientNow,
            utcMinus10ClientNow,
            utcPlus5Hours45MinutesClientNow,
            losAngelesClientNow
        ]
        let referenceDate = try date(utcClientNow)

        let oneSecondOlderThan90Days = (createdAt: "2024-04-01T00:29:59Z", expectedIsNew: false)
        let exactly90DaysOld = (createdAt: "2024-04-01T00:30:00Z", expectedIsNew: true)
        let oneSecondYoungerThan90Days = (createdAt: "2024-04-01T00:30:01Z", expectedIsNew: true)
        let createdNow = (createdAt: "2024-06-30T00:30:00Z", expectedIsNew: true)
        let createdOneSecondInTheFuture = (createdAt: "2024-06-30T00:30:01Z", expectedIsNew: true)
        let createdOneYearInTheFuture = (createdAt: "2025-06-30T00:30:00Z", expectedIsNew: true)
        let cases = [
            oneSecondOlderThan90Days,
            exactly90DaysOld,
            oneSecondYoungerThan90Days,
            createdNow,
            createdOneSecondInTheFuture,
            createdOneYearInTheFuture
        ]

        for clientTime in clientTimes {
            let now = try date(clientTime)
            XCTAssertEqual(now, referenceDate)

            for testCase in cases {
                let fact = try makeFact(createdAt: testCase.createdAt)

                XCTAssertEqual(
                    fact.isNew(relativeTo: now),
                    testCase.expectedIsNew,
                    "Created at \(testCase.createdAt), client local time: \(clientTime)"
                )
            }
        }
    }

    func testFactDoesNotExpireEarlyWhenNewYorkClocksMoveForward() throws {
        let fact = try makeFact(createdAt: "2023-12-11T07:30:00Z")
        let stillNewBeforeClockChange = (
            now: "2024-03-10T01:59:59-05:00",
            expectedIsNew: true
        )
        let stillNewImmediatelyAfterClockChange = (
            now: "2024-03-10T03:00:00-04:00",
            expectedIsNew: true
        )
        let exactly90DaysOldAfterClockChange = (
            now: "2024-03-10T03:30:00-04:00",
            expectedIsNew: true
        )
        let expiredOneSecondAfter90Days = (
            now: "2024-03-10T03:30:01-04:00",
            expectedIsNew: false
        )
        let cases = [
            stillNewBeforeClockChange,
            stillNewImmediatelyAfterClockChange,
            exactly90DaysOldAfterClockChange,
            expiredOneSecondAfter90Days
        ]

        try assertFreshness(of: fact, cases: cases, message: "New York spring transition")
    }

    func testExpiredFactDoesNotBecomeNewAgainWhenNewYorkClocksMoveBack() throws {
        let fact = try makeFact(createdAt: "2024-08-05T05:30:00Z")
        let stillNewOneSecondBefore90Days = (
            now: "2024-11-03T01:29:59-04:00",
            expectedIsNew: true
        )
        let exactly90DaysOldBeforeClockChange = (
            now: "2024-11-03T01:30:00-04:00",
            expectedIsNew: true
        )
        let expiredBeforeClockChange = (
            now: "2024-11-03T01:59:59-04:00",
            expectedIsNew: false
        )
        let stillExpiredImmediatelyAfterClockChange = (
            now: "2024-11-03T01:00:00-05:00",
            expectedIsNew: false
        )
        let stillExpiredOneHourAfterClockChange = (
            now: "2024-11-03T02:00:00-05:00",
            expectedIsNew: false
        )
        let cases = [
            stillNewOneSecondBefore90Days,
            exactly90DaysOldBeforeClockChange,
            expiredBeforeClockChange,
            stillExpiredImmediatelyAfterClockChange,
            stillExpiredOneHourAfterClockChange
        ]

        try assertFreshness(of: fact, cases: cases, message: "New York autumn transition")
    }

    private func assertFreshness(
        of fact: CatFact,
        cases: [(now: String, expectedIsNew: Bool)],
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for testCase in cases {
            let now = try date(testCase.now, file: file, line: line)

            XCTAssertEqual(
                fact.isNew(relativeTo: now),
                testCase.expectedIsNew,
                "\(message), now: \(testCase.now)",
                file: file,
                line: line
            )
        }
    }

    private func makeFact(createdAt: String) throws -> CatFact {
        try CatFact(id: "fact", text: "Cat fact", createdAt: date(createdAt), isVerified: false)
    }

    private func date(_ value: String, file: StaticString = #filePath, line: UInt = #line) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value), value, file: file, line: line)
    }
}
