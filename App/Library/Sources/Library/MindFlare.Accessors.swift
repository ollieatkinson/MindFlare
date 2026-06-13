//
// github.com/screensailor 2026
//

import SwiftLexicon

private extension K {

	func appending<B: L>(_ name: String, as type: B.Type = B.self) -> K<B> {
		try! K<B>(bracketed: "\(bracketed).\(name)")
	}
}

extension K where A == L_app_document_browser {
	var cli: K<L_app_document_browser_cli> { appending("cli") }
}

extension K where A == L_app_document_editor {
	var cli: K<L_app_document_browser_cli> { appending("cli") }
}
