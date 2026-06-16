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

	let ui: CLI.UI.Properties
	let connections: [Document.Snapshot.Connection]

	var body: some View {
		VStack(alignment: .leading, spacing: 1) {

			if let protonym = ui.protonym {
				Synonym(protonym: protonym, synonym: ui.cli.lemma)
			}

			if let defaultValue = ui.defaultValue {
				MetadataCell(
					kind: .defaultValue,
					value: defaultValue.displayValue,
					help: defaultValue.helpValue
				)
			}

			ForEach(Array(ui.documentNotes.enumerated()), id: \.offset) { _, note in
				MetadataCell(kind: .documentNote, value: note)
			}

			ForEach(Array(ui.documentComments.enumerated()), id: \.offset) { _, comment in
				MetadataCell(kind: .documentComment, value: comment)
			}

			ForEach(Array(ui.notes.enumerated()), id: \.offset) { _, note in
				MetadataCell(kind: .note, value: note)
			}

			ForEach(Array(ui.comments.enumerated()), id: \.offset) { _, comment in
				MetadataCell(kind: .comment, value: comment)
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
	}

	struct MetadataCell: View {

		let kind: MetadataKind
		let value: String
		var help: String?

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
			}
			.propertyListRow()
			.foregroundColor(Color(nsColor: .textColor))
			.background(Color(nsColor: .textBackgroundColor))
			.cornerRadius(4)
			.help(help ?? value)
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
