//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon

struct Editor: View {
	
	@EnvironmentObject var my: Object

	@Environment(\.events) var events
    @Environment(\.animated) var animated
	@Environment(\.undoManager) var undoManager
	
	@Environment(\.focusedDocumentID) var focusedDocumentID
	@Environment(\.documentID) var documentID
	
	let document: Document
	
	@Binding var isExporting: Bool

    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
			CompositionDiagnosticsView(diagnostics: my.snapshot.compositionDiagnostics)
            CLIView(text: my.ui.text)
            ColumnsView(columns: my.ui.columns)
            PropertiesView(ui: my.ui.properties)
        }
		.cliEvents(for: my.doc.browser.cli)
		.searchable(my.doc.editor.search, in: Binding(get: { my.cli.lemma.lexicon }, set: { _ in }))
		
        .animation(animated ? .default : nil, value: my.cli)
		.padding(.horizontal)
        .padding(.bottom)
        
        .fileExporter(
			isPresented: $isExporting,
            document: document,
			contentType: document.export?.generator.utType ?? .data,
            defaultFilename: document.description
        ) { _ in }
		
		.onChange(of: document) { _, document in
			my.document = document
		}
		
		.onChange(of: document.snapshot) { _, snapshot in
			my.revert(to: snapshot)
		}
		
		.onChange(of: my.snapshot) { _, snapshot in
			document.update(with: snapshot, undo: undoManager)
		}

		.onChange(of: focusedDocumentID) { _, focusedDocumentID in
			my.focusedDocumentID = focusedDocumentID
		}

        .onAppear {
            my.focusedDocumentID = focusedDocumentID
        }
    }
}

struct CompositionDiagnosticsView: View {

	let diagnostics: [String]

	var body: some View {
		if !diagnostics.isEmpty {
			HStack(spacing: 6) {
				Image(systemName: "exclamationmark.triangle.fill")
				Text("\(diagnostics.count) Lexicon composition issue\(diagnostics.count == 1 ? "" : "s")")
			}
			.font(.caption)
			.foregroundColor(.orange)
			.help(diagnostics.joined(separator: "\n"))
		}
	}
}

#if DEBUG
#Preview("Composition diagnostics") {
	CompositionDiagnosticsView(diagnostics: [
		"importResolution conflict at ./shared.lexicon: unresolved <> local",
		"defaultValue conflict at app.document.editor: true <> false",
	])
	.padding()
	.frame(width: 420, alignment: .leading)
}
#endif
