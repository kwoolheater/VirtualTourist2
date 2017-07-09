//
//  Image+CoreDataClass.swift
//  VirtualTourist2
//
//  Created by Kiyoshi Woolheater on 7/8/17.
//  Copyright © 2017 Kiyoshi Woolheater. All rights reserved.
//

import Foundation
import CoreData

@objc(Image)
public class Image: NSManagedObject {
    
    convenience init(pin: Pin, imageData: NSData, context: NSManagedObjectContext) {
        if let ent = NSEntityDescription.entity(forEntityName: "Image", in: context){
            self.init(entity: ent, insertInto: context)
            self.pin = pin
            self.imageData = imageData
        } else {
            fatalError("Could not find Entity Name!")
        }
    }

}
