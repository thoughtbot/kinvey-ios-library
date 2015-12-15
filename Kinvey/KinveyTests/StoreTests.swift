//
//  StoreTests.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-14.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import XCTest
@testable import Kinvey

class StoreTests: KinveyTestCase {
    
    class Person: NSObject, Persistable {
        
        var personId: String?
        var name: String?
        var age: Int?
        
        override init() {
            super.init()
        }
        
        static func kinveyPropertyMapping() -> [String : String] {
            return [
                "personId" : Kinvey.PersistableIdKey,
                "name" : "name",
                "age" : "age"
            ]
        }
        
        required convenience init(json: [String : AnyObject]) {
            self.init()
            if let personId = json[Kinvey.PersistableIdKey] as? String {
                self.personId = personId
            }
            if let name = json["name"] as? String {
                self.name = name
            }
            if let age = json["age"] as? Int {
                self.age = age
            }
        }
        
        func toJson() -> [String : AnyObject] {
            var json: [String : AnyObject] = [:]
            if let personId = personId {
                json[Kinvey.PersistableIdKey] = personId
            }
            if let name = name {
                json["name"] = name
            }
            if let age = age {
                json["age"] = age
            }
            return json
        }
        
        func merge<T : Persistable>(object: T) {
            if let object = object as? Person {
                merge(object)
            }
        }
        
        func merge(object: Person) {
            personId = object.personId
            name = object.name
            age = object.age
        }
        
    }
    
    var store: NetworkStore<Person>!
    var person:Person {
        get {
            let person = Person()
            person.name = "Victor"
            person.age = 29
            return person
        }
    }
    
    override func setUp() {
        super.setUp()
        
        signUp()
        
        store = NetworkStore<Person>(collectionName: "Person", client: client)
    }
    
    func save() -> Person {
        let person = self.person
        
        weak var expectationCreate = expectationWithDescription("Create")
        
        store.save(person) { (person, error) -> Void in
            XCTAssertTrue(NSThread.isMainThread())
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            if let person = person {
                XCTAssertNotNil(person.personId)
                XCTAssertNotNil(person.age)
                if let age = person.age {
                    XCTAssertEqual(age, 29)
                }
            }
            
            expectationCreate?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationCreate = nil
        }
        
        return person
    }
    
    func testCreate() {
        save()
    }
    
    func testRetrieve() {
        let person = save()
        
        weak var expectationGet = expectationWithDescription("Get")
        
        store.get(person.personId!) { (person, error) -> Void in
            XCTAssertTrue(NSThread.isMainThread())
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            expectationGet?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationGet = nil
        }
    }
    
    func testUpdate() {
        let person = save()
        
        weak var expectationUpdate = expectationWithDescription("Update")
        
        person.age = 30
        
        store.save(person) { (person, error) -> Void in
            XCTAssertTrue(NSThread.isMainThread())
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            if let person = person {
                XCTAssertNotNil(person.age)
                if let age = person.age {
                    XCTAssertEqual(age, 30)
                }
            }
            
            expectationUpdate?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationUpdate = nil
        }
    }
    
    func testQuery() {
        save()
        
        weak var expectationUpdate = expectationWithDescription("Update")
        
        person.age = 30
        
        XCTAssertNotNil(client._activeUser)
        
        store.find(Query(format: "age == %@ AND _acl.creator == %@", 29, client._activeUser!.acl!.creator)) { (persons, error) -> Void in
            XCTAssertTrue(NSThread.isMainThread())
            XCTAssertNotNil(persons)
            XCTAssertNil(error)
            
            if let persons = persons {
                XCTAssertEqual(persons.count, 1)
            }
            
            expectationUpdate?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationUpdate = nil
        }
    }
    
    func testRemoveById() {
        let person = save()
        
        weak var expectationDelete = expectationWithDescription("Delete")
        
        store.remove(person.personId!) { (count, error) -> Void in
            XCTAssertTrue(NSThread.isMainThread())
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            if let count = count {
                XCTAssertGreaterThan(count, 0)
            }
            
            expectationDelete?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationDelete = nil
        }
    }
    
    func testRemoveByIds() {
        let person1 = save()
        let person2 = save()
        
        weak var expectationDelete = expectationWithDescription("Delete")
        
        store.remove([person1.personId!, person2.personId!]) { (count, error) -> Void in
            XCTAssertTrue(NSThread.isMainThread())
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            if let count = count {
                XCTAssertGreaterThan(count, 0)
            }
            
            expectationDelete?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationDelete = nil
        }
    }
    
    func testRemoveOneEntity() {
        let person = save()
        
        weak var expectationDelete = expectationWithDescription("Delete")
        
        store.remove(person) { (count, error) -> Void in
            XCTAssertTrue(NSThread.isMainThread())
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            if let count = count {
                XCTAssertGreaterThan(count, 0)
            }
            
            expectationDelete?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationDelete = nil
        }
    }
    
    func testRemoveMultipleEntity() {
        let person1 = save()
        let person2 = save()
        
        weak var expectationDelete = expectationWithDescription("Delete")
        
        store.remove([person1, person2]) { (count, error) -> Void in
            XCTAssertTrue(NSThread.isMainThread())
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            if let count = count {
                XCTAssertGreaterThan(count, 0)
            }
            
            expectationDelete?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationDelete = nil
        }
    }
    
}