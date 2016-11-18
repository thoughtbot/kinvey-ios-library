//
//  NetworkStoreTests.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-15.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import XCTest
@testable import Kinvey

class NetworkStoreTests: StoreTestCase {
    
    override func setUp() {
        super.setUp()
        signUp()
        
        store = DataStore<Person>.collection()
    }
    
    override func assertThread() {
        XCTAssertTrue(NSThread.isMainThread())
    }
    
    func testSaveEvent() {
        let store = DataStore<Event>.collection(.Network)
        
        let event = Event()
        event.name = "Friday Party!"
        event.date = NSDate(timeIntervalSince1970: 1468001397) // Fri, 08 Jul 2016 18:09:57 GMT
        event.location = "The closest pub!"
        
        event.acl?.globalRead.value = true
        event.acl?.globalWrite.value = true
        
        do {
            weak var expectationCreate = expectationWithDescription("Create")
            
            let request = store.save(event) { event, error in
                XCTAssertNotNil(event)
                XCTAssertNil(error)
                
                expectationCreate?.fulfill()
            }
            
            var uploadProgressCount = 0
            var uploadProgressSent: Int64? = nil
            var uploadProgressTotal: Int64? = nil
            
            var downloadProgressCount = 0
            var downloadProgressSent: Int64? = nil
            var downloadProgressTotal: Int64? = nil
            
            request.progress = {
                XCTAssertTrue(NSThread.isMainThread())
                if $0.countOfBytesSent == $0.countOfBytesExpectedToSend && $0.countOfBytesExpectedToReceive > 0 {
                    if downloadProgressCount == 0 {
                        downloadProgressSent = $0.countOfBytesReceived
                        downloadProgressTotal = $0.countOfBytesExpectedToReceive
                    } else {
                        XCTAssertEqual(downloadProgressTotal, $0.countOfBytesExpectedToReceive)
                        XCTAssertGreaterThan($0.countOfBytesReceived, downloadProgressSent!)
                        downloadProgressSent = $0.countOfBytesReceived
                    }
                    downloadProgressCount += 1
                    print("Download: \($0.countOfBytesReceived)/\($0.countOfBytesExpectedToReceive)")
                } else {
                    if uploadProgressCount == 0 {
                        uploadProgressSent = $0.countOfBytesSent
                        uploadProgressTotal = $0.countOfBytesExpectedToSend
                    } else {
                        XCTAssertEqual(uploadProgressTotal, $0.countOfBytesExpectedToSend)
                        XCTAssertGreaterThan($0.countOfBytesSent, uploadProgressSent!)
                        uploadProgressSent = $0.countOfBytesSent
                    }
                    uploadProgressCount += 1
                    print("Upload: \($0.countOfBytesSent)/\($0.countOfBytesExpectedToSend)")
                }
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationCreate = nil
            }
            
            XCTAssertGreaterThan(uploadProgressCount, 0)
            XCTAssertGreaterThan(downloadProgressCount, 0)
        }
        
        do {
            class DelayURLProtocol: NSURLProtocol {
                
                static var delay: NSTimeInterval?
                
                let urlSession = NSURLSession()
                
                override class func canInitWithRequest(request: NSURLRequest) -> Bool {
                    return true
                }
                
                override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
                    return request
                }
                
                override func startLoading() {
                    if let delay = DelayURLProtocol.delay {
                        NSThread.sleepForTimeInterval(delay)
                    }
                    
                    let dataTask = urlSession.dataTaskWithRequest(request) { data, response, error in
                        self.client?.URLProtocol(self, didReceiveResponse: response!, cacheStoragePolicy: .NotAllowed)
                        self.client?.URLProtocol(self, didLoadData: data!)
                        if let delay = DelayURLProtocol.delay {
                            NSThread.sleepForTimeInterval(delay)
                        }
                        self.client?.URLProtocolDidFinishLoading(self)
                    }
                    dataTask.resume()
                }
                
                override func stopLoading() {
                }
                
            }
            
            DelayURLProtocol.delay = 1
            
            setURLProtocol(DelayURLProtocol.self)
            defer {
                setURLProtocol(nil)
            }
            
            weak var expectationFind = expectationWithDescription("Find")
            
            let request = store.find() { (events, error) in
                XCTAssertTrue(NSThread.isMainThread())
                XCTAssertNotNil(events)
                XCTAssertNil(error)
                
                expectationFind?.fulfill()
            }
            
            var downloadProgressCount = 0
            var downloadProgressSent: Int64? = nil
            var downloadProgressTotal: Int64? = nil
            request.progress = {
                XCTAssertTrue(NSThread.isMainThread())
                if downloadProgressCount == 0 {
                    downloadProgressSent = $0.countOfBytesReceived
                    downloadProgressTotal = $0.countOfBytesExpectedToReceive
                } else {
                    XCTAssertEqual(downloadProgressTotal, $0.countOfBytesExpectedToReceive)
                    XCTAssertGreaterThan($0.countOfBytesReceived, downloadProgressSent!)
                    downloadProgressSent = $0.countOfBytesReceived
                }
                downloadProgressCount += 1
                print("Download: \($0.countOfBytesReceived)/\($0.countOfBytesExpectedToReceive)")
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationFind = nil
            }
            
            XCTAssertGreaterThan(downloadProgressCount, 0)
        }
    }
    
    func testSaveAddress() {
        let person = Person()
        person.name = "Victor Barros"
        
        let address = Address()
        address.city = "Vancouver"
        
        person.address = address
        
        weak var expectationSave = expectationWithDescription("Save")
        
        store.save(person, writePolicy: .ForceNetwork) { person, error in
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            if let person = person {
                XCTAssertNotNil(person.address)
                
                if let address = person.address {
                    XCTAssertNotNil(address.city)
                }
            }
            
            expectationSave?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationSave = nil
        }
    }
    
    func testCount() {
        let store = DataStore<Event>.collection(.Network)
        
        var eventsCount: UInt? = nil
        
        do {
            weak var expectationCount = expectationWithDescription("Count")
            
            store.count { (count, error) in
                XCTAssertNotNil(count)
                XCTAssertNil(error)
                
                if let count = count {
                    eventsCount = count
                }
                
                expectationCount?.fulfill()
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationCount = nil
            }
        }
        
        XCTAssertNotNil(eventsCount)
        
        do {
            let event = Event()
            event.name = "Friday Party!"
            
            weak var expectationCreate = expectationWithDescription("Create")
            
            store.save(event) { event, error in
                XCTAssertNotNil(event)
                XCTAssertNil(error)
                
                expectationCreate?.fulfill()
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationCreate = nil
            }
        }
        
        do {
            weak var expectationCount = expectationWithDescription("Count")
            
            store.count { (count, error) in
                XCTAssertNotNil(count)
                XCTAssertNil(error)
                
                if let eventsCount = eventsCount, let count = count {
                    XCTAssertEqual(eventsCount + 1, count)
                }
                
                expectationCount?.fulfill()
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationCount = nil
            }
        }
    }
    
    func testSaveAndFind10SkipLimit() {
        XCTAssertNotNil(Kinvey.sharedClient.activeUser)
        
        guard let user = Kinvey.sharedClient.activeUser else {
            return
        }
        
        var i = 0
        
        measureBlock {
            let person = Person {
                $0.name = "Person \(i)"
            }
            
            weak var expectationSave = self.expectationWithDescription("Save")
            
            self.store.save(person, writePolicy: .ForceNetwork) { person, error in
                XCTAssertNotNil(person)
                XCTAssertNil(error)
                
                expectationSave?.fulfill()
            }
            
            self.waitForExpectationsWithTimeout(self.defaultTimeout) { error in
                expectationSave = nil
            }
            
            i += 1
        }
        
        var skip = 0
        let limit = 2
        
        for _ in 0 ..< 5 {
            weak var expectationFind = expectationWithDescription("Find")
            
            let query = Query {
                $0.predicate = NSPredicate(format: "acl.creator == %@", user.userId)
                $0.skip = skip
                $0.limit = limit
                $0.ascending("name")
            }
            
            store.find(query, readPolicy: .ForceNetwork) { results, error in
                XCTAssertNotNil(results)
                XCTAssertNil(error)
                
                if let results = results {
                    XCTAssertEqual(results.count, limit)
                    
                    XCTAssertNotNil(results.first)
                    
                    if let person = results.first {
                        XCTAssertEqual(person.name, "Person \(skip)")
                    }
                    
                    XCTAssertNotNil(results.last)
                    
                    if let person = results.last {
                        XCTAssertEqual(person.name, "Person \(skip + 1)")
                    }
                }
                
                skip += limit
                
                expectationFind?.fulfill()
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationFind = nil
            }
        }
    }
    
    class MethodNotAllowedError: NSURLProtocol {
        
        override class func canInitWithRequest(request: NSURLRequest) -> Bool {
            return true
        }
        
        override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
            return request
        }
        
        override func startLoading() {
            let response = NSHTTPURLResponse(URL: request.URL!, statusCode: 405, HTTPVersion: "1.1", headerFields: [:])!
            client!.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
            
            let responseBody = [
                "error": "MethodNotAllowed",
                "debug": "insert' method is not allowed for this collection.",
                "description": "The method is not allowed for this resource."
            ]
            let responseBodyData = try! NSJSONSerialization.dataWithJSONObject(responseBody, options: [])
            client!.URLProtocol(self, didLoadData: responseBodyData)
            
            client!.URLProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {
        }
        
    }
    
    class DataLinkEntityNotFoundError: NSURLProtocol {
        
        override class func canInitWithRequest(request: NSURLRequest) -> Bool {
            return true
        }
        
        override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
            return request
        }
        
        override func startLoading() {
            let response = NSHTTPURLResponse(URL: request.URL!, statusCode: 404, HTTPVersion: "1.1", headerFields: [:])!
            client!.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
            
            let responseBody = [
                "error": "DataLinkEntityNotFound",
                "debug": "Error: Not Found",
                "description": "The data link could not find this entity"
            ]
            let responseBodyData = try! NSJSONSerialization.dataWithJSONObject(responseBody, options: [])
            client!.URLProtocol(self, didLoadData: responseBodyData)
            
            client!.URLProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {
        }
        
    }
    
    func testGetDataLinkEntityNotFound() {
        setURLProtocol(DataLinkEntityNotFoundError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectationWithDescription("Find")
        
        store.find("sample-id", readPolicy: .ForceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .DataLinkEntityNotFound(let debug, let description):
                    XCTAssertEqual(debug, "Error: Not Found")
                    XCTAssertEqual(description, "The data link could not find this entity")
                default:
                    XCTFail()
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testSaveMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        let person = Person()
        person.name = "Victor Barros"
        
        weak var expectationSave = expectationWithDescription("Save")
        
        store.save(person, writePolicy: .ForceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .MethodNotAllowed(let debug, let description):
                    XCTAssertEqual(debug, "insert' method is not allowed for this collection.")
                    XCTAssertEqual(description, "The method is not allowed for this resource.")
                default:
                    XCTFail()
                }
            }
            
            expectationSave?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationSave = nil
        }
    }
    
    func testFindMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectationWithDescription("Find")
        
        store.find(readPolicy: .ForceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .MethodNotAllowed(let debug, let description):
                    XCTAssertEqual(debug, "insert' method is not allowed for this collection.")
                    XCTAssertEqual(description, "The method is not allowed for this resource.")
                default:
                    XCTFail()
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testGetMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectationWithDescription("Find")
        
        store.find("sample-id", readPolicy: .ForceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .MethodNotAllowed(let debug, let description):
                    XCTAssertEqual(debug, "insert' method is not allowed for this collection.")
                    XCTAssertEqual(description, "The method is not allowed for this resource.")
                default:
                    XCTFail()
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testRemoveByIdMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectationWithDescription("Remove")
        
        store.removeById("sample-id", writePolicy: .ForceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .MethodNotAllowed(let debug, let description):
                    XCTAssertEqual(debug, "insert' method is not allowed for this collection.")
                    XCTAssertEqual(description, "The method is not allowed for this resource.")
                default:
                    XCTFail()
                }
            }
            
            expectationRemove?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testRemoveMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectationWithDescription("Remove")
        
        store.remove(writePolicy: .ForceNetwork) { count, error in
            XCTAssertNil(count)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .MethodNotAllowed(let debug, let description):
                    XCTAssertEqual(debug, "insert' method is not allowed for this collection.")
                    XCTAssertEqual(description, "The method is not allowed for this resource.")
                default:
                    XCTFail()
                }
            }
            
            expectationRemove?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testClientAppVersion() {
        class ClientAppVersionURLProtocol: NSURLProtocol {
            
            override class func canInitWithRequest(request: NSURLRequest) -> Bool {
                return true
            }
            
            override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
                return request
            }
            
            override func startLoading() {
                XCTAssertEqual(request.allHTTPHeaderFields?["X-Kinvey-Client-App-Version"], "1.0.0")
                
                let response = NSHTTPURLResponse(URL: request.URL!, statusCode: 200, HTTPVersion: "1.1", headerFields: ["Content-Type" : "application/json; charset=utf-8"])!
                client!.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
                client!.URLProtocol(self, didLoadData: "[]".dataUsingEncoding(NSUTF8StringEncoding)!)
                client!.URLProtocolDidFinishLoading(self)
            }
            
            override func stopLoading() {
            }
            
        }
        
        setURLProtocol(ClientAppVersionURLProtocol.self)
        client.clientAppVersion = "1.0.0"
        defer {
            setURLProtocol(nil)
            client.clientAppVersion = nil
        }
        
        weak var expectationFind = expectationWithDescription("Find")
        
        store.find(readPolicy: .ForceNetwork) { results, error in
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let results = results {
                XCTAssertEqual(results.count, 0)
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
}
