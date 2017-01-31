import Foundation
import Context

let currentFiberKey = "codes.rough.Fiber.Scheduler.currentFiber"

public protocol Scheduler {
    func spawn(_ entry: @escaping ()->Void)
    func destroy(_ fiber: Fiber)
	func schedule(_ fiber: Fiber)
	func unschedule(_ fiber: Fiber)
    func yield(_ fiber: Fiber)
	func runOnce() -> Bool
	func run()
}

/**
 * Simple single-threaded round-robin scheduler
 */
public class SimpleScheduler : Scheduler {
    var schedulerContext: coro_context = coro_context()
    var ready: Queue<Fiber> = Queue()
    var blocked: Set<Fiber> = Set()
    
    public func spawn(_ entry: @escaping ()->Void) {
        let fiber=Fiber(entry: entry, inScheduler: self)
        coro_create(&fiber.fiberContext, {
            (ptr) in
            let fiber=Unmanaged<Fiber>.fromOpaque(ptr!).autorelease().takeRetainedValue()
            fiber.entry()
            fiber.completed=true
            fiber.scheduler.destroy(fiber)
        }, Unmanaged.passUnretained(fiber).toOpaque(), fiber.fiberStack.sptr, fiber.fiberStack.ssze)
        schedule(fiber)
    }
    
    public func destroy(_ fiber: Fiber) {
        coro_transfer(&fiber.fiberContext, &schedulerContext)
    }
    
    public func run() {
        while(runOnce()) {
            
        }
    }

    public func runOnce() -> Bool {
        if(ready.isEmpty) {
            return false
        }
        let fiber=ready.pop()!
        if(fiber.blocked) {
            blocked.insert(fiber)
        } else {
            Thread.current.threadDictionary.setObject(fiber, forKey: currentFiberKey as NSCopying)
            fiber.next(schedulerCtx: &schedulerContext)
            Thread.current.threadDictionary.removeObject(forKey: currentFiberKey as NSCopying)
            if(!fiber.completed) {
                if(fiber.blocked) {
                    blocked.insert(fiber)
                } else {
                    ready.push(fiber)
                }
            }
        }
        return true
    }

    public func schedule(_ fiber: Fiber) {
        fiber.blocked=false
        ready.push(fiber)
    }
    
    public func unschedule(_ fiber: Fiber) {
        fiber.blocked=true
    }

    public func yield(_ fiber: Fiber) {
        coro_transfer(&fiber.fiberContext, &schedulerContext)
    }
    
    public init() {
    }
}

