//
//  VerifyCommand.swift
//
//  Copyright © 2024 Noah Kamara.
//

import ArgumentParser
import Foundation
import Logging
import PalindromeCore
import PostgresNIO

struct VerifyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Verify that all migrations can be applied and reverted",
        discussion: """
        Tests all migrations by:
        1. Creating a temporary database
        2. Applying each migration in sequence
        3. Verifying the migration was applied
        4. Reverting each migration
        5. Verifying the migration was reverted
        6. Cleaning up the temporary database

        This helps ensure that all migrations are valid and can be safely applied and reverted.
        """
    )

    @OptionGroup(title: "Database Options")
    var databaseOptions: DatabaseOptions

    @Option(help: "The path to the migrations folder")
    var migrationsDirectory: String = "./migrations"

    mutating func run() async throws {
        print("Verifying migrations...")

        // Create temporary Palindrome instance
        let palindrome = try await Palindrome(
            config: self.databaseOptions.config,
            migrationsPath: self.migrationsDirectory
        )

        // Run verification
        try await palindrome.verify()
    }
}
