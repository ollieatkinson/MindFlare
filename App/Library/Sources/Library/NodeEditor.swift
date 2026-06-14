//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon

extension View {
    
    @MainActor
    func nodeEditor(cli: CLI, name: Binding<Lemma.Name>, isPopped: Binding<Bool>, arrowEdge: Edge = .bottom) -> some View {
        modifier(NodeEditor(my: NodeEditor.Object(lemma: cli.lemma), name: name, isPopped: isPopped))
    }
}

extension NodeEditor {
    
    @MainActor final class Object: EventContext, ObservableObject {
        
        @Environment(\.events) var events
        
        var name: String
        let lemma: Lemma
        
        nonisolated var description: String {
            "\(Object.self):\(lemma)"
        }
        
        var bear: Mind = []
        
        @Bear var mind: Mind {
            
            get {}
        }
        
        init(lemma: Lemma) {
            self.lemma = lemma
            self.name = lemma.name
            bear.in(mind)
        }
    }
}

struct NodeEditor: ViewModifier {
    
    @StateObject var my: Object
    
    @Binding var name: Lemma.Name
    @Binding var isPopped: Bool
    
    var arrowEdge: Edge = .bottom
    
    @State var isValidName = true
    
    func body(content: Content) -> some View {
        content.popover(isPresented: $isPopped, arrowEdge: arrowEdge) {
            
            Group {
                
                HStack {
                    
                    Text("Name")
                        .fixedSize()
                    
                    TextField(name, text: $name)
                        .frame(minWidth: 100)
                        .onSubmit { isPopped = false }
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)
                }
                .foregroundColor(isValidName ? Color(nsColor: .textColor) : .red)
            }
            .padding()
            .foregroundColor(nil)
            .background(NSColor.textBackgroundColor.ui.scaleEffect(2))
        }
    }
}
