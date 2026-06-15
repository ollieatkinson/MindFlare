import Lexicon

extension CLI {

	@LexiconActor func selectingSibling(offset: Int) -> CLI {
		guard input.isEmpty else {
			return self
		}
		for lemma in visibleBreadcrumbs.dropFirst().reversed() {
			guard let parent = lemma.parent else {
				continue
			}
			let siblings = LemmaPresentationCache.sortedChildren(of: parent)
			guard siblings.children.count > 1, let index = siblings.index(of: lemma) else {
				continue
			}
			let nextIndex = (index + offset).wrapped(inside: siblings.children.count)
			return reseting(to: siblings.children[nextIndex], root: root)
		}
		return self
	}

	@LexiconActor private var visibleBreadcrumbs: ArraySlice<Lemma> {
		guard let rootIndex = breadcrumbs.firstIndex(of: root) else {
			return breadcrumbs[...]
		}
		return breadcrumbs[rootIndex...]
	}
}

private extension Int {

	func wrapped(inside count: Int) -> Int {
		precondition(count > 0)
		let remainder = self % count
		return remainder >= 0 ? remainder : remainder + count
	}
}
