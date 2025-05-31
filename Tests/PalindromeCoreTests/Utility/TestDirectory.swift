//
//  TestDirectory.swift
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation
@testable import PalindromeCore

struct TemporaryDirectory: Sendable {
    let url: URL
    var path: String { self.url.path(percentEncoded: false) }

    fileprivate init(url: URL) {
        self.url = url
    }

    static func create(fileManager: FileManager = .default) throws -> TemporaryDirectory {
        let directory = fileManager
            .temporaryDirectory
            .appending(component: "test-\(UUID().uuidString)", directoryHint: .isDirectory)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: false)

        return TemporaryDirectory(url: directory)
    }

    func delete(fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: self.url.path(percentEncoded: false)) {
            try fileManager.removeItem(at: self.url)
        }
    }

    func write(_ migrations: [Migration]) throws {
        for migration in migrations {
            try migration.save(
                to: self.url.appending(component: migration.id.fileName),
                expressionSeparator: "REVERT:"
            )
            print(self.url.appending(component: migration.id.fileName))
        }
    }
}
