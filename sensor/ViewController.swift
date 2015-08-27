//
//  ViewController.swift
//  sensor
//
//  Created by Greg McNutt on 7/29/15.
//  Copyright © 2015 Greg McNutt. All rights reserved.
//

import UIKit
import WatchConnectivity

class ViewController: UIViewController {
    
    @IBOutlet weak var nameVal: UILabel!
    @IBOutlet weak var emailVal: UILabel!
    @IBOutlet weak var idVal: UILabel!
    @IBOutlet weak var postalVal: UILabel!
    @IBOutlet weak var tokenExpireVal: UILabel!
    @IBOutlet weak var localStorageVal: UILabel!
    @IBOutlet weak var flushCountVal: UILabel!
    @IBOutlet weak var lastFlushTimeVal: UILabel!
    
    @IBOutlet weak var batchesVal: UILabel!
    @IBOutlet weak var elementsVal: UILabel!
    @IBOutlet weak var lastBatchVal: UILabel!
    @IBOutlet weak var lastTimeVal: UILabel!
    @IBOutlet weak var lastXVal: UILabel!
    @IBOutlet weak var lastYVal: UILabel!
    @IBOutlet weak var lastZVal: UILabel!
    @IBOutlet weak var gapErrorsVal: UILabel!
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    var credentialsProvider : AWSCognitoCredentialsProvider!
    var kinesis : AWSKinesisRecorder!
    
    var flushCount = 0
    var timeLastFlush = NSDate()
    
    let dateFormatter = NSDateFormatter()
    var batchesCount = 0
    var elementsCount = 0
    var gapErrors = 0
    var lastDate = NSDate.distantPast()
    var lastItem = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        
        // tune up kinesis
        kinesis = AWSKinesisRecorder.defaultKinesisRecorder()
        kinesis.diskAgeLimit = 30 * 24 * 60 * 60; // 30 days
        kinesis.diskByteLimit = 5 * 1024 * 1024; // 10MB
        kinesis.notificationByteThreshold = 4 * 1024 * 1024; // 5MB
        
        // see if we are already logged in
        let delegate = AuthorizeUserDelegate(parentController: self)
        delegate.launchGetAccessToken()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func loginAction(sender: AnyObject) {
        // Requesting both scopes for the current user.
        let requestScopes: [String] = ["profile", "postal_code"]
        let delegate = AuthorizeUserDelegate(parentController: self)
        AIMobileLib.authorizeUserForScopes(requestScopes, delegate: delegate)
    }
    
    @IBAction func logoutAction(sender: AnyObject) {
        let delegate = LogoutDelegate(parentController: self)
        
        AIMobileLib.clearAuthorizationState(delegate)
    }
    
    func renderNewData(userInfo: [String : AnyObject]) {
        batchesCount++
        let payload = userInfo[AppGlobals.ACCELEROMETER_KEY] as! [String]
        var elements : [String] = []
        var tasks : [AWSTask] = []
        
        // walk the elements looking for gaps in sensor records
        for (var i = 0; i < payload.count; i++) {
            let item = payload[i]
            elementsCount++
            elements = item.componentsSeparatedByString(",")
            
            let date = dateFormatter.dateFromString(elements[1])!
            if (abs(date.timeIntervalSinceDate(lastDate)) > 0.025) {
                NSLog("gap: index=%d, old=%@, new=%@", i, lastItem, item)
                gapErrors++
            }
            
            lastItem = item
            lastDate = date
        }
        
        let data = try! NSJSONSerialization.dataWithJSONObject(payload, options: NSJSONWritingOptions.PrettyPrinted)
        tasks.append(kinesis.saveRecord(data, streamName: appDelegate.infoPlist[AppGlobals.KINESIS_STREAM_KEY] as! String))
        
        // TODO add a idle flush timer
        if (NSDate().timeIntervalSinceDate(timeLastFlush) > 30) {
            
            // dump the data
            AWSTask(forCompletionOfAllTasks: tasks).continueWithSuccessBlock{
                (task: AWSTask!) -> AWSTask! in
                return self.kinesis.submitAllRecords()
            }
            timeLastFlush = NSDate()
            flushCount++
        }
        
        // render the last item
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.batchesVal.text = self.batchesCount.description
            self.elementsVal.text = self.elementsCount.description
            self.lastBatchVal.text = elements[0]
            self.lastTimeVal.text = elements[1]
            self.lastXVal.text = elements[2]
            self.lastYVal.text = elements[3]
            self.lastZVal.text = elements[4]
            self.gapErrorsVal.text = self.gapErrors.description
            self.localStorageVal.text = self.kinesis.diskBytesUsed.description
            self.flushCountVal.text = self.flushCount.description
            self.lastFlushTimeVal.text = self.dateFormatter.stringFromDate(self.timeLastFlush)
            self.tokenExpireVal.text = self.credentialsProvider.expiration != nil ? self.dateFormatter.stringFromDate(self.credentialsProvider.expiration) : "nil"
        }
    }
}

