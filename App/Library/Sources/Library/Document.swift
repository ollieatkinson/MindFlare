//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon
import LexiconGenerators
import Synchronization
import UniformTypeIdentifiers

final class Document: Identifiable, ObservableObject, ReferenceFileDocument, CustomStringConvertible {

	static func == (lhs: Document, rhs: Document) -> Bool {
		lhs === rhs
	}

	private static let pendingGraph = Mutex<Lexicon.Graph?>(nil)

	static func prepareNewDocument(graph: Lexicon.Graph?) {
		pendingGraph.withLock { pendingGraph in
			pendingGraph = graph
		}
	}

	static func newDocument() -> Document {
		Document(graph: pendingGraph.withLock { pendingGraph in
			defer { pendingGraph = nil }
			return pendingGraph
		})
	}

	struct Snapshot: Equatable, Sendable {
		struct Connection: Identifiable, Equatable, Sendable {
			let path: Lemma.ID
			let `import`: Lexicon.Import

			var id: String {
				"\(path)|\(`import`.reference)"
			}

			var lexicon: String {
				switch `import`.location {
					case .local:
						let name = URL(fileURLWithPath: `import`.reference).lastPathComponent
						return name.isEmpty ? `import`.reference : name
					case .remote:
						guard
							let url = URL(string: `import`.reference),
							let name = url.lastPathComponent.unlessEmpty
						else {
							return `import`.reference
						}
						return name
				}
			}
		}

		var old: Lemma.ID?
		var new: Lemma.ID?
		var document: Lexicon.Document
		var composed: Lexicon.Document
		var graph: Lexicon.Graph
		var compositionDiagnostics: [String]
		private let cachedConnections: [Connection]

		init(
			old: Lemma.ID? = nil,
			new: Lemma.ID? = nil,
			document: Lexicon.Document,
			composed: Lexicon.Document,
			graph: Lexicon.Graph,
			compositionDiagnostics: [String] = []
		) {
			self.old = old
			self.new = new
			self.document = document
			self.composed = composed
			self.graph = graph
			self.compositionDiagnostics = compositionDiagnostics
			self.cachedConnections = Self.connections(in: document)
		}

		init(old: Lemma.ID? = nil, new: Lemma.ID? = nil, graph: Lexicon.Graph) {
			let document = Lexicon.Document(graph)
			self.init(
				old: old,
				new: new,
				document: document,
				composed: document,
				graph: graph
			)
		}

		init(document: Lexicon.Document) throws {
			try self.init(document: document, composed: document, graph: document.graph())
		}

		static func == (lhs: Self, rhs: Self) -> Bool {
			lhs.old == rhs.old &&
			lhs.new == rhs.new &&
			lhs.graph == rhs.graph &&
			lhs.compositionDiagnostics == rhs.compositionDiagnostics &&
			documentsEqual(lhs.document, rhs.document) &&
			documentsEqual(lhs.composed, rhs.composed)
		}

		private static func documentsEqual(_ lhs: Lexicon.Document, _ rhs: Lexicon.Document) -> Bool {
			lhs.comments == rhs.comments &&
			lhs.notes == rhs.notes &&
			importReferences(lhs.imports) == importReferences(rhs.imports) &&
			nodesEqual(lhs.roots, rhs.roots)
		}

		private static func nodesEqual(
			_ lhs: Lexicon.Document.Roots,
			_ rhs: Lexicon.Document.Roots
		) -> Bool {
			let lhsKeys = Array(lhs.keys)
			let rhsKeys = Array(rhs.keys)
			guard lhsKeys == rhsKeys else {
				return false
			}
			return zip(lhs.values, rhs.values).allSatisfy(nodesEqual)
		}

		private static func nodesEqual(_ lhs: Lexicon.Graph.Node, _ rhs: Lexicon.Graph.Node) -> Bool {
			lhs.name == rhs.name &&
			lhs.type == rhs.type &&
			lhs.protonym == rhs.protonym &&
			lhs.defaultValue == rhs.defaultValue &&
			lhs.notes == rhs.notes &&
			lhs.comments == rhs.comments &&
			importReferences(lhs.connections) == importReferences(rhs.connections) &&
			nodesEqual(lhs.children, rhs.children)
		}

		private static func importReferences(_ imports: [Lexicon.Import]) -> [String] {
			imports
				.map(\.reference)
				.sorted()
		}

		func composing(relativeTo sourceURL: URL?) throws -> Self {
			guard let sourceURL else {
				return self
			}
			let baseURL = sourceURL.deletingLastPathComponent()
			let storedScopes = SecurityScopedImportAccess.storedScopeURLs(containing: baseURL)
			return try SecurityScopedImportAccess.withAccess(to: [sourceURL, baseURL] + storedScopes) {
				let resolver = SecurityScopedLexiconImportResolver(baseURL: baseURL)
				let plan = try document.composed(resolving: resolver)
				return try Self(
					old: old,
					new: new,
					document: document,
					composed: plan.document,
					graph: plan.document.graph(root: graph.root.name),
					compositionDiagnostics: Self.compositionDiagnostics(for: plan.conflicts, sourceURL: sourceURL)
				)
			}
		}

		static func compositionFailureDescription(_ error: Error, sourceURL: URL?) -> String {
			if let request = error as? SecurityScopedImportAccess.Request {
				return request.diagnosticDescription(sourceURL: sourceURL)
			}
			if let sourceURL {
				return "Could not compose Lexicon imports for \(sourceURL.lastPathComponent): \(error.localizedDescription). Check that imported files are readable and use paths relative to \(sourceURL.deletingLastPathComponent().path)."
			}
			return "Could not compose Lexicon imports: \(error.localizedDescription). Save the document before using relative imports."
		}

		private static func compositionDiagnostics(for conflicts: [Lexicon.MergeConflict], sourceURL: URL) -> [String] {
			let basePath = sourceURL.deletingLastPathComponent().path
			return conflicts.map { conflict in
				switch conflict.kind {
					case .importResolution:
						if conflict.incoming == Lexicon.Import.Location.local.rawValue {
							return "Could not resolve local Lexicon import for \(conflict.path). MindFlare resolves local imports relative to \(basePath). Check that the referenced .lexicon file exists and that macOS granted access to its containing folder."
						}
						return "Could not resolve remote Lexicon import \(conflict.path). Remote imports are disabled for document composition."
					case .defaultValue:
						return "Conflicting default values at \(conflict.path): \(conflict.existing) and \(conflict.incoming). Move the shared value into one imported lexicon or make the local override explicit."
					case .nodeKind:
						return "Conflicting Lexicon node kinds at \(conflict.path): \(conflict.existing) and \(conflict.incoming). Rename one branch or make the shared structure explicit before composing."
					case .protonym:
						return "Conflicting inheritance at \(conflict.path): \(conflict.existing) and \(conflict.incoming). Choose one parent term or split the local vocabulary into a separate branch."
				}
			}
		}

		func sourceDocument(updatingTo composed: Lexicon.Document, graph: Lexicon.Graph) -> Lexicon.Document {
			guard graph != self.graph else {
				return document
			}
			return composed
		}

		func connections(covering id: Lemma.ID) -> [Connection] {
			cachedConnections.filter { connection in
				id == connection.path || id.hasPrefix(connection.path + ".")
			}
		}

		private static func connections(in document: Lexicon.Document) -> [Connection] {
			var connections = [Connection]()

			if let rootName = document.roots.keys.first {
				for `import` in document.imports.sorted(by: { $0.reference < $1.reference }) {
					connections.append(Connection(path: rootName, import: `import`))
				}
			}

			for root in document.roots.values {
				root.traverse { id, _, node in
					for `import` in node.connections.sorted(by: { $0.reference < $1.reference }) {
						connections.append(Connection(path: id, import: `import`))
					}
				}
			}

			return connections.sorted {
				($0.path, $0.import.reference) < ($1.path, $1.import.reference)
			}
		}
	}

	struct Export: Sendable {
		let generator: LexiconSourceGenerator
		let json: Lexicon.Graph.JSON
	}

	private struct Storage: Sendable {
		var snapshot: Snapshot
		var export: Export?
	}

	static let readableContentTypes: [UTType] = [.lexicon, .taskpaper]
	static let writableContentTypes: [UTType] = [.lexicon] + Lexicon.Graph.JSON.generators.values.map { $0.utType }

	private let filename: String?
	private let storage: Mutex<Storage>

	@MainActor var export: Export? {
		get {
			storage.withLock { storage in
				storage.export
			}
		}
		set {
			objectWillChange.send()
			storage.withLock { storage in
				storage.export = newValue
			}
		}
	}

	var isExporting: Bool {
		storage.withLock { storage in
			storage.export != nil
		}
	}

	var snapshot: Snapshot {
		storage.withLock { storage in
			storage.snapshot
		}
	}

	var description: String {
		if let name = filename, !name.isEmpty {
			if name.hasSuffix(".taskpaper") {
				return String(name.dropLast(".taskpaper".count))
			}
			else if name.hasSuffix(".lexicon") {
				return String(name.dropLast(".lexicon".count))
			}
			else {
				return name
			}
		} else {
			return storage.withLock { storage in
				storage.snapshot.graph.root.name
			}
		}
	}

	init(graph: Lexicon.Graph? = nil) {
		let snapshot = Snapshot(graph: graph ?? .init())
		self.filename = nil
		self.storage = Mutex(Storage(snapshot: snapshot, export: nil))
	}

	required init(configuration: ReadConfiguration) throws {

		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}

		let snapshot: Snapshot
		let filename: String?

		switch configuration.contentType {

			case .lexicon, .taskpaper:
				snapshot = try Snapshot(document: TaskPaper(data).decodeDocument())
				filename = configuration.file.filename

			default:
				throw CocoaError(.fileReadUnsupportedScheme)
		}

		self.filename = filename
		self.storage = Mutex(Storage(snapshot: snapshot, export: nil))
	}

	@MainActor
	func update(with new: Snapshot, undo manager: UndoManager?) {

		guard new != snapshot else {
			return
		}

		let old = Snapshot(
			old: new.new,
			new: new.old,
			document: snapshot.document,
			composed: snapshot.composed,
			graph: snapshot.graph,
			compositionDiagnostics: snapshot.compositionDiagnostics
		)
		objectWillChange.send()
		storage.withLock { storage in
			storage.snapshot = new
		}

		manager?.registerUndo(withTarget: self) { [old, manager] my in
			my.update(with: old, undo: manager)
		}
	}

	func snapshot(contentType: UTType) throws -> Snapshot {
		storage.withLock { storage in
			storage.snapshot
		}
	}

	func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper {

		let data: Data

		switch configuration.contentType {

			case .lexicon, .taskpaper:
				data = try TaskPaper.encode(snapshot.document).data(using: .utf8).try()

			default:
				guard
					let export = storage.withLock({ storage in storage.export }),
					export.generator.utType == configuration.contentType
				else {
					throw CocoaError(.fileWriteUnknown)
				}
				data = try export.generator.generate(export.json)
		}

		return FileWrapper(regularFileWithContents: data)
	}
}

extension Document: Equatable {}

private struct SecurityScopedLexiconImportResolver: LexiconImportResolving {

	let baseURL: URL
	let allowRemote = false

	func resolve(_ import: Lexicon.Import) throws -> Lexicon.Document? {
		let url: URL
		switch `import`.location {
			case .local:
				guard let local = localURL(for: `import`.reference) else {
					return nil
				}
				url = local
			case .remote:
				guard
					allowRemote,
					let remote = URL(string: `import`.reference),
					let scheme = remote.scheme?.lowercased(),
					["http", "https"].contains(scheme)
				else {
					return nil
				}
				url = remote
		}

		do {
			return try SecurityScopedImportAccess.withAccess(to: [url] + SecurityScopedImportAccess.storedScopeURLs(containing: url)) {
				try TaskPaper(Data(contentsOf: url)).decodeDocument()
			}
		} catch {
			if let request = SecurityScopedImportAccess.requestIfNeeded(for: error, fileURL: url, import: `import`) {
				throw request
			}
			throw error
		}
	}

	private func localURL(for reference: String) -> URL? {
		guard
			!reference.isEmpty,
			!reference.hasPrefix("/"),
			URLComponents(string: reference)?.scheme == nil
		else {
			return nil
		}

		let base = baseURL.standardizedFileURL.resolvingSymlinksInPath()
		let candidate = URL(fileURLWithPath: reference, relativeTo: base)
			.standardizedFileURL
			.resolvingSymlinksInPath()
		guard candidate.isFileURL else {
			return nil
		}
		return candidate
	}
}
