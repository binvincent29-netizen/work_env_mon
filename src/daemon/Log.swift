import Foundation

/// 파일 한 개에 남기는 간단한 기록. 너무 커지면 앞부분을 버린다.
final class Log {
    static let shared = Log()

    private let queue = DispatchQueue(label: "io.github.binvincent29-netizen.streamguard.log")
    private let maxBytes = 512 * 1024
    private let formatter: DateFormatter

    private init() {
        formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        // 폴더에 실행 권한이 없으면 사용자가 기록을 열 수 없다.
        FilePermissions.ensureDirectory(Paths.logDir, mode: 0o755)
    }

    func write(_ message: String) {
        queue.async {
            let line = "[\(self.formatter.string(from: Date()))] \(message)\n"
            FileHandle.standardError.write(Data(line.utf8))

            let url = URL(fileURLWithPath: Paths.logFile)
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? line.write(to: url, atomically: true, encoding: .utf8)
                FilePermissions.ensureFile(Paths.logFile, mode: 0o644)
            }
            self.trimIfNeeded(url)
        }
    }

    private func trimIfNeeded(_ url: URL) {
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > maxBytes,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = text.components(separatedBy: "\n")
        let kept = lines.suffix(lines.count / 2).joined(separator: "\n")
        try? kept.write(to: url, atomically: true, encoding: .utf8)
        // 통째로 바꿔 쓰면 새 파일이 되므로 권한을 다시 맞춘다.
        FilePermissions.ensureFile(Paths.logFile, mode: 0o644)
    }
}

func log(_ message: String) { Log.shared.write(message) }
