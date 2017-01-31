import Foundation

/**
 * struct Queue
 * Queue implementation with a ring buffer backed by array
 * Queue is a struct as underlying array is also a struct
 */
public struct Queue<T> {
    var items: [T?] = Array(repeating: Optional.none, count: 16)
    var head: Int = 0
    var tail: Int = 0

    /**
     * Count of available elements
     */
    public var count : Int {
        get {
            return (tail + items.count - head) % items.count
        }
    }
    
    public var isEmpty : Bool {
        get {
            // head==tail indicates that the queue is empty
            // NOTE: head may also equal to tail after an insertion, which indicates that the queue is full
            //  We expand the queue immediately after this insertion before returning, so we should never have
            //  a full queue.
            return head == tail
        }
    }
    
    public mutating func pop() -> T? {
        if isEmpty {
            return Optional.none
        } else {
            // Pop element at items[head]
            let ret = items[head]
            // Clear stored element
            items[head]=Optional.none
            // Advance head by 1
            head = (head+1) % items.count
            return ret
        }
    }
    
    public mutating func push(_ newElement: T) {
        // Push item to tail
        items.insert(newElement, at:tail)
        // Advance tail
        tail = (tail+1) % items.count
        // tail==head indicates that the queue is full, nees to expand
        if(head == tail) {
            // Queue is full
            expand()
        }
    }
    
    mutating func expand() {
        // Double array size by inserting a empty chunk before items[head]
        let newChunk: [T?] = Array<T?>(repeating: Optional.none, count: self.items.count)
        items.insert(contentsOf: newChunk, at: tail)
        // Move head to appropriate position
        head = (head+newChunk.count) % items.count
    }
}

/**
 * Multi-producer multi-consumer concurrent queue
 * It has to be a class as we need some cleanup before destruction
 */
public class MPMCQueue<T> {
    let maxSize: Int
    var closing: Bool = false
    var queue: Queue<T> = Queue()
    var queueMutex: pthread_mutex_t = pthread_mutex_t()
    var condNoLongerEmpty: pthread_cond_t = pthread_cond_t()
    var condNoLongerFull: pthread_cond_t = pthread_cond_t()
    var condBecomeEmpty: pthread_cond_t = pthread_cond_t()
    
    /**
     * Init the queue with size bound
     */
    public init(withCapacity capacity: Int = Int.max) {
        maxSize = capacity
        pthread_mutex_init(&queueMutex, nil)
        pthread_cond_init(&condNoLongerEmpty, nil)
        pthread_cond_init(&condNoLongerFull, nil)
        pthread_cond_init(&condBecomeEmpty, nil)
    }
    
    public func close() {
        closing=true
        pthread_mutex_lock(&queueMutex)
        // Wake up all waiting pushers
        pthread_cond_broadcast(&condNoLongerFull)
        pthread_mutex_unlock(&queueMutex)
    }
    
    public func drain() {
        close()
        
        defer {
            pthread_mutex_unlock(&queueMutex)
        }
        pthread_mutex_lock(&queueMutex)
        while(!queue.isEmpty) {
            pthread_cond_wait(&condBecomeEmpty, &queueMutex)
        }
    }
    
    /**
     * Blocking pop
     * It never returns Optional.none
     */
    public func pop() -> T {
        defer {
            pthread_cond_signal(&condNoLongerFull)
            if queue.isEmpty {
                pthread_cond_broadcast(&condBecomeEmpty)
            }
            pthread_mutex_unlock(&queueMutex)
        }
        pthread_mutex_lock(&queueMutex)
        while(queue.isEmpty) {
            pthread_cond_wait(&condNoLongerEmpty, &queueMutex)
            if(!queue.isEmpty) {
                break
            }
        }
        return queue.pop()!
    }
    
    /**
     * Blocking push
     */
    public func push(element: T) {
        if(closing) {
            // TODO: Error?
            return
        }
        defer {
            pthread_cond_signal(&condNoLongerEmpty)
            pthread_mutex_unlock(&queueMutex)
        }
        pthread_mutex_lock(&queueMutex)
        while(queue.count==maxSize) {
            pthread_cond_wait(&condNoLongerFull, &queueMutex)
            if(closing) {
                // TODO: Error?
                return
            }
            if(queue.count<maxSize) {
                queue.push(element)
                break
            }
        }
    }
    
    deinit {
        pthread_cond_destroy(&condBecomeEmpty)
        pthread_cond_destroy(&condNoLongerFull)
        pthread_cond_destroy(&condNoLongerEmpty)
        pthread_mutex_destroy(&queueMutex)
    }
}
