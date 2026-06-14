//
// github.com/screensailor 2022
//

import Lexicon
import Combine
import Foundation
import SwiftUI

@MainActor final class LexiconSearchModel: ObservableObject {

	struct Presentation: Identifiable, Equatable {
		let query: String

		var id: String {
			query
		}
	}

	@Binding var lexicon: Lexicon

	@Published var suggestions: [String] = []
	@Published var results: [Lexicon.Search.Result] = []
	@Published var presentation: Presentation?
	@Published var isSearching = false

	var query: String = "" { didSet { stream.send(query) }}
	var store: [String: [Lexicon.Search.Result]] = [:]

	private var task: Task<Void, Never>?

	private let stream = PassthroughSubject<String, Never>()
	private var bag: Set<AnyCancellable> = []

	init(in lexicon: Binding<Lexicon>) {
		self._lexicon = lexicon
		stream
			.debounce(for: 0.1, scheduler: RunLoop.main)
			.removeDuplicates()
			.sink{ query in self.update(to: query) }
			.store(in: &bag)
	}

	func submit(_ query: String) {
		let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else {
			return
		}
		presentation = Presentation(query: query)
		update(to: query)
	}

	func dismiss() {
		presentation = nil
	}

	private func update(to query: String) {
		task?.cancel()

		let query = query.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !query.isEmpty else {
			store = [:]
			results = []
			suggestions = []
			isSearching = false
			return
		}

		let cacheKey = query.localizedLowercase

		if let stored = store[cacheKey] {
			results = stored
			suggestions = stored.map(\.id)
			isSearching = false
			return
		}

		isSearching = true

		task = Task { [weak self] in

			guard let self else {
				return
			}

			let document = await self.lexicon.document
			let results = await Self.results(for: query, in: document)

			store[cacheKey] = results
			guard !Task.isCancelled else {
				return
			}
			guard query == self.query.trimmingCharacters(in: .whitespacesAndNewlines) || self.presentation?.query == query else {
				return
			}
			self.results = results
			self.suggestions = results.map(\.id)
			self.isSearching = false
		}
	}

	nonisolated static func results(
		for query: String,
		in document: Lexicon.Document,
		limit: Int = 1_000
	) async -> [Lexicon.Search.Result] {
		let options = Lexicon.Search.Options(
			limit: limit,
			mode: .hybrid,
			scope: .full
		)
		let index = Lexicon.Search.Index(document: document, options: options)

		do {
			return try await index.search(query, in: document)
		} catch {
			let fallback = Lexicon.Search.Options(
				limit: limit,
				mode: [.lexical, .token],
				scope: .own
			)
			return document.search(query, options: fallback)
		}
	}
}
