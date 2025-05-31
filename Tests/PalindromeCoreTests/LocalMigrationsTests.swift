//
//  LocalMigrationsTests.swift
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation
import Testing

@testable import PalindromeCore

@Suite("LocalMigrations Tests")
struct LocalMigrationsTests {
    @Test("Should list migrations")
    func testList() async throws {
        // Create test migrations
        let migrations = [
            Migration(
                index: 1,
                name: "create_users",
                apply: "CREATE TABLE users (id SERIAL PRIMARY KEY);",
                revert: "DROP TABLE users;"
            ),
            Migration(
                index: 2,
                name: "create_posts",
                apply:
                "CREATE TABLE posts (id SERIAL PRIMARY KEY, user_id INTEGER REFERENCES users(id));",
                revert: "DROP TABLE posts;"
            ),
        ]

        let tempDir = try TemporaryDirectory.create()
        defer { try? tempDir.delete() }

        try tempDir.write(migrations)

        let local = try LocalMigrations(using: tempDir)
        let listedIdentifiers = try local.listIdentifiers()
        #expect(listedIdentifiers == migrations.map(\.id))

        // Test
        let listedMigrations = try await local.list()
        print(local.directoryUrl)

        // Verify
        #expect(listedMigrations.count == 2)

        for (listed, expected) in zip(listedMigrations, migrations) {
            #expect(listed.index == expected.index)
            #expect(listed.name == expected.name)
            #expect(listed.apply == expected.apply)
            #expect(listed.revert == expected.revert)
        }
    }

    @Test("Should create migration")
    func testCreate() async throws {
        let tempDir = try TemporaryDirectory.create()
        defer { try? tempDir.delete() }

        let local = try LocalMigrations(using: tempDir)

        // Test
        let id = try local.create("create_users")

        // Verify
        #expect(id.index == 1)
        #expect(id.name == "create_users")

        let migration = try local.get(id)
        #expect(migration.index == id.index)
        #expect(migration.name == id.name)

        let migrationFilePath = local.directoryUrl
            .appending(components: id.fileName)
            .path(percentEncoded: false)

        let fileExists = FileManager.default.fileExists(atPath: migrationFilePath)
        #expect(fileExists)

        let secondId = try local.create("create_articles")
        #expect(secondId.index == 2)
        #expect(secondId.name == "create_articles")
    }

    @Test("Should get migration by id")
    func getById() async throws {
        let id = MigrationID(index: 1, name: "create_users")
        let migration = Migration(id: id, apply: "Hello There", revert: "Goodbye there")
        let tempDir = try TemporaryDirectory.create()
        defer { try? tempDir.delete() }

        try tempDir.write([migration])
        let local = try LocalMigrations(using: tempDir)

        let gottenMigration = try local.get(id)
        #expect(gottenMigration.index == migration.index)
        #expect(gottenMigration.name == migration.name)
        #expect(gottenMigration.apply == migration.apply)
        #expect(gottenMigration.revert == migration.revert)
    }
}

extension LocalMigrations {
    init(using directory: TemporaryDirectory) throws {
        try self.init(at: directory.url)
    }
}
