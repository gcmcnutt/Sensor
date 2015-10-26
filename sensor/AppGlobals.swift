//
//  AppGlobals.swift
//  sensor
//
//  Created by Greg McNutt on 8/26/15.
//  Copyright © 2015 Greg McNutt. All rights reserved.
//

import Foundation

class AppGlobals {
    // key for exchange between watch and iPhone (WCSession)
    static let PHONE_DATA_KEY = "acc"
    static let PHONE_DATA_BATCH_ID = "id"
    
    // key for the cognito pool in Info
    static let IDENTITY_POOL_ID_KEY = "cognitoPool"
    
    // key for the stream name
    static let KINESIS_STREAM_KEY = "kinesisStream"
    
    static let PAYLOAD_USER_ID = "userId"
    static let PAYLOAD_PROCESS_DATE = "processDate"
    static let PAYLOAD_BATCH = "data"
    static let PAYLOAD_BATCH_ID = "id"
    
    let dateFormatter = NSDateFormatter()
    
    // used for global date formatting...
    static let ISO8601_FORMAT = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    
    static let sharedInstance = AppGlobals()
    
    init() {
        dateFormatter.dateFormat = AppGlobals.ISO8601_FORMAT
        dateFormatter.timeZone = NSTimeZone(name:"UTC");
    }
}
