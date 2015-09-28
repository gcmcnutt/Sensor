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

class InterfaceController: WKInterfaceController, WCSessionDelegate {
    static let MAX_PAYLOAD_COUNT = 1000
    static let FAST_POLL_DELAY_SEC = 0.01
    static let SLOW_POLL_DELAY_SEC = 4.0
    static let MAX_EARLIEST_TIME_SEC = -24.0 * 60.0 * 60.0 // a day ago
    
    let wcsession = WCSession.defaultSession()
    let sr = CMSensorRecorder()
    let dateFormatter = NSDateFormatter()
    let summaryDateFormatter = NSDateFormatter()
    
    var durationValue = 5.0
    var lastStart = NSDate()
    var timer = NSTimer()
    var dequeuerState = false
    
    var cmdCount : UInt64 = 0
    var batchNum : UInt64 = 0
    var itemCount = 0
    var latestDate = NSDate.distantPast()
    var errors = 0
    
    var payloadBatch : [NSDictionary] = []
    var newItems = 0
    var newLatestDate : NSDate!
    var newBatchNum : UInt64!
    
    var haveAccelerometer : Bool!
    
    @IBOutlet var durationVal: WKInterfaceLabel!
    @IBOutlet var startVal: WKInterfaceButton!
    @IBOutlet var lastStartVal: WKInterfaceLabel!
    @IBOutlet var cmdCountVal: WKInterfaceLabel!
    @IBOutlet var batchNumVal: WKInterfaceLabel!
    @IBOutlet var itemCountVal: WKInterfaceLabel!
    @IBOutlet var latestVal: WKInterfaceLabel!
    @IBOutlet var errorsVal: WKInterfaceLabel!
    @IBOutlet var lastVal: WKInterfaceLabel!
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        dateFormatter.dateFormat = AppGlobals.ISO8601_FORMAT
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
                userInfo: nil,
                repeats: false)
        } else {
            timer.invalidate()
        }
    }
    
    func timerHandler(timer : NSTimer) {
        cmdCount++
        NSLog("timerHander(\(cmdCount))")
        
        // create a pending update state (only committed if the data gets to phone)
        payloadBatch = []
        newItems = itemCount
        newBatchNum = batchNum
        
        // within a certain time of now
        let earliest = NSDate().dateByAddingTimeInterval(InterfaceController.MAX_EARLIEST_TIME_SEC)
        newLatestDate = latestDate.laterDate(earliest)

        // real or faking it?
        if (haveAccelerometer!) {
            let data = sr.accelerometerDataFromDate(newLatestDate, toDate: NSDate())
            if (data != nil) {
                
                for element in data! {
                    
                    let lastElement = element as! CMRecordedAccelerometerData
                    
                    // skip repeated element from prior batch
                    if (!(lastElement.startDate.compare(newLatestDate) == NSComparisonResult.OrderedDescending)) {
                        continue;
                    }
                    
                    // note that we really received an element
                    newItems++;
                    
                    // this tracks the query date for the next round...
                    newLatestDate = newLatestDate.laterDate(lastElement.startDate)
                    
                    newBatchNum = lastElement.identifier
                    
                    // next item, here we enqueue it
                    if (lastElement.startDate.compare(NSDate.distantPast()) == NSComparisonResult.OrderedAscending) {
                        NSLog("odd date: " + lastElement.description)
                    }
                    
                    payloadBatch.append(AccelerometerData(dateFormatter: dateFormatter, data: lastElement).element)
                    
                    if (payloadBatch.count >= InterfaceController.MAX_PAYLOAD_COUNT) {
                        break
                    }
                }
            }
        } else {
            newBatchNum = batchNum + 1
            while (payloadBatch.count < InterfaceController.MAX_PAYLOAD_COUNT && newLatestDate.compare(NSDate()) == NSComparisonResult.OrderedAscending) {
                
                let data = AccelerometerData(dateFormatter: dateFormatter, id: cmdCount, date: newLatestDate, x: random(), y: random(), z: random())
                
                newItems++
                newLatestDate = newLatestDate.dateByAddingTimeInterval(0.02)
                
                payloadBatch.append(data.element)
            }
        }
        
        // flush any data
        if (!payloadBatch.isEmpty) {
            
            let output = try! NSJSONSerialization.dataWithJSONObject(payloadBatch,
                options: NSJSONWritingOptions.PrettyPrinted)
            
            self.wcsession.sendMessage(
                [AppGlobals.ACCELEROMETER_KEY : output],
                replyHandler: sendSuccess,
                errorHandler: sendError)
        } else {
            // no data, do a slow poll
            updateUI(true)
        }
    }
    
    func random() -> Double {
        return Double(arc4random()) / 0xFFFFFFFF
    }
    
    func sendSuccess(reply : [String : AnyObject]) {
        // commit the updates on success
        batchNum = newBatchNum
        latestDate = newLatestDate
        itemCount = newItems
        
        // reset UI and try again
        updateUI(payloadBatch.count < InterfaceController.MAX_PAYLOAD_COUNT)
    }
    
    
    func sendError(error : NSError) {
        errors++
        NSLog("sendError[\(errors)](\(error))")
        
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.errorsVal.setText(self.errors.description)
            self.lastVal.setText(error.description)
        }
        
        updateUI(true)
    }
    
    func updateUI(slow : Bool) {
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.cmdCountVal.setText(self.cmdCount.description)
            self.batchNumVal.setText(self.batchNum.description)
            self.itemCountVal.setText(self.itemCount.description)
            self.latestVal.setText(self.summaryDateFormatter.stringFromDate(self.latestDate))
            
            // reset the timer -- slow poll if not full buffer
            self.manageDequeuerTimer(slow)
        }
    }
}
