//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon
import LexiconGenerators
import Synchronization
import UniformTypeIdentifiers

final class Document: Identifiable, Equatable, ObservableObject, ReferenceFileDocument, CustomStringConvertible, @unchecked Sendable {
	
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
	
	struct Snapshot: Equatable {
		var old: Lemma.ID?
		var new: Lemma.ID?
		var document: Lexicon.Document
		var composed: Lexicon.Document
		var graph: Lexicon.Graph
		var compositionDiagnostics: [String]

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
			TaskPaper.encode(lhs.document) == TaskPaper.encode(rhs.document) &&
			TaskPaper.encode(lhs.composed) == TaskPaper.encode(rhs.composed)
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
	}

	static let readableContentTypes: [UTType] = [.lexicon, .taskpaper]
	static let writableContentTypes: [UTType] = [.lexicon] + Lexicon.Graph.JSON.generators.values.map{ $0.utType }

	private let filename: String?
	
	@Published private(set) var snapshot: Snapshot
	@Published var isExporting = false
	
	var export: (generator: LexiconSourceGenerator, json: Lexicon.Graph.JSON)? {
		didSet {
			isExporting = export != nil
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
			return snapshot.graph.root.name
        }
    }

    init(graph: Lexicon.Graph? = nil) {
		self.filename = nil
		self.snapshot = Snapshot(graph: graph ?? .init())
    }
	
	init(configuration: ReadConfiguration) throws {
        
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        switch configuration.contentType {
                
			case .lexicon, .taskpaper:
				snapshot = try Snapshot(document: TaskPaper(data).decodeDocument())
                filename = configuration.file.filename
                
            default:
                throw CocoaError(.fileReadUnsupportedScheme)
        }
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
		self.snapshot = new
		
		manager?.registerUndo(withTarget: self) { [old, manager] my in
			my.update(with: old, undo: manager)
		}
	}

	func snapshot(contentType: UTType) throws -> Snapshot {
		snapshot
	}
	
	func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        
        let data: Data
        
        switch configuration.contentType {
                
			case .lexicon, .taskpaper:
				data = try TaskPaper.encode(snapshot.document).data(using: .utf8).try()
                
            default:
				guard
					let (generator, json) = export,
					generator.utType == configuration.contentType
				else {
					throw CocoaError(.fileWriteUnknown)
				}
				data = try generator.generate(json)
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
}

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
