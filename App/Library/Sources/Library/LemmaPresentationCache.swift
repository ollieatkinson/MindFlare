//
// github.com/screensailor 2026
//

import Lexicon

@LexiconActor enum LemmaPresentationCache {

	struct SortedChildren {
		let children: [Lemma]
		private let indexByID: [Lemma.ID: Int]

		init(children: [Lemma]) {
			var childrenByFirstOccurrence = [Lemma]()
			var indexByID = [Lemma.ID: Int]()
			for lemma in children where indexByID[lemma.id] == nil {
				indexByID[lemma.id] = childrenByFirstOccurrence.count
				childrenByFirstOccurrence.append(lemma)
			}
			self.children = childrenByFirstOccurrence
			self.indexByID = indexByID
		}

		func index(of lemma: Lemma) -> Int? {
			indexByID[lemma.id]
		}
	}

	struct GroupedChildren {
		let type: Lemma
		let children: [Lemma]
		private let indexByID: [Lemma.ID: Int]

		init(type: Lemma, children: [Lemma]) {
			self.type = type
			self.children = children
			var indexByID = [Lemma.ID: Int]()
			for (index, lemma) in children.enumerated() where indexByID[lemma.id] == nil {
				indexByID[lemma.id] = index
			}
			self.indexByID = indexByID
		}

		func index(of id: Lemma.ID) -> Int? {
			indexByID[id]
		}
	}

	private static var sortedChildrenByLemmaID: [ObjectIdentifier: SortedChildren] = [:]
	private static var groupedChildrenByLemmaID: [ObjectIdentifier: [GroupedChildren]] = [:]
	private static let maximumCachedLemmas = 1_024

	static func sortedChildren(of lemma: Lemma) -> SortedChildren {
		let id = ObjectIdentifier(lemma)
		if let children = sortedChildrenByLemmaID[id] {
			return children
		}

		let children = SortedChildren(
			children: groupedChildren(of: lemma).flatMap(\.children)
		)
		cache(children, for: id)
		return children
	}

	static func groupedChildren(of lemma: Lemma) -> [GroupedChildren] {
		let id = ObjectIdentifier(lemma)
		if let children = groupedChildrenByLemmaID[id] {
			return children
		}

		let children = lemma.childrenGroupedByTypeAndSorted.map(GroupedChildren.init)
		cache(children, for: id)
		return children
	}

	private static func cache(_ children: SortedChildren, for id: ObjectIdentifier) {
		prepareToCache()
		sortedChildrenByLemmaID[id] = children
	}

	private static func cache(_ children: [GroupedChildren], for id: ObjectIdentifier) {
		prepareToCache()
		groupedChildrenByLemmaID[id] = children
	}

	private static func prepareToCache() {
		guard sortedChildrenByLemmaID.count + groupedChildrenByLemmaID.count > maximumCachedLemmas else {
			return
		}
		sortedChildrenByLemmaID.removeAll(keepingCapacity: true)
		groupedChildrenByLemmaID.removeAll(keepingCapacity: true)
	}
}
