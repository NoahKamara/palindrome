//
//  RemoteMigrations.swift
//
//  Copyright © 2024 Noah Kamara.
//

import PostgresNIO

package final class RemoteMigrations: Sendable {
    let config: PostgresClient.Configuration
    let client: PostgresClient
    let task: Task<Void, Never>
    let logger: Logger

    init(config: PostgresClient.Configuration) async throws {
        self.config = config
        let client = PostgresClient(
            configuration: config,
            backgroundLogger: .init(label: "PostgresNIO")
        )
        self.logger = .init(label: "RemoteMigrations")
        self.client = client
        self.task = Task {
            print("Starting database connection...")
            await client.run()
            print("Database connection closed")
        }

        // Give the connection time to establish
        try await Task.sleep(for: .milliseconds(500))
        try await self.initialize()
    }

    func initialize() async throws {
        print("Initialize")
        try await self.client.query(
            """
            CREATE TABLE IF NOT EXISTS palindrome_migrations (
                "index" integer NOT NULL PRIMARY KEY,
                "name" text NOT NULL,
                "apply" text NOT NULL,
                "revert" text
            )  
            """,
            logger: self.logger
        )
    }

    func list() async throws -> [Migration] {
        do {
            let stream = try await client
                .query(
                    "SELECT \"index\", name, apply, revert FROM palindrome_migrations ORDER BY \"index\"",
                    logger: self.logger
                )
                .decode((Int, String, String, String?).self, context: .default)

            var migrations: [Migration] = []
            for try await (index, name, apply, revert) in stream {
                let migration = Migration(index: index, name: name, apply: apply, revert: revert)
                migrations.append(migration)
            }
            return migrations
        } catch {
            print("Failed to fetch migrations: \(String(reflecting: error))")
            throw error
        }
    }

    func apply(_ migration: Migration) async throws {
        let logger = Logger(label: "[\(migration)]")

        print("Applying migration - index: \(migration.index), name: '\(migration.name)'")

        do {
            try await self.client.withTransaction(logger: logger) { connection in
                // Split the migration SQL into individual statements
                let statements = migration.apply
                    .split(separator: ";")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                // Execute each statement separately
                for statement in statements {
                    try await connection.query(PostgresQuery(stringLiteral: statement), logger: logger)
                }

                // Record the migration
                let query: PostgresQuery = """
                INSERT INTO palindrome_migrations (index, name, apply, revert)
                VALUES (\(Int(migration.index)), \(migration.name), \(migration.apply), \(migration
                    .revert
                ))
                """
                try await connection.query(query, logger: logger)
            }
        } catch {
            print(String(reflecting: error))
            throw error
        }
    }

    func revert() async throws -> MigrationID? {
        let migrations = try await list()
        guard let latestMigration = migrations.last else {
            print("No migrations to revert")
            return nil
        }

        guard let revert = latestMigration.revert else {
            fatalError(
                "No revert function for migration: \(latestMigration.index) - \(latestMigration.name)"
            )
        }

        try await self.client.withTransaction(logger: self.logger) { connection in
            // Split the revert SQL into individual statements
            let statements = revert
                .split(separator: ";")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // Execute each statement separately
            for statement in statements {
                try await connection.query(
                    PostgresQuery(stringLiteral: statement),
                    logger: self.logger
                )
            }

            // Delete migration record
            try await connection.query(
                "DELETE FROM palindrome_migrations WHERE \"index\" = \(Int(latestMigration.index))",
                logger: self.logger
            )
        }

        return migrations.dropLast().last?.id
    }

    /// Reverts migrations down to and including the target migration
    func revert(count: Int = 1) async throws -> MigrationID? {
        let migrations = try await list().reversed()

        var head = migrations.last?.id

        for migration in migrations.suffix(count) {
            print("Reverting migration - index: \(migration.index), name: '\(migration.name)'")
            head = try await self.revert()
        }
        return head
    }

    
    /// Reverts migrations down to and including the target migration
    func revert(to identifier: MigrationID) async throws {
        let migrations = try await list().reversed()

        guard let index = migrations.lastIndex(where: { $0.id == identifier }) else {
            fatalError("Not found \(identifier)")
        }

        var head = migrations.last?.id

        for migration in migrations.suffix(from: index).reversed() {
            if head != migration.id {
                fatalError("Inconsistent migration state - expected \(head), got \(migration.id)")
            }
            print("Reverting migration - index: \(migration.index), name: '\(migration.name)'")
            head = try await self.revert()
        }
    }

    deinit {
        print("Cleaning up database connection...")
        task.cancel()
    }
}

extension Migration {}
