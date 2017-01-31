import XCTest
@testable import Fiber

class FiberTests: XCTestCase {
    func testQueue() {
        var q = Queue<Int>()
        for n in 1...100 {
            q.push(n)
        }
        var n=1
        while !q.isEmpty {
            XCTAssertEqual(n, q.pop())
            n+=1
        }
        for n in 1...100 {
            q.push(n)
        }
        n=1
        while !q.isEmpty {
            XCTAssertEqual(n, q.pop())
            n+=1
        }
        for n in 1...1000 {
            q.push(n)
            XCTAssertEqual(n, q.pop())
        }
        for n in 1...2000 {
            q.push(n)
            XCTAssertEqual(n, q.pop())
        }
    }
    
    func testMPMCQueue() {
        let q: MPMCQueue<Int> = MPMCQueue(withCapacity: 10)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
            // Producer
            for i in 1...100 {
                q.push(element: i)
            }
        }
        DispatchQueue.main.async {
            // Consumer
            for i in 1...100 {
                XCTAssertEqual(i, q.pop())
            }
        }
    }
    
    func testSimpleScheduler() {
        var n1 = 0
        var n2 = 0
        
        let sched=SimpleScheduler()
        
        sched.spawn {
            print("Fiber1 started")
            n1=1
            Fiber.yield()
            print("Fiber1 resumed")
            n1=2
            Fiber.yield()
            print("Fiber1 resumed again")
            n1=3
            Fiber.yield()
            print("Fiber1 existing")
        }
        
        sched.spawn {
            print("Fiber2 started")
            n2=1
            Fiber.yield()
            print("Fiber2 resumed")
            n2=2
            Fiber.yield()
            print("Fiber2 resumed again")
            n2=3
            Fiber.yield()
            print("Fiber2 existing")
        }
        
        XCTAssertTrue(sched.runOnce())
        XCTAssertEqual(n1, 1)
        XCTAssertEqual(n2, 0)
        XCTAssertTrue(sched.runOnce())
        XCTAssertEqual(n1, 1)
        XCTAssertEqual(n2, 1)
        XCTAssertTrue(sched.runOnce())
        XCTAssertEqual(n1, 2)
        XCTAssertEqual(n2, 1)
        XCTAssertTrue(sched.runOnce())
        XCTAssertEqual(n1, 2)
        XCTAssertEqual(n2, 2)
        XCTAssertTrue(sched.runOnce())
        XCTAssertEqual(n1, 3)
        XCTAssertEqual(n2, 2)
        XCTAssertTrue(sched.runOnce())
        XCTAssertEqual(n1, 3)
        XCTAssertEqual(n2, 3)
        XCTAssertTrue(sched.runOnce())
        XCTAssertTrue(sched.runOnce())
        XCTAssertFalse(sched.runOnce())
    }
    
    static var allTests : [(String, (FiberTests) -> () throws -> Void)] {
        return [
            ("testQueue", testQueue),
            ("testMPMCQueue", testMPMCQueue),
            ("testSimpleScheduler", testSimpleScheduler),
        ]
    }
}
