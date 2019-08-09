//
//  UIKitControlHelpers.swift
//  TMLPresentation
//
//  Distributed under the MIT license, see LICENSE.
//

import Foundation
import UIKit

/// Manage a picker that is a list of fixed strings
public final class StringPicker : NSObject, UIPickerViewDelegate, UIPickerViewDataSource {

    // Store the strings to be picked from, user responsible for any sort order
    private var values: [String]

    public init(values: [String]) {
        self.values = values
    }

    // Assigning a picker makes us take it over
    //
    public var picker: UIPickerView? {
        didSet {
            picker?.delegate = self
            picker?.dataSource = self
            picker?.reloadAllComponents()
            picker?.selectRow(values.count/2, inComponent: 0, animated: false)
        }
    }

    public var selectedValue: String {
        guard let row = picker?.selectedRow(inComponent: 0) else {
            fatalError("Picker not configured")
        }
        return values[row]
    }

    // MARK: - UIPickerViewDataSource

    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        assert(component == 0)
        return values.count
    }

    // MARK: - UIPickerViewDelegate

    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        assert(component == 0)
        return values[row]
    }
}

/// Utility to pop up a cancel/delete dialog
extension UIViewController {
    public func confirmDelete(title: String, message: String, delete: @escaping (UIAlertAction) -> Void) {
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: delete)

        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)

        present(alertController, animated: false, completion: nil)
    }
}

extension UITextField {
    /// Attempt to autocomplete some new typing in a `UITextField`
    ///
    /// Call from the `shouldChangeCharactersInRange` delegate method.
    /// - returns: `true` if autocomplete happened and the text field
    ///     has been updated.  `false` if no autcomplete, let iOS normal
    ///     behaviour happen.
    ///
    /// Credit Greg Brown.
    public func autoCompleteText(newText: String, suggestions: [String]) -> Bool {
        guard !newText.isEmpty,                         // typed something
            let selectedTextRange = selectedTextRange,  // have cursor
            selectedTextRange.end == endOfDocument,     // cursor at end of text
            let prefixRange = textRange(from: beginningOfDocument, to: selectedTextRange.start),
                                                        // world not broken #1
            let preText = text(in: prefixRange) else {  // world not broken #2
                // Not a normal typing situation, bail
                return false
        }

        let prefix = preText + newText // existing in box + just-typed stuff
        let matches = suggestions.filter { $0.hasPrefix(prefix) }

        guard matches.count > 0 else {
            // No match, let the new typing in
            return false
        }

        // Update text & attempt to update selection to what we autocompleted
        text = matches[0]
        if let start = position(from: beginningOfDocument, offset: prefix.count) {
            self.selectedTextRange = textRange(from: start, to: endOfDocument)
        }
        return true
    }
}

extension UIViewController {
    /// Pop up simple choice at bottom of screen, report which one is made
    public func presentActionSheetChoice<T>(choices: [String], results: [T], done: @escaping (T?) -> Void) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for (index, choice) in choices.enumerated() {
            alert.addAction(UIAlertAction(title: choice, style: .default) {_ in done(results[index]) })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) {_ in done(nil) })
        present(alert, animated: true)
    }
}
