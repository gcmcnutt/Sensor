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

    @IBOutlet weak var batchesVal: UILabel!
    @IBOutlet weak var elementsVal: UILabel!
    @IBOutlet weak var lastBatchVal: UILabel!
    @IBOutlet weak var lastTimeVal: UILabel!
    @IBOutlet weak var lastXVal: UILabel!
    @IBOutlet weak var lastYVal: UILabel!
    @IBOutlet weak var lastZVal: UILabel!
    
    var batchesCount = 0
    var elementsCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func renderNewData(userInfo: [String : AnyObject]) {
        batchesCount++
        let payload = userInfo["data"] as! [String]
        
        elementsCount += payload.count
        
        // TODO temporary until WCSession serialization support
        let lastItem = (payload[payload.count-1] as String!).componentsSeparatedByString(",")
        
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.batchesVal.text = self.batchesCount.description
            self.elementsVal.text = self.elementsCount.description
            self.lastBatchVal.text = lastItem[0]
            self.lastTimeVal.text = lastItem[1]
            self.lastXVal.text = lastItem[2]
            self.lastYVal.text = lastItem[3]
            self.lastZVal.text = lastItem[4]
        }
    }
}

