import XCTest
@testable import CoverUp

final class HotkeyHandlerTests: XCTestCase {

    final class MockDelegate: HotkeyHandlerDelegate {
        var toggleCount = 0
        var addCount = 0
        var removeCount = 0

        func toggleOverlayVisibility() { toggleCount += 1 }
        func addStaticRegion() { addCount += 1 }
        func removeLastRegion() { removeCount += 1 }
    }

    var handler: HotkeyHandler!
    var mockDelegate: MockDelegate!

    override func setUp() {
        super.setUp()
        handler = HotkeyHandler()
        mockDelegate = MockDelegate()
        handler.delegate = mockDelegate
    }

    override func tearDown() {
        handler = nil
        mockDelegate = nil
        super.tearDown()
    }

    func testCmdShiftHTogglesOverlay() {
        handler.handleKeyEvent(flags: [.command, .shift], keyCode: HotkeyHandler.keyH)
        XCTAssertEqual(mockDelegate.toggleCount, 1)
        XCTAssertEqual(mockDelegate.addCount, 0)
        XCTAssertEqual(mockDelegate.removeCount, 0)
    }

    func testCmdShiftAAddsRegion() {
        handler.handleKeyEvent(flags: [.command, .shift], keyCode: HotkeyHandler.keyA)
        XCTAssertEqual(mockDelegate.addCount, 1)
        XCTAssertEqual(mockDelegate.toggleCount, 0)
    }

    func testCmdShiftDRemovesRegion() {
        handler.handleKeyEvent(flags: [.command, .shift], keyCode: HotkeyHandler.keyD)
        XCTAssertEqual(mockDelegate.removeCount, 1)
        XCTAssertEqual(mockDelegate.toggleCount, 0)
    }

    func testMissingModifierDoesNothing() {
        handler.handleKeyEvent(flags: [], keyCode: HotkeyHandler.keyH)
        XCTAssertEqual(mockDelegate.toggleCount, 0)
        handler.handleKeyEvent(flags: [.command], keyCode: HotkeyHandler.keyH)
        XCTAssertEqual(mockDelegate.toggleCount, 0)
        handler.handleKeyEvent(flags: [.shift], keyCode: HotkeyHandler.keyH)
        XCTAssertEqual(mockDelegate.toggleCount, 0)
    }

    func testUnknownKeyCodeIsIgnored() {
        handler.handleKeyEvent(flags: [.command, .shift], keyCode: 99)
        XCTAssertEqual(mockDelegate.toggleCount, 0)
        XCTAssertEqual(mockDelegate.addCount, 0)
        XCTAssertEqual(mockDelegate.removeCount, 0)
    }

    func testMultipleEventsAccumulate() {
        for _ in 0..<3 {
            handler.handleKeyEvent(flags: [.command, .shift], keyCode: HotkeyHandler.keyH)
        }
        XCTAssertEqual(mockDelegate.toggleCount, 3)
    }
}
