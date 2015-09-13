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
    static let ACCELEROMETER_KEY = "acc"
    
    // key for the cognito pool in Info
    static let IDENTITY_POOL_ID_KEY = "cognitoPool"
    
    // key for the stream name
    static let KINESIS_STREAM_KEY = "kinesisStream"
    
    static let ISO8601_FORMAT = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
}
