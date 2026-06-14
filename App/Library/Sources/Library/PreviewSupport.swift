//
// github.com/screensailor 2026
//

#if DEBUG
import SwiftUI
import Lexicon

@MainActor struct MindFlarePreviewLoader<Content: View>: View {

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

@MainActor struct MindFlarePreviewFixture {

	let editor: Editor.Object
	let browser: Browser.Object
	let editorUI: CLI.UI.Editor
	let renamingUI: CLI.UI.Editor
	let protonym: Lemma
	let synonym: Lemma

	static func make() async -> Self {
		let document = try! TaskPaper(Self.source).decodeDocument()
		let graph = try! document.graph(root: "app")
		let model = Document(graph: graph)
		let editor = await Editor.Object(id: 9_001, document: model, fileURL: nil)
		let lexicon = try! await Lexicon.from(document, root: "app")
		let lemma = (await lexicon["app.document.editor"])!
		let protonym = (await lexicon["app.document.editor.search"])!
		let synonym = (await lexicon["app.shortcuts.find"])!

		let cli = await CLI(lemma)
		var renaming = cli
		renaming.input = "preview"

		editor.cli = cli
		editor.uiContext = .inheriting
		let browser = await Browser.Object(parent: editor)

		return Self(
			editor: editor,
			browser: browser,
			editorUI: await cli.ui(context: .viewing),
			renamingUI: await renaming.ui(context: .renaming),
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
#endif
