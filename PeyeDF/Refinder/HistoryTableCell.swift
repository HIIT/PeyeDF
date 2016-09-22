//
// Copyright (c) 2015 Aalto University
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

import Cocoa

class HistoryTableCell: NSTableCellView {
    
    static let dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [NSCalendar.Unit.hour, NSCalendar.Unit.minute]
        return formatter
    }()

    @IBOutlet weak var filenameLab: NSTextField!
    @IBOutlet weak var titleLab: NSTextField!
    @IBOutlet weak var authorsLab: NSTextField!
    @IBOutlet weak var dateLab: NSTextField!
    
    @IBOutlet weak var readingTimeLab: NSTextField!
    @IBOutlet weak var readingTimeClock: LittleClock!
    
    @IBOutlet weak var readBar: RefinderProgressIndicator!
    @IBOutlet weak var interestingBar: RefinderProgressIndicator!
    @IBOutlet weak var criticalBar: RefinderProgressIndicator!
    
    func setValues(fromReadingEvent readingEvent: SummaryReadingEvent, sciDoc: ScientificDocument) {
        DispatchQueue.main.async {
            if UserDefaults.standard.value(forKey: PeyeConstants.prefUseEyeTracker) as! Bool {
                self.readBar.setProgress(readingEvent.proportionRead, forClass: .low)
            } else {
                self.readBar.setProgress(readingEvent.proportionSeen, forClass: .low)
            }
            self.interestingBar.setProgress(readingEvent.proportionInteresting, forClass: .medium)
            self.criticalBar.setProgress(readingEvent.proportionCritical, forClass: .high)
            
            let fnameUrl = URL(fileURLWithPath: sciDoc.uri)
            self.filenameLab.stringValue = fnameUrl.lastPathComponent
            if let tit = sciDoc.title {
                self.titleLab.stringValue = tit
            } else {
                self.titleLab.stringValue = sciDoc.uri
            }
            if let authors = sciDoc.authors {
                self.authorsLab.stringValue = authors.description
            } else {
                self.authorsLab.stringValue = ""
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            dateFormatter.timeStyle = .medium
            self.dateLab.stringValue = dateFormatter.string(from: readingEvent.startDate as Date)
            
            if let rTime = readingEvent.readingTime {
                self.readingTimeLab.stringValue = HistoryTableCell.dateComponentsFormatter.string(from: rTime)!
                self.readingTimeLab.isHidden = false
                self.readingTimeClock.hours = CGFloat((rTime / 3600))
                self.readingTimeClock.minutes = CGFloat((rTime / 60).truncatingRemainder(dividingBy: 60))
                self.readingTimeClock.showClock = true
            }
        }
    }
}
