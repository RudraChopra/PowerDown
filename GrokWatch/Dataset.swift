import Foundation

// We only need the shape and a sample of rows, so we stream the file rather than
// load it whole — a 4GB CSV shouldn't cost 4GB of RAM.
struct Dataset {
    let name: String
    let url: URL
    let trainRows: Int
    let columnCount: Int
    let testRows: Int?
    let testURL: URL?
    var header: [String] = []
    var trainSample: [[String]] = []   // rows the model "trained on"
    var testSample: [[String]] = []    // held-out rows it never saw

    var totalRows: Int { trainRows + (testRows ?? 0) }

    var shapeDescription: String { "\(trainRows) train rows · \(columnCount) columns" }

    var splitDescription: String? {
        guard let testRows, totalRows > 0 else { return nil }
        let trainPct = Int((Double(trainRows) / Double(totalRows) * 100).rounded())
        return "\(trainRows) train / \(testRows) test  (\(trainPct)% / \(100 - trainPct)%)"
    }

    var difficulty: Double {
        let n = max(totalRows, trainRows)
        guard n > 1 else { return 0.4 }
        let lo = log(400.0), hi = log(10000.0)
        let d = (log(Double(n)) - lo) / (hi - lo)
        return min(max(d, 0), 1)
    }
}

enum DatasetLoader {
    // Off the main thread — scanning a big file can take a moment.
    static func load(url: URL, completion: @escaping (Dataset?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let cols = columnCount(url)
            guard let lines = countLines(url) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let trainRows = max(0, lines - 1)   // minus header
            let (testRows, testURL) = findTest(for: url)
            let (header, trainSample) = sampleRows(url, max: 250)
            let (_, testSample) = testURL != nil ? sampleRows(testURL!, max: 250) : (header, [])
            let ds = Dataset(name: url.lastPathComponent, url: url,
                             trainRows: trainRows, columnCount: cols,
                             testRows: testRows, testURL: testURL,
                             header: header, trainSample: trainSample,
                             testSample: testSample.isEmpty ? trainSample : testSample)
            DispatchQueue.main.async { completion(ds) }
        }
    }

    // Header + up to `max` rows, read from the first chunk only.
    private static func sampleRows(_ url: URL, max: Int) -> ([String], [[String]]) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return ([], []) }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4 << 20) else { return ([], []) }
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(whereSeparator: \.isNewline)
        guard let first = lines.first else { return ([], []) }
        let header = first.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        var rows: [[String]] = []
        for line in lines.dropFirst() {
            if rows.count >= max { break }
            let cells = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            if cells.count == header.count { rows.append(cells) }
        }
        return (header, rows)
    }

    // Count newlines with memchr over 1MB chunks. Constant memory, and fast.
    private static func countLines(_ url: URL) -> Int? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var total = 0
        let chunkSize = 1 << 20   // 1 MB
        while let data = try? handle.read(upToCount: chunkSize), !data.isEmpty {
            total += data.withUnsafeBytes { raw -> Int in
                guard var base = raw.baseAddress else { return 0 }
                var remaining = raw.count
                var count = 0
                while remaining > 0, let hit = memchr(base, 0x0A, remaining) {
                    count += 1
                    let consumed = UnsafeRawPointer(hit) - base + 1
                    base = UnsafeRawPointer(hit) + 1
                    remaining -= consumed
                }
                return count
            }
        }
        return total
    }

    private static func columnCount(_ url: URL) -> Int {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return 0 }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 1 << 16) else { return 0 }
        let firstLine: Data
        if let nl = data.firstIndex(of: 0x0A) { firstLine = data[..<nl] } else { firstLine = data }
        let line = String(decoding: firstLine, as: UTF8.self)
        return line.split(separator: ",", omittingEmptySubsequences: false).count
    }

    // "<x>_train.csv" → "<x>_test.csv" sitting next to it, if there is one.
    private static func findTest(for url: URL) -> (Int?, URL?) {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        let candidateName: String
        if base.hasSuffix("_train") {
            candidateName = String(base.dropLast("_train".count)) + "_test"
        } else if base.hasSuffix("train") {
            candidateName = base.replacingOccurrences(of: "train", with: "test")
        } else {
            candidateName = base + "_test"
        }

        let candidate = dir.appendingPathComponent(candidateName).appendingPathExtension(ext)
        if fm.fileExists(atPath: candidate.path), let lines = countLines(candidate) {
            return (max(0, lines - 1), candidate)
        }
        return (nil, nil)
    }
}
