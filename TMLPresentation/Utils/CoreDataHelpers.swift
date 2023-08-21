//
//  CoreDataHelpers.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation

//
// ValueTransformer to store images as PNGs in the database
//
public final class ImageTransformer : ValueTransformer {
    public override class func transformedValueClass() -> AnyClass {
        return UIImage.self
    }

    public override class func allowsReverseTransformation() -> Bool {
        return true
    }

    public override func transformedValue(_ value: Any?) -> Any? {
        guard let image = value as? UIImage else {
            Log.fatal("Image transformer confused")
        }
        return image.pngData()
    }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            Log.fatal("Image transformer confused")
        }
        return UIImage(data: data)
    }

    /// One-time step
    public static func install() {
        ValueTransformer.setValueTransformer(ImageTransformer(), forName: NSValueTransformerName(rawValue: "ImageTransformer"))
    }
}

