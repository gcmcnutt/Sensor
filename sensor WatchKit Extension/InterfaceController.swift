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
    public func csv(dateFormatter : NSDateFormatter) -> String {
        let dateString = dateFormatter.stringFromDate(startDate)
        return "\(identifier),\(dateString),\(acceleration.x),\(acceleration.y),\(acceleration.z)"
    }
}

class InterfaceController: WKInterfaceController, WCSessionDelegate {
    let wcsession = WCSession.defaultSession()
    let sr = CMSensorRecorder()
    let dateFormatter = NSDateFormatter()

    var durationValue = 2.0
    var lastStart = NSDate()
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
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        
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
        self.sr.recordAccelerometerForDuration(durationValue * 60.0)
    }

    @IBAction func dequeuerAction(value: Bool) {
        dequeuerState = value
        
        if (dequeuerState) {
            latestDate = lastStart
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
        
        let data = sr.accelerometerDataFromDate(latestDate, toDate: NSDate())
        if (data != nil) {
            var payloadBatch : [String] = []
            let lastBatchNum = batchNum
            
            for element in data! {
                
                let lastElement = element as! CMRecordedAccelerometerData
                
                // we skip prior batch numbers that may be returned
                if (lastBatchNum != 0 && batchNum == lastElement.identifier) {
                    continue
                }
                
                // this is the batch we're working on
                batchNum = lastElement.identifier
                
                // we only do one batch at a time
                if (batchNum != lastElement.identifier) {
                    break
                }
                
                // note that we really received an element
                itemCount++;
                haveData = true;
                
                // this tracks the query date for the next round...
                latestDate = latestDate.laterDate(lastElement.startDate)

                // next item, here we enqueue it
                if (lastElement.startDate.compare(NSDate.distantPast()) == NSComparisonResult.OrderedAscending) {
                    NSLog("odd date: " + lastElement.description)
                }
                
                // TODO temporary until WCSession serialization support
                payloadBatch.append(lastElement.csv(dateFormatter))
            }
            
            // flush any data
            if (!payloadBatch.isEmpty) {
                let result = self.wcsession.transferUserInfo(["data" : payloadBatch]) as WCSessionUserInfoTransfer?
                if (result != nil) {
                    
                }
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
