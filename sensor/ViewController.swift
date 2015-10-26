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
    
    // TODO A little hacky to rendezvous this value through view...
    var idRaw : String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
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
    
    func updateDisplayState(appDelegate : AppDelegate) {
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.batchesVal.text = appDelegate.batchesCount.description
            self.elementsVal.text = appDelegate.elementsCount.description
            self.lastBatchVal.text = appDelegate.lastBatchNum
            if let ts = appDelegate.lastItem?.timeStamp {
                self.lastTimeVal.text = AppGlobals.sharedInstance.dateFormatter.stringFromDate(ts)
            } else {
                self.lastTimeVal.text = nil
            }
            self.lastXVal.text = appDelegate.lastItem?.x.description
            self.lastYVal.text = appDelegate.lastItem?.y.description
            self.lastZVal.text = appDelegate.lastItem?.z.description
            self.gapErrorsVal.text = appDelegate.gapErrors.description
            
            self.localStorageVal.text = appDelegate.kinesis.diskBytesUsed.description
            self.flushCountVal.text = appDelegate.flushCount.description
            self.lastFlushTimeVal.text = AppGlobals.sharedInstance.dateFormatter.stringFromDate(appDelegate.timeLastFlush)
            if let ts = appDelegate.credentialsProvider.expiration {
                self.tokenExpireVal.text = AppGlobals.sharedInstance.dateFormatter.stringFromDate(ts)
            } else {
                self.tokenExpireVal.text = nil
            }
        }
    }
    
    func updateLoginState(name : String = "", email : String = "", userId : String = "", postal : String = "") {
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.nameVal.text = name
            self.emailVal.text = email
            self.idVal.text = userId
            self.idRaw = userId
            self.postalVal.text = postal
        }
    }
}

