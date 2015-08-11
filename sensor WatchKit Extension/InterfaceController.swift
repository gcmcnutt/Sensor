//
//  InterfaceController.swift
//  sensor WatchKit Extension
//
//  Created by Greg McNutt on 7/29/15.
//  Copyright © 2015 Greg McNutt. All rights reserved.
//

import WatchKit
import Foundation
import CoreMotion
import Darwin
import WatchConnectivity

extension CMSensorDataList: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}

extension CMRecordedAccelerometerData {
    public func csv() -> String {
        return "\(identifier),\(startDate),\(timestamp),\(acceleration.x),\(acceleration.y),\(acceleration.z)"
    }
}

class InterfaceController: WKInterfaceController, WCSessionDelegate {
    let wcsession = WCSession.defaultSession()
    let sr = CMSensorRecorder()
    let dateFormatter = NSDateFormatter()

    var durationValue = 2.0
    var lastStart = NSDate.distantFuture()
    var timer = NSTimer()
    var dequeuerState = false
    
    var cmdCount = 0
    var batchNum : UInt64 = 0
    var itemCount = 0
    var latestDate = NSDate.distantPast()
    var queueDepth = 0

    @IBOutlet var durationVal: WKInterfaceLabel!
    @IBOutlet var startVal: WKInterfaceButton!
    @IBOutlet var lastStartVal: WKInterfaceLabel!
    @IBOutlet var cmdCountVal: WKInterfaceLabel!
    @IBOutlet var batchNumVal: WKInterfaceLabel!
    @IBOutlet var itemCountVal: WKInterfaceLabel!
    @IBOutlet var latestVal: WKInterfaceLabel!
    @IBOutlet var queueDepthVal: WKInterfaceLabel!
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        dateFormatter.dateFormat = "yyyy-MM-dd'T'hh:mm:ss"
        
        // can we record?
        self.startVal.setEnabled(CMSensorRecorder.isAccelerometerRecordingAvailable())
        self.lastStartVal.setText(dateFormatter.stringFromDate(lastStart))
        
        // wake up session to phone
        wcsession.delegate = self
        wcsession.activateSession()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // UI stuff
    @IBAction func durationAction(value: Float) {
        durationValue = Double(value)
        self.durationVal.setText(value.description)
    }
    
    @IBAction func startRecorderAction() {
        lastStart = NSDate()
        self.lastStartVal.setText(dateFormatter.stringFromDate(lastStart))
        self.sr.recordAccelerometerFor(durationValue * 60.0)
    }

    @IBAction func dequeuerAction(value: Bool) {
        dequeuerState = value
        
        // reset the batch scanner to latestDate
        if (dequeuerState) {
            batchNum = 0
        }
        
        manageDequeuerTimer(true)
    }
    
    func manageDequeuerTimer(fast : Bool) {
        if (dequeuerState) {
            timer = NSTimer.scheduledTimerWithTimeInterval(fast ? 0.1 : 5.0,
                target: self,
                selector: "dequeuerTimer:",
                userInfo: nil,
                repeats: false)
        } else {
            timer.invalidate()
        }
    }
    
    func dequeuerTimer(timer : NSTimer) {
        var haveData = false
        
        cmdCount++
        
        // first or subsequent batch?
        let data : CMSensorDataList!
        if (batchNum == 0) {
            data = sr.accelerometerDataFrom(lastStart, to: NSDate())
        } else {
            data = sr.accelerometerDataSince(batchNum)
        }
        
        if (data != nil) {
            var currentBatch : UInt64 = 0
            var payloadBatch : [String] = []
            
            for element in data as CMSensorDataList {
                
                let lastElement = element as! CMRecordedAccelerometerData
                
                // we only do one batch at a time
                if (currentBatch != 0 && currentBatch != lastElement.identifier) {
                    break
                }
                currentBatch = lastElement.identifier
                
                // note that we really received an element
                itemCount++;
                haveData = true;
                latestDate = latestDate.laterDate(lastElement.startDate)

                // next item, here we enqueue it
                if (lastElement.startDate.compare(NSDate.distantPast()) == NSComparisonResult.OrderedAscending) {
                    NSLog("odd date: " + lastElement.description)
                }
                
                // TODO temporary until WCSession serialization support
                payloadBatch.append(lastElement.csv())
            }
            
            // flush any data
            if (!payloadBatch.isEmpty) {
                let result = self.wcsession.transferUserInfo(["data" : payloadBatch]) as WCSessionUserInfoTransfer?
                if (result != nil) {
                    
                }
            }
        
            // if we had data track the next batch for next round
            if (currentBatch != 0) {
                batchNum = currentBatch + 1
            }
        }
        
        // update the UI
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.cmdCountVal.setText(self.cmdCount.description)
            self.batchNumVal.setText(self.batchNum.description)
            self.itemCountVal.setText(self.itemCount.description)
            self.latestVal.setText(self.dateFormatter.stringFromDate(self.latestDate))

            self.queueDepthVal.setText(self.wcsession.outstandingUserInfoTransfers.count.description)

            // reset the timer
            self.manageDequeuerTimer(haveData)
        }
    }
    
    func session(session: WCSession, didFinishUserInfoTransfer userInfoTransfer: WCSessionUserInfoTransfer, error: NSError?) {
        if (error != nil) {
            NSLog(error!.description)
        }
    }
}
