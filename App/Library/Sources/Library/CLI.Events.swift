//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon
import UniformTypeIdentifiers

extension View {

	func cliEvents<A: L & I_app_ui_cli>(
		for cli: K<A>,
		while isEnabled: @escaping () -> Bool = { true }
	) -> some View {
		modifier(CLI.Events(cli: cli, isEnabled: isEnabled))
	}
}

extension CLI {

	struct Events<A: L & I_app_ui_cli>: ViewModifier {

		@Environment(\.events) var events
		@Environment(\.windowNumber) var windowNumber
		@Environment(\.isSearching) var isSearching

		let cli: K<A>
		let isEnabled: () -> Bool

		func body(content: Content) -> some View {

			content
				.onReceive(NSWindow.keyDown) { event in

					guard
						event.windowNumber == windowNumber,
						!isSearching,
						isEnabled()
					else {
						return
					}

					if event.keyCode == .escKey {
						events.send(Event(app.menu.edit.cancel))
						return
					}

					switch (event.specialKey, event.characters.map(String.init(_:))) {

						case (_, "\r"):
							break

						case (.delete?, _), (.leftArrow?, _):
							if event.modifierFlags.contains(.command) {
								events.send(Event(cli.reset))
							} else {
								events.send(Event(cli.backspace))
							}

						case (.tab?, _), (.rightArrow?, _), (_, " "), (_, "."):
							events.send(Event(cli.enter))

						case (.upArrow?, _):
							events.send(Event(cli.select.previous))

						case (.downArrow?, _):
							events.send(Event(cli.select.next))

						case (_, let c?)
							where event.modifierFlags.isDisjoint(with: [.control, .option, .command])
							&& c.count == 1:

							events.send(Event(cli.append[String(c.first!)]))

						default:
							break
					}
				}
				.onReceive(NSResponder.insertedText) { input in

					guard
						input.windowNumber == windowNumber,
						!isSearching,
						isEnabled()
					else {
						return
					}

					for character in input.string {
						switch character {
							case "\r", "\n", "\t", " ", ".":
								events.send(Event(cli.enter))
							default:
								events.send(Event(cli.append[String(character)]))
						}
					}
				}
		}
	}
}

private extension UInt16 {
	static let escKey: UInt16 = 53
}
