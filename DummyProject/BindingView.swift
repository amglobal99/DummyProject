//
//  BindingView.swift
//  DummyProject
//
//  Created by amglobal on 8/12/26.
//

import Foundation
import SwiftUI




// 1. The Parent View owns the source of truth using @State
struct ParentView: View {
    @State private var isOn: Bool = false //
    
    var body: some View {
        VStack(spacing: 50) {
        Text("Parent is-on value: \(isOn.description)")
            
            // Pass a binding using the $ prefix
            ChildView(isOn: $isOn) //
        }
        .padding()
    }
}

// 2. The Child View accepts the value using @Binding
struct ChildView: View {
    @Binding var isOn: Bool //

    var body: some View {
        Toggle("Switch from Child", isOn: $isOn) //
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}






// 3. Preview provider to run in Xcode
#Preview {
    ParentView()
}
