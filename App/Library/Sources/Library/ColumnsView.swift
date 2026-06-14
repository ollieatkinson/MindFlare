//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon
import Combine

struct ColumnsView: View {

	let columns: [CLI.UI.Column]

	var body: some View {

		ScrollViewReader { p in
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(alignment: .top, spacing: 0) {
					ForEach(columns) { column in
						Group {
							ColumnView(ui: column)
								.padding(4)
								.frame(width: 160)
								.id(column.id)

							Divider()
						}
						.opacity(column.isDisabled ? 0.5 : 1)
					}
				}
			}
			.onChange(of: columns.last) { _, column in
				withAnimation {
					p.scrollTo(column?.id)
				}
			}
			.onAppear {
				withAnimation {
					p.scrollTo(columns.last?.id)
				}
			}
		}

		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(NSColor.textBackgroundColor.ui)
		.roundedBorder()
	}
}

struct ColumnView: View {

	let ui: CLI.UI.Column

	var body: some View {
		ScrollViewReader { p in
			ScrollView(showsIndicators: false) {
				VStack(spacing: 0) {
					ForEach(ui.sections) { section in
						ColumnChildGroupView(ui: section)
					}
				}
				.frame(maxWidth: .infinity)

			}
			.onChange(of: ui) { _, ui in
				withAnimation {
					p.scrollTo(ui.selectedRow)
				}
			}
			.onAppear {
				withAnimation {
					p.scrollTo(ui.selectedRow)
				}
			}
		}
	}
}

struct ColumnChildGroupView: View {

	@Environment(\.events) var events
	@Environment(\.documentID) var id

	let ui: CLI.UI.Column.Section

	var body: some View {
		LazyVStack(alignment: .leading, spacing: 0) {

			if let type = ui.type {

				Text(ui.displayID)
					.font(.caption2)
					.foregroundColor(.secondary)
					.padding(.columnSectionHeader(isFirst: ui.isFirst))
					.onTapGesture {
						app.document[id].browser.column.section.heading[type.id].event.tap >> events
					}

				Divider()
			}

			ForEach(ui.rows) { row in
				ColumnCell(ui: row).id(row.id)
			}
		}
		.frame(maxWidth: .infinity)
	}

}

struct ColumnCell: View {

	@EnvironmentObject var my: Editor.Object

	@Environment(\.events) var events
	@Environment(\.documentID) var id

	let ui: CLI.UI.Column.Row

	@State var name: String
	@FocusState var textFieldFocus

	@State var browser: Browser.Object?

	@State var bear: Mind = []

	init(ui: CLI.UI.Column.Row) {
		self.ui = ui
		self._name = .init(initialValue: ui.lemma.name)
	}

	var body: some View {

		HStack(spacing: 2) {

			if ui.isEditing {

				TextField(ui.lemma.name, text: $name)
					.focused($textFieldFocus)
					.onAppear {
						textFieldFocus = true
					}
					.onSubmit {
						my.uiContext = .viewing
						if Lemma.isValid(name: name) {
							my.editor.cli.lemma.rename.to[name] >> events
						}
					}
					.disableAutocorrection(true)
					.textFieldStyle(.squareBorder)
					.foregroundColor(Lemma.isValid(name: name) ? NSColor.textColor.ui : .red)
					.background(NSColor.textBackgroundColor.ui)
					.frame(maxWidth: .infinity)

			} else {
				Text(ui.name)
			}

			Spacer()

			if ui.hasChildren {
				Image(systemName: "chevron.right").controlSize(.mini)
			}
		}
		.padding(.columnCell)
		.foregroundColor(textColor)
		.background(backgroundColor)
		.contentShape(Rectangle())
		.cornerRadius(4)
		.onTapGesture {
			app.document[id].browser.column.cell[ui.lemma.id].event.tap >> events
		}
		.onRightClick{
			app.document[id].browser.column.cell[ui.lemma.id].event.tap >> events
		}
		.contextMenu {
			if my.uiContext == .viewing, !ui.isIherited {
				VStack{
					Button(\.edit.rename, events)
					Button(\.edit.inherit, events)
					Button(\.edit.synonym, events)
					Divider()
					Button(\.edit.cut, events)
					Button(\.edit.copy.lemma, events)
					Button(\.edit.copy.lexicon, events)
					Button(\.edit.paste.default, events)
				}
			}
		}

		.popover(item: $browser) { browser in
			Browser(commitTitle: relationshipBrowserTitle)
				.environmentObject(browser)
				.as(app.document[id].browser.view)
				.onDisappear {
					my.uiContext = .viewing
				}
		}
		.onChange(of: ui.relationshipBrowserMode) { _, mode in
			Task { @MainActor in
				browser = mode == nil ? nil : await Browser.Object(parent: my)
			}
		}
	}

	var relationshipBrowserTitle: String {
		switch ui.relationshipBrowserMode {
			case .synonym:
				"Become synonym of this lemma"
			case .inheritance, nil:
				"Inherit from this lemma"
		}
	}

	var textColor: Color {
		let o: NSColor
		switch (ui.isSelected, ui.isSynonym) {
			case (true, _):   o = ui.isIherited ? .unemphasizedSelectedTextColor : .selectedMenuItemTextColor
			case (false, true):  o = .secondaryLabelColor
			case (false, false): o = .textColor
		}
		return Color(nsColor: o)
	}

	var backgroundColor: Color {
		guard ui.isSelected else {
			return .clear
		}
		return Color(
			nsColor: ui.isIherited ? .unemphasizedSelectedTextBackgroundColor :
					.selectedContentBackgroundColor.withAlphaComponent(ui.isSynonym ? 0.5 : 1)
		)
	}
}

private enum RelationshipBrowserMode: Equatable {
	case inheritance
	case synonym
}

private extension CLI.UI.Column.Row {

	var relationshipBrowserMode: RelationshipBrowserMode? {
		if isInheriting {
			return .inheritance
		}
		if isSearchingProtonym {
			return .synonym
		}
		return nil
	}
}

private extension EdgeInsets {

	static var columnCell: EdgeInsets {
		EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)
	}

	static func columnSectionHeader(isFirst: Bool) -> EdgeInsets {
		EdgeInsets(top: isFirst ? 3 : 12, leading: 5, bottom: 3, trailing: 5)
	}
}

private extension Button where Label == Text {

	init<A: L>(_ event: KeyPath<I_app_menu, A>, _ events: Events) {
		let menuEvent = app.menu[keyPath: event]
		self.init(A.localized) {
			menuEvent >> events
		}
	}
}

#if DEBUG
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
#endif
