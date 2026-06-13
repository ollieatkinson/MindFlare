//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon

extension Browser {
    
    @MainActor final class Object: EventContext, ObservableObject {
		
		@Published var ui: CLI.UI.Browser
        
		let id: UInt
		let description: String
		let uiContext: CLI.UI.Context
		let parentCLI: CLI
		
        @Environment(\.events) var events
        
        lazy var then = mainContext()
        
        var cli: CLI {
            didSet {
                guard cli != oldValue else { return }
                app.document[id].browser.cli.did.change >> events
            }
        }

        var back: [Lemma.ID] = []
        var forward: [Lemma.ID] = []

        private var bear: Mind = []

        init(parent: Editor.Object) async {
            
			id = parent.id
			description = parent.description
			uiContext = parent.uiContext
            parentCLI = parent.cli
            
            if parent.uiContext == .synonym, let root = parent.cli.lemma.parent {
                cli = await CLI(parent.cli.lemma, root: root)
            } else {
                cli = await CLI(parent.cli.root)
            }

            ui = await cli.ui(
                parent: parent.cli,
                canCommit: cli.lemma != parent.cli.lemma
            )
            
            bear.in(mind)
        }
        
        deinit {
            print("🗑 browser", cli.description, id)
        }
    }
}
