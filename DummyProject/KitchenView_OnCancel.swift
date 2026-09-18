//
//  KitchenView_OnCancel.swift
//  DummyProject
//
//  Created by amglobal on 9/15/26.
//

/// search 1. swift withTaskCancellationHandler
/// 2. expand above example ... show how the task gets cancelled
///  3. where is the lock getting unlocked ?
///  4. how do I apply this withTaskCancellationHandler to my example where I process kitchen Order s as an AsyncStream .... what happens if onCancel gets triggered when task is waiting for next order
///  5. how do I call this example to run
///   6.
import Foundation
import SwiftUI
import Synchronization


nonisolated func logWarning(_ message: String) {
    let now = Date()
    
    // 1. Get the base time string (HH:mm:ss)
    let baseTime = now.formatted(Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
    
    // 2. Extract microseconds from nanoseconds
    let nanoseconds = Calendar.current.component(.nanosecond, from: now)
    let microseconds = nanoseconds / 1000
    
    // 3. Print combined log
    print("\(baseTime).\(String(format: "%06d", microseconds)) - \(message)")
}



// MARK: - Synchronized State Machine

/// A state machine that handles states synchronously to preserve cancellation order.
// 1. Explicitly marking the class nonisolated cuts it completely free from @MainActor tracking.


nonisolated final class KitchenStateMachine: Sendable {
    
    private enum State: Equatable {
        case idle
        case active(AsyncStream<KitchenOrder>.Continuation)
        case cancelled
        
        var description: String {
            switch self {
            case .idle:
                return "idle"
            case .active(_):
                return "active"
            case .cancelled:
                return "cancelled"
            }
        }
    }
    
    // Mutex explicitly wraps the mutable state it protects
    private let protectedState = Mutex<State>(.idle)
    
    /// Switches state to active and returns the associated stream
    func createStream() -> AsyncStream<KitchenOrder> {
        let (stream, continuation) = AsyncStream.makeStream(of: KitchenOrder.self)
        
        // Use withLock to safely access and modify the state
        protectedState.withLock { state in
            // If already cancelled or active, clean up old state first
            if case .active(let oldContinuation) = state {
                oldContinuation.finish()
            }
            
            if case .cancelled = state {
                // If the system was already cancelled before starting, terminate immediately
                continuation.finish()
            } else {
                state = .active(continuation)
            }
        }
        
        /// Termination
        continuation.onTermination = { [weak self] termination in
            logWarning("🤡 continuation .onTermination block")
            switch termination {
            case .finished:
                logWarning("  ⚡️ .onTermination continuation == .finished")
            case .cancelled:
                logWarning("  ⚡️ .onTermination continuation == .cancelled, cleaning up...")
                self?.cancelAndFinish()
            @unknown default:
                logWarning("  ⚡️ Stream status: continuation == \(termination)")
                break
            }
        }
        
        /// return stream
        return stream
    }


/// Synchronously yields an item if the state is active
    func yieldOrder(_ order: KitchenOrder) {
        protectedState.withLock { state in
            if case .active(let continuation) = state {
                continuation.yield(order)
            }
        }
    }
    
    /// Synchronously transitions to cancelled and instantly terminates the stream
    /// called from **onCancel:** block of Task
    func cancelAndFinish() {
        // Read state before lock only for logging, or shift log after to be data-race safe
        protectedState.withLock { state in
            logWarning("   🧼 State Machine: cancelAndFinish() - CURRENT state: \(state.description)")
            
            guard state != .cancelled else {
                logWarning("   🧼 State Machine: it is already .cancelled")
                return
            }
            
            if case .active(let continuation) = state {
                continuation.finish() // Triggers IMMEDIATELY on the current thread
                logWarning("   🧼 State Machine: continuation.finish() completed synchronously.")
            }
            state = .cancelled
        }
    }
    
    
    
    
    /// Reset back to idle to allow restarting the kitchen system
    func reset() {
        protectedState.withLock { state in
            state = .idle
        }
    }

}



// MARK: - View Model

@Observable
@MainActor
class KitchenViewModel {
    
    var logs: [String] = []
    private var processingTask: Task<Void, Never>?
    private let stateMachine = KitchenStateMachine()
    private var orderCounter = 101
    
    
    //MARK: - Start System
    
    func startSystem()  {
        stateMachine.reset()
        
        print(" *****************************************************")
        log("--- Order System Starting ---")
        
        // Generate the stream from our synchronized state machine
        let stream = stateMachine.createStream()
        
        

        //MARK: - ******** TASK **************
        
        /// wehn Task below gets cancelled,
        /// The **.onTermination ** block triggers first because the for await loop is suspended waiting on the stream.
        /// When you call Task.cancel(), the Swift concurrency runtime first notifies the active stream iterator,
        /// invoking its internal cancellation mechanism and triggering .onTermination before the
        /// outer ** onCancel block **  of your withTaskCancellationHandler can run

         processingTask = Task {
            await withTaskCancellationHandler {
                 log("👩‍🍳 Chef is Ready...")
                 
                 for await order in stream {
                     if Task.isCancelled { break }
                     
                     log("🍳 Cooking Order #\(order.id): \(order.dishName)")
                     try? await Task.sleep(for: .seconds(5))
                     log("🍳 Completed: \(order.dishName)")
                 }
                 log("👩‍🍳 Operation OVER. Closed")
                 logWarning("👩‍🍳 Operation OVER. Closed")
                
            } onCancel: {
                // This executes synchronously on the cancellation thread,stopping the stream instantly and guaranteeing order.
                logWarning("🧵 .onCancel block in Processing Task")
                stateMachine.cancelAndFinish()
            }
             
         }
         
        
        // Simulate immediate orders
        submitOrder(name: "Tacos")
        submitOrder(name: "Burgers")
    } //func startMachine
    

    
    func submitOrder(name: String) {
        let order = KitchenOrder(id: orderCounter, dishName: name)
        orderCounter += 1
        stateMachine.yieldOrder(order)
    }
    
    func cancelSystem() {
        log("⏰ Closing time requested!")
        logWarning("⏰ Close Kitchen Button Tapped - will call Task.cancel()")
        processingTask?.cancel()
        processingTask = nil
    }
    
    
    public func log(_ message: String) {
        logs.append(message)
    }
}



// MARK: - SwiftUI View

struct KitchenView: View {
    @State private var viewModel = KitchenViewModel()
    @State private var customDish: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Control Buttons
                HStack(spacing: 16) {
                    Button(action: { viewModel.startSystem() }) {
                        Label("Open Kitchen", systemImage: "play.fill")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.gradient)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button(action: { viewModel.cancelSystem() }) {
                        Label("Close Kitchen", systemImage: "stop.fill")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.gradient)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                // Add Custom Order Input
                HStack {
                    TextField("Enter dish name...", text: $customDish)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Send Order") {
                        guard !customDish.isEmpty else { return }
                        viewModel.submitOrder(name: customDish)
                        customDish = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                
                // Live Stream Logs Display
                VStack(alignment: .leading) {
                    Text("Kitchen Logs")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(viewModel.logs.indices, id: \.self) { index in
                                    Text(viewModel.logs[index])
                                        .font(.system(.body, design: .monospaced))
                                        .id(index)
                                }
                            }
                        } // Scroll View
                        .onChange(of: viewModel.logs.count) { _, _ in
                            if let lastIndex = viewModel.logs.indices.last {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    } // ScrollViewReader
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } // Vstack
            .padding()
            .navigationTitle("Order Streamer")
        }
    }
}



// MARK: - Model

struct KitchenOrder: Sendable, Identifiable {
    let id: Int
    let dishName: String
}




#Preview {
    KitchenView()
}
