//
//  MigrateCommand.swift
//
//  Copyright © 2024 Noah Kamara.
//

import ArgumentParser
import PalindromeCore

struct MigrateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        abstract: "Apply or revert migrations to reach a target state",
        discussion: """
        Migrates the database to a target state by applying or reverting migrations as needed.

        The target can be specified in three ways:
        1. 'head' - Migrate to the latest migration
        2. An index number - Migrate to a specific migration by index
        3. A name - Migrate to a specific migration by name

        If there are conflicts, you'll be prompted to revert them first.
        Use --force to skip the confirmation prompt.
        """
    )

    @OptionGroup(title: "Database Options")
    var databaseOptions: DatabaseOptions

    @Option(help: "The path to the migrations folder")
    var migrationsDirectory: String = "./migrations"

    @Argument(help: "The target migration (head, index, or name)")
    var reference: Reference = .head

    @Flag(help: "Skip confirmation prompts")
    var force: Bool = false

    mutating func run() async throws {
        let palindrome = try await Palindrome(
            config: databaseOptions.config,
            migrationsPath: self.migrationsDirectory
        )

        print("Migrations")
        let state = try await palindrome.state()
        print(state.formatted())

        if state.hasConflicts {
            guard self.force || confirm("Revert conflicting migrations? (y/N)") else {
                print("Ok. stopping")
                return
            }

            print("Reverting conflicting migrations...")
            let firstConflict = state.migrations.first(where: { $0.status.isConflict })!
            try await palindrome.migrate(to: firstConflict.id)
        }

        guard let migrationId = try reference.resolve(using: palindrome) else {
            print("Could not resolve \(self.reference)")
            return
        }

        do {
            try await palindrome.migrate(to: migrationId)
            print("Successfully migrated to \(migrationId)")
        } catch {
            print("Failed to migrate: \(error)")
            throw error
        }

        try await print(palindrome.state().formatted())
    }
}

func confirm(_ prompt: String) -> Bool {
    while true {
        print("Revert conflicting migrations? (y/N): \n", terminator: "> ")
        switch (readLine(strippingNewline: true) ?? "n").lowercased() {
        case "n": return false
        case "y": return true
        default: print("Invalid input. Please enter 'y' or 'n'.")
        }
    }
}

enum Reference: ExpressibleByArgument {
    case head
    case index(Int)
    case name(String)

    init(argument: String) {
        if let index = Int(argument: argument) {
            self = .index(index)
        } else if argument == "head" {
            self = .head
        } else {
            self = .name(argument)
        }
    }

    func resolve(using palindrome: Palindrome) throws -> MigrationID? {
        let identifiers = try palindrome.local.listIdentifiers()

        switch self {
        case .head:
            return identifiers.last
        case .index(let index):
            return identifiers.last(where: { $0.index == index })
        case .name(let name):
            return identifiers.last(where: { $0.name == name || $0.fileName == name })
        }
    }
}
