//
// github.com/screensailor 2026
//

import Foundation
import Lexicon

enum MetadataEditTarget: Equatable, Sendable {
	case defaultValue
	case note(index: Int?)
	case comment(index: Int?)
}

extension Editor.Object {

	func saveMetadata(_ target: MetadataEditTarget, value: String) {
		Task { @LexiconActor [weak self, cli] in
			let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
			guard let lemma = applyMetadataEdit(target, value: value, to: cli.lemma) else {
				Task { @MainActor in
					self?.presentMetadataIssue(for: target)
				}
				return
			}
			Task { @MainActor in
				self?.isEditingMetadata = false
				self?.nextLemma = lemma
			}
		}
	}

	@MainActor private func presentMetadataIssue(for target: MetadataEditTarget) {
		presentIssue(
			"Could Not Edit Metadata",
			information: target.failureDescription
		)
	}
}

@LexiconActor
func applyMetadataEdit(
	_ target: MetadataEditTarget,
	value: String,
	to lemma: Lemma
) -> Lemma? {
	switch target {
		case .defaultValue:
			return lemma.settingDefaultValue(value.defaultValue)
		case .note(let index):
			var notes = lemma.node.notes
			notes.updateMetadataValue(at: index, with: value)
			return lemma.settingNotes(notes)
		case .comment(let index):
			var comments = lemma.node.comments
			comments.updateMetadataValue(at: index, with: value)
			return lemma.settingComments(comments)
	}
}

private extension MetadataEditTarget {

	var failureDescription: String {
		switch self {
			case .defaultValue, .note, .comment:
				return "This metadata belongs to an inherited lemma. Open the source Lexicon to edit it."
		}
	}
}

private extension Lemma {

	func settingDefaultValue(_ defaultValue: Lexicon.Graph.Node.DefaultValue?) -> Lemma? {
		updatingGraphNode { node in
			node.defaultValue = defaultValue
		}
	}

	func settingNotes(_ notes: [String]) -> Lemma? {
		updatingGraphNode { node in
			node.notes = notes
		}
	}

	func settingComments(_ comments: [String]) -> Lemma? {
		updatingGraphNode { node in
			node.comments = comments
		}
	}

	func updatingGraphNode(_ update: (inout Lexicon.Graph.Node) -> Void) -> Lemma? {
		guard
			isGraphNode,
			let graphPath
		else {
			return nil
		}
		var graph = lexicon.graph
		graph.date = .init()
		update(&graph[graphPath])
		lexicon.reset(to: graph)
		return lexicon[id] ?? lexicon.root
	}
}

private extension Array where Element == String {

	mutating func updateMetadataValue(at index: Int?, with value: String) {
		guard let index else {
			if !value.isEmpty {
				append(value)
			}
			return
		}
		guard indices.contains(index) else {
			return
		}
		if value.isEmpty {
			remove(at: index)
		} else {
			self[index] = value
		}
	}
}

private extension String {

	var defaultValue: Lexicon.Graph.Node.DefaultValue? {
		guard !isEmpty else {
			return nil
		}
		if hasPrefix("@") {
			let id = dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
			return .reference(id)
		}
		return .literal(.parse(self))
	}
}
