//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon
import LexiconGenerators

public struct MindFlareApp: App {

	@NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

	@AppStorage("animated") var animated = false
	@AppStorage("launchCount") var launchCount = 0

	@Environment(\.events) var events

	@FocusedValue(\.focusedDocumentID) var focusedDocumentID

	@State var documentCount = 0

	private var bear: Mind = []

	@Bear var mind: Mind {

		events.on { event in
			print("🎙", event)
		}
	}

	public init() {
		launchCount += 1
		bear.in(mind)
		app.did.launch >> events
	}

	public var body: some Scene {

		// WindowGroup {
		//     if documentCount < 1 {
		//         WelcomeView()
		//             .windowEnvironmentValue()
		//     }
		// }

		DocumentGroup(newDocument: Document.newDocument) { file in

			Editor.LoadingView(document: file.document, fileURL: file.fileURL, animated: $animated)

				.environment(\.focusedDocumentID, focusedDocumentID)

				.environment(\.animated, animated)

				.windowEnvironmentValue()

				.onAppear {
					documentCount += 1
				}
				.onDisappear {
					documentCount -= 1
				}
		}

		.commands {

			CommandGroup(after: .newItem) {

				Divider()
					.onAppear {
						if documentCount == 0, launchCount == 1 {
							do {
								let graph = try "Hello.lexicon".file().string().graph()
								Document.prepareNewDocument(graph: graph)
								NSDocumentController.shared.newDocument(nil)
							} catch {
								print("😱", error)
								return
							}
						}
					}

				Menu("New from Example") {

					let examples = [
						"Test",
						"Hello",
						"MindFlare",
						"Alice in Wonderland",
					]

					ForEach(examples, id: \.self) { example in
						Button(example) {
							do {
								Document.prepareNewDocument(graph: try "\(example).lexicon".file().string().graph())
								NSDocumentController.shared.newDocument(nil)
							} catch {
								assertionFailure("\(error)")
								return
							}
						}
					}
				}

				Button("New from Clipboard") {
					do {
						let string = try Self.pasteboardText()
						Self.openNewDocument(graph: try TaskPaper(string).decode())
					} catch {
						Self.showNewDocumentError(error, title: "Could Not Read Clipboard")
					}
				}
				.keyboardShortcut("n", modifiers: [.shift, .command])
				.disabled(!Self.hasPasteboardText)

				Button("New Sentences from Clipboard") {
					Task { @MainActor in
						do {
							let string = try Self.pasteboardText()
							Self.openNewDocument(graph: Lexicon.Graph.from(sentences: string, root: "a"))
						} catch {
							Self.showNewDocumentError(error, title: "Could Not Read Clipboard")
						}
					}
				}
				.keyboardShortcut("n", modifiers: [.shift, .option, .command])
				.disabled(!Self.hasPasteboardText)
			}

			CommandGroup(after: .undoRedo) {
				Divider()
				Button(\.edit.cancel, events).keyboardShortcut(.escape, modifiers: [])
				Divider()
				Button(\.edit.commit, events).keyboardShortcut(.return, modifiers: [])
				Button(\.edit.commit.and.enter, events).keyboardShortcut(.return, modifiers: [.shift])
				Divider()
				Button(\.edit.rename, events).keyboardShortcut("r", modifiers: .command)
				Button(\.edit.inherit, events).keyboardShortcut("i", modifiers: .command)
				Button(\.edit.synonym, events).keyboardShortcut("i", modifiers: [.shift, .command])
			}

			CommandGroup(replacing: .pasteboard) {
				Button(\.edit.cut, events).keyboardShortcut("x", modifiers: .command)
				Button(\.edit.copy.lemma, events).keyboardShortcut("c", modifiers: .command)
				Button(\.edit.copy.lexicon, events).keyboardShortcut("c", modifiers: [.shift, .command])
				Button(\.edit.paste.default, events).keyboardShortcut("v", modifiers: .command)
				Button(\.edit.paste.sentences, events).keyboardShortcut("v", modifiers: [.option, .command])
			}

			CommandGroup(after: .textEditing) {
				Divider()
				Button("Find") {
					guard let focusedDocumentID else {
						return
					}
					app.document[focusedDocumentID].editor.search.did.start >> events
				}
				.keyboardShortcut("f", modifiers: .command)
				.disabled(focusedDocumentID == nil)
			}

			CommandGroup(replacing: .toolbar) {
				Button(\.view.back, events).keyboardShortcut(.leftArrow, modifiers: .option)
				Button(\.view.forward, events).keyboardShortcut(.rightArrow, modifiers: .option)
				Divider()
				Button(\.view.stats, events).keyboardShortcut("l", modifiers: .command)
				Button(\.view.theme.toggle, events).keyboardShortcut("8", modifiers: .command)
				Divider()
			}

			CommandGroup(after: .saveItem) {
				Menu(app.menu.file.export(\.localizedType)) {
					ForEach(Array(Lexicon.Graph.JSON.generators), id: \.key) { (name, generator) in
						Button(name) {
							app.menu.file.export[name] >> events
						}
					}
				}
			}
		}
	}
}

private extension MindFlareApp {

	static var hasPasteboardText: Bool {
		(try? pasteboardText()) != nil
	}

	static func pasteboardText() throws -> String {
		guard
			let string = NSPasteboard.general
				.string(forType: .string)?
				.trimmingCharacters(in: .whitespacesAndNewlines),
			!string.isEmpty
		else {
			throw CocoaError(.fileReadNoSuchFile)
		}
		return string
	}

	static func openNewDocument(graph: Lexicon.Graph) {
		Document.prepareNewDocument(graph: graph)
		NSDocumentController.shared.newDocument(nil)
	}

	static func showNewDocumentError(_ error: Error, title: String) {
		let alert = NSAlert()
		alert.messageText = title
		alert.informativeText = error is CocoaError
			? "The clipboard does not contain readable Lexicon text."
			: error.localizedDescription
		alert.alertStyle = .warning
		alert.runModal()
	}
}

private extension Button where Label == Text {

	init<A: L>(_ event: KeyPath<I_app_menu, A>, _ events: Events) {
		let menuEvent = app.menu[keyPath: event]
		self.init(A.localized) {
			menuEvent >> events
		}
	}
}
