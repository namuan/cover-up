import XCTest
import Combine
@testable import CoverUp

final class MaskRegionManagerTests: XCTestCase {

    var manager: MaskRegionManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        manager = MaskRegionManager()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - addRegion

    func testAddRegionAppendsToList() {
        let region = MaskRegion(id: "r1", relativeRect: CGRect(x: 10, y: 20, width: 100, height: 50))
        manager.addRegion(region)
        XCTAssertEqual(manager.regions.count, 1)
        XCTAssertEqual(manager.regions.first?.id, "r1")
    }

    func testAddRegionIgnoresDuplicateId() {
        let region = MaskRegion(id: "r1")
        manager.addRegion(region)
        manager.addRegion(region) // duplicate
        XCTAssertEqual(manager.regions.count, 1)
    }

    func testAddRegionPublishesUpdate() {
        let expectation = expectation(description: "publisher fires")
        var receivedCount = 0

        manager.regionsPublisher
            .dropFirst() // skip initial empty value
            .sink { regions in
                receivedCount = regions.count
                expectation.fulfill()
            }
            .store(in: &cancellables)

        manager.addRegion(MaskRegion(id: "r1"))
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedCount, 1)
    }

    // MARK: - removeRegion

    func testRemoveRegionDeletesById() {
        manager.addRegion(MaskRegion(id: "r1"))
        manager.addRegion(MaskRegion(id: "r2"))
        manager.removeRegion(id: "r1")
        XCTAssertEqual(manager.regions.count, 1)
        XCTAssertEqual(manager.regions.first?.id, "r2")
    }

    func testRemoveRegionNoOpIfNotFound() {
        manager.addRegion(MaskRegion(id: "r1"))
        manager.removeRegion(id: "non-existent")
        XCTAssertEqual(manager.regions.count, 1) // unchanged
    }

    // MARK: - toggleRegion

    func testToggleRegionFlipsIsActive() {
        let region = MaskRegion(id: "r1", isActive: true)
        manager.addRegion(region)
        manager.toggleRegion(id: "r1")
        XCTAssertFalse(manager.regions.first!.isActive)
        manager.toggleRegion(id: "r1")
        XCTAssertTrue(manager.regions.first!.isActive)
    }

    func testToggleRegionNoOpIfNotFound() {
        manager.addRegion(MaskRegion(id: "r1", isActive: true))
        manager.toggleRegion(id: "non-existent") // must not crash
        XCTAssertTrue(manager.regions.first!.isActive) // unchanged
    }

    // MARK: - updateRect

    func testUpdateRectChangesRelativeRect() {
        let region = MaskRegion(id: "r1", relativeRect: .zero)
        manager.addRegion(region)
        let newRect = CGRect(x: 50, y: 60, width: 200, height: 100)
        manager.updateRect(id: "r1", rect: newRect)
        XCTAssertEqual(manager.regions.first?.relativeRect, newRect)
    }

    // MARK: - MaskRegion struct

    func testMaskRegionDefaultValues() {
        let region = MaskRegion()
        XCTAssertFalse(region.id.isEmpty)
        XCTAssertNil(region.targetWindowTitle)
        XCTAssertEqual(region.relativeRect, .zero)
        XCTAssertFalse(region.useBlur)
        XCTAssertTrue(region.isActive)
    }
}
