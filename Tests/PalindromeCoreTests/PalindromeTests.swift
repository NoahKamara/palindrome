//
//  PalindromeTests.swift
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation
import Testing

@testable import PalindromeCore

@Suite("Palindrome Tests")
struct PalindromeTests {
    let db = TestDatabase()

    @Test("Should initialize and create migrations table")
    func initialize() async throws {
        try await self.db.withTestDatabase { remote in
            let tempDir = try TemporaryDirectory.create()
            defer { try? tempDir.delete() }

            let palindrome = try await Palindrome(remote: remote, local: .init(using: tempDir))
            _ = try await palindrome.remote.list()
            _ = try await palindrome.local.list()
        }
    }

    //    @Test("Should show correct migration state")
    //    func testState() async throws {
    //        try await db.withTestDatabase { remote in
    //            let tempDir = try TemporaryDirectory.create()
    //            defer { try? tempDir.delete() }
    //
    //            let palindrome = try await Palindrome(config: config, migrationsPath:
    //            tempDir.path)
    //            _ = try await palindrome.remote.list()
    //            _ = try await palindrome.local.list()
    //
    //            // Verify initial state
    //            let state = try await palindrome.state()
    //            #expect(state.migrations.isEmpty)
    //            #expect(!state.hasPending)
    //            #expect(!state.hasConflicts)
    //
    //            // Create and apply a migration
    //            let migration = Migration(
    //                index: 1,
    //                name: "create_users",
    //                apply: "CREATE TABLE users (id SERIAL PRIMARY KEY);",
    //                revert: "DROP TABLE users;"
    //            )
    //            tempDir.write(migration)
    //            let migration = try await palindrome.local.create("create_users")
    //            try await palindrome.apply(migration)
    //
    //            // Verify updated state
    //            let updatedState = try await palindrome.state()
    //            #expect(updatedState.localMigrations.count == 1)
    //            #expect(updatedState.remoteMigrations.count == 1)
    //            #expect(updatedState.conflicts.isEmpty)
    //            #expect(updatedState.localMigrations[0].index == 1)
    //            #expect(updatedState.localMigrations[0].name == "create_users")
    //        }
    //    }

    //    @Test("Should detect migration conflicts")
    //    func testMigrationConflicts() async throws {
    //        try await db.withTestDatabase { remote in
    //            let tempDir = try TemporaryDirectory.create()
    //            defer { try? tempDir.delete() }
    //
    //            let palindrome = try await Palindrome(config: config, migrationsPath:
    //            tempDir.path)
    //
    //            // Create and apply a migration
    //            let migration = try await palindrome.local.create("create_users")
    //            try await palindrome.apply(migration)
    //
    //            // Modify the migration file
    //            let modifiedMigration = Migration(
    //                id: migration.id,
    //                index: migration.index,
    //                name: migration.name,
    //                apply: "CREATE TABLE users (id SERIAL PRIMARY KEY, email TEXT);",
    //                revert: "DROP TABLE users;"
    //            )
    //
    //            // Test
    //            let state = try await palindrome.state()
    //
    //            // Verify
    //            #expect(state.conflicts.count == 1)
    //            #expect(state.conflicts[0].localMigration.index == 1)
    //            #expect(state.conflicts[0].localMigration.name == "create_users")
    //            #expect(state.conflicts[0].remoteMigration.index == 1)
    //            #expect(state.conflicts[0].remoteMigration.name == "create_users")
    //            #expect(state.conflicts[0].localMigration.apply !=
    //            state.conflicts[0].remoteMigration.apply)
    //        }
    //    }
    //
    //    @Test("Should verify migrations")
    //    func testVerify() async throws {
    //        try await TestHelpers.withTestDatabase {
    //            let config = TestHelpers.createTestDatabaseOptions(TestHelpers.testDatabaseName)
    //            let palindrome = try await Palindrome(configuration: config)
    //
    //            // Create and apply a migration
    //            let migration = try await palindrome.create(name: "create_users")
    //            try await palindrome.apply(migration)
    //
    //            // Test
    //            let result = try await palindrome.verify()
    //
    //            // Verify
    //            #expect(result.isValid)
    //            #expect(result.conflicts.isEmpty)
    //        }
    //    }
    //
    //    @Test("Should generate correct migration strategy")
    //    func testGenerateStrategy() async throws {
    //        try await TestHelpers.withTestDatabase {
    //            let config = TestHelpers.createTestDatabaseOptions(TestHelpers.testDatabaseName)
    //            let palindrome = try await Palindrome(configuration: config)
    //
    //            // Create test migrations
    //            let migration1 = try await palindrome.create(name: "create_users")
    //            let migration2 = try await palindrome.create(name: "create_posts")
    //
    //            // Test apply strategy
    //            let applyStrategy = try await palindrome.generateStrategy(to: migration2)
    //            #expect(applyStrategy.migrations.count == 2)
    //            #expect(applyStrategy.migrations[0].index == 1)
    //            #expect(applyStrategy.migrations[1].index == 2)
    //
    //            // Apply migrations
    //            try await palindrome.apply(migration1)
    //            try await palindrome.apply(migration2)
    //
    ////            // Test revert strategy
    ////            let revertStrategy = try await palindrome.generateStrategy(to: migration1)
    ////            #expect(revertStrategy.migrations.count == 1)
    ////            #expect(revertStrategy.migrations[0].index == 2)
    ////        }
    ////    }
}

@Suite("State")
struct PalindromStateTests {
    let db = TestDatabase()

    @Test
    func empty() async throws {
        try await self.db.withTestDatabase { remote in
            let tempDir = try TemporaryDirectory.create()
            defer { try? tempDir.delete() }

            let palindrome = try Palindrome(remote: remote, local: .init(using: tempDir))
            
            // Verify initial state
            let state = try await palindrome.state()
            #expect(state.migrations.isEmpty)
            #expect(!state.hasUnapplied)
            #expect(!state.hasConflicts)
        }
    }

    @Test
    func pending() async throws {
        try await self.db.withTestDatabase { remote in
            let tempDir = try TemporaryDirectory.create()
            defer { try? tempDir.delete() }

            let expectedMigration = Migration(
                index: 1,
                name: "create_users",
                apply: "CREATE TABLE users (id SERIAL PRIMARY KEY);",
                revert: "DROP TABLE users;"
            )

            try tempDir.write([expectedMigration])

            let palindrome = try Palindrome(remote: remote, local: .init(using: tempDir))

            // Verify initial state
            let state = try await palindrome.state()
            #expect(state.hasUnapplied)
            #expect(!state.hasConflicts)
            try #require(state.migrations.count == 1)
            let actualMigration = state.migrations[0]

            #expect(actualMigration.id == expectedMigration.id)
            #expect(actualMigration.status == .unapplied)
        }
    }

    @Test(arguments: [
//        (
//            MigrationState.Status.Change.name,
//            Migration(index: 2, name: "create_users", apply: "", revert: nil)
//        ),
        (
            MigrationState.Status.Change.expression,
            Migration(index: 2, name: "create_articles", apply: "CHANGE", revert: nil)
        ),

    ])
    func conflict(change: MigrationState.Status.Change, localMigration: Migration) async throws {
        try await self.db.withTestDatabase { remote in
            let tempDir = try TemporaryDirectory.create()
            defer { try? tempDir.delete() }

            let appliedMigrations = [
                Migration(
                    index: 1,
                    name: "init",
                    apply: "",
                    revert: nil
                ),
                Migration(
                    index: 2,
                    name: "create_articles",
                    apply: "",
                    revert: nil
                )
            ]

            try tempDir.write([localMigration])

            let palindrome = try Palindrome(remote: remote, local: .init(using: tempDir))
            for migration in appliedMigrations {
                print("apply")
                try await palindrome.remote.apply(migration)
            }

            try await print(palindrome.remote.list())
            // Verify initial state
            let state = try await palindrome.state()
            #expect(!state.hasUnapplied)
            #expect(state.hasConflicts)
            
            try #require(state.migrations.count == 2)
            #expect(state.migrations.map(\.status) == [.applied, .conflict(change)])
            #expect(state.migrations.last?.id == localMigration.id)
        }
    }
}

//// Create and apply a migration
// let migration = Migration(
//    index: 1,
//    name: "create_users",
//    apply: "CREATE TABLE users (id SERIAL PRIMARY KEY);",
//    revert: "DROP TABLE users;"
// )
// try tempDir.write([migration])
//
// let migration = try await palindrome.local.create("create_users")
// try await palindrome.apply(migration)
//
//// Verify updated state
// let updatedState = try await palindrome.state()
// #expect(updatedState.localMigrations.count == 1)
// #expect(updatedState.remoteMigrations.count == 1)
// #expect(updatedState.conflicts.isEmpty)
// #expect(updatedState.localMigrations[0].index == 1)
// #expect(updatedState.localMigrations[0].name == "create_users")
