//
// github.com/screensailor 2026
//

import SwiftLexicon

struct MainEventContextHandler<Object: AnyObject & Sendable>: Sendable {
	weak var object: Object?
	let events: Events?
	let predicate: @MainActor @Sendable (Object, Event) -> Bool
	let action: @MainActor @Sendable (Object, Event) async -> Void
}

extension EventContext {

	func mainContext(
		_ when: @escaping @MainActor @Sendable (Self, Event) -> Bool
	) -> (@escaping @MainActor @Sendable (Self, Event) async -> Void) -> MainEventContextHandler<Self> {
		{ [weak self] action in
			MainEventContextHandler(
				object: self,
				events: self?.events,
				predicate: when,
				action: action
			)
		}
	}

	func mainContext(
		_ when: @escaping @MainActor @Sendable (Self) -> Bool
	) -> (@escaping @MainActor @Sendable (Self, Event) async -> Void) -> MainEventContextHandler<Self> {
		mainContext { object, _ in when(object) }
	}

	func mainContext() -> (@escaping @MainActor @Sendable (Self, Event) async -> Void) -> MainEventContextHandler<Self> {
		mainContext { _, _ in true }
	}
}

@discardableResult func >> <O, A>(event: A.Type, handler: MainEventContextHandler<O>) -> EventObserver
where O: AnyObject & Sendable {
	handler.observe { value in
		value.is(event)
	}
}

@discardableResult func >> <O, A>(event: A, handler: MainEventContextHandler<O>) -> EventObserver
where A: I, O: AnyObject & Sendable {
	handler.observe { value in
		value.is(event)
	}
}

@discardableResult func >> <O, A>(event: K<A>, handler: MainEventContextHandler<O>) -> EventObserver
where A: L, O: AnyObject & Sendable {
	handler.observe { value in
		value.is(event)
	}
}

private extension MainEventContextHandler {

	func observe(_ matches: @escaping @Sendable (Event) -> Bool) -> EventObserver {
		guard let events else {
			return EventObserver(Task {})
		}
		return events.on(where: matches) { [weak object, predicate, action] event in
			guard let object else {
				return
			}
			guard await MainActor.run(body: { predicate(object, event) }) else {
				return
			}
			await action(object, event)
		}
	}
}
