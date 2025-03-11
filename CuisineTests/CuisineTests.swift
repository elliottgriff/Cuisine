//
//  CuisineTests.swift
//  CuisineTests
//
//  Created by Elliott Griffin on 3/11/25.
//

import XCTest
@testable import Cuisine

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Request handler is not set")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}

class MockNetworkService: NetworkServiceProtocol {
    var shouldSucceed = true
    var mockRecipes: [Recipe] = [
        Recipe(cuisine: "Italian", name: "Pizza", photoUrlLarge: "https://example.com/large.jpg",
               photoUrlSmall: "https://example.com/small.jpg", uuid: "1", sourceUrl: nil, youtubeUrl: nil),
        Recipe(cuisine: "Mexican", name: "Tacos", photoUrlLarge: "https://example.com/large2.jpg",
               photoUrlSmall: "https://example.com/small2.jpg", uuid: "2", sourceUrl: nil, youtubeUrl: nil)
    ]
    var error: NetworkError?
    
    func fetchRecipes() async throws -> [Recipe] {
        if shouldSucceed {
            return mockRecipes
        } else if let error = error {
            throw error
        } else {
            throw NetworkError.serverError(statusCode: 500)
        }
    }
}

class NetworkServiceTests: XCTestCase {
    var networkService: NetworkService!
    var session: URLSession!
    
    override func setUp() {
        super.setUp()
        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        networkService = NetworkService(baseURL: "https://example.com/recipes.json", session: session)
    }
    
    override func tearDown() {
        networkService = nil
        session = nil
        MockURLProtocol.requestHandler = nil
        
        super.tearDown()
    }
    
    func testFetchRecipesSuccess() async throws {
        let mockResponse = """
        {
            "recipes": [
                {
                    "cuisine": "Italian",
                    "name": "Pasta Carbonara",
                    "photo_url_large": "https://example.com/large.jpg",
                    "photo_url_small": "https://example.com/small.jpg",
                    "uuid": "123e4567-e89b-12d3-a456-426614174000",
                    "source_url": "https://example.com/recipe",
                    "youtube_url": "https://youtube.com/watch?v=123"
                }
            ]
        }
        """
        let data = Data(mockResponse.utf8)
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!,
                                      statusCode: 200,
                                      httpVersion: nil,
                                      headerFields: nil)!
        
        MockURLProtocol.requestHandler = { _ in
            return (response, data)
        }
        
        let recipes = try await networkService.fetchRecipes()
        
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes[0].name, "Pasta Carbonara")
        XCTAssertEqual(recipes[0].cuisine, "Italian")
        XCTAssertEqual(recipes[0].uuid, "123e4567-e89b-12d3-a456-426614174000")
    }
    
    func testFetchRecipesServerError() async {
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!,
                                      statusCode: 500,
                                      httpVersion: nil,
                                      headerFields: nil)!
        
        MockURLProtocol.requestHandler = { _ in
            return (response, Data())
        }
        
        do {
            _ = try await networkService.fetchRecipes()
            XCTFail("Expected server error")
        } catch {
            if case NetworkError.serverError(let statusCode) = error {
                XCTAssertEqual(statusCode, 500)
            } else {
                XCTFail("Expected NetworkError.serverError but got \(error)")
            }
        }
    }
    
    func testFetchRecipesDecodingError() async {
        let invalidData = Data("Invalid JSON".utf8)
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!,
                                      statusCode: 200,
                                      httpVersion: nil,
                                      headerFields: nil)!
        
        MockURLProtocol.requestHandler = { _ in
            return (response, invalidData)
        }
        
        do {
            _ = try await networkService.fetchRecipes()
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? NetworkError, NetworkError.decodingError)
        }
    }
}

class ImageCacheServiceTests: XCTestCase {
    var imageCacheService: ImageCacheService!
    var tempDirectoryURL: URL!
    
    override func setUp() {
        super.setUp()
        
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        
        imageCacheService = ImageCacheService(cacheDirectory: tempDirectoryURL, session: session)
    }
    
    override func tearDown() {
        imageCacheService = nil
        try? FileManager.default.removeItem(at: tempDirectoryURL)
        tempDirectoryURL = nil
        MockURLProtocol.requestHandler = nil
        
        super.tearDown()
    }
    
    func testClearCache() {
        let testImageData = UIImage(systemName: "star")!.pngData()!
        let testFilePath = tempDirectoryURL.appendingPathComponent("test.png")
        try? testImageData.write(to: testFilePath)
        
        imageCacheService.clearCache()
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFilePath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectoryURL.path))
    }
    
    func testLoadImageFromCache() async throws {
        let testUrl = "https://example.com/test-image.jpg"
        let fileName = String(testUrl.hash)
        let fileURL = tempDirectoryURL.appendingPathComponent(fileName)
        
        let testImage = UIImage(systemName: "star")!
        let testImageData = testImage.pngData()!
        try testImageData.write(to: fileURL)
        
        MockURLProtocol.requestHandler = { _ in
            XCTFail("Network request should not be made when image is in cache")
            let response = HTTPURLResponse(url: URL(string: testUrl)!,
                                          statusCode: 200,
                                          httpVersion: nil,
                                          headerFields: nil)!
            return (response, testImageData)
        }
        
        let cachedImage = try await imageCacheService.loadImage(from: testUrl)
        
        XCTAssertNotNil(cachedImage)
    }
}

class RecipeListViewModelTests: XCTestCase {
    var viewModel: RecipeListViewModel!
    var mockNetworkService: MockNetworkService!
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        viewModel = RecipeListViewModel(networkService: mockNetworkService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockNetworkService = nil
        super.tearDown()
    }
    
    @MainActor
    func testLoadRecipesSuccess() async {
        mockNetworkService.shouldSucceed = true
        
        await viewModel.loadRecipes()
        
        if case .loaded(let recipes) = viewModel.state {
            XCTAssertEqual(recipes.count, 2)
            XCTAssertEqual(recipes[0].name, "Pizza")
            XCTAssertEqual(recipes[1].name, "Tacos")
        } else {
            XCTFail("Expected .loaded state, got \(viewModel.state)")
        }
    }
    
    @MainActor
    func testLoadRecipesEmpty() async {
        mockNetworkService.shouldSucceed = true
        mockNetworkService.mockRecipes = []
        
        await viewModel.loadRecipes()
        
        if case .empty = viewModel.state {
        } else {
            XCTFail("Expected .empty state, got \(viewModel.state)")
        }
    }
    
    @MainActor
    func testLoadRecipesError() async {
        mockNetworkService.shouldSucceed = false
        
        await viewModel.loadRecipes()
        
        if case .error = viewModel.state {
        } else {
            XCTFail("Expected .error state, got \(viewModel.state)")
        }
    }
    
    @MainActor
    func testLoadRecipesDecodingError() async {
        mockNetworkService.shouldSucceed = false
        mockNetworkService.error = NetworkError.decodingError
        
        await viewModel.loadRecipes()
        
        if case .error(let message) = viewModel.state {
            XCTAssertTrue(message.contains("malformed"))
        } else {
            XCTFail("Expected .error state, got \(viewModel.state)")
        }
    }
}
