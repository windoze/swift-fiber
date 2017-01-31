import Foundation
import Context

public class Fiber : Hashable, Equatable {
    var blocked = false
    var completed = false
    var fiberContext = coro_context()
    var fiberStack = coro_stack()
    var entry: ()->Void
    var scheduler: Scheduler
    
    public var hashValue: Int {
        get {
            return fiberStack.sptr.hashValue
        }
    }

    public static func ==(lhs: Fiber, rhs: Fiber) -> Bool {
        return lhs.fiberStack.sptr==rhs.fiberStack.sptr
    }
    
    func next(schedulerCtx: UnsafeMutablePointer<coro_context>) {
        if(!completed) {
            coro_transfer(schedulerCtx, &fiberContext)
        }
    }
    
    init(entry: @escaping ()->Void, inScheduler: Scheduler) {
        self.entry=entry
        self.scheduler=inScheduler
        coro_stack_alloc(&fiberStack, 0)
    }
    
    deinit {
        coro_stack_free(&fiberStack)
    }
    
    public var id: UInt {
        get {
            // HACK: How to cast pointer into int?
            return UInt(1-fiberStack.sptr.distance(to: UnsafeMutableRawPointer(bitPattern: 1)!))
        }
    }
    
    public class var current: Fiber? {
        get {
            return Thread.current.threadDictionary[currentFiberKey] as! Fiber?
        }
    }
    
    public static func yield() {
        if let f=current {
            f.scheduler.yield(f)
        }
    }
    
    public static func spawn(_ entry: @escaping ()->Void) {
        if let f=current {
            f.scheduler.spawn(entry)
        }
    }
}
