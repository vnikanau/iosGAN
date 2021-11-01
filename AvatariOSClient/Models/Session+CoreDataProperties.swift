//
//  Session+CoreDataProperties.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 9/21/20.
//
//

import Foundation
import CoreData


extension Session {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Session> {
        return NSFetchRequest<Session>(entityName: "Session")
    }

    @NSManaged public var date: Date?
    @NSManaged public var local: Bool
    @NSManaged public var modelDescription: String?
    @NSManaged public var modelDetailsUrl: URL?
    @NSManaged public var modelName: String?
    @NSManaged public var modelUrl: URL?
    @NSManaged public var path: URL?
    @NSManaged public var processed: Bool
    @NSManaged public var uploaded: Bool
    @NSManaged public var modelId: String?

}

extension Session : Identifiable {

}
