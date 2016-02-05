//
//  HttpNetworkTransport.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-08.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import Foundation

class HttpRequestFactory: RequestFactory {
    
    let client: Client
    
    required init(client: Client) {
        self.client = client
    }
    
    typealias CompletionHandler = (NSData?, NSURLResponse?, NSError?) -> Void
    
    func buildUserSignUp(username username: String? = nil, password: String? = nil) -> Request {
        let request = HttpRequest(httpMethod: .Post, endpoint: Endpoint.User(client: client), client: client)
        
        request.request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var bodyObject: [String : String] = [:]
        if let username = username {
            bodyObject["username"] = username
        }
        if let password = password {
            bodyObject["password"] = password
        }
        request.request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(bodyObject, options: [])
        return request
    }
    
    func buildUserDelete(userId userId: String, hard: Bool) -> Request {
        let request = HttpRequest(httpMethod: .Delete, endpoint: Endpoint.UserById(client: client, userId: userId), credential: client.activeUser, client: client)
        
        //FIXME: make it configurable
        request.request.setValue("2", forHTTPHeaderField: "X-Kinvey-API-Version")
        
        var bodyObject: [String : Bool] = [:]
        if hard {
            bodyObject["hard"] = true
        }
        request.request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(bodyObject, options: [])
        return request
    }
    
    func buildUserLogin(username username: String, password: String) -> Request {
        let request = HttpRequest(httpMethod: .Post, endpoint: Endpoint.UserLogin(client: client), client: client)
        request.request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyObject = [
            "username" : username,
            "password" : password
        ]
        request.request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(bodyObject, options: [])
        return request
    }
    
    func buildUserExists(username username: String) -> Request {
        let request = HttpRequest(httpMethod: .Post, endpoint: Endpoint.UserExistsByUsername(client: client), client: client)
        request.request.HTTPMethod = "POST"
        
        request.request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyObject = ["username" : username]
        request.request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(bodyObject, options: [])
        return request
    }
    
    func buildUserGet(userId userId: String) -> Request {
        let request = HttpRequest(endpoint: Endpoint.UserById(client: client, userId: userId), credential: client.activeUser, client: client)
        return request
    }
    
    func buildUserSave(user user: User) -> Request {
        let request = HttpRequest(httpMethod: .Put, endpoint: Endpoint.UserById(client: client, userId: user.userId), credential: client.activeUser, client: client)
        request.request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyObject = user.toJson()
        request.request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(bodyObject, options: [])
        return request
    }
    
    func buildAppDataGetById(collectionName collectionName: String, id: String) -> Request {
        let request = HttpRequest(endpoint: Endpoint.AppDataById(client: client, collectionName: collectionName, id: id), credential: client.activeUser, client: client)
        return request
    }
    
    func buildAppDataFindByQuery(collectionName collectionName: String, query: Query) -> Request {
        let request = HttpRequest(endpoint: Endpoint.AppDataByQuery(client: client, collectionName: collectionName, query: query), credential: client.activeUser, client: client)
        return request
    }
    
    func buildAppDataSave<T: Persistable where T: NSObject>(collectionName collectionName: String, persistable: T) -> Request {
        let bodyObject = T.toJson(persistable: persistable)
        let request = HttpRequest(
            httpMethod: bodyObject[Kinvey.PersistableIdKey] == nil ? .Post : .Put,
            endpoint: Endpoint.AppData(client: client, collectionName: collectionName),
            credential: client.activeUser,
            client: client
        )
        
        request.request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(bodyObject, options: [])
        return request
    }
    
    func buildAppDataRemoveByQuery(collectionName collectionName: String, query: Query) -> Request {
        let request = HttpRequest(
            httpMethod: .Delete,
            endpoint: Endpoint.AppDataByQuery(client: client, collectionName: collectionName, query: query),
            credential: client.activeUser,
            client: client
        )
        return request
    }
    
    func buildPushRegisterDevice(deviceToken: NSData) -> Request {
        let request = HttpRequest(
            httpMethod: .Post,
            endpoint: Endpoint.PushRegisterDevice(client: client),
            credential: client.activeUser,
            client: client
        )
        
        let bodyObject = [
            "platform" : "ios",
            "deviceId" : deviceToken.hexString()
        ]
        request.request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(bodyObject, options: [])
        return request
    }
    
    func buildPushUnRegisterDevice(deviceToken: NSData) -> Request {
        let request = HttpRequest(
            httpMethod: .Post,
            endpoint: Endpoint.PushUnRegisterDevice(client: client),
            credential: client.activeUser,
            client: client
        )
        
        let bodyObject = [
            "platform" : "ios",
            "deviceId" : deviceToken.hexString()
        ]
        request.request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(bodyObject, options: [])
        return request
    }
    
    func buildBlobUploadFile(file: File) -> Request {
        let request = HttpRequest(
            httpMethod: file.fileId == nil ? .Post : .Put,
            endpoint: Endpoint.BlobUpload(client: client, fileId: file.fileId, tls: true),
            credential: client.activeUser,
            client: client
        )
        
        var bodyObject: [String : AnyObject] = [
            "_public" : file.publicAccessible
        ]
        
        if let fileId = file.fileId {
            bodyObject["_id"] = fileId
        }
        
        if let fileName = file.fileName {
            bodyObject["_filename"] = fileName
        }
        
        if let size = file.size {
            bodyObject["size"] = String(size)
        }
        
        if let mimeType = file.mimeType {
            bodyObject["mimeType"] = mimeType
        }
        
        request.request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(bodyObject, options: [])
        return request
    }
    
    func buildBlobDownloadFile(file: File, ttl: TTL?) -> Request {
        let request = HttpRequest(
            httpMethod: .Get,
            endpoint: Endpoint.BlobDownload(client: client, fileId: file.fileId!, query: nil, tls: true, ttlInSeconds: nil),
            credential: client.activeUser,
            client: client
        )
        return request
    }
    
    func buildBlobDeleteFile(file: File) -> Request {
        let request = HttpRequest(
            httpMethod: .Delete,
            endpoint: Endpoint.BlobById(client: client, fileId: file.fileId!),
            credential: client.activeUser,
            client: client
        )
        return request
    }
    
    func buildBlobQueryFile(query: Query, ttl: TTL?) -> Request {
        let request = HttpRequest(
            httpMethod: .Get,
            endpoint: Endpoint.BlobDownload(client: client, fileId: nil, query: query, tls: true, ttlInSeconds: nil),
            credential: client.activeUser,
            client: client
        )
        return request
    }

}
