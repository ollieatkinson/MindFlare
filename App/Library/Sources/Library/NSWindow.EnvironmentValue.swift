//
// github.com/screensailor 2022
//

import SwiftUI

extension View {

	func windowEnvironmentValue() -> some View {
		modifier(NSWindow.EnvironmentValue())
	}
}

extension EnvironmentValues {

	var windowNumber: Int? {
		get { self[NSWindowNumberKey.self] }
		set { self[NSWindowNumberKey.self] = newValue }
	}

	private struct NSWindowNumberKey: EnvironmentKey {
		static let defaultValue: Int? = nil
	}
}

extension NSWindow {

	struct EnvironmentValue: ViewModifier {

		@State private var windowNumber: Int?

		func body(content: Content) -> some View {
			content
				.background(ViewRepresentable(binding: $windowNumber))
				.environment(\.windowNumber, windowNumber)
		}
	}

	struct ViewRepresentable {
		@Binding var binding: Int?
	}
}

extension NSWindow.ViewRepresentable: NSViewRepresentable {

	func makeCoordinator() -> Coordinator {
		.init(binding: $binding)
	}

	func makeNSView(context: Context) -> View {
		.init(context.coordinator)
	}

	func updateNSView(_: View, context: Context) {}
}

extension NSWindow.ViewRepresentable {

	struct Coordinator {
		@Binding var binding: Int?
	}

	class View: NSStackView {

		let coordinator: Coordinator

		override var description: String {
			"NSStackView/NSWindow.ViewRepresentable"
		}

		required init?(coder: NSCoder) {
			fatalError()
		}

		init(_ coordinator: Coordinator) {
			self.coordinator = coordinator
			super.init(frame: .zero)
		}

		deinit { print("🗑", self) }

		override func viewWillMove(toWindow window: NSWindow?) {
			coordinator.binding = window?.windowNumber
			window?.titlebarAppearsTransparent = true
		}
	}
}

// MARK: interpretKeyEvents

private final class KeyEventInterpreter: NSStackView {

	class TextView: NSTextView {
		override func keyDown(with event: NSEvent) {}
		override func doCommand(by selector: Selector) {}
		override func insertText(_ insertString: Any) {}
	}

	let textView = TextView(frame: .zero, textContainer: nil)

	override var acceptsFirstResponder: Bool { false }

//    let coordinator: Coordinator

	required init?(coder: NSCoder) {
		fatalError()
	}

//    init(_ coordinator: Coordinator) {
//        self.coordinator = coordinator
//        super.init(frame: .zero)
//    }

	deinit { print("🗑", self) }

	override func viewWillMove(toWindow window: NSWindow?) {

		if window != nil {
//            coordinator.view = self
		}
	}

	override func interpretKeyEvents(_ eventArray: [NSEvent]) {
		textView.interpretKeyEvents(eventArray)
	}
}
