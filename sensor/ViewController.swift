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
    @IBOutlet weak var gapErrorsVal: UILabel!
    
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
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func renderNewData(userInfo: [String : AnyObject]) {
        batchesCount++
        let payload = userInfo["data"] as! [String]
        var elements : [String] = []
        
        // walk the elements looking for gaps in sensor records
        for item in payload {
            elementsCount++
            elements = item.componentsSeparatedByString(",")
            
            let date = dateFormatter.dateFromString(elements[1])!
            if (date.timeIntervalSinceDate(lastDate) > 0.025) {
                NSLog("gap: old=%@, new=%@", lastItem, item)
                gapErrors++
            }
            
            lastItem = item
            lastDate = date
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
        }
    }
}

