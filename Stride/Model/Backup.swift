import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Everything Stride keeps, in one file the user can save to Files and restore after a reinstall.
struct StrideBackup: Codable {
    var version = 1
    var exportedAt: Date
    var state: SavedState
    var walks: [Walk]
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var backup: StrideBackup

    init(backup: StrideBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        backup = try JSONDecoder().decode(StrideBackup.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(backup))
    }

    /// Reads a backup the user picked in Files.
    static func read(from url: URL) throws -> StrideBackup {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try JSONDecoder().decode(StrideBackup.self, from: Data(contentsOf: url))
    }

    static var defaultFilename: String {
        "Stride Backup \(Date().formatted(.iso8601.year().month().day()))"
    }
}
