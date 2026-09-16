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

nonisolated func logWarning(_ message: String) {
    let timestamp = Date().formatted(
        Date.FormatStyle()
            .hour()
            .minute()
            .second(.twoDigits)
            .secondFraction(.fractional(4))
    )
    
    print("[\(timestamp)] \(message)")
}




// MARK: - Synchronized State Machine

/// A state machine that handles states synchronously to preserve cancellation order.
// 1. Explicitly marking the class nonisolated cuts it completely free from @MainActor tracking.
nonisolated final class KitchenStateMachine: @unchecked Sendable {
    
    private enum State {
        case idle
        case active(AsyncStream<KitchenOrder>.Continuation)
        case cancelled
    }
    
    private let lock = NSLock()
    private var state: State = .idle
    
    
    /// Switches state to active and returns the associated stream
    func createStream() -> AsyncStream<KitchenOrder> {
        lock.lock()
        
        defer {
            lock.unlock()
        }
        
        // If already cancelled or active, clean up old state first
        if case .active(let oldContinuation) = state {
            oldContinuation.finish()
        }
        
        let (stream, continuation) = AsyncStream.makeStream(of: KitchenOrder.self)
        
        if case .cancelled = state {
            // If the system was already cancelled before starting, terminate immediately
            continuation.finish()
        } else {
            state = .active(continuation)
        }
        
        /// Termination
        continuation.onTermination = { termination in
            logWarning("🤡 continuation .onTermination block")
            switch termination {
            case .finished:
                logWarning("  ⚡️ .onTermination == .finished")
            case .cancelled:
                logWarning("  ⚡️ .onTermination == .cancelled, cleaning up...")
            @unknown default:
                logWarning("  ⚡️ Stream status: \(termination)")
                break
            }
        }
        
        /// return stream
        return stream
    }
    
    
    
    /// Synchronously yields an item if the state is active
    func yieldOrder(_ order: KitchenOrder) {
        lock.lock()
        defer { lock.unlock() }
        
        // ***** HERE, WE CHECK IF TASK IS ALREADY CACELLED
        if case .active(let continuation) = state {
            continuation.yield(order)
        }
    }
    
    
    /// Synchronously transitions to cancelled and instantly terminates the stream
    /// callled from **onCancel:** block of Task
    func cancelAndFinish() {
        logWarning("   🧼 State Machine: cancelAndFinish() - state: \(state)")
        lock.lock()
        
        defer { lock.unlock() }
        
        if case .active(let continuation) = state {
            continuation.finish() // Triggers IMMEDIATELY on the current thread
            logWarning("   🧼 State Machine: continuation.finish() completed  synchronously.")
        }
        state = .cancelled
    }
    
    
    
    /// Reset back to idle to allow restarting the kitchen system
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        state = .idle
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
                //stateMachine.cancelAndFinish()
            } onCancel: {
                logWarning("🧵 .onCancel block in Processing Task")
                // This executes synchronously on the cancellation thread,
                // stopping the stream instantly and guaranteeing order.
                stateMachine.cancelAndFinish()
            }
            
        }
        

        
        // Simulate immediate orders
        submitOrder(name: "Tacos")
        //submitOrder(name: "Burgers")
    } //func startMachine
    

    
    func submitOrder(name: String) {
        let order = KitchenOrder(id: orderCounter, dishName: name)
        orderCounter += 1
        stateMachine.yieldOrder(order)
    }
    
    func cancelSystem() {
        log("⏰ Closing time requested!")
        logWarning("⏰ Close Kitchen Tapped - will call Task.cancel()")
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
                        }
                        .onChange(of: viewModel.logs.count) { _, _ in
                            if let lastIndex = viewModel.logs.indices.last {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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
