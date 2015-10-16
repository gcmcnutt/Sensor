//
//  AppDelegate.swift
//  sensor
//
//  Created by Greg McNutt on 7/29/15.
//  Copyright © 2015 Greg McNutt. All rights reserved.
//

import UIKit
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {
    // how long until flush?
    static let KINESIS_FLUSH_DELAY_SEC : Double = 30.0
    
    static let DISPLAY_UPDATE_SEC : Double = 0.5
    
    // how close to expiration should we refresh STS token?
    static let CREDENTIAL_REFRESH_WINDOW_SEC : Double = 1800.0
    
    var window: UIWindow?
    var viewController : ViewController!
    var infoPlist : NSDictionary!
    
    let wcsession = WCSession.defaultSession()
    let dateFormatter = NSDateFormatter()
    
    // AWS plumbing
    var credentialsProvider : AWSCognitoCredentialsProvider!
    var kinesis : AWSKinesisRecorder!
    
    // stats
    var flushCount = 0
    var timeLastFlush = NSDate.distantPast()
    var batchesCount = 0
    var elementsCount = 0
    var gapErrors = 0
    var lastDate = NSDate.distantPast()
    var lastItem : AccelerometerData?
    var lastBatchNum : String = ""
    
    var flushTimer = NSTimer()
    var displayTimer = NSTimer()
    var tasks : [AWSTask] = []
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        dateFormatter.dateFormat = AppGlobals.ISO8601_FORMAT
        
        let path = NSBundle.mainBundle().pathForResource("Info", ofType: "plist")!
        infoPlist = NSDictionary(contentsOfFile: path)
        
        viewController = self.window?.rootViewController as! ViewController
        
        // set up Cognito
        //AWSLogger.defaultLogger().logLevel = .Verbose
        
        credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: AWSRegionType.USEast1, identityPoolId: infoPlist[AppGlobals.IDENTITY_POOL_ID_KEY] as! String)
        
        let defaultServiceConfiguration = AWSServiceConfiguration(
            region: AWSRegionType.USEast1, credentialsProvider: credentialsProvider)
        
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = defaultServiceConfiguration
        
        // tune up kinesis
        kinesis = AWSKinesisRecorder.defaultKinesisRecorder()
        kinesis.diskAgeLimit = 30 * 24 * 60 * 60; // 30 days
        kinesis.diskByteLimit = 100 * 1024 * 1024;
        kinesis.notificationByteThreshold = 80 * 1024 * 1024;
        
        // see if we are already logged in
        let delegate = AuthorizeUserDelegate(parentController: viewController)
        delegate.launchGetAccessToken()
        
        // lastly, wake up session to watch
        wcsession.delegate = self
        wcsession.activateSession()
        
        return true
    }
    
    func application(application: UIApplication, openURL: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        // Pass on the url to the SDK to parse authorization code from the url.
        let isValidRedirectSignInURL = AIMobileLib.handleOpenURL(openURL, sourceApplication: sourceApplication)
        
        return isValidRedirectSignInURL
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if (!self.displayTimer.valid) {
            NSOperationQueue.mainQueue().addOperationWithBlock() {
                self.displayTimer = NSTimer.scheduledTimerWithTimeInterval(
                    AppDelegate.DISPLAY_UPDATE_SEC,
                    target: self,
                    selector: "displayUpdate:",
                    userInfo: nil,
                    repeats: true)
            }
        }
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func displayUpdate(timer : NSTimer) {
        self.viewController.updateDisplayState(self)
    }
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject],replyHandler: ([String : AnyObject]) -> Void) {
        batchesCount++
        NSLog("receiveBatch(\(batchesCount))")
        let payload = message[AppGlobals.PHONE_DATA_KEY] as! NSData
        lastBatchNum = message[AppGlobals.PHONE_DATA_BATCH_ID] as! String
        
        // let's get the payload back
        let data = try! NSJSONSerialization.JSONObjectWithData(payload, options: NSJSONReadingOptions(rawValue: UInt(0))) as! [NSDictionary]
        
        // walk the elements looking for gaps in sensor records
        var i = 0
        for element in data {
            let accelerometerData = AccelerometerData(dateFormatter: dateFormatter, dictionary: element)
            elementsCount++
            i++
            
            if (abs(accelerometerData.timeStamp.timeIntervalSinceDate(lastDate)) > 0.025) {
                NSLog("gap: index=%d, old=%@, new=%@", i, lastDate, accelerometerData.timeStamp)
                gapErrors++
            }
            
            lastItem = accelerometerData
            lastDate = accelerometerData.timeStamp
        }
        
        // send the record
        let outData = [
            AppGlobals.PAYLOAD_USER_ID : viewController.idRaw,
            AppGlobals.PAYLOAD_PROCESS_DATE : dateFormatter.stringFromDate(NSDate()),
            AppGlobals.PAYLOAD_BATCH : data,
            AppGlobals.PAYLOAD_BATCH_ID : lastBatchNum
        ]
        let output = try! NSJSONSerialization.dataWithJSONObject(outData,
            options: NSJSONWritingOptions.PrettyPrinted)
        self.tasks.append(self.kinesis.saveRecord(output, streamName: self.infoPlist[AppGlobals.KINESIS_STREAM_KEY] as! String))
        
        if (!self.flushTimer.valid) {
            NSOperationQueue.mainQueue().addOperationWithBlock() {
                self.flushTimer = NSTimer.scheduledTimerWithTimeInterval(
                    AppDelegate.KINESIS_FLUSH_DELAY_SEC,
                    target: self,
                    selector: "flushHandler:",
                    userInfo: nil,
                    repeats: false)
            }
        }
        replyHandler(NSDictionary() as! [String : AnyObject])
    }
    
    func flushHandler(timer : NSTimer) {
        self.flushCount++
        NSLog("flushHandler(\(self.flushCount))")
        
        AWSTask(forCompletionOfAllTasks: self.tasks).continueWithBlock {
            (task: AWSTask!) -> AWSTask! in
            
            self.tasks = []
            
            // TODO eventually remove this manual refresh of the token if near
            if (self.credentialsProvider.expiration == nil ||
                self.credentialsProvider.expiration.timeIntervalSinceNow < AppDelegate.CREDENTIAL_REFRESH_WINDOW_SEC) {
                    let delegate = AuthorizeUserDelegate(parentController: self.viewController)
                    delegate.launchGetAccessToken()
                    NSLog("refreshed Cognito credentials")
            }
            
            self.timeLastFlush = NSDate()
            self.kinesis.submitAllRecords().continueWithBlock {
                (task: AWSTask!) -> AWSTask! in
                if (task.error != nil) {
                    NSLog("flushHandler error:\(task.error)")
                }
                return task
            }
            return task
        }
    }
}

