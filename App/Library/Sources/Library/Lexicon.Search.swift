//
// github.com/screensailor 2022
//

import Lexicon
import Combine
import Foundation
import SwiftUI

@MainActor final class LexiconSearchModel: ObservableObject {
	@Binding var lexicon: Lexicon

	@Published var suggestions: [String] = []

	var query: String = "" { didSet { stream.send(query) }}
	var store: [String: [String]] = [:]

	private var task: Task<(), Error>?

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

	private func update(to query: String) {
		task?.cancel()

		let query = query.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !query.isEmpty else {
			store = [:]
			suggestions = []
			return
		}

		let cacheKey = query.localizedLowercase

		if let stored = store[cacheKey] {
			suggestions = stored
			return
		}

		task = Task.detached { @Sendable [weak self] in

			guard let self = self else { return }

			try Task.checkCancellation()

			let document = await self.lexicon.document
			let suggestions = await Self.suggestions(for: query, in: document)

			Task { @MainActor [weak self] in
				guard let self = self else { return }
				self.store[cacheKey] = suggestions
				guard !Task.isCancelled else { return }
				guard query == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
				self.suggestions = suggestions
			}
		}
	}

	private static func suggestions(for query: String, in document: Lexicon.Document) async -> [String] {
		let options = Lexicon.Search.Options(
			limit: 1000,
			mode: .hybrid,
			scope: .live,
			bounds: .init(depth: 4, candidates: 200, budget: 10_000)
		)
		let index = Lexicon.Search.Index(document: document, options: options)

		do {
			return try await index.search(query, in: document).map(\.id)
		} catch {
			let fallback = Lexicon.Search.Options(
				limit: 1000,
				mode: [.lexical, .token],
				scope: .own
			)
			return document.search(query, options: fallback).map(\.id)
		}
	}
}
