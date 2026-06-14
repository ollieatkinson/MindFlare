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
			CompositionDiagnosticsView(
				diagnostics: my.snapshot.compositionDiagnostics,
				grantFolderAccess: my.pendingImportAccessRequest == nil && my.fileURL == nil ? nil : {
					my.grantImportFolderAccess()
				}
			)
			CLIView(text: my.ui.text)
			ColumnsView(columns: my.ui.columns)
			PropertiesView(ui: my.ui.properties)
		}
			.cliEvents(for: my.doc.browser.cli, while: { my.uiContext != .renaming })
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
	let grantFolderAccess: (() -> Void)?

	var body: some View {
		if !diagnostics.isEmpty {
			VStack(alignment: .leading, spacing: 3) {
				HStack(spacing: 6) {
					Image(systemName: "exclamationmark.triangle.fill")
					Text("\(diagnostics.count) Lexicon composition issue\(diagnostics.count == 1 ? "" : "s")")
				}
				.foregroundColor(.orange)

				if let diagnostic = diagnostics.first {
					Text(diagnostic)
						.foregroundStyle(.secondary)
						.lineLimit(3)
				}

				if diagnostics.count > 1 {
					Text("\(diagnostics.count - 1) more issue\(diagnostics.count == 2 ? "" : "s")")
						.foregroundStyle(.secondary)
				}

				if let grantFolderAccess {
					Button {
						grantFolderAccess()
					} label: {
						Label("Grant Folder Access", systemImage: "folder.badge.gearshape")
					}
					.buttonStyle(.borderless)
					.help("Allow MindFlare to read imported Lexicon files")
				}
			}
			.font(.caption)
			.frame(maxWidth: .infinity, alignment: .leading)
			.help(diagnostics.joined(separator: "\n"))
		}
	}
}

#if DEBUG
#Preview("Composition diagnostics") {
	CompositionDiagnosticsView(diagnostics: [
		"Could not resolve local Lexicon import for organization.products. MindFlare resolves local imports relative to /Users/example/Vocabulary. Check that the referenced .lexicon file exists and that macOS granted access to its containing folder.",
		"Conflicting default values at app.document.editor: true and false. Move the shared value into one imported lexicon or make the local override explicit.",
	], grantFolderAccess: {})
	.padding()
	.frame(width: 520, alignment: .leading)
}
#endif
