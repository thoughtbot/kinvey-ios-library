//
//  PushOperation.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-02-18.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation
import PromiseKit

class PushOperation<T: Persistable where T: NSObject>: WriteOperation<T, UInt> {
    
    override init(writePolicy: WritePolicy, sync: Sync, cache: Cache, client: Client) {
        super.init(writePolicy: writePolicy, sync: sync, cache: cache, client: client)
    }
    
    override func execute(completionHandler: CompletionHandler?) -> Request {
        let requests = MultiRequest()
        var promises: [Promise<NSData>] = []
        for pendingOperation in sync.pendingOperations() {
            let request = HttpRequest(request: pendingOperation.buildRequest(), client: client)
            requests.addRequest(request)
            promises.append(Promise<NSData> { fulfill, reject in
                request.execute() { data, response, error in
                    if let response = response where response.isResponseOK, let data = data {
                        let json = self.client.responseParser.parse(data, type: [String : AnyObject].self)
                        if let json = json, let pendindObjectId = pendingOperation.objectId {
                            if let entity = self.cache.findEntity(pendindObjectId) {
                                self.cache.removeEntity(entity)
                            }
                            
                            let persistable: T = T.fromJson(json)
                            let persistableJson = self.merge(persistable, json: json)
                            self.cache.saveEntity(persistableJson)
                        }
                        self.sync.removePendingOperation(pendingOperation)
                        fulfill(data)
                    } else if let error = error {
                        reject(error)
                    } else {
                        reject(Error.InvalidResponse)
                    }
                }
            })
        }
        when(promises).thenInBackground { results in
            completionHandler?(UInt(results.count), nil)
        }.error { error in
            completionHandler?(nil, error)
        }
        return requests
    }
    
}