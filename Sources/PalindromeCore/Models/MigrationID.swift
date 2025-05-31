//
//  MigrationID.swift
//
//  Copyright © 2024 Noah Kamara.
//

package struct MigrationID: Sendable, Hashable, CustomStringConvertible {
    package let index: Int
    package let name: String

    package var fileName: String {
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

    package var description: String {
        self.fileName
    }
}
