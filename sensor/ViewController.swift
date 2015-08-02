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

    @IBOutlet weak var reachableVal: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // register listener for extension messages
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "phoneReachabilityHandler:", name: "phoneReachability", object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func phoneReachabilityHandler(notification: NSNotification) {
        let session = notification.object as! WCSession
        if (session.reachable) {
            self.reachableVal.textColor = UIColor.greenColor()
            self.reachableVal.text = "reachable"
        } else {
            self.reachableVal.textColor = UIColor.redColor()
            self.reachableVal.text = "not reachable"
        }
    }
}

