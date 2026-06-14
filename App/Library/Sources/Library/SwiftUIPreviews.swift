//
// github.com/screensailor 2026
//

#if DEBUG
import SwiftUI
import Lexicon

@MainActor private struct MindFlarePreviewLoader<Content: View>: View {

	@State private var fixture: MindFlarePreviewFixture?

	let content: (MindFlarePreviewFixture) -> Content

	init(@ViewBuilder content: @escaping (MindFlarePreviewFixture) -> Content) {
		self.content = content
	}

	var body: some View {
		Group {
			if let fixture {
				content(fixture)
			} else {
				ProgressView()
					.frame(width: 320, height: 180)
			}
		}
		.task {
			if fixture == nil {
				fixture = await MindFlarePreviewFixture.make()
			}
		}
	}
}

@MainActor private struct MindFlarePreviewFixture {

	let editor: Editor.Object
	let editorUI: CLI.UI.Editor
	let renamingUI: CLI.UI.Editor
	let browserUI: CLI.UI.Browser
	let protonym: Lemma
	let synonym: Lemma

	static func make() async -> Self {
		let document = try! TaskPaper(Self.source).decodeDocument()
		let graph = try! document.graph(root: "app")
		let model = Document(graph: graph)
		let editor = await Editor.Object(id: 9_001, document: model, fileURL: nil)
		let lexicon = try! await Lexicon.from(document, root: "app")
		let lemma = (await lexicon["app.document.editor"])!
		let browserLemma = (await lexicon["app.document.browser"])!
		let protonym = (await lexicon["app.document.editor.search"])!
		let synonym = (await lexicon["app.shortcuts.find"])!

		let cli = await CLI(lemma)
		var renaming = cli
		renaming.input = "preview"

		let browserCLI = await CLI(browserLemma)

		return Self(
			editor: editor,
			editorUI: await cli.ui(context: .viewing),
			renamingUI: await renaming.ui(context: .renaming),
			browserUI: await browserCLI.ui(parent: cli, canCommit: true),
			protonym: protonym,
			synonym: synonym
		)
	}

	private static let source = """
		app:
			type:
				command:
				view:
				window:
			document:
				browser:
				+ app.type.view
					cli:
					column:
						cell:
						section:
							heading:
				editor:
				+ app.type.view
					search:
					+ app.type.command
					show:
						stats:
					status:
			menu:
				edit:
					commit:
					rename:
					synonym:
				view:
					back:
					forward:
			shortcuts:
				find:
				= app.document.editor.search
		"""
}

#Preview("CLI breadcrumb") {
	MindFlarePreviewLoader { fixture in
		CLIView(text: fixture.editorUI.text)
			.padding()
			.frame(width: 420, alignment: .leading)
	}
}

#Preview("Columns") {
	MindFlarePreviewLoader { fixture in
		ColumnsView(columns: fixture.editorUI.columns)
			.environmentObject(fixture.editor)
			.environment(\.documentID, fixture.editor.id)
			.frame(width: 520, height: 260)
			.padding()
	}
}

#Preview("Renaming row") {
	MindFlarePreviewLoader { fixture in
		ColumnsView(columns: fixture.renamingUI.columns)
			.environmentObject(fixture.editor)
			.environment(\.documentID, fixture.editor.id)
			.frame(width: 360, height: 160)
			.padding()
	}
}

#Preview("Inheritance") {
	MindFlarePreviewLoader { fixture in
		InheritanceList(ui: fixture.editorUI.properties)
			.environment(\.documentID, fixture.editor.id)
			.frame(width: 360)
			.padding()
	}
}

#Preview("Synonym") {
	MindFlarePreviewLoader { fixture in
		Synonym(protonym: fixture.protonym, synonym: fixture.synonym)
			.environment(\.documentID, fixture.editor.id)
			.frame(width: 360)
			.padding()
	}
}

#Preview("Composition diagnostics") {
	CompositionDiagnosticsView(diagnostics: [
		"importResolution conflict at ./shared.lexicon: unresolved <> local",
		"defaultValue conflict at app.document.editor: true <> false",
	])
	.padding()
	.frame(width: 420, alignment: .leading)
}

#Preview("Browser chooser") {
	MindFlarePreviewLoader { fixture in
		VStack(alignment: .leading, spacing: 8) {
			CLIView(text: fixture.browserUI.text)
			ColumnsView(columns: fixture.browserUI.columns)
				.environmentObject(fixture.editor)
				.environment(\.documentID, fixture.editor.id)
			Button("Inherit from this lemma") {}
				.disabled(!fixture.browserUI.canCommit)
				.frame(maxWidth: .infinity, alignment: .trailing)
		}
		.padding()
		.frame(width: 520, height: 300)
	}
}

#Preview("Stats") {
	MindFlarePreviewLoader { fixture in
		StatsView()
			.environmentObject(fixture.editor)
	}
}
#endif
