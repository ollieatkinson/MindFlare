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
	@Environment(\.isSearching) var isSearching

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
				}

				Spacer()

				Image(systemName: "chevron.right")
					.imageScale(.small)
					.foregroundStyle(.tertiary)
			}

			let evidence = result.searchEvidence
			if evidence.isEmpty {
				Text("Matched by \(result.matchKinds)")
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				VStack(alignment: .leading, spacing: 4) {
					ForEach(evidence) { item in
						HStack(alignment: .firstTextBaseline, spacing: 6) {
							Text(item.label)
								.font(.caption.weight(.semibold))
								.foregroundStyle(.secondary)
								.frame(width: 72, alignment: .leading)
							Text(item.value)
								.font(.caption)
								.foregroundStyle(.primary)
								.lineLimit(2)
						}
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
		let semantic = result.scores.semantic.map { String(format: "semantic %.2f", $0) }
		return ([
			String(format: "relevance %.0f", result.score),
			String(format: "lexical %.0f", result.scores.lexical),
			String(format: "token %.0f", result.scores.token),
			semantic,
		].compactMap { $0 }).joined(separator: " · ")
	}
}

private struct LexiconSearchEvidence: Identifiable {
	let label: String
	let value: String

	var id: String {
		"\(label):\(value)"
	}
}

private extension Lexicon.Search.Result {

	var searchEvidence: [LexiconSearchEvidence] {
		let metadata = matches
			.filter { [.note, .comment].contains($0.field) }
			.map(LexiconSearchEvidence.init(match:))
		let matched = matches
			.filter { ![.note, .comment].contains($0.field) }
			.map(LexiconSearchEvidence.init(match:))
		let context = (notes.prefix(2).map { LexiconSearchEvidence(label: "Note", value: $0) }
			+ comments.prefix(2).map { LexiconSearchEvidence(label: "Comment", value: $0) })
			.filter { item in !metadata.contains(where: { $0.value == item.value }) }

		return Array((metadata + matched + context).prefix(5))
	}

	var matchKinds: String {
		matches.map(\.kind).uniqued().joined(separator: ", ").unlessEmpty ?? "semantic search"
	}
}

private extension LexiconSearchEvidence {

	init(match: Lexicon.Search.Result.Match) {
		self.init(label: match.field.displayName, value: match.displayValue)
	}
}

private extension Lexicon.Search.Result.Match {

	var displayValue: String {
		if kind == "semantic" {
			return "Semantic context matched \"\(term)\"."
		}
		return value
	}
}

private extension Lexicon.Search.Field {

	var displayName: String {
		switch self {
			case .id:
				return "Path"
			case .name:
				return "Name"
			case .type:
				return "Type"
			case .protonym:
				return "Synonym"
			case .defaultReference:
				return "Default"
			case .defaultLiteral:
				return "Value"
			case .note:
				return "Note"
			case .comment:
				return "Comment"
			case .connection:
				return "Connects"
			case .ancestor:
				return "Ancestor"
			case .contextChild:
				return "Context"
		}
	}
}

#if DEBUG
#Preview("Hybrid search results") {
	LexiconSearchResultsView(
		query: "checkout submit",
		results: [
			.init(
				id: "commerce.ui.product.card.buy.enabled",
				name: "enabled",
				score: 1420,
				scores: .init(lexical: 240, token: 180, semantic: 0.94, total: 1420),
				matches: [
					.init(field: .note, term: "checkout", value: "Checkout submit state comes from the storefront API.", kind: "containsPhrase"),
					.init(field: .type, term: "submit", value: "commerce.api.storefront.order.create.can.submit", kind: "token"),
				],
				type: ["commerce.api.storefront.order.create.can.submit"],
				protonym: nil,
				defaultValue: nil,
				notes: ["Checkout submit state comes from the storefront API."],
				comments: ["Product cards surface this as enabled."],
				children: []
			),
			.init(
				id: "commerce.api.storefront.order.create.can.submit",
				name: "submit",
				score: 980,
				scores: .init(lexical: 320, token: 210, semantic: 0.45, total: 980),
				matches: [
					.init(field: .name, term: "submit", value: "submit", kind: "exactPhrase"),
				],
				type: ["commerce.db.type.boolean"],
				protonym: nil,
				defaultValue: nil,
				notes: [],
				comments: ["Order submission capability."],
				children: ["state", "reason"]
			),
		],
		isSearching: false,
		select: { _ in }
	)
}
#endif
