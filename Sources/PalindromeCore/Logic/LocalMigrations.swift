//
//  LocalMigrations.swift
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation

package struct LocalMigrations {
    let directoryUrl: URL
    let fileManager: FileManager
    let expressionSeparator: String = "REVERT:"

    package init(
        at directoryUrl: URL,
        fileManager: FileManager = .default
    ) throws(ValidationError) {
        self.directoryUrl = directoryUrl
        self.fileManager = fileManager
        try self.validate()
    }

    package enum ValidationError: Error {
        case directoryNotFound
    }

    private func validate() throws(ValidationError) {
        if !self.fileManager.directoryExists(at: self.directoryUrl) {
            throw ValidationError.directoryNotFound
        }
    }

    package func listIdentifiers() throws -> [MigrationID] {
        try self.validate()

        return try self.fileManager
            .contentsOfDirectory(
                at: self.directoryUrl,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
            .compactMap { MigrationID(fileName: $0.lastPathComponent) }
            .sorted(by: { $0.index < $1.index })
    }

    func list() async throws -> [Migration] {
        try self.validate()

        let identifiers = try listIdentifiers()
        let expressionSeparator = expressionSeparator

        return try await withThrowingTaskGroup(of: Migration.self) { taskGroup in
            for identifier in identifiers {
                let migrationFileUrl = self.directoryUrl.appending(component: identifier.fileName)
                taskGroup.addTask {
                    try Migration
                        .load(at: migrationFileUrl, expressionSeparator: expressionSeparator)
                }
            }
            var migrations = [Migration]()

            for try await migration in taskGroup {
                migrations.append(migration)
            }

            return migrations.sorted(by: { $0.index < $1.index })
        }
    }

    func get(_ identifier: MigrationID) throws -> Migration {
        try self.validate()
        let migrationFileUrl = self.directoryUrl.appending(component: identifier.fileName)
        return try Migration.load(
            at: migrationFileUrl,
            expressionSeparator: self.expressionSeparator
        )
    }

    package func create(_ name: String) throws -> MigrationID {
        let nextIndex: Int = try nextIndext()
        let cleanName = name.replaceIllegalFileNameCharacters()
        let id = MigrationID(index: nextIndex, name: cleanName)

        let template = """
        -- \(id.index): \(id.name)

        -- REVERT:

        """

        do {
            try template
                .data(using: .utf8)?
                .write(
                    to: self.directoryUrl.appending(component: id.fileName),
                    options: .withoutOverwriting
                )
        } catch {
            print("Failed to create migration file")
            throw error
        }

        return id
    }

    private func nextIndext() throws -> Int {
        try self.listIdentifiers().last.map { $0.index + 1 } ?? 1
    }
}

private extension String {
    func replaceIllegalFileNameCharacters() -> String {
        replacing(/[:\\*?"<>|]/, with: "_")
    }
}

extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(
            atPath: url.path(percentEncoded: false),
            isDirectory: &isDirectory
        ) && isDirectory.boolValue
    }
}
