//
//  AccelerometerData.swift
//  sensor
//
//  Created by Greg McNutt on 8/31/15.
//  Copyright © 2015 Greg McNutt. All rights reserved.
//

import Foundation
import CoreMotion

// TODO seems a bit much just to get a json serialization...
class AccelerometerData {
    var element = [String : AnyObject]()
    var dateFormatter : NSDateFormatter!
    static let idKey = "id"
    static let tsKey = "ts"
    static let xKey = "x"
    static let yKey = "y"
    static let zKey = "z"
    
    init(dateFormatter : NSDateFormatter, data : CMRecordedAccelerometerData) {
        self.dateFormatter = dateFormatter
        element[AccelerometerData.idKey] = data.identifier.description
        element[AccelerometerData.tsKey] = dateFormatter.stringFromDate(data.startDate)
        element[AccelerometerData.xKey] = data.acceleration.x
        element[AccelerometerData.yKey] = data.acceleration.y
        element[AccelerometerData.zKey] = data.acceleration.z
    }
    
    init(dateFormatter : NSDateFormatter, id : UInt64, date : NSDate, x : Double, y : Double, z : Double) {
        self.dateFormatter = dateFormatter
        element[AccelerometerData.idKey] = id.description
        element[AccelerometerData.tsKey] = dateFormatter.stringFromDate(date)
        element[AccelerometerData.xKey] = x
        element[AccelerometerData.yKey] = y
        element[AccelerometerData.zKey] = z
    }
    
    init(dateFormatter : NSDateFormatter, dictionary : NSDictionary) {
        self.dateFormatter = dateFormatter
        element[AccelerometerData.idKey] = dictionary[AccelerometerData.idKey]
        element[AccelerometerData.tsKey] = dictionary[AccelerometerData.tsKey]
        element[AccelerometerData.xKey] = dictionary[AccelerometerData.xKey]
        element[AccelerometerData.yKey] = dictionary[AccelerometerData.yKey]
        element[AccelerometerData.zKey] = dictionary[AccelerometerData.zKey]
    }
    
    var id : UInt64 {
        get {
            return UInt64(element[AccelerometerData.idKey] as! String)!
        }
    }
    
    var timeStamp : NSDate {
        get {
            return dateFormatter.dateFromString(element[AccelerometerData.tsKey] as! String)!
        }
    }
    
    var x : Double {
        get {
            return element[AccelerometerData.xKey] as! Double
        }
    }

    var y : Double {
        get {
            return element[AccelerometerData.yKey] as! Double
        }
    }
    
    var z : Double {
        get {
            return element[AccelerometerData.zKey] as! Double
        }
    }
    
    var description : String {
        get {
            return "\(id),\(timeStamp),\(x),\(y),\(z)"
        }
    }
}
