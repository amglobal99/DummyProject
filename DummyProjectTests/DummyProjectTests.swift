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

 @Suite("Dummy Project")
struct DummyProjectTests {
    
    
    @Suite("Feature 1 Tests")
    class Feature1Tests {
        
        let nwManager = NetworkManager()
        let testerURL = "https://httpbin.org/get"
        
        
        init() {
            print("**** doing setup ...")
        }
        
        deinit {
            print("****** doing deinit ...")
        }
        
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
                throw MyError.networkCallFailed
            }
            
            func fetchDataResponse(url: String) async  throws -> (Data, URLResponse) {
                guard let url = URL(string: url) else {
                    throw URLError(.badURL)
                }
                let (data,response) = try await URLSession.shared.data(from: url)
                return (data,response)
            }
            
        }
        
        
        
        @Test("Example")
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
            let (_,response) = try await nwManager.fetchDataResponse(url: testerURL)
            
            // 3. Assert (Cast to HTTPURLResponse and verify status code)
            let httpResponse = try #require(response as? HTTPURLResponse, "Response was not an HTTPURLResponse")
            #expect(httpResponse.statusCode == 200, "Expected status code 200, but got \(httpResponse.statusCode)")
        }
        
        
        
        @Test("Wll Fail Test", .disabled())
        func testWillFail() {
            print("running failing test")
            #expect(1 == 2, "This test will always fail")
        }
        
        
        
        
        @Test("Validate network fails")
        func throwErrorOnNetworkFailure() async {
            await #expect(throws: MyError.networkCallFailed, "A MyError should be thrown when the network fails") {
                try await nwManager.fetchDataWithNetworkFailure()
            }
        }
        
        
    } //Feature1 Tests
    
    
    



@Suite("Protocol Based Tests")
struct ProtocolBasedTests {
    
    // 1. Define the abstraction
    protocol APIClientProtocol {
        func fetchData(url: String) async throws -> String
    }

    // 2. Wrap the real production logic
    struct ProductionAPIClient: APIClientProtocol {
        
        func fetchData(url: String) async throws -> String {
            return "jack"
        }
        
    }
    
    // 3. Create the mock for testing
    struct MockAPIClient: APIClientProtocol {
        
        var resultToReturn: String = "Mocked Data"
        
        func fetchData(url: String) async throws -> String {
            return resultToReturn
        }
    }
    
    
    
        
//        func fetchData(url: String) async  throws -> String {
//            guard let url = URL(string: url) else { return "url bad" }
//            let (data,_) = try await URLSession.shared.data(from: url)
//            let str = String(decoding: data, as: UTF8.self)
//            return str
//        }
//        
//        
//        func fetchDataResponse(url: String) async  throws -> (Data, URLResponse) {
//            guard let url = URL(string: url) else {
//                throw URLError(.badURL)
//            }
//            let (data,response) = try await URLSession.shared.data(from: url)
//            return (data,response)
//        }
        
    
    
    @Test("Get URL String")
    func getURLData() async throws {
        let mock = MockAPIClient()
        let str = try await mock.fetchData(url: "https://httpbin.org/get")
        #expect(str.contains("origin"), "the string does not contain 'origin'")
    }
    
} //end suite


    
    
    @Suite("Mock Service Tests")
    struct MockServiceTests {
        
        // 1. The abstraction interface
        protocol NetworkService {
            func fetchUserData(userId: String) async throws -> String
        }
        
        class MockNetworkService: NetworkService {
            // Properties to control behavior (Stubbing)
            var stubbedResult: Result<String, Error> = .success("Mock User")
            
            // Properties to record interaction (Spying)
            var fetchUserDataCalledCount = 0
            var passedUserId: String?
            
            func fetchUserData(userId: String) async throws -> String {
                fetchUserDataCalledCount += 1
                passedUserId = userId
                
                switch stubbedResult {
                case .success(let value):
                    return value
                case .failure(let error):
                    throw error
                }
            }
        }
        
        
        // 2. The production component using Dependency Injection
        struct UserManager {
            private let networkService: NetworkService
            
            // Inject the service via the initializer
            init(networkService: NetworkService) {
                self.networkService = networkService
            }
            
            func getUserGreeting(id: String) async -> String {
                do {
                    let name = try await networkService.fetchUserData(userId: id)
                    return "Hello, \(name)!"
                } catch {
                    return "Hello, Guest!"
                }
            }
        }
        
        
        
        @Test func greetingReturnsSuccessWhenNetworkSucceeds() async {
            // Arrange
            let mockService = MockNetworkService()
            mockService.stubbedResult = .success("Alice")
            let sut = UserManager(networkService: mockService)
            
            // Act
            let greeting = await sut.getUserGreeting(id: "123")
            
            // Assert
            #expect(greeting == "Hello, Alice!")
            #expect(mockService.fetchUserDataCalledCount == 1)
            #expect(mockService.passedUserId == "123")
        }
        
        @Test func greetingReturnsGuestWhenNetworkFails() async {
            // Arrange
            let mockService = MockNetworkService()
            mockService.stubbedResult = .failure(URLError(.badServerResponse))
            let sut = UserManager(networkService: mockService)
            
            // Act
            let greeting = await sut.getUserGreeting(id: "123")
            
            // Assert
            #expect(greeting == "Hello, Guest!")
        }
        
        
    }
    

    
} // DummyProjectTests


