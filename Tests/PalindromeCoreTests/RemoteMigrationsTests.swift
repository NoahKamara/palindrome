//
//  RemoteMigrationsTests.swift
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation
@testable import PalindromeCore
import PostgresNIO
import Testing

@Suite("RemoteMigrations Tests")
struct RemoteMigrationsTests {
    let db = TestDatabase()

    @Test("Should initialize and create migrations table")
    func initialize() async throws {
        try await self.db.withTestDatabase { remote in

            // Verify table exists by trying to list migrations
            let migrations = try await remote.list()
            #expect(migrations.isEmpty)
        }
    }

    @Test
    func apply() async throws {
        try await self.db.withTestDatabase { remote in
            let initialMigrations = try await remote.list()
            #expect(initialMigrations.isEmpty)
            
            // Create test migration
            let fooMigration = Migration(
                index: 1,
                name: "create_users",
                apply: "CREATE TABLE users (id SERIAL PRIMARY KEY);",
                revert: "DROP TABLE users;"
            )

            // Test
            try await remote.apply(fooMigration)
            
            let afterInsertMigrations = try await remote.list()

            // Verify
            try #require(afterInsertMigrations.count == 1)
            #expect(afterInsertMigrations.first?.id == fooMigration.id)
            #expect(afterInsertMigrations.first?.apply == fooMigration.apply)
            #expect(afterInsertMigrations.first?.revert == fooMigration.revert)
            
            // Create test migration
            let barMigration = Migration(
                index: 2,
                name: "alter_users",
                apply: "ALTER TABLE users ADD COLUMN email VARCHAR(255) NOT NULL UNIQUE;",
                revert: "ALTER TABLE users DROP COLUMN email;"
            )
            
            try await remote.apply(barMigration)
            
            let afterSecondInsertMigrations = try await remote.list()

            // Verify
            try #require(afterSecondInsertMigrations.count == 2)
            #expect(afterSecondInsertMigrations.first?.id == fooMigration.id)
            #expect(afterSecondInsertMigrations.last?.id == barMigration.id)
            #expect(afterSecondInsertMigrations.last?.apply == barMigration.apply)
            #expect(afterSecondInsertMigrations.last?.revert == barMigration.revert)
        }
    }

    
    @Test("Should apply and list migrations")
    func applyAndList() async throws {
        try await self.db.withTestDatabase { remote in
            // Create test migration
            let migration = Migration(
                index: 1,
                name: "create_users",
                apply: "CREATE TABLE users (id SERIAL PRIMARY KEY);",
                revert: "DROP TABLE users;"
            )

            // Test
            try await remote.apply(migration)
            let migrations = try await remote.list()

            // Verify
            #expect(migrations.count == 1)
            #expect(migrations[0].index == 1)
            #expect(migrations[0].name == "create_users")
            #expect(migrations[0].apply.contains("CREATE TABLE users"))
            #expect(migrations[0].revert?.contains("DROP TABLE users") == true)
        }
    }

    @Test("Should revert migrations")
    func testRevert() async throws {
        try await self.db.withTestDatabase { remote in
            // Create and apply test migrations
            let migration1 = Migration(
                index: 1,
                name: "create_users",
                apply: "CREATE TABLE users (id SERIAL PRIMARY KEY);",
                revert: "DROP TABLE users;"
            )

            let migration2 = Migration(
                index: 2,
                name: "create_posts",
                apply: "CREATE TABLE posts (id SERIAL PRIMARY KEY, user_id INTEGER REFERENCES users(id));",
                revert: "DROP TABLE posts;"
            )

            try await remote.apply(migration1)
            try await remote.apply(migration2)

            // Test
            let revertedId = try await remote.revert()

            // Verify
            #expect(revertedId?.index == 1)
            #expect(revertedId?.name == "create_users")

            let migrations = try await remote.list()
            #expect(migrations.count == 1)
            #expect(migrations[0].index == 1)
        }
    }

    @Test("Should revert to specific migration")
    func revertTo() async throws {
        try await self.db.withTestDatabase { remote in
            // Create and apply test migrations
            let migration1 = Migration(
                index: 1,
                name: "create_users",
                apply: "CREATE TABLE users (id SERIAL PRIMARY KEY);",
                revert: "DROP TABLE users;"
            )

            let migration2 = Migration(
                index: 2,
                name: "create_posts",
                apply: "CREATE TABLE posts (id SERIAL PRIMARY KEY, user_id INTEGER REFERENCES users(id));",
                revert: "DROP TABLE posts;"
            )

            try await remote.apply(migration1)
            try await remote.apply(migration2)

            // Test
            try await remote.revert(to: migration1.id)

            // Verify
            let migrations = try await remote.list()
            #expect(migrations.count == 1)
            #expect(migrations[0].index == 1)
            #expect(migrations[0].name == "create_users")
        }
    }
}
