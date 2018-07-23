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
