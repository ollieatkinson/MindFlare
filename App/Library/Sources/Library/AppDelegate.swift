//
// github.com/screensailor 2022
//

import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

	func applicationDidFinishLaunching(_: Notification) {
		NSWindow.swizzle(
			method: #selector(NSWindow.swizzled_sendEvent(_:)),
			inPlaceOf: #selector(NSWindow.sendEvent(_:))
		)
			NSResponder.swizzle(
				method: #selector(NSResponder.swizzled_noResponder(for:)),
				inPlaceOf: #selector(NSResponder.noResponder(for:))
			)
			NSResponder.swizzle(
				method: #selector(NSResponder.swizzled_insertText(_:)),
				inPlaceOf: #selector(NSResponder.insertText(_:))
			)
		}
	}

extension NSWindow {

	static let keyDown = PassthroughSubject<NSEvent, Never>()

	@objc func swizzled_sendEvent(_ event: NSEvent) {
		if event.type == .keyDown {
			NSWindow.keyDown.send(event)
		}
		swizzled_sendEvent(event)
	}
}

extension NSResponder {

	struct InsertedText {
		let windowNumber: Int
		let string: String
	}

	static let insertedText = PassthroughSubject<InsertedText, Never>()

	@objc func swizzled_noResponder(for selector: Selector) {
		if selector == #selector(keyDown(with:)) {
			// don't beep!
		} else {
			swizzled_noResponder(for: selector)
		}
	}

	@objc func swizzled_insertText(_ insertString: Any) {
		if
			NSApp.currentEvent?.type != .keyDown,
			let string = Self.string(from: insertString),
			!string.isEmpty,
			let windowNumber = insertionWindowNumber
		{
			Self.insertedText.send(InsertedText(windowNumber: windowNumber, string: string))
		}
		swizzled_insertText(insertString)
	}

	private var insertionWindowNumber: Int? {
		switch self {
			case let window as NSWindow:
				window.windowNumber
			case let view as NSView:
				view.window?.windowNumber
			default:
				nil
		}
	}

	private static func string(from insertString: Any) -> String? {
		switch insertString {
			case let string as String:
				string
			case let string as NSAttributedString:
				string.string
			default:
				nil
		}
	}
}

public extension NSObjectProtocol {

	static func swizzle(method new: Selector, inPlaceOf old: Selector) {
		guard
			let old = class_getInstanceMethod(self, old),
			let new = class_getInstanceMethod(self, new)
		else { return }
		method_exchangeImplementations(old, new)
	}
}
