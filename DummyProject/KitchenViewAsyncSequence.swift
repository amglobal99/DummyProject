//
//  KitchenViewAsyncSequence.swift
//  DummyProject
//
//  Created by amglobal on 9/14/26.
//

import Foundation
import Observation
import Atomics
import Synchronization

/*


// MARK: - Order Sequence


// 1. Explicitly mark the struct as nonisolated and Sendable so it is legal to pass across Task boundaries.
nonisolated  struct OrderSequence: AsyncSequence, Sendable {
    
    typealias Element = Order
    
    private let channel = OrderChannel()
    
    // 2. Mark this method nonisolated to allow background tasks to initialize the iterator.
    func makeAsyncIterator() -> OrderIterator {
        OrderIterator(channel: channel)
    }
    
    
    //MARK: - Iterator
    
    // 3. Mark the Iterator itself nonisolated
    struct OrderIterator: AsyncIteratorProtocol, Sendable {
        fileprivate var channel: OrderChannel
        
        //MARK: -  Next
        
        nonisolated mutating func next() async -> Order? {
            
            //FIXME: - ************ Change here **********
            await channel.next()
            
            
        }
    }
    
    
    
    // Core actions wrapper methods exposed safely as nonisolated
    nonisolated func yield(_ order: Order) {
        Task { await channel.enqueue(order) }
    }
    
    nonisolated func finish() {
        Task { await channel.finish() }
    }
    
    
    //MARK: -  Order Channel
    
    // The Internal background actor manages actual serialization safely
    fileprivate actor OrderChannel {
        
        private var buffer: [Order] = []
        private var isFinished = false
        private var continuations: [CheckedContinuation<Order?, Never>] = []
        
        //MARK: - Enqueue
        
        func enqueue(_ order: Order) {
            guard !isFinished else { return }
            if !continuations.isEmpty {
                let nextContinuation = continuations.removeFirst()
                nextContinuation.resume(returning: order)
            } else {
                buffer.append(order)
            }
        }
        
        func finish() {
            isFinished = true
            for continuation in continuations {
                continuation.resume(returning: nil)
            }
            continuations.removeAll()
        }
        
        func next() async -> Order? {
            if !buffer.isEmpty {
                return buffer.removeFirst()
            }
            if isFinished {
                return nil
            }
            return await withCheckedContinuation { continuation in
                continuations.append(continuation)
            }
        }
    }
}




// MARK: - Kitchen Manager

@Observable
@MainActor
final class KitchenManager {
    
    var pipelineTask: Task<Void, any Error>?

    var activeOrders: [OrderState] = []
    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    private let kitchen = KitchenActor()
    
    // 1. Replaced AsyncStream with our custom OrderSequence
    private let incomingStream = OrderSequence()
    
    init() {
        startOrderPipeline()
    }
    
    private func startOrderPipeline() {
       // let taskToCancel = self.pipelineTask
        
        // Local reference captures for cancellation isolation boundary rules
        let sequenceToFinish = self.incomingStream
        
        pipelineTask = Task {
            await withTaskCancellationHandler {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        
                        /// ** Task #1 **
                        group.addTask {
                            await withDiscardingTaskGroup { discardingGroup in
                                // 2. Consuming our custom OrderSequence natively
                                for await order in sequenceToFinish {
                                    let orderID = order.id
                                    
                                    await self.appendInitialOrderState(order)
                                    
                                    _ = discardingGroup.addTaskUnlessCancelled {
                                        print("Jack: added task for order \(orderID)")
                                        await self.processOrder(order)
                                    }
                                }
                            }
                        }
                        
                        /// ** Task #2 **
                        group.addTask {
                            try await Task.sleep(for: .seconds(25))
                            print("Jack: ******* Sleep OVER ***********")
                        }
                        
                        try await group.next()
                        print("Jack: will cancel all groups tasks")
                        group.cancelAll()
                        
                        // 3. Manually breaking the loop via our custom sequence finish event
                        sequenceToFinish.finish()
                    }
                } catch {
                    print("Jack: Pipeline task group encountered an error: \(error)")
                }
            } onCancel: {
                print("Jack: pipelineTask cancellation intercepted!")
                // Sequence termination via cancellation handler hook can be executed here if necessary
            }
        }
    }
    
    private func appendInitialOrderState(_ order: Order) async {
        let initialState = OrderState(id: order.id, tableNumber: order.tableNumber, status: "Pending🧑‍🍳", progress: 0.0)
        self.activeOrders.append(initialState)
    }

    private func endShift() {
        // 4. Clean signature cleanly referencing our sequence type
        incomingStream.finish()
    }
    
    isolated deinit {
        pipelineTask?.cancel()
    }
    
    private func processOrder(_ order: Order) async {
        updateStatus(for: order.id, to: "Cooking 🔥", progress: 0.1)
        print("Jack: processOrder - working on tabel number: \(order.tableNumber)")
        
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in order.items {
                    let added = group.addTaskUnlessCancelled {
                        print("Jack: processOrder - will start to cook \(item.name)")
                        try await self.kitchen.cookItem(item) { progress in
                            await self.updateProgress(orderID: order.id, itemProgress: progress, totalItems: order.items.count)
                            print("Jack: processOrder - Completed \(item.name) at table:  \(order.tableNumber)")
                        }
                    }
                    
                    guard added else {
                        print("   Jack: ***** will throw cancel error from guard")
                        throw CancellationError()
                    }
                }
            }
        } catch is CancellationError {
            print("Jack: processOrder - I see a cancellation!")
            updateStatus(for: order.id, to: "Cancelled ❌", progress: 0.0)
        } catch {
            updateStatus(for: order.id, to: "Error ⚠️", progress: 0.0)
        }
    }
    
    func addOrderManually(tableNumber: Int) {
        let burger = MenuItem(name: "Wagyu Burger", preparationTime: 10.0)
        let fries = MenuItem(name: "Truffle Fries", preparationTime: 10.0)
        let shake = MenuItem(name: "Chocolate Shake", preparationTime: 10.0)
        
        let newOrder = Order(tableNumber: tableNumber, items: [burger, fries, shake])
        
        // 5. Pushing order values using our custom sequence yield pipeline wrapper
        incomingStream.yield(newOrder)
    }
    
    func cancelOrder(id: UUID) {
        print("Jack: will cancel order ....")
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)
        pipelineTask?.cancel()
    }
    
    private func updateStatus(for id: UUID, to status: String, progress: Double) {
        if let index = activeOrders.firstIndex(where: { $0.id == id }) {
            print("Jack: .... updateStatus() to: \(status)")
            activeOrders[index].status = status
            activeOrders[index].progress = progress
        }
    }
    
    private func updateProgress(orderID: UUID, itemProgress: Double, totalItems: Int) {
        // Unchanged progression tracking
    }
} // KitchenManager








// MARK: - 2. Kitchen Actor

actor KitchenActor {
    
    /// Simulates cooking a single item with cooperative cancellation
    /// uses a completion handler to send updated completion value
    /// called from **processOrder()**
    func cookItem(_ item: MenuItem, onProgress: @Sendable (Double) async -> Void) async throws {
        let steps = 5
        let stepDuration = item.preparationTime / Double(steps)  /// 10 / 5 = 2
        
        for step in 1...steps {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(stepDuration))
            let currentProgress = Double(step) / Double(steps) ///  1 / 5 = 0.2 ,    2 / 5 = 0.4
            await onProgress(currentProgress)
        }
        
    }
    
    
    
    
    func generateOrder() {
        
    }
    
    
    
} //end Kitchen





// MARK: - 1. Core Data Models
struct MenuItem: Sendable, Hashable {
    let id: UUID = UUID()
    let name: String
    let preparationTime: Double
}

struct Order: Sendable, Identifiable, Hashable {
    let id: UUID = UUID()
    let tableNumber: Int
    let items: [MenuItem]
}

// Visual state tracker for individual orders in the UI
struct OrderState: Identifiable, Sendable, Hashable {
    let id: UUID
    let tableNumber: Int
    var status: String
    var progress: Double // 0.0 to 1.0
}



*/
