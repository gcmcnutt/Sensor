//
//  ComplicationController.swift
//  sensor WatchKit Extension
//
//  Created by Greg McNutt on 7/29/15.
//  Copyright © 2015 Greg McNutt. All rights reserved.
//

import ClockKit


class ComplicationController: NSObject, CLKComplicationDataSource {
    var currentCount = 0;
    var beforeCount = 0;
    var afterCount = 0;
    var lastUpdate : NSDate?
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirectionsForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.Backward, .Forward])
    }
    
    func getTimelineStartDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        handler(NSDate(timeIntervalSinceNow: (-60 * 60 * 4)))
    }
    
    func getTimelineEndDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        handler(NSDate(timeIntervalSinceNow: (60 * 60 * 4)))
    }
    
    func getPrivacyBehaviorForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.ShowOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntryForComplication(complication: CLKComplication, withHandler handler: ((CLKComplicationTimelineEntry?) -> Void)) {
        // Call the handler with the current timeline entry

        currentCount++
        handler(getEntry("current"))
    }
    
    func getTimelineEntriesForComplication(complication: CLKComplication, beforeDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries prior to the given date

        beforeCount++
        handler([getEntry("before")])
    }
    
    func getTimelineEntriesForComplication(complication: CLKComplication, afterDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries after to the given date
        
        afterCount++
        handler([getEntry("after")])
    }
    
    // MARK: - Update Scheduling
    
    func getNextRequestedUpdateDateWithHandler(handler: (NSDate?) -> Void) {
        // Call the handler with the date when you would next like to be given the opportunity to update your complication content
        handler(NSDate(timeIntervalSinceNow: 60.0));
    }
    
    // MARK: - Placeholder Templates
    
    func getPlaceholderTemplateForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        let template = CLKComplicationTemplateModularLargeStandardBody()
        
        template.headerTextProvider = CLKTimeTextProvider(date: NSDate())
        template.body1TextProvider = CLKSimpleTextProvider(text: "Count", shortText: "#")
        template.body2TextProvider = CLKSimpleTextProvider(text: "HelloWorld", shortText: "hi")
        
        handler(template)
    }
    
    func getEntry(source: String) -> CLKComplicationTimelineEntry {
        let template = CLKComplicationTemplateModularLargeStandardBody()
        lastUpdate = NSDate()
        
        template.headerTextProvider = CLKTimeTextProvider(date: lastUpdate!)
        template.body1TextProvider = CLKSimpleTextProvider(text: "c:\(currentCount) b:\(beforeCount) a:\(afterCount)")
        template.body2TextProvider = CLKSimpleTextProvider(text: source)

        return CLKComplicationTimelineEntry(date: lastUpdate!, complicationTemplate: template)
    }
}
