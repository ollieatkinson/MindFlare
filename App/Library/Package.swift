// swift-tools-version: 6.3

import PackageDescription

let package = Package(
	name: "Library",
	platforms: [
		.macOS(.v15),
	],
	products: [
		.library(name: "Library", targets: ["Library"]),
	],
	dependencies: [
		.package(url: "https://github.com/screensailor/Hope", branch: "trunk"),
		.package(
			url: "https://github.com/ollieatkinson/Lexicon.git",
			branch: "trunk",
			traits: [
				.defaults,
				.trait(name: "Editor"),
			]
		),
		.package(url: "https://github.com/apple/swift-collections", from: "1.5.1"),
		.package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
	],
	targets: [
		.target(
			name: "Library",
			dependencies: [
				.product(name: "Lexicon", package: "Lexicon"),
				.product(name: "SwiftLexicon", package: "Lexicon"),
				.product(name: "LexiconGenerators", package: "Lexicon"),
				.product(name: "Algorithms", package: "swift-algorithms"),
				.product(name: "Collections", package: "swift-collections"),
			],
			resources: [
				.copy("Resources")
			]
		),
		.testTarget(
			name: "LibraryTests",
			dependencies: [
				"Hope",
				"Library",
				.product(name: "Lexicon", package: "Lexicon"),
			]
		),
	]
)
