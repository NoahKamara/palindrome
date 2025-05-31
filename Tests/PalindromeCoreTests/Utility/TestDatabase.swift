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

    @inline(__always)
    func withTestDatabase(
        method: String = #function,
        perform: (RemoteMigrations) async throws -> Void
    ) async throws {
        let global = try await RemoteMigrations(config: globalConfig)
        try await global.withTemporary("test_\(method)_\(UUID().uuidString.prefix(8))") { migrations in
            try await perform(migrations)
        }
    }
}
