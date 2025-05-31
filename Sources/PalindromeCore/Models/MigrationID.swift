//
//  MigrationID.swift
//
//  Copyright © 2024 Noah Kamara.
//

public struct MigrationID: Sendable, Hashable, CustomStringConvertible {
    public let index: Int
    public let name: String

    public var fileName: String {
        String(format: "%06d", self.index) + "_" + self.name + ".sql"
    }

    init(index: Int, name: String) {
        self.index = index
        self.name = name
    }

    init?(fileName: String) {
        guard let match = fileName.wholeMatch(of: /(\d+)_(.*?).sql/) else {
            return nil
        }

        self.init(index: Int(match.output.1)!, name: String(match.output.2))
    }

    public var description: String {
        self.fileName
    }
}
