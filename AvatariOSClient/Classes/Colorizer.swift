//
//  Colorizer.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/19/20.
//

import Foundation

class Colorizer {

    struct storedColors {
        var id: UUID
        var color: UIColor
    }
    var savedColors = [storedColors]()

    init() {

    }

    func assignColor(to: UUID, classification: ARMeshClassification) -> UIColor {
        return savedColors.first(where: { $0.id == to })?.color ?? saveColor(uuid: to, classification: classification)
    }

    func color(forUUID uuid: UUID, classsification: ARMeshClassification) -> UIColor {
        var hasher = Hasher()
        hasher.combine(uuid)
        hasher.combine(classsification)
        let hash = hasher.finalize()
        let colorCode = abs(hash) % 0x1000000
        let red = colorCode >> 16
        let green = (colorCode >> 8) & 0xff
        let blue = colorCode & 0xff
        return UIColor(red: CGFloat(red) / 256, green: CGFloat(green) / 256, blue: CGFloat(blue) / 256, alpha: 1)
    }

    func saveColor(uuid: UUID, classification: ARMeshClassification) -> UIColor {
        let newColor = color(forUUID: uuid, classsification: classification).withAlphaComponent(0.7)
        let stored = storedColors(id: uuid, color: newColor)
        savedColors.append(stored)
        return newColor
    }
}
