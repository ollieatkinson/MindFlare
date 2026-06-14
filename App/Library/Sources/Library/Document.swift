//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon
import LexiconGenerators
import UniformTypeIdentifiers

final class Document: Identifiable, Equatable, ObservableObject, ReferenceFileDocument, CustomStringConvertible {
	
	static func == (lhs: Document, rhs: Document) -> Bool {
		lhs === rhs
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
			let resolver = FileLexiconImportResolver(baseURL: sourceURL.deletingLastPathComponent())
			let plan = try document.composed(resolving: resolver)
			return try Self(
				old: old,
				new: new,
				document: document,
				composed: plan.document,
				graph: plan.document.graph(root: graph.root.name),
				compositionDiagnostics: plan.conflicts.map(\.description)
			)
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

	let file: FileWrapper?
	
	@Published private(set) var snapshot: Snapshot
	@Published var isExporting = false
	
	var export: (generator: LexiconSourceGenerator, json: Lexicon.Graph.JSON)? {
		didSet {
			isExporting = export != nil
		}
	}
    
    var description: String {
        if let name = file?.filename, !name.isEmpty {
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
		self.file = nil
		self.snapshot = Snapshot(graph: graph ?? .init())
    }
	
	init(configuration: ReadConfiguration) throws {
        
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        switch configuration.contentType {
                
			case .lexicon, .taskpaper:
				snapshot = try Snapshot(document: TaskPaper(data).decodeDocument())
                file = configuration.file
                
            default:
                throw CocoaError(.fileReadUnsupportedScheme)
        }
    }
	
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
