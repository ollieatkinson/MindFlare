//
// github.com/screensailor 2022
//

import Lexicon
import Combine
import SwiftUI

extension View {

	func searchable<A: L & I_app_ui_search>(_ search: K<A>, in lexicon: Binding<Lexicon>) -> some View {
		modifier(Searchable(search, in: lexicon))
	}
}

struct Searchable<A: L & I_app_ui_search>: ViewModifier {

	@Environment(\.events) var events
	@Environment(\.windowNumber) var windowNumber

	@State var query = ""
	@State var submitted = ""

	@FocusState private var isSearchFocused: Bool

	let search: K<A>

	@StateObject var my: LexiconSearchModel

	func body(content: Content) -> some View {
		content
			.searchable(text: $query, prompt: Text(app.ui.search.prompt(\.localizedType))) {
				ForEach(my.suggestions, id: \.self) { id in
					Text(id.replacingOccurrences(of: ".", with: " "))
						.preferredColorScheme(.dark)
						.lineLimit(1)
						.truncationMode(.head)
						.searchCompletion(id)
				}
			}
			.searchFocused($isSearchFocused)
			.sheet(item: $my.presentation) { presentation in
				LexiconSearchResultsView(
					query: presentation.query,
					results: my.results,
					isSearching: my.isSearching
				) { result in
					submitted = result.id
					query = ""
					my.dismiss()
					search.query[result.id].did.submit >> events
				}
			}
			.onChange(of: query) { _, query in
				guard query != submitted else {
					return
				}
				my.query = query
				search.query[query].did.change >> events
			}
			.onSubmit(of: .search) {
				let submittedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !submittedQuery.isEmpty else {
					return
				}
				submitted = submittedQuery
				my.submit(submittedQuery)
			}
			.on(search.did.start) { _ in
				isSearchFocused = true
			}
			.onReceive(NSWindow.keyDown) { event in
				guard
					isSearchFocused,
					event.windowNumber == windowNumber,
					event.keyCode == .escKey
				else {
					return
				}
				isSearchFocused = false
				event.window?.makeFirstResponder(nil)
			}
			.modifier(Child(search: search))
	}

	init(_ search: K<A>, in lexicon: Binding<Lexicon>) {
		self.search = search
		self._my = .init(wrappedValue: LexiconSearchModel(in: lexicon))
	}

	struct Child: ViewModifier {

		@Environment(\.events) var events
		@Environment(\.isSearching) var isSearching

		let search: K<A>

		func body(content: Content) -> some View {
			content.onChange(of: isSearching) { _, isSearching in
				if isSearching {
					search.did.start >> events
				} else {
					search.did.end >> events
				}
			}
		}
	}
}

private extension UInt16 {
	static let escKey: UInt16 = 53
}

struct LexiconSearchResultsView: View {

	let query: String
	let results: [Lexicon.Search.Result]
	let isSearching: Bool
	let select: (Lexicon.Search.Result) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			header

			if isSearching && results.isEmpty {
				ProgressView()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else if results.isEmpty {
				ContentUnavailableView(
					"No Matches",
					systemImage: "magnifyingglass",
					description: Text("Full hybrid search found no Lexicon matches for \"\(query)\".")
				)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 8) {
						ForEach(results, id: \.id) { result in
							Button {
								select(result)
							} label: {
								LexiconSearchResultRow(result: result)
							}
							.buttonStyle(.plain)
						}
					}
					.padding(.vertical, 2)
				}
			}
		}
		.padding(16)
		.frame(minWidth: 720, idealWidth: 820, minHeight: 460, idealHeight: 560)
	}

	private var header: some View {
		HStack(alignment: .firstTextBaseline) {
			VStack(alignment: .leading, spacing: 3) {
				Text("Search")
					.font(.title2.weight(.semibold))
				Text(query)
					.font(.callout)
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
			}

			Spacer()

			Label("\(results.count)", systemImage: "text.magnifyingglass")
				.labelStyle(.titleAndIcon)
				.foregroundStyle(.secondary)
				.help("Results are ranked by Lexicon full hybrid relevance")
		}
	}
}

private struct LexiconSearchResultRow: View {

	let result: Lexicon.Search.Result

	var body: some View {
		let summary = result.searchSummary

		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .firstTextBaseline, spacing: 8) {
				Image(systemName: "magnifyingglass.circle")
					.foregroundStyle(.secondary)
				VStack(alignment: .leading, spacing: 2) {
					Text(result.id)
						.font(.headline)
						.lineLimit(1)
						.truncationMode(.middle)
					Text(scoreSummary)
						.font(.caption)
						.foregroundStyle(.secondary)
						.help(scoreDetails)
				}

				Spacer()

				Image(systemName: "chevron.right")
					.imageScale(.small)
					.foregroundStyle(.tertiary)
			}

			if !summary.facets.isEmpty {
				HStack(spacing: 5) {
					ForEach(Array(summary.facets.prefix(6))) { facet in
						Text(facet.label)
							.font(.caption2.weight(.semibold))
							.foregroundStyle(.secondary)
							.padding(.horizontal, 6)
							.padding(.vertical, 2)
							.background(Color(nsColor: .separatorColor).opacity(0.28))
							.clipShape(Capsule())
					}
					if summary.facets.count > 6 {
						Text("+\(summary.facets.count - 6)")
							.font(.caption2.weight(.semibold))
							.foregroundStyle(.tertiary)
					}
				}
			}

			if !summary.evidence.isEmpty {
				VStack(alignment: .leading, spacing: 4) {
					ForEach(summary.evidence) { item in
						SearchEvidenceLine(item: item)
					}
				}
			}
		}
		.padding(10)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(6)
		.overlay(
			RoundedRectangle(cornerRadius: 6)
				.stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
		)
	}

	private var scoreSummary: String {
		"Hybrid score \(Int(result.score.rounded()))"
	}

	private var scoreDetails: String {
		let semantic = result.scores.semantic.map { String(format: "semantic %.2f", $0) }
		return ([
			String(format: "lexical %.0f", result.scores.lexical),
			String(format: "token %.0f", result.scores.token),
			semantic,
		].compactMap { $0 }).joined(separator: " · ")
	}
}

private struct SearchEvidenceLine: View {

	let item: LexiconSearchEvidence

	var body: some View {
		HStack(alignment: .top, spacing: 8) {
			Image(systemName: item.symbol)
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)
				.frame(width: 14, alignment: .center)

			VStack(alignment: .leading, spacing: 1) {
				Text(item.value)
					.font(.caption.weight(.medium))
					.foregroundStyle(.primary)
					.lineLimit(2)
				Text(item.label)
					.font(.caption2.weight(.semibold))
					.foregroundStyle(.secondary)
			}
		}
	}
}

private struct LexiconSearchSummary {
	let facets: [LexiconSearchFacet]
	let evidence: [LexiconSearchEvidence]
}

private struct LexiconSearchFacet: Identifiable {
	let label: String

	var id: String {
		label
	}
}

private struct LexiconSearchEvidence: Identifiable {
	let label: String
	let value: String
	let symbol: String

	var id: String {
		"\(label):\(value)"
	}
}

private extension Lexicon.Search.Result {

	var searchSummary: LexiconSearchSummary {
		.init(
			facets: searchFacets,
			evidence: searchEvidence
		)
	}

	private var searchFacets: [LexiconSearchFacet] {
		var facets: [String] = []

		func add(_ label: String, when condition: Bool) {
			guard condition, !facets.contains(label) else {
				return
			}
			facets.append(label)
		}

		add("Path", when: matches.contains { $0.field == .id })
		add("Name", when: matches.contains { $0.field == .name })
		add("Inheritance", when: matches.contains { [.type, .protonym].contains($0.field) })
		add("Default", when: matches.contains { [.defaultReference, .defaultLiteral].contains($0.field) })
		add("Notes", when: matches.contains { $0.field == .note })
		add("Comments", when: matches.contains { $0.field == .comment })
		add("Connections", when: matches.contains { $0.field == .connection })
		add("Lineage", when: matches.contains { $0.field == .ancestor })
		add("Descendants", when: matches.contains { $0.field == .contextChild })
		add("Semantic", when: matches.contains { $0.kind == "semantic" })

		return facets.map(LexiconSearchFacet.init(label:))
	}

	private var searchEvidence: [LexiconSearchEvidence] {
		var evidence: [LexiconSearchEvidence] = []
		let semanticMatched = matches.contains { $0.kind == "semantic" }

		func add(_ label: String, symbol: String, values: [String], limit: Int = 3) {
			let values = Array(values
				.map { $0.cleanedSearchEvidenceValue }
				.filter(\.isNotEmpty)
				.uniqued()
				.prefix(limit))
			guard values.isNotEmpty else {
				return
			}
			evidence.append(.init(label: label, value: values.joined(separator: ", "), symbol: symbol))
		}

		add("Matched note", symbol: "note.text", values: matchedValues(in: [.note]) + (semanticMatched ? notes : []), limit: 2)
		add("Matched comment", symbol: "text.bubble", values: matchedValues(in: [.comment]) + (semanticMatched ? comments : []), limit: 2)
		add("Inherits from", symbol: "arrow.triangle.branch", values: matchedValues(in: [.type, .protonym]).filter { $0 != id })
		add("Default value", symbol: "equal.circle", values: matchedValues(in: [.defaultReference, .defaultLiteral]))
		add("Connected to", symbol: "link", values: matchedValues(in: [.connection]))
		add("Related child", symbol: "point.3.connected.trianglepath.dotted", values: matchedValues(in: [.contextChild]), limit: 2)
		add("Closest lineage", symbol: "point.topleft.down.curvedto.point.bottomright.up", values: lineageEvidence, limit: 1)

		if evidence.isEmpty, matches.contains(where: { $0.kind == "semantic" }) {
			evidence.append(.init(label: "Semantic match", value: "Related wording appears in this lemma's context.", symbol: "sparkle.magnifyingglass"))
		}

		return Array(evidence.prefix(4))
	}

	private func matchedValues(in fields: Set<Lexicon.Search.Field>) -> [String] {
		matches
			.filter { fields.contains($0.field) }
			.map(\.value)
	}

	private var lineageEvidence: [String] {
		let ancestors = matchedValues(in: [.ancestor])
			.filter { id.hasPrefix($0 + ".") }
			.sorted { $0.count > $1.count }
		guard let closest = ancestors.first else {
			return []
		}
		return [closest]
	}
}

private extension String {

	var cleanedSearchEvidenceValue: String {
		var words: [String] = []
		for word in split(separator: " ").map(String.init) {
			if words.last != word {
				words.append(word)
			}
		}

		let collapsed = words.joined(separator: " ")
		let parts = collapsed.split(separator: " ").map(String.init)
		if
			parts.count == 2,
			let path = parts.first,
			let name = parts.last,
			path.contains("."),
			path.split(separator: ".").last.map(String.init) == name
		{
			return path
		}
		return collapsed
	}
}

#if DEBUG
#Preview("Hybrid search results") {
	LexiconSearchResultsView(
		query: "store",
		results: [
			.init(
				id: "commerce.api.storefront",
				name: "storefront",
				score: 3127,
				scores: .init(lexical: 2252, token: 544, semantic: 0.33, total: 3127),
				matches: [
					.init(field: .id, term: "store", value: "commerce.api.storefront", kind: "containsPhrase"),
					.init(field: .name, term: "store", value: "storefront", kind: "prefixToken"),
					.init(field: .name, term: "store", value: "storefront", kind: "ngram"),
					.init(field: .type, term: "store", value: "commerce.api.storefront", kind: "token"),
					.init(field: .contextChild, term: "store", value: "commerce.api.storefront.order order", kind: "token"),
				],
				type: ["commerce.api.storefront"],
				protonym: nil,
				defaultValue: nil,
				notes: ["Storefront API terms describe customer-facing commerce flows."],
				comments: ["Orders and products inherit the storefront vocabulary."],
				children: ["order", "products"]
			),
			.init(
				id: "commerce.session.state.stored",
				name: "stored",
				score: 2901,
				scores: .init(lexical: 2125, token: 544, semantic: 0.23, total: 2901),
				matches: [
					.init(field: .id, term: "store", value: "commerce.session.state.stored", kind: "containsPhrase"),
					.init(field: .name, term: "store", value: "stored", kind: "prefixToken"),
					.init(field: .name, term: "store", value: "stored", kind: "ngram"),
					.init(field: .type, term: "store", value: "commerce.session.state.stored", kind: "token"),
					.init(field: .contextChild, term: "store", value: "commerce.session.state.stored.value value", kind: "token"),
				],
				type: ["commerce.session.state.stored"],
				protonym: nil,
				defaultValue: nil,
				notes: [],
				comments: ["Persisted session state used by recovery flows."],
				children: ["value"]
			),
			.init(
				id: "commerce.api.storefront.products.product.is",
				name: "is",
				score: 2247,
				scores: .init(lexical: 1538, token: 408, semantic: 0.30, total: 2247),
				matches: [
					.init(field: .id, term: "store", value: "commerce.api.storefront.products.product.is", kind: "containsPhrase"),
					.init(field: .ancestor, term: "store", value: "commerce.api.storefront", kind: "containsPhrase"),
					.init(field: .ancestor, term: "store", value: "commerce.api.storefront.products", kind: "containsPhrase"),
					.init(field: .ancestor, term: "store", value: "commerce.api.storefront.products.product", kind: "containsPhrase"),
					.init(field: .type, term: "store", value: "commerce.api.storefront.products.product.is", kind: "token"),
				],
				type: ["commerce.api.storefront.products.product.is"],
				protonym: nil,
				defaultValue: nil,
				notes: [],
				comments: [],
				children: []
			),
		],
		isSearching: false,
		select: { _ in }
	)
}
#endif
