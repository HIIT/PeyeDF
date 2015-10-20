//
//  Person.swift
//  PeyeDF
//
//  Created by Marco Filetti on 20/10/2015.
//  Copyright © 2015 HIIT. All rights reserved.
//

import Foundation

/// A person is represented by this struct (not a class)
struct Person: CustomStringConvertible, Dictionariable {
    
    let firstName: String
    let lastName: String
    /// middle names not used right now
    let middleNames: [String]?
    
    /// Returns the name in a string separated by spaces, such as "FistName MiddleName1 MiddleName2 LastName"
    var description: String { get {
        var outVal = firstName + " "
        if let middleNames = middleNames {
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
                        middleNames = [String]()
                        for remName in resplitted! {
                            middleNames!.append(remName)
                        }
                    } else {
                        middleNames = nil
                    }
                }
                else {
                    self.firstName = spl[1]
                    self.middleNames = nil
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
                    middleNames = [String]()
                    for i in 1..<spl.count - 1 {
                        middleNames!.append(spl[i])
                    }
                } else {
                    middleNames = nil
                }
            } else {
                return nil
            }
        }
    }
    
    /// Returns itself in a dict of strings, matching DiMe's Person class
    func getDict() -> [String : AnyObject] {
        var retDict = [String: AnyObject]()
        retDict["firstName"] = firstName
        retDict["lastName"] = lastName
        if let midNames = middleNames {
            retDict["middleNames"] = midNames
        }
        
        // dime-required
        retDict["@type"] = "Person"
        retDict["type"] = "http://www.hiit.fi/ontologies/dime/#Person"
        
        return retDict
    }
}