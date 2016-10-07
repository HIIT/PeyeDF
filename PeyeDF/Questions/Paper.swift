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

import Foundation

enum TargetTopicGroup: String {
    case A
    case B
}

/// Represents a paper which associated filename, code and target topic group
class Paper: NSObject {
    override var description: String { get {
        return self.code + "_" + self.group.rawValue
        } }
        
    /// Default papers
    /// - Note: Last one (index 4) is the practice paper. Note that practice only has ttg A)
    static let defaultPapers = [(code: "P1", filename: "Bener2011_asthma.pdf", title: "The Impact of Asthma and Allergic Diseases on Schoolchildren"),
                                (code: "P2", filename: "StewartEtAl2013_ClinicalPsychology.pdf", title: "Acceptability of Psychotherapy, Pharmacotherapy, and Self-Directed Therapies in Australians Living with Chronic Hepatitis C"),
                                (code: "P3", filename: "HardcastleEtAl2012_Motivational.pdf", title: "The effectiveness of a motivational interviewing primary-care based intervention"),
                                (code: "P4", filename: "Rose2012_Placebo.pdf", title: "Choice and placebo expectation effects in the context of pain analgesia"),
                                (code: "Practice", filename: "PrimackEtAl2012_Waterpipe.pdf", title: "Waterpipe Smoking Among U.S. University Students")]
    
    /// Creates a paper from a number (0 to 3) and a target topic group (A, or B)
    init(fromDefault: Int, withGroup: TargetTopicGroup) {
        code = Paper.defaultPapers[fromDefault].code
        filename = Paper.defaultPapers[fromDefault].filename
        index = fromDefault
        group = withGroup
        title = Paper.defaultPapers[fromDefault].title
    }
    
    let code: String
    let index: Int
    let filename: String
    let title: String
    let group: TargetTopicGroup
}
