//
//  Temp.swift
//  DummyProject
//
//  Created by amglobal on 9/14/26.
//


import Foundation
import Atomics // Required for ManagedAtomic


/*

//MARK: - Order State

// 1. Your exact OrderState implementation
public final class OrderState: Sendable {
    let protectedIsRunning = ManagedAtomic<Bool>(true)
    
    var isRunning: Bool {
        get { protectedIsRunning.load(ordering: .acquiring) }
        set { protectedIsRunning.store(newValue, ordering: .relaxed) }
    }
    
    func cancel() {
        isRunning = false
    }
}


//MARK: - Order

// 2. Data model for incoming orders
public struct Order: Sendable {
    public let id: UUID
    public let items: [String]
}

// 3. The Custom AsyncSequence
public struct RestaurantOrderSequence: AsyncSequence {
    public typealias Element = Order
    
    private let engine: OrderEngine

    // Provide the sequence with your OrderState state manager
    public init(state: OrderState) {
        self.engine = OrderEngine(state: state)
    }
    
    // External interface to stream new orders into the sequence
    public func receive(_ order: Order) {
        engine.enqueue(order)
    }

    public func makeAsyncIterator() -> RestaurantOrderIterator {
        return RestaurantOrderIterator(engine: engine)
    }
}



//MARK: - Iterator


// 4. The Custom AsyncIteratorProtocol utilizing your next() function
public struct RestaurantOrderIterator: AsyncIteratorProtocol {
    private let engine: OrderEngine

    fileprivate init(engine: OrderEngine) {
        self.engine = engine
    }

    // Your required next() function matching AsyncIteratorProtocol
    public mutating func next() async -> Order? {
        // Read your atomic state safely
        guard engine.state.isRunning else {
            engine.invalidateAndWakeUpAll()
            return nil
        }
        
        // Grab the next order or suspend until one arrives
        return await engine.dequeue()
    }
}


//MARK: - Order Engine

// 5. Internal Thread-Safe Synchronization Engine
private final class OrderEngine: @unchecked Sendable {
    let state: OrderState
    private let lock = NSLock()
    
    private var orderBuffer: [Order] = []
    private var suspendedIterators: [CheckedContinuation<Order?, Never>] = []
    
    init(state: OrderState) {
        self.state = state
    }
    
    func enqueue(_ order: Order) {
        lock.lock()
        
        // Respect your atomic flag: don't buffer if canceled
        guard state.isRunning else {
            lock.unlock()
            return
        }
        
        // If an iterator is waiting for an order, hand it over directly
        if !suspendedIterators.isEmpty {
            let continuation = suspendedIterators.removeFirst()
            lock.unlock()
            continuation.resume(returning: order)
        } else {
            // Otherwise, store it until next() is called
            orderBuffer.append(order)
            lock.unlock()
        }
    }
    
    
    
    
//    func dequeue() async -> Order? {
//        lock.lock()
//        
//        // If an order is already ready in the buffer, return it immediately
//        if !orderBuffer.isEmpty {
//            let order = orderBuffer.removeFirst()
//            lock.unlock()
//            return order
//        }
//        
//        // Double-check your atomic flag before deciding to suspend execution
//        guard state.isRunning else {
//            lock.unlock()
//            return nil
//        }
//        
//        // No orders available: suspend next() safely using a checked continuation
//        return await withCheckedContinuation { continuation in
//            // Re-verify under lock protection to prevent race conditions during suspension
//            guard state.isRunning else {
//                lock.unlock()
//                continuation.resume(returning: nil)
//                return
//            }
//            
//            suspendedIterators.append(continuation)
//            lock.unlock()
//        }
//    }
    
    
    func dequeue() async -> Order? {
        // Step 1: Use a swift critical section scope to query our arrays safely
        let decision: DequeueDecision = lock.withLock {
            if !orderBuffer.isEmpty {
                return .returnImmediately(orderBuffer.removeFirst())
            }
            
            guard state.isRunning else {
                return .terminateStream
            }
            
            return .shouldSuspend
        }
        
        // Step 2: Handle the branch logic safely out of the lock context
        switch decision {
        case .returnImmediately(let order):
            return order
        case .terminateStream:
            return nil
        case .shouldSuspend:
            // Suspend naturally when the queue is completely empty
            return await withCheckedContinuation { continuation in
                // Re-evaluate state carefully using scoped locking inside the continuation
                let immediateOrder: Order? = lock.withLock {
                    guard state.isRunning else {
                        return nil
                    }
                    
                    // Double check if an order sneaked in during the context change
                    if !orderBuffer.isEmpty {
                        return orderBuffer.removeFirst()
                    }
                    
                    // Otherwise register the suspension point
                    suspendedIterators.append(continuation)
                    return nil
                }
                
                // If an order bypassed the queue race condition, return it immediately without locking
                if let order = immediateOrder {
                    continuation.resume(returning: order)
                } else if !state.isRunning {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    // Cleanup helper called when next() detects isRunning turned false
    func invalidateAndWakeUpAll() {
        lock.lock()
        let pending = suspendedIterators
        suspendedIterators.removeAll()
        orderBuffer.removeAll()
        lock.unlock()
        
        // Safely resume any iterators that were stuck waiting for orders when canceled
        for continuation in pending {
            continuation.resume(returning: nil)
        }
    }
}




// Initialize the state and the custom sequence
let orderState = OrderState()
let orderSequence = RestaurantOrderSequence(state: orderState)



func startKitchen() async {
    
    // Task 1: Consume the custom sequence using a standard asynchronous loop
    Task {
        print("🍳 Kitchen opened. Waiting for orders...")
        for await order in orderSequence {
            print("🍔 Cooking Order #\(order.id): \(order.items.joined(separator: ", "))")
        }
        print("🛑 Kitchen closed. Loop naturally terminated via custom state.")
    }
    
    // Task 2: Simulate live system events dropping in orders and executing cancellation
    Task {
        try? await Task.sleep(for: .seconds(1))
        orderSequence.receive(Order(id: UUID(), items: ["Tacos", "Soda"]))
        
        try? await Task.sleep(for: .seconds(1))
        orderSequence.receive(Order(id: UUID(), items: ["Pancakes", "Coffee"]))
        
        try? await Task.sleep(for: .seconds(1))
        print("🚨 Triggering cancel() on custom OrderState...")
        orderState.cancel() // Changes the atomic value to false
        
        // This order will be safely rejected because isRunning is checked atomically inside the sequence
        orderSequence.receive(Order(id: UUID(), items: ["Pizza"]))
    }
    
    
    
}




await startKitchen()


*/
