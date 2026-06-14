//
// github.com/screensailor 2022
//

import SwiftUI
import Lexicon

extension Browser.Object {

	var doc: K<L_app_document> { app.document[id] }

	@Bear var mind: Mind {
		mindBrowser
		mindCLI
		mindEditMenu
		mindViewMenu
	}

	@Bear var mindBrowser: Mind {

		doc.browser.cli.commit >> then { my, event in
			switch my.uiContext {

					case .inheriting:
						my.doc.browser.cli.lemma.add.inheritance[my.cli.lemma.id] >> my.events

					case .synonym:
					my.doc.browser.cli.lemma.add.protonym[my.cli.lemma.id] >> my.events

				default:
					break
			}
		}

		doc.browser.column.cell.event.tap >> then { my, event in
			guard
				let id: Lemma.ID = try? event[app.document.browser.column.cell, as: Lemma.ID.self],
				let lemma = await my.cli.lemma.lexicon[id]
			else {
				return
			}
			if my.uiContext == .synonym {
				guard await lemma.isDescendant(of: my.cli.root) else {
					return
				}
			}
			my.cli = await my.cli.reseting(to: lemma)
		}
	}

	@Bear var mindCLI: Mind {

		doc.browser.cli.did.change >> then { my, event in

			my.ui = await my.cli.ui(
				parent: my.parentCLI,
				canCommit: my.uiContext == .synonym
				? my.parentCLI.lemma.isValid(protonym: my.cli.lemma)
				: my.parentCLI.lemma.isValid(newType: my.cli.lemma)
			)

			guard my.cli.lemma.id != my.back.last else {
				return
			}

			my.back.append(my.cli.lemma.id)
			my.forward.removeAll()
		}

		doc.browser.cli.append >> then { my, event in
			guard
				let string: String = try? event[type: String.self],
				let c = string.first
			else { return }
			my.cli = await my.cli.appending(c)
		}

		doc.browser.cli.backspace >> then { my, event in
			let cli = await my.cli.backspaced()
			if my.uiContext == .synonym {
				guard await my.cli.root.isAncestor(of: cli.lemma) else {
					return
				}
			}
			my.cli = cli
		}

		doc.browser.cli.enter >> then { my, event in
			my.cli = await my.cli.entered()
		}

		doc.browser.cli.reset >> then { my, event in
			my.cli = await my.cli.reseting()
		}

		doc.browser.cli.select.next >> then { my, event in
			if my.cli.input.isEmpty {
				let cli = await my.cli.selectingSibling(offset: 1)
				guard cli.lemma.id != my.cli.lemma.id else {
					return
				}
				my.cli = cli
			} else {
				my.cli.selectNext(cycle: true)
			}
		}

		doc.browser.cli.select.previous >> then { my, event in
			if my.cli.input.isEmpty {
				let cli = await my.cli.selectingSibling(offset: -1)
				guard cli.lemma.id != my.cli.lemma.id else {
					return
				}
				my.cli = cli
			} else {
				my.cli.selectPrevious(cycle: true)
			}
		}
	}

	@Bear var mindEditMenu: Mind {

		let pb = NSPasteboard.general

		app.menu.edit.copy.lemma >> then { my, event in
			pb.clearContents()
			pb.setString(my.cli.description, forType: .string)
		}

		app.menu.edit.copy.lexicon >> then { my, event in
			let string = await TaskPaper.encode(my.cli.lemma.graph)
			pb.clearContents()
			pb.setString(string, forType: .string)
		}

		app.menu.edit.paste.default >> then { my, event in
			guard
				let string = pb
					.string(forType: .string)?
					.trimmingCharacters(in: .whitespacesAndNewlines),
				let lemma = await my.cli.lemma.lexicon[string]
			else {
				return
			}
			my.cli = await my.cli.reseting(to: lemma)
		}
	}

	@Bear var mindViewMenu: Mind {

		app.menu.view.back >> then { my, event in
			let (cli, back, forward) = await Editor.Object.backwards(cli: my.cli, back: my.back, forward: my.forward)
			my.back = back
			my.forward = forward
			if let cli {
				my.cli = cli
			}
		}

		app.menu.view.forward >> then { my, event in
			let (cli, back, forward) = await Editor.Object.forwards(cli: my.cli, back: my.back, forward: my.forward)
			my.back = back
			my.forward = forward
			if let cli {
				my.cli = cli
			}
		}
	}
}
