//
// Copyright (c) 2018 University of Helsinki, Aalto University
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

// MARK: - Rectangle reading classes

/// How important is a paragraph
public enum ReadingClass: Int {
    case unset = 0
    case tag = 1  // note: this is treated separately ("tags" are not "marks")
    case viewport = 10
    case paragraph = 15
    case low = 20  // known as "read" in dime
    case foundString = 25
    case medium = 30  // known as "critical" in dime
    case high = 40  // known as "high" in dime
}

// MARK: - Rectangle class source

/// What decided that a paragraph is important
public enum ClassSource: Int {
    case unset = 0
    case viewport = 1
    case click = 2  // "Quick-annotate" function: double click for important, triple for critical
    case eye = 3
    case ml = 4
    case search = 5
    case localPeer = 6
    case networkPeer = 7
    case manualSelection = 8 // Selected by dragging and then setting importance
    case anyPeer = 9
}
