//
//  Palindrome.swift
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation
import Logging
import PostgresNIO

package final class Palindrome {
    let remote: RemoteMigrations
    package let local: LocalMigrations

    package init(remote: RemoteMigrations, local: LocalMigrations) {
        self.remote = remote
        self.local = local
    }
    
    package convenience init(
        config: PostgresClient.Configuration,
        migrationsPath: String
    ) async throws {
        let remote = try await RemoteMigrations(config: config)
        let local = try LocalMigrations(at: URL(filePath: migrationsPath))
        self.init(remote: remote, local: local)
    }

    private func generateStrategy(to identifier: MigrationID) async throws -> MigrationStrategy {
        let state = try await self.state()
        precondition(!state.hasConflicts)

        // Get all migrations in order
        let allMigrations = try await local.list()
        let remoteMigrations = try await remote.list()

        // Find the target migration
        guard let targetMigration = allMigrations.first(where: { $0.index == identifier.index })
        else {
            throw MigrationError.invalidMigrationFile
        }

        // Find the latest applied migration
        let latestApplied = remoteMigrations.max(by: { $0.index < $1.index })

        // Case 1: Target is unapplied - apply until reaching target
        if latestApplied == nil || targetMigration.index > latestApplied!.index {
            let pendingMigrations = allMigrations
                .filter {
                    $0.index > (latestApplied?.index ?? 0) && $0.index <= targetMigration.index
                }
                .sorted { $0.index < $1.index }

            return MigrationStrategy(applies: pendingMigrations, reverts: [])
        }

        // Case 2: Target is already applied and is latest - do nothing
        if targetMigration.index == latestApplied?.index {
            print(
                "Already applied latest migration: \(targetMigration.index) - \(targetMigration.name)"
            )
            return MigrationStrategy(applies: [], reverts: [])
        }

        // Case 3: Target is already applied but not latest - revert until target
        if targetMigration.index < latestApplied!.index {
            // Get migrations to revert in reverse order
            let migrationsToRevert = remoteMigrations
                .filter { $0.index > targetMigration.index }
                .sorted { $0.index > $1.index }

            return MigrationStrategy(applies: [], reverts: migrationsToRevert)
        }

        return MigrationStrategy(applies: [], reverts: [])
    }

    package func migrate(to identifier: MigrationID) async throws {
        let strategy = try await generateStrategy(to: identifier)

        if strategy.isEmpty {
            return
        }

        // Execute reverts first
        for migration in strategy.reverts {
            try await self.remote.revert(to: migration.id)
        }

        // Then execute applies
        for migration in strategy.applies {
            try await self.remote.apply(migration)
        }
    }

    package func state(status: MigrationStatus? = nil) async throws -> MigrationState {
        let remoteMigrations = try await remote.list()
        let localMigrations = try await local.list()

        // Create a dictionary of migrations for quick lookup
        let localDict = Dictionary(uniqueKeysWithValues: localMigrations.map { ($0.index, $0) })
        let remoteDict = Dictionary(uniqueKeysWithValues: remoteMigrations.map { ($0.index, $0) })

        let allMigrations = Set(remoteDict.keys).union(localMigrations.map(\.index))
        
        let migrations = allMigrations
            .sorted()
            .map { index in
                let local = localDict[index]
                let remote = remoteDict[index]
                
                return if let local, let remote {
                    if remote.apply != local.apply {
                        MigrationState.Migration(
                            id: .init(index: local.index, name: local.name),
                            status: .conflict(.expression)
                        )
                    } else if local.name != remote.name {
                        MigrationState.Migration(
                            id: .init(index: local.index, name: local.name),
                            status: .conflict(.name)
                        )
                    } else {
                        MigrationState.Migration(
                            id: .init(index: local.index, name: local.name),
                            status: .applied
                        )
                    }
                } else if let remote {
                    MigrationState.Migration(
                        id: .init(index: remote.index, name: remote.name),
                        status: .applied
                    )
                } else {
                    // We assume that it must be an unapplied
                    MigrationState.Migration(
                        id: .init(index: local!.index, name: local!.name),
                        status: .unapplied
                    )
                }
            }

        // Filter based on status if provided
        if let status {
            switch status {
            case .applied:
                return MigrationState(migrations: migrations.filter {
                    if case .applied = $0.status { return true }
                    return false
                })
            case .pending:
                return MigrationState(migrations: migrations.filter {
                    if case .applied = $0.status { return false }
                    return true
                })
            }
        }

        return MigrationState(migrations: migrations)
    }
}

enum MigrationError: Error {
    case conflictsExist
    case invalidMigrationFile
    case notImplemented(String)
}

package enum MigrationStatus {
    case applied
    case pending
}

package struct MigrationState {
    package struct Migration {
        package let id: MigrationID
        package let status: Status
    }

    package enum Status: Equatable {
        case applied
        case conflict(Change)
        case unapplied

        package enum Change: Equatable {
            case name
            case expression
        }

        package var isConflict: Bool {
            if case .conflict = self { true } else { false }
        }

        package var isApplied: Bool {
            if case .applied = self { true } else { false }
        }

        package var isUnapplied: Bool {
            if case .unapplied = self { true } else { false }
        }
    }

    package let migrations: [Migration]

    package var hasApplied: Bool {
        self.migrations.contains(where: \.status.isApplied)
    }

    package var hasConflicts: Bool {
        self.migrations.contains(where: \.status.isConflict)
    }

    package var hasUnapplied: Bool {
        self.migrations.contains(where: \.status.isUnapplied)
    }

    package func formatted() -> String {
        var lines: [String] = []

        for (index, migration) in self.migrations.enumerated() {
            let isLast = index == self.migrations.count - 1
            let prefix = isLast ? "┗━" : "┣━"

            switch migration.status {
            case .applied:
                lines
                    .append(
                        "\(prefix)[x] \(String(format: "%03d", migration.id.index)) - \(migration.id.name)"
                    )
            case .conflict(let remoteName):
                lines
                    .append(
                        "\(prefix)[!] \(String(format: "%03d", migration.id.index)) - \(migration.id.name) => \(remoteName)"
                    )
            case .unapplied:
                lines
                    .append(
                        "\(prefix)[ ] \(String(format: "%03d", migration.id.index)) - \(migration.id.name)"
                    )
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct MigrationConflict {
    let local: MigrationID
    let remote: Migration
    let reason: ConflictReason

    enum ConflictReason {
        case hashMismatch
        case nameMismatch
    }
}

struct MigrationStrategy {
    let applies: [Migration]
    let reverts: [Migration]

    var isEmpty: Bool {
        self.applies.isEmpty && self.reverts.isEmpty
    }
}

enum VerificationError: Error {
    case migrationNotApplied(MigrationID)
    case migrationNotReverted(MigrationID)

    var localizedDescription: String {
        switch self {
        case .migrationNotApplied(let id):
            "Migration \(id) was not applied successfully"
        case .migrationNotReverted(let id):
            "Migration \(id) was not reverted successfully"
        }
    }
}

extension Palindrome {
    /// Verifies all migrations by testing apply and revert operations
    package func verify() async throws {
        try await self.remote.withTemporary { temporaryRemote in
            print("Verifying migrations in '\(temporaryRemote.config.database ?? "-")' :")
            
            let palindrome = Palindrome(remote: temporaryRemote, local: local)
            
            let migrations = try await local.list()

            for migration in migrations {
                print("Verifying migration: \(migration.index) - \(migration.name)")

                // Apply the migration
                print("  applying...")
                try await palindrome.migrate(to: migration.id)

                // Verify the migration was applied
                let state = try await palindrome.state()
                guard state.migrations.last(where: { $0.id == migration.id })?.status.isApplied == true
                else {
                    throw VerificationError.migrationNotApplied(migration.id)
                }
                print("  ✓ Applied successfully")

                // Revert the migration
                print("  reverting...")
                _ = try await palindrome.remote.revert()

                // Verify the migration was reverted
                let afterRevert = try await palindrome.state()
                guard afterRevert.migrations.first(where: { $0.id == migration.id })?.status
                    .isUnapplied == true
                else {
                    throw VerificationError.migrationNotReverted(migration.id)
                }
                print("  ✓ Reverted successfully")
            }
            print("All migrations verified successfully! 🎉")
        }
    }
}

extension RemoteMigrations {
    package func withTemporary<T>(perform: (RemoteMigrations) async throws -> T) async throws -> T {
        // Create a temporary database name
        let tempDatabase = "\(config.database!)_verify"
        

        // Create temporary database
        print("Creating temporary database '\(tempDatabase)'...")
        let logger = Logger(label: "PostgresNIO")
        
        _ = try await self.client.withConnection { connection in
            try await connection.query(
                "DROP DATABASE IF EXISTS \(unescaped: tempDatabase)",
                logger: logger
            )
            try await connection.query("CREATE DATABASE \(unescaped: tempDatabase)", logger: logger)
        }

        // Create a copy of database options for the temp database
        var tempConfiguration = config
        tempConfiguration.database = tempDatabase

        // Initialize Palindrome with temp database
        let remote = try await RemoteMigrations(config: tempConfiguration)
        
        do {
            let result = try await perform(remote)
            try await self.cleanup(databaseName: tempDatabase)
            return result
        } catch {
            try await self.cleanup(databaseName: tempDatabase)
            throw error
        }
    }

    /// Cleans up the temporary database
    fileprivate func cleanup(databaseName: String) async throws {
        _ = try await client.withConnection { connection in
            // Terminate all connections to the temporary database
            try await connection.query("""
            SELECT pg_terminate_backend(pid) 
            FROM pg_stat_activity 
            WHERE datname = \(databaseName)
            """, logger: logger)

            // Now we can safely drop the database
            try await connection.query(
                "DROP DATABASE IF EXISTS \(unescaped: databaseName)",
                logger: logger
            )
        }
    }
}
