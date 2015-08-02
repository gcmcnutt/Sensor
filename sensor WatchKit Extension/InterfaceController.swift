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

class InterfaceController: WKInterfaceController {
    
    let sr = CMSensorRecorder()
    var durationValue = 2.0
    var lastStart = NSDate()
    let dateFormatter = NSDateFormatter()
    var cmdCount = 0

    @IBOutlet var durationVal: WKInterfaceLabel!
    @IBOutlet var startVal: WKInterfaceButton!
    @IBOutlet var lastStartVal: WKInterfaceLabel!
    @IBOutlet var reachableVal: WKInterfaceLabel!
    @IBOutlet var cmdCountVal: WKInterfaceLabel!

    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        dateFormatter.dateFormat = "yyyy-MM-dd'T'hh:mm:ss"
        
        // can we record?
        self.startVal.setEnabled(CMSensorRecorder.isAccelerometerRecordingAvailable())
        self.lastStartVal.setText(dateFormatter.stringFromDate(lastStart))
        
        // register listener for extension messages
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "watchReachabilityHandler:", name: "watchReachability", object: nil)

    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    dynamic private func watchReachabilityHandler(notification: NSNotification) {
        let session = notification.object as! WCSession
        if (session.reachable) {
            self.reachableVal.setTextColor(UIColor.greenColor())
            self.reachableVal.setText("reachable")
        } else {
            self.reachableVal.setTextColor(UIColor.redColor())
            self.reachableVal.setText("not reachable")
        }
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
    }

}
