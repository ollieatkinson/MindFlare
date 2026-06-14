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

	var bear: Mind = [] // TODO: @State and where to +=

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
//						 launchCount = 0 // TODO: remove
					}

				let pb = NSPasteboard.general

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
					guard
						let string = pb
							.string(forType: .string)?
							.trimmingCharacters(in: .whitespacesAndNewlines),
						let graph = try? TaskPaper(string).decode() // TODO: error handling
					else {
						return
					}
					Document.prepareNewDocument(graph: graph)
					NSDocumentController.shared.newDocument(nil)
				}
				.keyboardShortcut("n", modifiers: [.shift, .command])
				// .disabled(pb.string(forType: .string)?.isNotEmpty ?? false) // TODO: !

				Button("New Sentences from Clipboard") {
					Task { @MainActor in
						guard
							let string = pb.string(forType: .string)
						else {
							return
						}
						Document.prepareNewDocument(graph: Lexicon.Graph.from(sentences: string, root: "a"))
						NSDocumentController.shared.newDocument(nil)
					}
				}
				.keyboardShortcut("n", modifiers: [.shift, .option, .command])
				// .disabled(pb.string(forType: .string)?.isNotEmpty ?? false) // TODO: !
			}

			CommandGroup(after: .undoRedo) {
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

			// TODO: ↓
			// CommandGroup(after: .textEditing) {
			//     if my.isRecording {
			//         Button(\.edit.recording.stop, events)
			//     } else if case .some = my.focused {
			//         Button(\.edit.recording.start, events)
			//     }
			// }

			// TODO: ⌘ F for Find

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
					// TODO: ↓
					// if my.hasRecord {
					//     Divider()
					//     Button(\.file.export.recording, events)
					// }
				}
			}
		}
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
