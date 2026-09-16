//
//  KitchenView.swift
//  DummyProject
//
//  Created by amglobal on 8/31/26.
//

import SwiftUI


/*

// MARK: - 4. SwiftUI Interface
struct KitchenView: View {
    @State private var manager = RestaurantManager()
    
    var body: some View {
        NavigationStack {
            List(manager.activeOrders) { order in
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Table \(order.tableNumber)")
                            .font(.headline)
                        Text("Status: \(order.status)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        ProgressView(value: order.progress)
                            .animation(.linear, value: order.progress)
                    }
                    
                    Spacer()
                    
                    if order.status == "Cooking 🔥" || order.status == "Pending🧑‍🍳" {
                        Button(role: .destructive) {
                            manager.cancelOrder(id: order.id)
                        } label: {
                            Image(systemName: "multiply.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Parallel Kitchen")
            .toolbar {
                Button("Open Kitchen Flow") {
                    manager.startOrderPipeline()
                }
                .disabled(!manager.activeOrders.isEmpty)
            }
        }
    }
}


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




// MARK: - 2. Kitchen Actor

actor Kitchen {
    
    // Simulates cooking a single item with cooperative cancellation
    func cookItem(_ item: MenuItem, onProgress: @Sendable (Double) async -> Void) async throws {
        let steps = 10
        let stepDuration = item.preparationTime / Double(steps)
        
        for step in 1...steps {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(stepDuration))
            
            let currentProgress = Double(step) / Double(steps)
            await onProgress(currentProgress)
        }
    }
}



// MARK: - 3. Observable View Model (MainActor Bound)

@Observable
@MainActor
final class RestaurantManager {
    // UI-bound state arrays
    var activeOrders: [OrderState] = []
    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    
    private let kitchen = Kitchen()
    
    // Simulates a continuous stream of incoming tickets
    func startOrderPipeline() {
        Task {
            let incomingStream = AsyncStream<Order> { continuation in
                Task {
                    let burger = MenuItem(name: "Wagyu Burger", preparationTime: 3.0)
                    let fries = MenuItem(name: "Truffle Fries", preparationTime: 1.5)
                    let shake = MenuItem(name: "Chocolate Shake", preparationTime: 2.0)
                    
                    for table in 1...5 {
                        try? await Task.sleep(for: .seconds(1.2)) // New order arriving every ~1.2s
                        let order = Order(tableNumber: table, items: [burger, fries, shake])
                        continuation.yield(order)
                    }
                    continuation.finish()
                }
            }
            
            // CONCURRENT PROCESSING LOOP
            for await order in incomingStream {
                let orderID = order.id
                
                // Add to UI immediately
                let initialState = OrderState(id: orderID, tableNumber: order.tableNumber, status: "Pending🧑‍🍳", progress: 0.0)
                activeOrders.append(initialState)
                
                // CRITICAL: Fire-and-forget a separate Task per order.
                // This ensures orders process in parallel without waiting turn-by-turn.
                let orderTask = Task {
                    await self.processOrderConcurrently(order)
                }
                
                // Track task reference to allow UI manual cancellations
                runningTasks[orderID] = orderTask
            }
        }
    }
    
    
    
    
    
    
    
    
    
    private func processOrderConcurrently(_ order: Order) async {
        updateStatus(for: order.id, to: "Cooking 🔥", progress: 0.1)
        
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in order.items {
                    group.addTask {
                        // Concurrent subtask for cooking each item
                        try await self.kitchen.cookItem(item) { progress in
                            // Item reporting progress safely back to MainActor view model
                            await self.updateProgressFromActor(orderID: order.id, itemProgress: progress, totalItems: order.items.count)
                        }
                    }
                }
                try await group.waitForAll()
            }
            
            updateStatus(for: order.id, to: "Ready 🛎️", progress: 1.0)
            runningTasks.removeValue(forKey: order.id)
            
        } catch is CancellationError {
            updateStatus(for: order.id, to: "Cancelled ❌", progress: 0.0)
        } catch {
            updateStatus(for: order.id, to: "Error ⚠️", progress: 0.0)
        }
    }
    
    // Safe UI cancellation trigger
    func cancelOrder(id: UUID) {
        runningTasks[id]?.cancel()
        runningTasks.removeValue(forKey: id)
    }
    
    // MARK: - State Mutators (MainActor guaranteed)
    private func updateStatus(for id: UUID, to status: String, progress: Double) {
        if let index = activeOrders.firstIndex(where: { $0.id == id }) {
            activeOrders[index].status = status
            activeOrders[index].progress = progress
        }
    }
    
    private func updateProgressFromActor(orderID: UUID, itemProgress: Double, totalItems: Int) {
        if let index = activeOrders.firstIndex(where: { $0.id == orderID }) {
            // Aggregate child progress loops mathematically for smooth bar progression
            let currentProgress = activeOrders[index].progress
            let incrementalProgress = (itemProgress / Double(totalItems)) * 0.1
            activeOrders[index].progress = min(0.95, currentProgress + incrementalProgress)
        }
    }
} //class




*/













/*

#Preview {
    KitchenView()
}


*/
