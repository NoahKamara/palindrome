//
//  ShowCommand.swift
//
//  Copyright © 2024 Noah Kamara.
//

import ArgumentParser
import PalindromeCore

struct ShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Display the current state of migrations",
        discussion: """
        Shows the current state of all migrations, including:
        - Applied migrations [x]
        - Pending migrations [ ]
        - Conflicting migrations [!]

        The output is formatted as a tree, showing the migration index and name.
        """
    )

    @OptionGroup(title: "Database Options")
    var databaseOptions: DatabaseOptions

    @Option(help: "The path to the migrations folder")
    var migrationsDirectory: String = "./migrations"

    mutating func run() async throws {
        let palindrome = try await Palindrome(
            config: databaseOptions.config,
            migrationsPath: self.migrationsDirectory
        )

        print("Migrations")
        let migrations = try await palindrome.state()
        print(migrations.formatted())
    }
}
