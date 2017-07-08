//
//  Pin+CoreDataProperties.swift
//  VirtualTourist2
//
//  Created by Kiyoshi Woolheater on 7/8/17.
//  Copyright © 2017 Kiyoshi Woolheater. All rights reserved.
//

import Foundation
import CoreData


extension Pin {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Pin> {
        return NSFetchRequest<Pin>(entityName: "Pin")
    }

    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var image: NSSet?

}

// MARK: Generated accessors for image
extension Pin {

    @objc(addImageObject:)
    @NSManaged public func addToImage(_ value: Image)

    @objc(removeImageObject:)
    @NSManaged public func removeFromImage(_ value: Image)

    @objc(addImage:)
    @NSManaged public func addToImage(_ values: NSSet)

    @objc(removeImage:)
    @NSManaged public func removeFromImage(_ values: NSSet)

}
