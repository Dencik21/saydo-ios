import XCTest
@testable import SayDo

final class DateParserTests: XCTestCase {

    private var cal: Calendar!

    override func setUp() {
        super.setUp()
        cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    private func makeParser(fixedNow: Date) -> DateParser {
        DateParser(calendar: cal, locale: Locale(identifier: "ru_RU")) { fixedNow }
    }

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func assertYMD(_ date: Date,
                           _ y: Int, _ m: Int, _ d: Int,
                           file: StaticString = #filePath, line: UInt = #line) {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(c.year, y, file: file, line: line)
        XCTAssertEqual(c.month, m, file: file, line: line)
        XCTAssertEqual(c.day, d, file: file, line: line)
    }

    func testToday() {
        let now = makeDate(2026, 2, 19, 10, 0)
        let parser = makeParser(fixedNow: now)

        let (date, _) = parser.parse(from: "купить молоко сегодня")

        XCTAssertNotNil(date)
        assertYMD(date!, 2026, 2, 19)
    }

    func testTomorrowWithTimeHHMM() {
        let now = makeDate(2026, 2, 19, 10, 0)
        let parser = makeParser(fixedNow: now)

        let (date, _) = parser.parse(from: "спортзал завтра в 18:30")

        XCTAssertNotNil(date)
        assertYMD(date!, 2026, 2, 20)
        XCTAssertEqual(cal.component(.hour, from: date!), 18)
        XCTAssertEqual(cal.component(.minute, from: date!), 30)
    }

    func testDayMarkedNearestFuture() {
        let now = makeDate(2026, 2, 19, 10, 0)
        let parser = makeParser(fixedNow: now)

        let (date, _) = parser.parse(from: "встреча с аней 19 числа")

        XCTAssertNotNil(date)
        assertYMD(date!, 2026, 2, 19)
    }

    func testFullDate() {
        let now = makeDate(2026, 2, 19, 10, 0)
        let parser = makeParser(fixedNow: now)

        let (date, _) = parser.parse(from: "с друзьями в ресторан 24 февраля")

        XCTAssertNotNil(date)
        assertYMD(date!, 2026, 2, 24)
    }
}
