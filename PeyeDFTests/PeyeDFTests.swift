//
//  PeyeDFTests.swift
//  PeyeDFTests
//
//  Created by Marco Filetti on 18/06/2015.
//  Copyright (c) 2015 HIIT. All rights reserved.
//

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
            randVals.append(CGFloat(random()) / 10000.00)
        }
        let sortedVals = randVals.sort()
        let theTarget = CGFloat(random()) / 10000.00
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
        self.measureBlock() {
            // repeats the testBinarySearch() 1000 times
            for _ in 1..<100 {
                self.testBinarySearch()
            }
        }
    }
    
}
