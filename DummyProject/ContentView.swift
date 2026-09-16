//
//  ContentView.swift
//  DummyProject
//
//  Created by amglobal on 8/11/26.
//

import SwiftUI

struct ContentView: View {
    
    @State private var todos: [Todo] = []
    let jackActor = JackActor()
    @State private var isShowingSheet = false
    
    
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .border(/*@START_MENU_TOKEN@*/Color.black/*@END_MENU_TOKEN@*/, width: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/)
                .foregroundStyle(.tint)
            Text("Hello, worlds")
            Button("My Button") {
                Task {
                   // await jackActor.testThis()
                   await performHeavyCalculation()
                }
            }
            
            Button("Open Test View") {
                isShowingSheet = true
            }
            .sheet(isPresented: $isShowingSheet) {
                ParentView()
            }
            
            
            
        }
        .task {
            let myTodos = await jackActor.loadTodos(url: "https://jsonplaceholder.typicode.com/todos")
            todos = myTodos ?? []
        }
        .padding()
    }
    
    
    
    
    func performHeavyCalculation() async {
        // 1. Suspend immediately to jump from the caller's thread to the background pool
        await Task.yield()
        
        MainActor.assertIsolated("\(#function) -  This is NOT running on the Main Actor!")
        
        // 2. Perform CPU-heavy work safely in the background
        let result = (1...1_000_000).map { $0 * 2 }
        print(result.count)
    }
    
} // struct ContentView







//MARK: - Actor

actor JackActor {
    
    nonisolated(nonsending) func loadTodos(url: String) async  -> [Todo]? {
        
        MainActor.assertIsolated("\(#function) -  This is NOT running on the Main Actor!")
        print("JackActor -loadTodos - starting ...")
        
        
        do {
            guard let url = URL(string: url) else { return nil }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Jack: Invalid response or status code")
                return nil
            }
            let decoder = JSONDecoder()
            let codes = try decoder.decode([Todo].self, from: data)
            //print("Jack: codes: \(codes)")
            return codes
        }catch {
            print("we have an error")
        }
        
        return []
    }
    
    
    
    nonisolated func testThis() async {
        print("tapped ...")
        MainActor.assertIsolated("This must run on MAIN actor ...")
    
    }
    

  
    
} //end TesterJack






























public class Todo: Decodable {
    var id: Int
    var userId: Int
    var title: String
    var completed: Bool
}



extension Todo: Equatable, Hashable {
    
    public static func == (lhs: Todo, rhs: Todo) -> Bool {
        return lhs.id == rhs.id &&
        lhs.userId == rhs.userId
    }
    
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(userId)
    }
    
}







nonisolated func getPhysicalThread() -> Thread {
    return Thread.current
}


nonisolated func isMainThread() -> Bool {
    return Thread.isMainThread
}





#Preview {
    ContentView()
}
