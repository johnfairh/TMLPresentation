//
//  UIKitArtHelpers.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation
import UIKit

/// Image resizing and badging - originally guided by a stackoverflow answers
/// but evolved under all my own horrible hard-coded ways...
extension UIImage {

    public static var badgeColor: UIColor?

    private func addTextBadge(_ size: CGSize, text: String) {
        let nsString = NSString(string: text)

        let font = UIFont(name: "AvenirNext-Bold", size: 18)!

        var attrs: [NSAttributedString.Key: Any] =
            [ NSAttributedString.Key.font: font,
              NSAttributedString.Key.strokeWidth: 10.0,
              NSAttributedString.Key.strokeColor: UIColor.black,
              NSAttributedString.Key.foregroundColor: UIImage.badgeColor ?? UIColor.white ]

        let textSize = nsString.size(withAttributes: attrs)
        var xOffset = 1, yOffset = 3
        if size.width > 60 {
            xOffset = 3
            yOffset = 0
        }
        let stringPoint = CGPoint(x: size.width-textSize.width-CGFloat(xOffset),
                                  y: size.height-textSize.height+CGFloat(yOffset))

        // seem to have to draw this twice, can't do both outline + fill??
        nsString.draw(at: stringPoint, withAttributes: attrs)

        attrs.removeValue(forKey: NSAttributedString.Key.strokeWidth)
        attrs.removeValue(forKey: NSAttributedString.Key.strokeColor)

        nsString.draw(at: stringPoint, withAttributes: attrs)
    }

    private func addFavMark(_ size: CGSize) {
        let nsString = NSString(string: "★")

        let font = UIFont(name: "AvenirNext-Bold", size: 18)!

        let attrs = [ NSAttributedString.Key.font: font,
                      NSAttributedString.Key.foregroundColor: UIColor(red: 240.0/255.0, green: 12.0/255.0, blue: 127.0/255.0, alpha: 1) ]

        nsString.draw(at: CGPoint(x: 0, y: -3), withAttributes: attrs)
    }

    public func imageWithTextBadge(_ text: String?, fav: Bool = false) -> UIImage {
        return imageWithSize(size, andBadge: text, fav: fav)
    }

    public func imageWithSize(_ size: CGSize, andBadge text: String? = nil, fav: Bool = false) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(
            size,
            false, // opaque
            UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))

        if let text = text {
            addTextBadge(size, text: text)
        }

        if fav {
            addFavMark(size)
        }

        return UIGraphicsGetImageFromCurrentImageContext()!
    }
}

/// Prettify icon views
extension UIImageView {
    public func enableRoundCorners(width: Int? = nil) {
        layer.cornerCurve = .continuous
        layer.cornerRadius = 6
        layer.masksToBounds = true
        if let width = width {
            layer.borderWidth = CGFloat(width)
        }
    }
}

/// Prettify a view
extension UIView {
    public func enableBorder() {
        layer.cornerCurve  = .continuous
        layer.cornerRadius = 6
        layer.borderWidth  = 1
        layer.borderColor  = UIColor.lightGray.cgColor
    }
}
