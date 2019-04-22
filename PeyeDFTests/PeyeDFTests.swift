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

import Cocoa
import XCTest
@testable import PeyeDF

class UtilsTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /// Tests the binary search by creating a random vector of 10 000 values in increasing order and making sure the found value corresponds to what should have been found
    func testBinarySearch() {
        // testing using predefined values
        let myArr: [Double] = [1,1,2,2,3,4,5,6,6,7,7]
        var testOne = binaryGreaterOrEqOnSortedArray(myArr, target:2)
        XCTAssert(testOne == 2, "Should find third element of test array")
        testOne = binaryGreaterOrEqOnSortedArray(myArr, target:6.9)
        XCTAssert(testOne == 9, "Should find penultimate element of test array")
        testOne = binaryGreaterOrEqOnSortedArray(myArr, target:7)
        XCTAssert(testOne == 9, "Should find penultimate element of test array")
        testOne = binaryGreaterOrEqOnSortedArray(myArr, target:7.1)
        XCTAssert(testOne == myArr.count, "Should find count of test array")
        
        // testing using a random array
        var randVals = [CGFloat]()
        for _ in 1..<10000 {
            randVals.append(CGFloat(arc4random()) / 10000.00)
        }
        let sortedVals = randVals.sorted()
        let theTarget = CGFloat(arc4random()) / 10000.00
        let foundI = binaryGreaterOnSortedArray(sortedVals, target: theTarget)
        if foundI == sortedVals.count {
            XCTAssert(sortedVals.last! <= theTarget, "Last item + 1 correctly found")
        } else if foundI == 0 {
            XCTAssert(sortedVals.first! > theTarget, "Item 0 correctly found")
        } else {
            let foundElem = sortedVals[foundI]
            let previousElem = sortedVals[foundI - 1]
            XCTAssert(foundElem > theTarget , "Following item correctly found")
            XCTAssert(previousElem <= theTarget , "Previous item correctly found")
        }
    }
    
    func testStrideTest() {
        var testArr: [Double] = [1,2,3,4,5,6,7]
        XCTAssertTrue(strideArrayTest(ary: testArr, index: 2, precedingFunc: <, followingFunc: >))
        
        testArr = [1,2,3,4,5,4,5,6,7]
        XCTAssertFalse(strideArrayTest(ary: testArr, index: 5, precedingFunc: <, followingFunc: >))
        
        testArr = [1,2,3,4,5,4,5,6,7]
        XCTAssertTrue(strideArrayTest(ary: testArr, index: 2, strideLength: 2, precedingFunc: <, followingFunc: >))
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // repeats the testBinarySearch() 10 times
            for _ in 1..<10 {
                self.testBinarySearch()
            }
        }
    }
    
}
