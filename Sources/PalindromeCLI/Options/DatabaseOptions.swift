//
//  DatabaseOptions.swift
//
//  Copyright © 2024 Noah Kamara.
//

import ArgumentParser
import PostgresNIO

struct DatabaseOptions: ParsableArguments {
    @Option(help: "postgres host")
    var host: String = "localhost"

    @Option(help: "postgres port")
    var port: Int = 5432

    @Option(help: "postgres username")
    var username: String = "postgres"

    @Option(help: "postgres password")
    var password: String = "postgres"

    @Option(help: "postgres database")
    var database: String = "postgres"

    @Option(help: "enable TLS (disable, prefer, require)")
    var tls: TLSMode = .prefer

    enum TLSMode: String, ExpressibleByArgument {
        case disable
        case prefer
        case require

        var mode: PostgresClient.Configuration.TLS {
            switch self {
            case .disable: .disable
            case .prefer: .prefer(.clientDefault)
            case .require: .require(.clientDefault)
            }
        }
    }

    var config: PostgresClient.Configuration {
        PostgresClient.Configuration(
            host: self.host,
            port: self.port,
            username: self.username,
            password: self.password,
            database: self.database,
            tls: self.tls.mode
        )
    }
}
