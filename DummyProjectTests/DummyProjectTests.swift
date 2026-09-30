//
//  DummyProjectTests.swift
//  DummyProjectTests
//
//  Created by amglobal on 9/29/26.
//

import Testing
import Foundation
@testable import DummyProject


// Write your test here and use APIs like `#expect(...)` to check expected conditions.
// Swift Testing Documentation
// https://developer.apple.com/documentation/testing

struct DummyProjectTests {
    
    let nwManager = NetworkManager()
    
    
    enum MyError: Error {
        case networkCallFailed
        case routerDown
    }
    
    class NetworkManager {
        
        func fetchData(url: String) async  throws -> Data? {
            guard let url = URL(string: url) else { return nil }
            let (data,_) = try await URLSession.shared.data(from: url)
            return data
        }
        
        func fetchDataWithNetworkFailure() async throws {
            throw MyError.routerDown
        }
    
        func fetchDataResponse(url: String) async  throws -> (Data, URLResponse) {
            guard let url = URL(string: url) else {
                throw URLError(.badURL)
            }
            let (data,response) = try await URLSession.shared.data(from: url)
            return (data,response)
        }
        
    }
    
    
    
    @Test
    func example() async throws {
        
    }
    
    
    @Test("Get URL Data")
    func getWebData() async throws {
        let nwManager = NetworkManager()
        let data = try await nwManager.fetchData(url: "https://httpbin.org/get")
        
        let unwrappedValue = try #require(data)
        #expect(!unwrappedValue.isEmpty)
    }
    
    @Test("Verify HTTP code 200")
    func verifyHTTPSuccessCode() async throws {
        let (data,response) = try await nwManager.fetchDataResponse(url: "https://httpbin.org/get")
        
        // 3. Assert (Cast to HTTPURLResponse and verify status code)
        let httpResponse = try #require(response as? HTTPURLResponse, "Response was not an HTTPURLResponse")
        #expect(httpResponse.statusCode == 200, "Expected status code 200, but got \(httpResponse.statusCode)")
    }
    
    
    
    @Test("Wll Fail Test") func testWillFail() {
        print("running failing test")
        #expect(1 == 2, "This test will always fail")
      }
    
    

    
    @Test("Validate network fails")
    func throwErrorOnNetworkFailure() async {
        await #expect(throws: MyError.networkCallFailed, "A MyError should be thrown when the network fails") {
            try await nwManager.fetchDataWithNetworkFailure()
        }
    }
    
    
    
    
    
    
} // DummyProjectTests
