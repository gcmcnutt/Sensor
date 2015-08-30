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
    
    // how close to expiration should we refresh STS token?
    static let CREDENTIAL_REFRESH_WINDOW_SEC : Double = 200.0
    
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
    var lastItem = ""
    
    var flushTimer : NSTimer!
    var tasks : [AWSTask] = []
    let lockQueue = dispatch_queue_create("com.accelero.kinesisTaskQueue", nil)
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        
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
        kinesis.diskByteLimit = 5 * 1024 * 1024; // 10MB
        kinesis.notificationByteThreshold = 4 * 1024 * 1024; // 5MB
        
        // see if we are already logged in
        let delegate = AuthorizeUserDelegate(parentController: viewController)
        delegate.launchGetAccessToken()
        
        // wake up session to watch (ASSUMES no early phone->watch messages...)
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
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        batchesCount++
        NSLog("receiveBatch(\(batchesCount))")
        let payload = message[AppGlobals.ACCELEROMETER_KEY] as! [String]
        var elements : [String] = []
        
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
        
        // send the record
        let data = try! NSJSONSerialization.dataWithJSONObject(payload, options: NSJSONWritingOptions.PrettyPrinted)
        
        dispatch_sync(lockQueue) {
            self.tasks.append(self.kinesis.saveRecord(data, streamName: self.infoPlist[AppGlobals.KINESIS_STREAM_KEY] as! String))
            
            if (self.flushTimer == nil) {
                NSOperationQueue.mainQueue().addOperationWithBlock() {
                    self.flushTimer = NSTimer.scheduledTimerWithTimeInterval(
                        AppDelegate.KINESIS_FLUSH_DELAY_SEC,
                        target: self,
                        selector: "flushHandler:",
                        userInfo: nil,
                        repeats: false)
                }
            }
        }
        
        viewController.updateSensorState(self, elements: elements)
        viewController.updateKinesisState(self)
    }
    
    func flushHandler(timer : NSTimer) {
        self.flushCount++
        NSLog("flushHandler(\(self.flushCount))")
        
        dispatch_sync(lockQueue) {
            
            AWSTask(forCompletionOfAllTasks: self.tasks).continueWithSuccessBlock {
                (task: AWSTask!) -> AWSTask! in
                
                self.tasks = []
                self.flushTimer = nil
                
                // TODO eventually remove this manual refresh of the token if near
                if (self.credentialsProvider.expiration == nil ||
                    self.credentialsProvider.expiration.timeIntervalSinceNow < AppDelegate.CREDENTIAL_REFRESH_WINDOW_SEC) {
                        self.credentialsProvider.refresh()
                }
                
                self.timeLastFlush = NSDate()
                return self.kinesis.submitAllRecords()
            }
        }
        viewController.updateKinesisState(self)
    }
}

