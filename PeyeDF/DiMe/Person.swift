//
//  Person.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation

/// A person is represented by this struct (not a class)
class Person: DiMeBase {
    
    private(set) var firstName: String = "N/A"
    private(set) var lastName: String = "N/A"
    private(set) var middleNames: [String] = [String]()
    
    /// Returns the name in a string separated by spaces, such as "FistName MiddleName1 MiddleName2 LastName"
    override var description: String { get {
        var outVal = firstName + " "
        if middleNames.count > 0 {
            for midName in middleNames {
                outVal += midName + " "
            }
        }
        outVal += lastName
        return outVal
        } }
    
    /// Generates a person from a string. If there is a comma in the string, it is assumed that the first name after the comma, otherwise first name is the first non-whitespace separated string, and last name is the last. Middle names are assumed to all come after the first name if there was a comma, between first and last if there is no comma.
    /// **Fails (returns nil) if the string could not be parsed.**
    init?(fromString string: String) {
        super.init()
        
        if string.containsChar(",") {
            let splitted = string.split(",")
            guard let spl = splitted else {
                return nil
            }
            if spl.count == 2 {
                self.lastName = spl[0]
                
                // check if there are middle names in the following part
                if spl[1].containsChar(" ") {
                    var resplitted = spl[1].split(" ")
                    self.firstName = resplitted!.removeAtIndex(0)
                    if resplitted!.count > 0 {
                        for remName in resplitted! {
                            middleNames.append(remName)
                        }
                    }
                }
                else {
                    self.firstName = spl[1]
                }
            } else {
                return nil
            }
        } else {
            let splitted = string.split(" ")
            guard let spl = splitted else {
                return nil
            }
            if spl.count >= 2 {
                self.firstName = spl.first!
                self.lastName = spl.last!
                if spl.count > 2 {
                    for i in 1..<spl.count - 1 {
                        middleNames.append(spl[i])
                    }
                }
            } else {
                return nil
            }
        }
        
        theDictionary["firstName"] = firstName
        theDictionary["lastName"] = lastName
        if middleNames.count > 0 {
            theDictionary["middleNames"] = middleNames
        }
        
        // dime-required
        theDictionary["@type"] = "Person"
        theDictionary["type"] = "http://www.hiit.fi/ontologies/dime/#Person"
    }
    
}