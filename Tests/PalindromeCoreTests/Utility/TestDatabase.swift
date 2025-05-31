//
//  TestDatabase.swift
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation
@testable import PalindromeCore
import PostgresNIO
import Testing

struct TestDatabase {
    let host: String
    let port: Int
    let username: String
    let password: String
    let databaseName: String
    let tls: PostgresClient.Configuration.TLS

    init(
        host: String = "localhost",
        port: Int = 5432,
        username: String = "postgres",
        password: String = "postgres",
        databaseName: String = "postgres",
        tls: PostgresClient.Configuration.TLS = .prefer(.clientDefault)
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.databaseName = databaseName
        self.tls = tls
    }

    func config(database: String) -> PostgresClient.Configuration {
        PostgresClient.Configuration(
            host: self.host,
            username: self.username,
            password: self.password,
            database: database,
            tls: self.tls
        )
    }

    var globalConfig: PostgresClient.Configuration {
        self.config(database: self.databaseName)
    }

    func withTestDatabase(
        method: String = #function,
        perform: (PostgresClient.Configuration) async throws -> Void
    ) async throws {
        let cleanMethod = method
            .replacing(/[^a-z,_,0-9]/, with: "_")
            .trimmingCharacters(in: ["/"])

        let databaseName = "test_\(cleanMethod)_\(UUID().uuidString.prefix(8))"
            .lowercased()

        let logger = Logger(label: databaseName)

        let client = PostgresClient(configuration: globalConfig, backgroundLogger: logger)

        Task { await client.run() }

        _ = try await client.withConnection { connection in
            try await connection.query("CREATE DATABASE \(unescaped: databaseName)", logger: logger)
        }

        do {
            let tempConfig = self.config(database: databaseName)
            try await perform(tempConfig)
        } catch {
            try await client.query("DROP DATABASE \(unescaped: databaseName)", logger: logger)
            throw error
        }

        try await client.query("DROP DATABASE \(unescaped: databaseName)", logger: logger)
    }
}
