//
// github.com/screensailor 2022
//

import Lexicon
import SwiftUI

extension CLI {

	enum UI {

		enum Context: Equatable {
			case viewing
			case renaming
			case inheriting
			case synonym
		}

		struct Editor: Equatable {
			var cli: CLI
			var text: AttributedString
			var columns: [Column]
			var properties: Properties
			var isBrowsing: Bool
		}

		struct Browser: Equatable {
			var parent: CLI
			var cli: CLI
			var text: AttributedString
			var columns: [Column]
			var canCommit: Bool
		}
	}

	@LexiconActor func ui(context: UI.Context) -> UI.Editor {
		UI.Editor(
			cli: self,
			text: attributedDescription(),
			columns: uiColumns(context: context, target: UI.Editor.self),
			properties: uiProperties(),
			isBrowsing: context == .inheriting
		)
	}

	@LexiconActor func ui(parent: CLI, canCommit: Bool) -> UI.Browser {
		UI.Browser(
			parent: parent,
			cli: self,
			text: attributedDescription(),
			columns: uiColumns(context: .viewing, target: UI.Browser.self),
			canCommit: canCommit
		)
	}
}

extension CLI.UI {

	struct Column: Identifiable, Equatable {
		var id: Lemma.ID
		var selectedRow: Lemma.ID?
		var sections: [Section]
		var isDisabled: Bool
	}
}

extension CLI.UI.Column {

	struct Section: Identifiable, Equatable {
		var id: Lemma.ID
		var displayID: String
		var type: Lemma?
		var isFirst: Bool
		var rows: [Row]
	}

	struct Row: Identifiable, Equatable {
		var id: Lemma.ID
		var name: Lemma.Name
		var lemma: Lemma
		var isSynonym: Bool
		var isSelected: Bool
		var hasChildren: Bool
		var isIherited: Bool
		var isInheriting: Bool
		var isSearchingProtonym: Bool
		var isEditing: Bool
	}
}

extension CLI.UI {

	struct Properties: Equatable {
		var cli: CLI
		var type: [Lemma]
		var isRoot: Bool?
		var isSynonym: Bool?
		var protonym: Lemma?
	}
}

extension CLI {

	@LexiconActor func attributedDescription() -> AttributedString {

		let font = Font.system(.title)
		var lemma = AttributedString(self.lemma.lineage.reversed().map(\.name).joined(separator: "\u{200B}."))
		lemma.font = font
		lemma.foregroundColor = .textColor

		if input.isEmpty {
			return lemma
		}

		var separator = AttributedString(suggestions.count > 1 ? "\u{200B}?" : suggestions.count == 1 ? "\u{200B}." : "\u{200B}+")
		separator.font = Font.system(.title).monospaced().weight(.medium)
		separator.foregroundColor = .placeholderTextColor

		var input = AttributedString(input)
		input.font = font
		input.foregroundColor = selectedSuggestion?.name == self.input ? .textColor : .systemRed

		guard let selectedSuggestion = self.selectedSuggestion, selectedSuggestion.name != self.input else {
			return lemma + separator + input
		}

		var suggestion = AttributedString(String(selectedSuggestion.name.dropFirst(self.input.count)))
		suggestion.font = font
		suggestion.foregroundColor = .placeholderTextColor

		return lemma + separator + input + suggestion
	}
}

extension CLI {

	@LexiconActor func uiColumns(context: UI.Context, target: Any.Type) -> [UI.Column] {

		let breadcrumbs = breadcrumbs
		let root = breadcrumbs[0]
		let breadcrumbIDs = Set(breadcrumbs.map(\.id))
		let suggestionIDs = input.isEmpty ? nil : Set(suggestions.map(\.id))
		var displayIDByTypeID = [Lemma.ID: String]()

		let rootColumn = UI.Column(
			id: "/",
			sections: [
				UI.Column.Section(
					id: "/section/",
					displayID: "",
					type: nil,
					isFirst: true,
					rows: [
						UI.Column.Row(
							id: root.id,
							name: root.displayName,
							lemma: root,
							isSynonym: root.protonym != nil,
							isSelected: true,
							hasChildren: root.children.isNotEmpty,
							isIherited: false,
							isInheriting: false,
							isSearchingProtonym: false,
							isEditing: context == .renaming && root == self.lemma
						)
					]
				)
			],
			isDisabled: root != self.root
		)

		let columns: [UI.Column] = breadcrumbs.map { lemma in

			var selectedRow: Lemma.ID?

			let sections: [UI.Column.Section] = lemma.childrenGroupedByTypeAndSorted

				.map { (type, children) -> (type: Lemma, children: [Lemma]) in
					guard let suggestionIDs, lemma == breadcrumbs.last else {
						return (type, children)
					}
					return (
						type: type,
						children: children.filter { suggestionIDs.contains($0.id) }
					)
				}

				.filter(\.children.isEmpty.not)
				.enumerated()
				.map { i, group in
					let selectedIndex = group.children.firstIndex { child in
						breadcrumbIDs.contains(child.id)
					}
					let children = group.children.visibleColumnChildren(around: selectedIndex)
					let displayID = displayIDByTypeID[group.type.id] ?? {
						let displayID = group.type.lineage.reversed().map(\.displayName).joined(separator: " ")
						displayIDByTypeID[group.type.id] = displayID
						return displayID
					}()

					return UI.Column.Section(
						id: group.type.id,
						displayID: displayID,
						type: group.type != lemma ? group.type : nil,
						isFirst: i == 0,
						rows: children.map { child in

							let isSelected = breadcrumbIDs.contains(child.id)

							if isSelected {
								selectedRow = child.id
							}

							return UI.Column.Row(
								id: child.id,
								name: child.displayName,
								lemma: child,
								isSynonym: child.protonym != nil,
								isSelected: isSelected,
								hasChildren: child.children.isNotEmpty,
								isIherited: !child.isGraphNode,
								isInheriting: context == .inheriting && child == self.lemma,
								isSearchingProtonym: context == .synonym && child == self.lemma,
								isEditing: context == .renaming && child == self.lemma
							)
						}
					)
				}

			return UI.Column(
				id: lemma.id,
				selectedRow: selectedRow,
				sections: sections,
				isDisabled: lemma.isAncestor(of: self.root)
			)
		}

		return [rootColumn] + columns
	}
}

extension CLI {

	@LexiconActor func uiProperties() -> UI.Properties {
		UI.Properties(
			cli: self,
			type: lemma.ownType.values.map(\.unwrapped).sorted(by: <),
			isRoot: lemma.parent == nil,
			isSynonym: lemma.protonym != nil,
			protonym: lemma.protonym?.unwrapped
		)
	}
}

private enum ColumnWindow {
	static let threshold = 560
	static let leadingCount = 48
	static let trailingCount = 24
	static let selectedRadius = 180
}

private extension Array where Element == Lemma {

	func visibleColumnChildren(around selectedIndex: Int?) -> [Element] {
		guard count > ColumnWindow.threshold else {
			return self
		}
		guard let selectedIndex else {
			return Array(prefix(ColumnWindow.threshold))
		}

		var included = IndexSet(integersIn: 0..<Swift.min(ColumnWindow.leadingCount, count))
		included.insert(integersIn: Swift.max(0, count - ColumnWindow.trailingCount)..<count)
		included.insert(integersIn: Swift.max(0, selectedIndex - ColumnWindow.selectedRadius)..<Swift.min(count, selectedIndex + ColumnWindow.selectedRadius + 1))
		return included.map { self[$0] }
	}
}
