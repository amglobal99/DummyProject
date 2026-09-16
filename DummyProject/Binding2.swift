//
//  Binding2.swift
//  DummyProject
//
//  Created by amglobal on 8/12/26.
//

import Foundation
import Observation
import SwiftUI


@Observable
class UserProfile {
    var username: String = "John Doe"
    var age: Int = 0
}



// 2. Parent View that creates and owns the single source of truth
struct ParentView2: View {
    // Use @State to instantiate and keep the observable object alive
    @State private var profile = UserProfile()
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Parent View Display:")
                .font(.headline)
            Text(profile.username)
                .font(.title2)
                .foregroundColor(.blue)
            Text(profile.age.description)
                .font(.title2)
                .foregroundColor(.blue)
            
            Spacer()
            
            // Pass the observable object reference down to the child view
            ChildEditView(profile: profile)
            Spacer()
        }
        .padding()
    }
}


// 3. Child View that creates a two-way binding to the object's properties
struct ChildEditView: View {
    // Use @Bindable to enable the '$' syntax for two-way bindings
    @Bindable var profile: UserProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Child Edit View:")
                .font(.headline)
            
            // The '$' symbol directly binds the TextField to the model property
            TextField("Edit Username", text: $profile.username)
                .textFieldStyle(.roundedBorder)
            TextField("Enter your age", value: $profile.age, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad) // Limits keyboard to numbers
                            .padding()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}


// 3. Preview provider to run in Xcode
#Preview {
    ParentView2()
}


