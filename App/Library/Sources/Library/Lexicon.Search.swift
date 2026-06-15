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
	private var store: [SearchResultCacheKey: [Lexicon.Search.Result]] = [:]
	private var cachedIndex: SearchIndexCache?

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

		isSearching = true

		task = Task { [weak self] in

			guard let self else {
				return
			}

			let document = await self.lexicon.document
			let signature = SearchDocumentSignature(document: document)
			let resultCacheKey = SearchResultCacheKey(
				signature: signature,
				query: cacheKey,
				limit: Self.defaultResultLimit
			)
			let results: [Lexicon.Search.Result]
			if let stored = store[resultCacheKey] {
				results = stored
			} else {
				results = await self.results(
					for: query,
					in: document,
					signature: signature,
					cacheKey: resultCacheKey
				)
			}

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
		limit: Int = defaultResultLimit
	) async -> [Lexicon.Search.Result] {
		do {
			let index = try await materializedIndex(for: document, limit: limit)
			return await search(query, in: index)
		} catch {
			return await fallbackResults(for: query, in: document, limit: limit)
		}
	}

	nonisolated private static let defaultResultLimit = 1_000

	private func results(
		for query: String,
		in document: Lexicon.Document,
		signature: SearchDocumentSignature,
		cacheKey: SearchResultCacheKey
	) async -> [Lexicon.Search.Result] {
		do {
			let cache = try await index(for: document, signature: signature, limit: cacheKey.limit)
			let results = await Self.search(query, in: cache.index)
			store[cacheKey] = results
			return results
		} catch {
			let results = await Self.fallbackResults(for: query, in: document, limit: cacheKey.limit)
			store[cacheKey] = results
			return results
		}
	}

	private func index(
		for document: Lexicon.Document,
		signature: SearchDocumentSignature,
		limit: Int
	) async throws -> SearchIndexCache {
		if let cachedIndex, cachedIndex.signature == signature, cachedIndex.limit == limit {
			return cachedIndex
		}

		let index = try await Self.materializedIndex(for: document, limit: limit)
		let cache = SearchIndexCache(signature: signature, limit: limit, index: index)
		cachedIndex = cache
		store = store.filter { $0.key.signature == signature }
		return cache
	}

	nonisolated private static func materializedIndex(
		for document: Lexicon.Document,
		limit: Int
	) async throws -> Lexicon.Search.Index {
		let options = Lexicon.Search.Options(
			limit: limit,
			mode: .hybrid,
			scope: .full
		)
		return try await Task.detached(priority: .userInitiated) {
			let index = Lexicon.Search.Index(document: document, options: options)
			return try await index.materialized(in: document)
		}.value
	}

	nonisolated private static func search(
		_ query: String,
		in index: Lexicon.Search.Index
	) async -> [Lexicon.Search.Result] {
		await Task.detached(priority: .userInitiated) {
			index.search(query)
		}.value
	}

	nonisolated private static func fallbackResults(
		for query: String,
		in document: Lexicon.Document,
		limit: Int
	) async -> [Lexicon.Search.Result] {
		let fallback = Lexicon.Search.Options(
			limit: limit,
			mode: [.lexical, .token],
			scope: .own
		)
		return await Task.detached(priority: .userInitiated) {
			return document.search(query, options: fallback)
		}.value
	}
}

private struct SearchIndexCache {
	let signature: SearchDocumentSignature
	let limit: Int
	let index: Lexicon.Search.Index
}

private struct SearchResultCacheKey: Hashable {
	let signature: SearchDocumentSignature
	let query: String
	let limit: Int
}

private struct SearchDocumentSignature: Hashable, Sendable {
	let date: Date
	let rootNames: [String]
	let imports: [String]

	init(document: Lexicon.Document) {
		self.date = document.date
		self.rootNames = Array(document.roots.keys)
		self.imports = document.imports.map {
			"\($0.location.rawValue):\($0.reference)"
		}
	}
}
