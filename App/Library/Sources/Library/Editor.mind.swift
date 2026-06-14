//
// github.com/screensailor 2022
//

import Algorithms
import SwiftUI
import Lexicon

extension Editor.Object {

	var isViewing: Bool { uiContext == .viewing }
	var isRenaming: Bool { uiContext == .renaming }
	var isBrowsing: Bool { uiContext == .inheriting }

	var isFocused: Bool { focusedDocumentID == id }

	var doc: K<L_app_document> { app.document[id] }
	var browser: K<L_app_document_browser> { doc.browser }
	var editor: K<L_app_document_editor> { doc.editor }

	@Bear var mind: Mind {
		mindCLI
		mindDocumentSearch
		mindFileMenu
		mindEditMenu
		mindViewMenu
	}

	@Bear var mindCLI: Mind {

		browser.column.cell.event.tap >> then { my, event in
			guard
				let id: Lemma.ID = try? event[app.document.browser.column.cell, as: Lemma.ID.self],
				let lemma = await my.cli.lemma.lexicon[id]
			else {
				return
			}
			my.cli = await CLI(lemma)
		}

		browser.column.section.heading.event.tap >> then { my, event in
			guard
				let id: Lemma.ID = try? event[app.document.browser.column.section.heading, as: Lemma.ID.self],
				let lemma = await my.cli.lemma.lexicon[id]
			else {
				return
			}
			my.cli = await CLI(lemma)
		}

		editor.cli.did.change >> then { my, event in
			//...
		}

		browser.cli.append >> then { my, event in
			guard
				let string: String = try? event[type: String.self],
				let c = string.first
			else { return }
			my.cli = await my.cli.appending(c)
		}

		browser.cli.backspace >> then { my, event in
			my.cli = await my.cli.backspaced()
		}

		browser.cli.enter >> then { my, event in
			my.cli = await my.cli.entered()
		}

		browser.cli.reset >> then { my, event in
			my.cli = await my.cli.reseting(to: my.cli.root)
		}

		browser.cli.select.next >> then { my, event in
			if my.cli.input.isEmpty {
				let cli = await my.cli.selectingSibling(offset: 1)
				guard cli.lemma.id != my.cli.lemma.id else {
					return
				}
				my.cli = cli
			} else {
				my.cli.selectNext(cycle: true)
			}
		}

		browser.cli.select.previous >> then { my, event in
			if my.cli.input.isEmpty {
				let cli = await my.cli.selectingSibling(offset: -1)
				guard cli.lemma.id != my.cli.lemma.id else {
					return
				}
				my.cli = cli
			} else {
				my.cli.selectPrevious(cycle: true)
			}
		}

		doc.browser.cli.lemma.add.inheritance >> inFocus { my, event in
			my.uiContext = .viewing
			guard
				let id: Lemma.ID = try? event[type: Lemma.ID.self],
				let type = await my.cli.lemma.lexicon[id],
				let lemma = await my.cli.lemma.add(type: type)
			else {
				return
			}
			my.nextLemma = lemma
		}

		doc.browser.cli.lemma.add.protonym >> inFocus { my, event in
			my.uiContext = .viewing
			guard
				let id: Lemma.ID = try? event[type: Lemma.ID.self],
				let lemma = await my.cli.lemma.lexicon[id]
			else {
				return
			}
			guard let lemma = await my.cli.lemma.set(protonym: lemma) else {
				return
			}
			my.nextLemma = lemma
		}

		editor.cli.lemma.remove.inheritance >> then { my, event in
			guard
				let id: Lemma.ID = try? event[type: Lemma.ID.self],
				let type = await my.cli.lemma.lexicon[id],
				let lemma = await my.cli.lemma.remove(type: type)
			else {
				return
			}
			my.nextLemma = lemma
		}

		editor.cli.lemma.remove.protonym >> then { my, event in
			guard
				let lemma = await my.cli.lemma.removeProtonym()
			else {
				return
			}
			my.nextLemma = lemma
		}

		editor.cli.lemma.rename.to >> inFocus { my, event in
			guard
				let name: Lemma.Name = try? event[type: Lemma.Name.self]
			else {
				my.presentIssue(
					"Could Not Rename Lemma",
					information: "MindFlare did not receive a valid replacement name."
				)
				return
			}
			if let failure = await my.cli.lemma.renameFailureDescription(to: name) {
				my.presentIssue("Could Not Rename Lemma", information: failure)
				return
			}
			guard let lemma = await my.cli.lemma.rename(to: name) else {
				my.presentIssue(
					"Could Not Rename Lemma",
					information: "The Lexicon rejected the rename after validation. Reload the document and try again."
				)
				return
			}
			my.nextLemma = lemma
		}
	}

	@Bear var mindDocumentSearch: Mind {

		editor.search.query.did.submit >> then { my, event in
			guard
				let id: String = try? event[app.document.editor.search.query, as: String.self],
				let lemma = await my.cli.lemma.lexicon[id]
			else {
				return
			}
			my.cli = await CLI(lemma)
		}
	}

	@Bear var mindFileMenu: Mind {

		app.menu.file.export >> then { my, event in
			guard
				let name: String = try? event[type: String.self],
				let generator = Lexicon.Graph.JSON.generators[name]
			else {
				return
			}
			let json = await my.cli.lemma.lexicon.json()
			my.document.export = Document.Export(generator: generator, json: json)
		}
	}

	@Bear var mindEditMenu: Mind {

		let pb = NSPasteboard.general

		app.menu.edit.cancel >> inFocus { my, _ in
			my.uiContext = .viewing
		}

		app.menu.edit.commit >> then { my, _ in
			if my.cli.selectedSuggestion?.name == my.cli.input {
				my.cli = await my.cli.entered()
			} else {
				guard let child = await my.cli.lemma.make(child: my.cli.input) else {
					return
				}
				my.nextLemma = child.parent ?? child
			}
		}

		app.menu.edit.commit.and.enter >> then { my, _ in
			if my.cli.selectedSuggestion?.name == my.cli.input {
				my.cli = await my.cli.entered()
			} else {
				guard let child = await my.cli.lemma.make(child: my.cli.input) else {
					return
				}
				my.nextLemma = child
			}
		}

		app.menu.edit.copy.lemma >> then { my, event in
			pb.clearContents()
			pb.setString(my.cli.description, forType: .string)
		}

		app.menu.edit.copy.lexicon >> then { my, event in
			let string = await TaskPaper.encode(my.cli.lemma.graph)
			pb.clearContents()
			pb.setString(string, forType: .string)
		}

		app.menu.edit.cut >> then { my, event in
			if let failure = await my.cli.lemma.graphEditFailureDescription(action: "cut") {
				my.presentIssue("Could Not Cut Lemma", information: failure)
				return
			}
			let string = await TaskPaper.encode(my.cli.lemma.graph)
			guard let lemma = await my.cli.lemma.lexicon.delete(my.cli.lemma) else {
				my.presentIssue(
					"Could Not Cut Lemma",
					information: "The root lemma cannot be cut. Rename it or move its children instead."
				)
				return
			}
			pb.clearContents()
			pb.setString(string, forType: .string)
			my.nextLemma = lemma
		}

		app.menu.edit.inherit >> then { my, event in
			if let failure = await my.cli.lemma.relationshipEditFailureDescription(action: "inherit from another lemma") {
				my.presentIssue("Could Not Add Inheritance", information: failure)
				return
			}
			my.uiContext = .inheriting
		}

		app.menu.edit.paste.default >> then { my, event in
			guard
				my.cli.lemma.isGraphNode,
				await !my.cli.lemma.hasProtonym,
				let string = pb
					.string(forType: .string)?
					.trimmingCharacters(in: .whitespacesAndNewlines)
			else {
				return
			}
			if let lemma = await my.cli.lemma.lexicon[string] {
				my.cli = await CLI(lemma)
			}
			else if let graph = try? TaskPaper(string).decode() {
				guard let child = await my.cli.lemma.make(child: graph) else {
					return
				}
				my.nextLemma = child
			}
		}

		app.menu.edit.paste.sentences >> then { my, event in
			guard
				my.cli.lemma.isGraphNode,
				await !my.cli.lemma.hasProtonym,
				let string = pb.string(forType: .string)
			else {
				return
			}
			Task { @LexiconActor [cli = my.cli] in
				let graph = Lexicon.Graph.from(sentences: string, root: cli.lemma.lexicon.root.name)
				cli.lemma.lexicon.reset(to: graph)
				let newCLI = CLI.with(lemma: cli.lemma.lexicon.root)
				Task { @MainActor in
					my.cli = newCLI
				}
			}
		}

		app.menu.edit.rename >> then { my, event in
			if let failure = await my.cli.lemma.graphEditFailureDescription(action: "rename") {
				my.presentIssue("Could Not Rename Lemma", information: failure)
				return
			}
			my.uiContext = .renaming
		}

		app.menu.edit.synonym >> then { my, event in
			if let failure = await my.cli.lemma.relationshipEditFailureDescription(action: "become a synonym") {
				my.presentIssue("Could Not Create Synonym", information: failure)
				return
			}
			my.uiContext = .synonym
		}
	}

	@Bear var mindViewMenu: Mind {

		app.menu.view.stats >> then { my, event in
			my.doc.editor.show.stats >> my.events
		}

		app.menu.view.back >> then { my, event in
			let (cli, back, forward) = await Self.backwards(cli: my.cli, back: my.back, forward: my.forward)
			my.back = back
			my.forward = forward
			if let cli = cli {
				my.cli = cli
			}
		}

		app.menu.view.forward >> then { my, event in
			let (cli, back, forward) = await Self.forwards(cli: my.cli, back: my.back, forward: my.forward)
			my.back = back
			my.forward = forward
			if let cli = cli {
				my.cli = cli
			}
		}
	}
}

private extension Lemma {

	func graphEditFailureDescription(action: String) -> String? {
		guard isGraphNode else {
			return "\(displayName) is inherited from another Lexicon. Open the source Lexicon to \(action) it."
		}
		return nil
	}

	func relationshipEditFailureDescription(action: String) async -> String? {
		if let failure = graphEditFailureDescription(action: action) {
			return failure
		}
		guard parent != nil else {
			return "The root lemma cannot \(action). Select one of its child lemmas instead."
		}
		guard !hasProtonym else {
			return "\(displayName) is already a synonym. Remove the synonym relationship before changing inheritance."
		}
		return nil
	}

	func renameFailureDescription(to name: Lemma.Name) async -> String? {
		if let failure = graphEditFailureDescription(action: "rename") {
			return failure
		}
		guard Lemma.isValid(name: name) else {
			return "\"\(name)\" is not a valid Lexicon name. Names must start with a letter and contain only letters, digits, or single underscores."
		}
		guard self.name != name else {
			return "\(displayName) already has that name."
		}
		guard parent?.children[name] == nil else {
			return "A sibling named \(name) already exists under \(parent?.displayName ?? "the parent lemma")."
		}
		return nil
	}
}
