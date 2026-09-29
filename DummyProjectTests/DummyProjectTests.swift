//
//  DummyProjectTests.swift
//  DummyProjectTests
//
//  Created by amglobal on 9/29/26.
//

import Testing
import Foundation

// Write your test here and use APIs like `#expect(...)` to check expected conditions.
// Swift Testing Documentation
// https://developer.apple.com/documentation/testing

struct DummyProjectTests {
    
    @Test
    func example() async throws {
        
    }
    
    
    @Test("A Sample Test")
    func getWebData() async throws {
        let nwManager = NetworkManager()
        let data = try await nwManager.fetchData(url: "https://httpbin.org/get")
        
        let unwrappedValue = try #require(data)
        #expect(!unwrappedValue.isEmpty)
    }
    
    
    
    class NetworkManager {
        
        func fetchData(url: String) async  throws -> Data? {
            guard let url = URL(string: url) else { return nil }
            let (data,_) = try await URLSession.shared.data(from: url)
            return data
        }
    }
    
    
    
    
//    @Test("Wll Fail Test") func testWillFail() {
//        print("running failing test")
//        #expect(1 == 2, "This test will always fail")
//      }
//    
    
    
    
} // DummyProjectTests
