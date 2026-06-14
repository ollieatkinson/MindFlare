//
// github.com/screensailor 2026
//

import AppKit
import Darwin
import Foundation
import Lexicon

enum SecurityScopedImportAccess {

	struct Request: Error, LocalizedError, Sendable {
		let fileURL: URL
		let importReference: String
		let underlyingDescription: String

		var id: String {
			"\(fileURL.path)|\(importReference)"
		}

		var fileName: String {
			fileURL.lastPathComponent
		}

		var folderURL: URL {
			fileURL.deletingLastPathComponent()
		}

		var folderPath: String {
			folderURL.path
		}

		var permissionTitle: String {
			"Permission needed for \(fileName)"
		}

		var permissionDetail: String {
			"Choose \(folderPath), or a parent folder that contains all related Lexicon files."
		}

		var permissionHelp: String {
			"Allow MindFlare to read \(fileName) and any related imported Lexicon files."
		}

		var errorDescription: String? {
			"MindFlare needs permission to read imported Lexicon file \"\(fileName)\"."
		}

		var recoverySuggestion: String? {
			"Grant access to \(folderPath), or to a parent folder that contains all related Lexicon files."
		}

		func diagnosticDescription(sourceURL: URL?) -> String {
			let source = sourceURL.map { " for \($0.lastPathComponent)" } ?? ""
			return "Could not compose Lexicon imports\(source): \(errorDescription ?? underlyingDescription) \(recoverySuggestion ?? "")"
		}
	}

	private static let bookmarksKey = "SecurityScopedImportAccess.bookmarks"

	static func requestIfNeeded(
		for error: Error,
		fileURL: URL,
		import: Lexicon.Import
	) -> Request? {
		guard needsUserAccess(error) else {
			return nil
		}
		return Request(
			fileURL: fileURL,
			importReference: `import`.reference,
			underlyingDescription: error.localizedDescription
		)
	}

	static func storedScopeURLs(containing url: URL? = nil) -> [URL] {
		let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
		var urls: [URL] = []

		for bookmark in bookmarks {
			var isStale = false
			guard
				let url = try? URL(
					resolvingBookmarkData: bookmark,
					options: [.withSecurityScope, .withoutUI],
					relativeTo: nil,
					bookmarkDataIsStale: &isStale
				),
				!isStale
			else {
				continue
			}
			urls.append(url)
		}

		let unique = urls.reduce(into: [URL]()) { result, url in
			guard !result.contains(where: { sameFile($0, url) }) else {
				return
			}
			result.append(url)
		}

		guard let url else {
			return unique
		}
		return unique.filter { contains(url, in: $0) }
	}

	static func withAccess<Result>(to urls: [URL], _ body: () throws -> Result) rethrows -> Result {
		let accessed = urls.filter { $0.startAccessingSecurityScopedResource() }
		defer {
			for url in accessed.reversed() {
				url.stopAccessingSecurityScopedResource()
			}
		}
		return try body()
	}

	@MainActor
	static func requestAccess(for request: Request) -> Bool {
		requestFolderAccess(
			defaultingTo: request.folderURL,
			requiredFileURL: request.fileURL,
			message: "MindFlare needs access to an imported Lexicon file.",
			informativeText: request.permissionDetail
		)
	}

	@MainActor
	static func requestFolderAccess(defaultingTo folderURL: URL, requiredFileURL: URL? = nil) -> Bool {
		requestFolderAccess(
			defaultingTo: folderURL,
			requiredFileURL: requiredFileURL,
			message: "Grant access to Lexicon imports.",
			informativeText: "Choose the folder that contains the imported Lexicon files, or a parent folder if imports live in several subfolders."
		)
	}

	@MainActor
	private static func requestFolderAccess(
		defaultingTo folderURL: URL,
		requiredFileURL: URL?,
		message: String,
		informativeText: String
	) -> Bool {
		let panel = NSOpenPanel()
		panel.message = message
		panel.prompt = "Grant Folder Access"
		panel.directoryURL = folderURL
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.allowsMultipleSelection = false
		panel.canCreateDirectories = false
		panel.resolvesAliases = true

		guard panel.runModal() == .OK, let selectedURL = panel.url else {
			return false
		}

		if let requiredFileURL, !contains(requiredFileURL, in: selectedURL) {
			let alert = NSAlert()
			alert.messageText = "That folder does not contain the imported Lexicon file."
			alert.informativeText = informativeText
			alert.alertStyle = .warning
			alert.addButton(withTitle: "OK")
			alert.runModal()
			return false
		}

		return storeBookmark(for: selectedURL)
	}

	@MainActor
	private static func storeBookmark(for folderURL: URL) -> Bool {
		do {
			let folderURL = folderURL.standardizedFileURL.resolvingSymlinksInPath()
			if storedScopeURLs().contains(where: { sameFile($0, folderURL) }) {
				return true
			}

			let bookmark = try folderURL.bookmarkData(
				options: [.withSecurityScope],
				includingResourceValuesForKeys: nil,
				relativeTo: nil
			)
			var bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
			bookmarks.append(bookmark)
			UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
			return true
		} catch {
			NSAlert(error: error).runModal()
			return false
		}
	}

	private static func needsUserAccess(_ error: Error) -> Bool {
		let error = error as NSError
		if error.domain == NSCocoaErrorDomain {
			let code = CocoaError.Code(rawValue: error.code)
			if code == .fileReadNoPermission {
				return true
			}
		}
		if error.domain == NSPOSIXErrorDomain, [Int(EACCES), Int(EPERM)].contains(error.code) {
			return true
		}
		if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
			return needsUserAccess(underlying)
		}
		return false
	}

	private static func contains(_ candidateURL: URL, in folderURL: URL) -> Bool {
		let candidatePath = candidateURL.standardizedFileURL.resolvingSymlinksInPath().path
		let folderPath = folderURL.standardizedFileURL.resolvingSymlinksInPath().path
		return candidatePath == folderPath || candidatePath.hasPrefix(folderPath + "/")
	}

	private static func sameFile(_ lhs: URL, _ rhs: URL) -> Bool {
		lhs.standardizedFileURL.resolvingSymlinksInPath().path ==
		rhs.standardizedFileURL.resolvingSymlinksInPath().path
	}
}
