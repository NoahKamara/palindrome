//
//  Migration.swift
//
//  Copyright © 2024 Noah Kamara.
//

import Foundation

final class Migration: Sendable, Decodable {
    var id: MigrationID { MigrationID(index: self.index, name: self.name) }

    let index: Int
    let name: String
    let apply: String
    let revert: String?

    init(index: Int, name: String, apply: String, revert: String?) {
        self.name = name
        self.index = index
        self.apply = apply
        self.revert = revert
    }

    convenience init(id: MigrationID, apply: String, revert: String?) {
        self.init(index: id.index, name: id.name, apply: apply, revert: revert)
    }

    enum CodingKeys: CodingKey {
        case name
        case index
        case apply
        case revert
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        print("WTF?")
        self.name = try container.decode(String.self, forKey: .name)
        self.index = try container.decode(Int.self, forKey: .index)
        self.apply = try container.decode(String.self, forKey: .apply)
        self.revert = try container.decodeIfPresent(String.self, forKey: .revert)
    }

    enum LoadingError: Error {
        case invalidName
        case couldNotAccessFile(underlyingError: any Error)
        case duplicateSeparator(atLine: Int)
        case invalidUTF8Encoding
    }

    /// Load a migration from a file
    /// - Parameters:
    ///   - url: the local file url to the migration
    ///   - expressionSeparator: the separator that splits apply and revert `--
    /// {expressionSeparator}`
    static func load(at url: URL, expressionSeparator: String) throws -> Migration {
        guard let id = MigrationID(fileName: url.lastPathComponent) else {
            throw LoadingError.invalidName
        }

        let contents = try Result { try Data(contentsOf: url) }
            .mapError { LoadingError.couldNotAccessFile(underlyingError: $0) }
            .get()

        guard let stringContent = String(data: contents, encoding: .utf8) else {
            throw LoadingError.invalidUTF8Encoding
        }

        var expression = [String]()
        var revertExpression = [String]()

        var isParsingRevert = false
        var lineNumber = 1

        var parsingError: LoadingError? = nil

        stringContent.enumerateLines { line, stop in
            defer { lineNumber += 1 }

            if line.starts(with: "--") {
                if line == "-- \(expressionSeparator)" {
                    if isParsingRevert {
                        parsingError = LoadingError.duplicateSeparator(atLine: lineNumber)
                        stop = true
                    }

                    isParsingRevert = true
                }
                return
            }

            if isParsingRevert {
                revertExpression.append(line)
            } else {
                expression.append(line)
            }
        }

        if let parsingError {
            throw parsingError
        }

        return Migration(
            id: id,
            apply: expression.joined(separator: "\n"),
            revert: revertExpression.joined(separator: "\n")
        )
    }

    package func save(to url: URL, expressionSeparator: String) throws {
        let fileContent = self.apply + "\n-- \(expressionSeparator)\n" + (self.revert ?? "")
        try fileContent.data(using: .utf8)!.write(to: url)
    }
}
