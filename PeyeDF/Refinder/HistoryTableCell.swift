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
    
    func setValues(fromReadingEvent readingEvent: ReadingEvent, sciDoc: ScientificDocument?) {
        if let sciDoc = sciDoc {
            // TODO: remove debugging checks
            for page in readingEvent.manualMarkings.get(ReadingClass.Interesting).keys {
                Swift.print("On page \(page) there are \(readingEvent.manualMarkings.get(.Interesting)[page]!.count) interesting rectangles")
            }
            let fnameUrl = NSURL(fileURLWithPath: sciDoc.uri.skipPrefix(7)) // skip file://: 7 chars
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
}
