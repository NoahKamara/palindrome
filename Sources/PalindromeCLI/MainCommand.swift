//
//  MainCommand.swift
//
//  Copyright © 2024 Noah Kamara.
//

import ArgumentParser
import PalindromeCore

@main
struct MainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "palindrome",
        abstract: "A command-line tool for managing PostgreSQL database migrations",
        discussion: """
        Palindrome helps you manage database migrations for PostgreSQL databases.
        It provides commands for creating, applying, and reverting migrations.

        Each migration consists of two parts:
        1. Apply: The SQL to run when applying the migration
        2. Revert: The SQL to run when reverting the migration

        Migrations are stored in a directory (default: ./migrations) and tracked in the database.
        """,
        subcommands: [
            ShowCommand.self,
            CreateCommand.self,
            MigrateCommand.self,
            VerifyCommand.self,
        ],
        defaultSubcommand: ShowCommand.self
    )

    @OptionGroup(title: "Database Options")
    var database: DatabaseOptions
}
