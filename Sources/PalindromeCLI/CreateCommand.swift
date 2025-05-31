//
//  CreateCommand.swift
//
//  Copyright © 2024 Noah Kamara.
//

import ArgumentParser
import PalindromeCore

struct CreateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new migration file",
        discussion: """
        Creates a new migration file in the migrations directory.
        The file will be named with the format: {index}_{name}.sql

        The migration file will contain:
        1. A header comment with the migration index and name
        2. A section for the apply SQL
        3. A section for the revert SQL (after the REVERT: marker)

        Example:
        -- 1: create_users_table
        CREATE TABLE users (id SERIAL PRIMARY KEY);

        -- REVERT:
        DROP TABLE users;
        """
    )

    @Option(help: "The path to the migrations folder")
    var migrationsDirectory: String = "./migrations"

    @Argument(help: "The name of the migration (will be converted to a valid filename)")
    var name: String

    mutating func run() throws {
        let migrations = try LocalMigrations(at: .init(filePath: migrationsDirectory))
        let name = try migrations.create(name)
        print("Created '\(name)'")
    }
}
