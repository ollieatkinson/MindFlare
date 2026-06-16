//
// github.com/screensailor 2022
//

import Foundation
import SwiftUI
import Lexicon

struct PropertiesView: View {

	@Environment(\.events) var events

	@EnvironmentObject var my: Editor.Object

	let ui: CLI.UI.Properties

	@State var shouldBeSynonym: Bool?
	@State var shouldShowStats = false

	var body: some View {
		GroupBox {
			RelationshipList(
				ui: ui,
				connections: my.snapshot.connections(covering: ui.cli.lemma.id)
			)
		}
	}
}

struct Synonym: View {

	@Environment(\.events) var events
	@Environment(\.documentID) var id

	let protonym: Lemma
	let synonym: Lemma

	@State var isHoveringOverRemoveButton = false
	@State var isHoveringOverProtonym = false

	var body: some View {
		HStack {

			Text(protonym.description)

			Spacer()

			if synonym.isGraphNode {

				Button {
					app.document[id].editor.cli.lemma.remove.protonym >> events
				} label: {
					Image(systemName: "xmark")
						.foregroundColor(isHoveringOverProtonym ? NSColor.selectedMenuItemTextColor.ui : .clear)
				}
				.buttonStyle(.plain)
				.onHover {
					isHoveringOverRemoveButton = $0
				}
			}
		}
		.propertyListRow()
		.frame(maxWidth: .infinity, alignment: .leading)
		.foregroundColor(foreground.ui)
		.background(background.ui)
		.cornerRadius(4)
		.onHover {
			isHoveringOverProtonym = $0
		}
		.onTapGesture {
			open(protonym)
		}
	}

	private func open(_ lemma: Lemma) {
		app.document[id].browser.column.section.heading[lemma.id].event.tap >> events
	}

	var foreground: NSColor {
		.selectedMenuItemTextColor
	}

	var background: NSColor {
		isHoveringOverRemoveButton ? .red : .selectedContentBackgroundColor
	}
}

struct RelationshipList: View {

	@EnvironmentObject var my: Editor.Object

	let ui: CLI.UI.Properties
	let connections: [Document.Snapshot.Connection]

	@State private var metadataDraft: MetadataEditDraft?

	var body: some View {
		VStack(alignment: .leading, spacing: 1) {

			if let protonym = ui.protonym {
				Synonym(protonym: protonym, synonym: ui.cli.lemma)
			}

			if let defaultValue = ui.defaultValue {
				MetadataCell(
					kind: .defaultValue,
					value: defaultValue.displayValue,
					help: defaultValue.helpValue,
					edit: canEditNodeMetadata ? {
						editMetadata(
							.defaultValue,
							target: .defaultValue,
							initialValue: defaultValue.editValue
						)
					} : nil
				)
			}

			ForEach(Array(ui.documentNotes.enumerated()), id: \.offset) { index, note in
				MetadataCell(
					kind: .documentNote,
					value: note,
					edit: canEditDocumentMetadata ? {
						editMetadata(
							.documentNote,
							target: .documentNote(index: index),
							initialValue: note
						)
					} : nil
				)
			}

			ForEach(Array(ui.documentComments.enumerated()), id: \.offset) { index, comment in
				MetadataCell(
					kind: .documentComment,
					value: comment,
					edit: canEditDocumentMetadata ? {
						editMetadata(
							.documentComment,
							target: .documentComment(index: index),
							initialValue: comment
						)
					} : nil
				)
			}

			ForEach(Array(ui.notes.enumerated()), id: \.offset) { index, note in
				MetadataCell(
					kind: .note,
					value: note,
					edit: canEditNodeMetadata ? {
						editMetadata(
							.note,
							target: .note(index: index),
							initialValue: note
						)
					} : nil
				)
			}

			ForEach(Array(ui.comments.enumerated()), id: \.offset) { index, comment in
				MetadataCell(
					kind: .comment,
					value: comment,
					edit: canEditNodeMetadata ? {
						editMetadata(
							.comment,
							target: .comment(index: index),
							initialValue: comment
						)
					} : nil
				)
			}

			if canAddMetadata {
				MetadataActionsCell(
					canAddDefault: canEditNodeMetadata && ui.defaultValue == nil,
					canAddDocumentMetadata: canEditDocumentMetadata,
					add: editNewMetadata
				)
			}

			ForEach(ui.type, id: \.self) { type in
				InheritanceCell(type: type, lemma: ui.cli.lemma)
			}

			ForEach(connections) { connection in
				ConnectionCell(connection: connection, selectedPath: ui.cli.lemma.id)
			}

			if isEmpty {
				Text("No metadata, inheritance or connections")
					.propertyListRow()
					.foregroundColor(Color(nsColor: .placeholderTextColor))
			}
		}
		.frame(maxWidth: .infinity)
		.popover(item: $metadataDraft) { draft in
			MetadataEditor(
				draft: draft,
				save: { value in
					my.saveMetadata(draft.target, value: value)
					metadataDraft = nil
				},
				cancel: {
					metadataDraft = nil
				}
			)
			.environmentObject(my)
		}
	}

	private var isEmpty: Bool {
		ui.protonym == nil &&
		ui.defaultValue == nil &&
		ui.documentNotes.isEmpty &&
		ui.documentComments.isEmpty &&
		ui.notes.isEmpty &&
		ui.comments.isEmpty &&
		ui.type.isEmpty &&
		connections.isEmpty
	}

	private var canEditNodeMetadata: Bool {
		ui.cli.lemma.isGraphNode
	}

	private var canEditDocumentMetadata: Bool {
		ui.cli.lemma.parent == nil
	}

	private var canAddMetadata: Bool {
		canEditNodeMetadata || canEditDocumentMetadata
	}

	private func editMetadata(
		_ kind: MetadataKind,
		target: MetadataEditTarget,
		initialValue: String
	) {
		metadataDraft = MetadataEditDraft(
			kind: kind,
			target: target,
			initialValue: initialValue,
			isNew: false
		)
	}

	private func editNewMetadata(_ kind: MetadataKind) {
		let target: MetadataEditTarget
		switch kind {
			case .defaultValue:
				target = .defaultValue
			case .documentNote:
				target = .documentNote(index: nil)
			case .documentComment:
				target = .documentComment(index: nil)
			case .note:
				target = .note(index: nil)
			case .comment:
				target = .comment(index: nil)
		}
		metadataDraft = MetadataEditDraft(
			kind: kind,
			target: target,
			initialValue: "",
			isNew: true
		)
	}
}

extension RelationshipList {

	enum MetadataKind {
		case defaultValue
		case documentNote
		case documentComment
		case note
		case comment

		var title: String {
			switch self {
				case .defaultValue:
					return "Default"
				case .documentNote:
					return "Doc Note"
				case .documentComment:
					return "Doc Comment"
				case .note:
					return "Note"
				case .comment:
					return "Comment"
			}
		}

		var editorTitle: String {
			switch self {
				case .defaultValue:
					return "Default Value"
				case .documentNote:
					return "Document Note"
				case .documentComment:
					return "Document Comment"
				case .note:
					return "Note"
				case .comment:
					return "Comment"
			}
		}

		var symbol: String {
			switch self {
				case .defaultValue:
					return "equal.circle"
				case .documentNote:
					return "doc.text"
				case .documentComment:
					return "doc.text.below.ecg"
				case .note:
					return "note.text"
				case .comment:
					return "text.bubble"
			}
		}

		var placeholder: String {
			switch self {
				case .defaultValue:
					return #"true, "label", {"key":"value"}, or @ lexicon.path"#
				case .documentNote:
					return "What is this lexicon useful for?"
				case .documentComment:
					return "What should maintainers know about this file?"
				case .note:
					return "What does this term mean or help with?"
				case .comment:
					return "What implementation or review context belongs here?"
			}
		}

		var guidance: String {
			switch self {
				case .defaultValue:
					return "Defaults give this term a canonical value for tools and generated output. Use JSON for literal values, or @ path to point at another lemma."
				case .documentNote:
					return "Document notes describe what the whole lexicon is useful for. They are searchable and travel with the file."
				case .documentComment:
					return "Document comments are for file-level working context: review notes, implementation detail, or migration reminders."
				case .note:
					return "Notes are for meaning, examples, and why this term exists. They help search explain why a result is relevant."
				case .comment:
					return "Comments are for implementation context, review notes, and temporary thinking that should stay near the term."
			}
		}
	}

	struct MetadataEditDraft: Identifiable {
		let id = UUID()
		let kind: MetadataKind
		let target: MetadataEditTarget
		let initialValue: String
		let isNew: Bool

		var title: String {
			"\(isNew ? "Add" : "Edit") \(kind.editorTitle)"
		}

		var canDelete: Bool {
			!isNew
		}
	}

	struct MetadataCell: View {

		let kind: MetadataKind
		let value: String
		var help: String?
		var edit: (() -> Void)?

		var body: some View {
			HStack(alignment: .firstTextBaseline, spacing: 8) {
				Image(systemName: kind.symbol)
					.foregroundColor(Color(nsColor: .secondaryLabelColor))
					.frame(width: 15, alignment: .center)

				Text(kind.title)
					.font(.caption2.weight(.semibold))
					.foregroundColor(Color(nsColor: .secondaryLabelColor))
					.frame(width: 82, alignment: .leading)

				Text(value)
					.lineLimit(2)
					.truncationMode(.tail)

				Spacer(minLength: 0)

				if let edit {
					Button(action: edit) {
						Image(systemName: "pencil")
							.imageScale(.small)
					}
					.buttonStyle(.plain)
					.foregroundColor(Color(nsColor: .secondaryLabelColor))
					.help("Edit \(kind.editorTitle)")
				}
			}
			.propertyListRow()
			.foregroundColor(Color(nsColor: .textColor))
			.background(Color(nsColor: .textBackgroundColor))
			.cornerRadius(4)
			.help(help ?? value)
		}
	}

	struct MetadataActionsCell: View {

		let canAddDefault: Bool
		let canAddDocumentMetadata: Bool
		let add: (MetadataKind) -> Void

		var body: some View {
			HStack(spacing: 6) {
				if canAddDefault {
					actionButton(.defaultValue)
				}
				actionButton(.note)
				actionButton(.comment)
				if canAddDocumentMetadata {
					Divider()
						.frame(height: 14)
					actionButton(.documentNote)
					actionButton(.documentComment)
				}
				Spacer(minLength: 0)
			}
			.propertyListRow()
		}

		private func actionButton(_ kind: MetadataKind) -> some View {
			Button {
				add(kind)
			} label: {
				Label(kind.title, systemImage: "plus")
			}
			.controlSize(.small)
			.buttonStyle(.borderless)
			.help("Add \(kind.editorTitle)")
		}
	}

	struct MetadataEditor: View {

		@EnvironmentObject var my: Editor.Object
		@FocusState private var isFocused: Bool

		let draft: MetadataEditDraft
		let save: (String) -> Void
		let cancel: () -> Void

		@State private var value: String

		init(
			draft: MetadataEditDraft,
			save: @escaping (String) -> Void,
			cancel: @escaping () -> Void
		) {
			self.draft = draft
			self.save = save
			self.cancel = cancel
			_value = State(initialValue: draft.initialValue)
		}

		var body: some View {
			VStack(alignment: .leading, spacing: 12) {
				Label(draft.title, systemImage: draft.kind.symbol)
					.font(.headline)

				Text(draft.kind.guidance)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				editor

				HStack(spacing: 8) {
					if draft.canDelete {
						Button(role: .destructive) {
							save("")
						} label: {
							Label("Delete", systemImage: "trash")
						}
					}

					Spacer()

					Button("Cancel", action: cancel)

					Button {
						save(value)
					} label: {
						Label("Save", systemImage: "checkmark")
					}
					.keyboardShortcut(.defaultAction)
				}
				.controlSize(.small)
			}
			.padding(14)
			.frame(width: 380)
			.onAppear {
				my.uiContext = .renaming
				isFocused = true
			}
			.onDisappear {
				if my.uiContext == .renaming {
					my.uiContext = .viewing
				}
			}
		}

		@ViewBuilder private var editor: some View {
			if draft.kind == .defaultValue {
				TextField(draft.kind.placeholder, text: $value)
					.textFieldStyle(.roundedBorder)
					.focused($isFocused)
					.font(.body.monospaced())
			} else {
				TextEditor(text: $value)
					.focused($isFocused)
					.font(.body)
					.frame(minHeight: 88)
					.overlay {
						RoundedRectangle(cornerRadius: 5)
							.stroke(Color(nsColor: .separatorColor), lineWidth: 1)
					}
					.accessibilityLabel(draft.kind.placeholder)
			}
		}
	}

	struct InheritanceCell: View {

		@Environment(\.events) var events
		@Environment(\.documentID) var id

		let type: Lemma
		let lemma: Lemma

		@State var isHoveringOverInheritance = false
		@State var isHoveringOverRemoveButton = false

		var body: some View {
			HStack {

				Text(type.id)

				Spacer()

				if lemma.isGraphNode {

					Button {
						app.document[id].editor.cli.lemma.remove.inheritance[type.id] >> events
					} label: {
						Image(systemName: "xmark")
							.foregroundColor(isHoveringOverInheritance ? NSColor.selectedMenuItemTextColor.ui : .clear)
					}
					.buttonStyle(.plain)
					.onHover {
						isHoveringOverRemoveButton = $0
					}
				}
			}
			.propertyListRow()
			.foregroundColor(foreground.ui)
			.background(background.ui)
			.cornerRadius(4)
			.onHover {
				isHoveringOverInheritance = $0
			}
			.onTapGesture {
				open(type)
			}
		}

		private func open(_ lemma: Lemma) {
			app.document[id].browser.column.section.heading[lemma.id].event.tap >> events
		}

		var foreground: NSColor {
			isHoveringOverInheritance ? .selectedMenuItemTextColor : .textColor
		}

		var background: NSColor {
			switch (isHoveringOverInheritance, isHoveringOverRemoveButton) {
				case (_, true): return .red
				case (true, _): return .selectedContentBackgroundColor
				default: return .textBackgroundColor
			}
		}
	}

	struct ConnectionCell: View {

		let connection: Document.Snapshot.Connection
		let selectedPath: Lemma.ID

		var body: some View {
			HStack(spacing: 8) {
				Image(systemName: "point.3.connected.trianglepath.dotted")
					.foregroundColor(Color(nsColor: .secondaryLabelColor))

				Text(inheritanceDescription)
					.lineLimit(1)
					.truncationMode(.middle)

				Spacer()

				HStack(spacing: 4) {
					Image(systemName: connection.import.location.symbol)
						.imageScale(.small)
					Text(connection.import.reference)
						.lineLimit(1)
						.truncationMode(.middle)
				}
				.font(.caption2.weight(.semibold))
				.foregroundColor(Color(nsColor: .secondaryLabelColor))
				.frame(maxWidth: 260, alignment: .trailing)
			}
			.propertyListRow()
			.foregroundColor(Color(nsColor: .textColor))
			.background(Color(nsColor: .textBackgroundColor))
			.cornerRadius(4)
			.help("\(connection.import.reference) at \(connection.path)")
		}

		private var inheritanceDescription: String {
			guard
				selectedPath != connection.path,
				selectedPath.hasPrefix(connection.path + ".")
			else {
				return connection.path
			}
			return "\(connection.path) / \(String(selectedPath.dropFirst(connection.path.count + 1)))"
		}
	}
}

private extension Lexicon.Import.Location {

	var symbol: String {
		switch self {
			case .local:
				return "doc"
			case .remote:
				return "globe"
		}
	}
}

private extension Lexicon.Graph.Node.DefaultValue {

	var displayValue: String {
		switch self {
			case .reference(let id):
				return "@ \(id)"
			case .literal(let value):
				return value.displayValue
		}
	}

	var editValue: String {
		switch self {
			case .reference(let id):
				return "@ \(id)"
			case .literal(let value):
				return value.editValue
		}
	}

	var helpValue: String {
		switch self {
			case .reference(let id):
				return "Default reference: \(id)"
			case .literal(let value):
				return "Default literal: \(value.displayValue)"
		}
	}
}

private extension JSONValue {

	var displayValue: String {
		switch self {
			case .string(let value):
				return value
			case .number(let value):
				return String(describing: value)
			case .bool(let value):
				return value ? "true" : "false"
			case .null:
				return "null"
			case .array, .object:
				return encodedValue
		}
	}

	private var encodedValue: String {
		guard
			let data = try? JSONSerialization.data(
				withJSONObject: jsonObject,
				options: [.fragmentsAllowed, .sortedKeys]
			),
			let string = String(data: data, encoding: .utf8)
		else {
			return String(describing: self)
		}
		return string
	}

	var editValue: String {
		encodedValue
	}
}

extension View {

	func propertyListRow() -> some View {
		modifier(PropertiesView.Row())
	}
}

extension PropertiesView {

	struct Row: ViewModifier {

		func body(content: Content) -> some View {
			content
				.padding(EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5))
		}
	}
}

#if DEBUG
#Preview("Connected nodes") {
	VStack(alignment: .leading, spacing: 1) {
		RelationshipList.ConnectionCell(
			connection: .init(path: "commerce", import: .init("./shared-commerce.lexicon")),
			selectedPath: "commerce.api.storefront.order"
		)
		RelationshipList.ConnectionCell(
			connection: .init(path: "commerce.api.storefront", import: .init("./storefront-api.lexicon")),
			selectedPath: "commerce.api.storefront.order"
		)
		RelationshipList.ConnectionCell(
			connection: .init(path: "commerce.api.storefront.order", import: .init("https://example.com/commerce/order.lexicon")),
			selectedPath: "commerce.api.storefront.order"
		)
	}
	.frame(width: 620)
	.padding()
}

#Preview("Relationships") {
	MindFlarePreviewLoader { fixture in
		RelationshipList(
			ui: fixture.editorUI.properties,
			connections: [
				.init(path: fixture.editorUI.cli.lemma.id, import: .init("./shared/editor.lexicon")),
				.init(path: fixture.editorUI.cli.lemma.id, import: .init("./shared/commands.lexicon")),
			]
		)
			.environment(\.documentID, fixture.editor.id)
			.environmentObject(fixture.editor)
			.frame(width: 360)
			.padding()
	}
}

#Preview("Metadata") {
	MindFlarePreviewLoader { fixture in
		var properties = fixture.editorUI.properties
		properties.defaultValue = .literal(.object([
			"enabled": .bool(true),
			"mode": .string("hybrid"),
		]))
		properties.documentNotes = [
			"This file describes the application vocabulary.",
		]
		properties.documentComments = [
			"Document comments remain visible when the root is selected.",
		]
		properties.notes = [
			"Search metadata is surfaced in the editor so the reason for a match stays visible.",
			"Notes can capture product vocabulary and domain reminders.",
		]
		properties.comments = [
			"Comments are useful for implementation details or review notes.",
		]
		return RelationshipList(
			ui: properties,
			connections: [
				.init(path: properties.cli.lemma.id, import: .init("./shared/metadata.lexicon")),
			]
		)
			.environment(\.documentID, fixture.editor.id)
			.environmentObject(fixture.editor)
			.frame(width: 620)
			.padding()
	}
}

#Preview("Synonym") {
	MindFlarePreviewLoader { fixture in
		Synonym(protonym: fixture.protonym, synonym: fixture.synonym)
			.environment(\.documentID, fixture.editor.id)
			.frame(width: 360)
			.padding()
	}
}
#endif
