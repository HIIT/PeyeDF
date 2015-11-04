//
//  HistoryTableCell.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Cocoa

class HistoryTableCell: NSTableCellView {

    @IBOutlet weak var filenameLab: NSTextField!
    @IBOutlet weak var titleLab: NSTextField!
    @IBOutlet weak var authorsLab: NSTextField!
    @IBOutlet weak var dateLab: NSTextField!
    
    @IBOutlet weak var readBar: RefinderProgressIndicator!
    @IBOutlet weak var interestingBar: RefinderProgressIndicator!
    @IBOutlet weak var criticalBar: RefinderProgressIndicator!
    
    func setValues(fromReadingEvent readingEvent: ReadingEvent, sciDoc: ScientificDocument) {
        readBar.setProgress(readingEvent.proportionRead!, forClass: .Read)
        interestingBar.setProgress(readingEvent.proportionInteresting!, forClass: .Interesting)
        criticalBar.setProgress(readingEvent.proportionCritical!, forClass: .Critical)
        
        let fnameUrl = NSURL(fileURLWithPath: sciDoc.uri)
        filenameLab.stringValue = fnameUrl.lastPathComponent!
        if let tit = sciDoc.title {
            titleLab.stringValue = tit
        } else {
            titleLab.stringValue = sciDoc.uri
        }
        if let authors = sciDoc.authors {
            authorsLab.stringValue = authors.description
        } else {
            authorsLab.stringValue = ""
        }
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = .FullStyle
        dateFormatter.timeStyle = .MediumStyle
        dateLab.stringValue = dateFormatter.stringFromDate(readingEvent.startDate)
    }
}
