//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon

struct CLIView: View {

	let text: AttributedString

	var body: some View {
		Text(text)
			.padding(.bottom, 8)
			.padding(.horizontal, 8)
			.animation(.none, value: text)
	}
}

#if DEBUG
#Preview("CLI breadcrumb") {
	MindFlarePreviewLoader { fixture in
		CLIView(text: fixture.editorUI.text)
			.padding()
			.frame(width: 420, alignment: .leading)
	}
}
#endif
