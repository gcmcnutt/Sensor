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
    static let MAX_PAYLOAD_COUNT = 200
    static let FAST_POLL_DELAY_SEC = 0.1
    static let SLOW_POLL_DELAY_SEC = 5.0
    
    let wcsession = WCSession.defaultSession()
    let sr = CMSensorRecorder()
    let dateFormatter = NSDateFormatter()
    let summaryDateFormatter = NSDateFormatter()
    
    var durationValue = 2.0
    var lastStart = NSDate()
    var timer = NSTimer()
    var dequeuerState = false
    
    var cmdCount = 0
    var batchNum : UInt64 = 0
    var itemCount = 0
    var latestDate = NSDate.distantPast()
    var queueDepth = 0
    
    var haveAccelerometer : Bool!
    
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
        summaryDateFormatter.dateFormat = "HH:mm:ss.SSS"
        
        // can we record?
        haveAccelerometer = CMSensorRecorder.isAccelerometerRecordingAvailable()
        startVal.setEnabled(haveAccelerometer)
        lastStartVal.setText(summaryDateFormatter.stringFromDate(lastStart))
        
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
        self.lastStartVal.setText(summaryDateFormatter.stringFromDate(lastStart))
        self.sr.recordAccelerometerForDuration(durationValue * 60.0)
    }
    
    @IBAction func dequeuerAction(value: Bool) {
        dequeuerState = value
        
        if (dequeuerState) {
            latestDate = lastStart
        }
        manageDequeuerTimer(true)
    }
    
    func manageDequeuerTimer(slow : Bool) {
        if (dequeuerState) {
            timer = NSTimer.scheduledTimerWithTimeInterval(slow ? InterfaceController.SLOW_POLL_DELAY_SEC : InterfaceController.FAST_POLL_DELAY_SEC,
                target: self,
                selector: "timerHandler:",
                userInfo: haveAccelerometer,
                repeats: false)
        } else {
            timer.invalidate()
        }
    }
    
    func timerHandler(timer : NSTimer) {
        var payloadBatch : [String] = []

        cmdCount++
        
        // real or faking it?
        if (timer.userInfo as! Bool) {
            let data = sr.accelerometerDataFromDate(latestDate, toDate: NSDate())
            if (data != nil) {
                
                for element in data! {
                    
                    let lastElement = element as! CMRecordedAccelerometerData
                    
                    // skip repeated element from prior batch
                    if (!(lastElement.startDate.compare(latestDate) == NSComparisonResult.OrderedDescending)) {
                        continue;
                    }
                    
                    // note that we really received an element
                    itemCount++;
                    
                    // this tracks the query date for the next round...
                    latestDate = latestDate.laterDate(lastElement.startDate)
                    
                    batchNum = lastElement.identifier
                    
                    // next item, here we enqueue it
                    if (lastElement.startDate.compare(NSDate.distantPast()) == NSComparisonResult.OrderedAscending) {
                        NSLog("odd date: " + lastElement.description)
                    }
                    
                    // TODO temporary until WCSession serialization support
                    payloadBatch.append(lastElement.csv(dateFormatter))
                    
                    if (payloadBatch.count >= InterfaceController.MAX_PAYLOAD_COUNT) {
                        break
                    }
                }
            }
        } else {
            batchNum++
            while (payloadBatch.count < InterfaceController.MAX_PAYLOAD_COUNT && latestDate.compare(NSDate()) == NSComparisonResult.OrderedAscending) {
                let dateString = dateFormatter.stringFromDate(latestDate)
                payloadBatch.append("\(cmdCount),\(dateString),0.0,0.1,0.2")
                itemCount++
                latestDate = latestDate.dateByAddingTimeInterval(0.02)
            }
        }
        
        // flush any data
        if (!payloadBatch.isEmpty) {
            self.wcsession.transferUserInfo([AppGlobals.ACCELEROMETER_KEY : payloadBatch])
        }
        
        // update the UI
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.cmdCountVal.setText(self.cmdCount.description)
            self.batchNumVal.setText(self.batchNum.description)
            self.itemCountVal.setText(self.itemCount.description)
            self.latestVal.setText(self.summaryDateFormatter.stringFromDate(self.latestDate))
            self.queueDepthVal.setText(self.wcsession.outstandingUserInfoTransfers.count.description)
            
            // reset the timer -- slow poll if not full buffer
            self.manageDequeuerTimer(payloadBatch.count < InterfaceController.MAX_PAYLOAD_COUNT)
        }
    }
    
    func session(session: WCSession, didFinishUserInfoTransfer userInfoTransfer: WCSessionUserInfoTransfer, error: NSError?) {
        if (error != nil) {
            NSLog(error!.description)
        }
    }
}
