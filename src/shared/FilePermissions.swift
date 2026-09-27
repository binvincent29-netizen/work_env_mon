import Foundation

/// 폴더와 파일의 권한을 뜻대로 맞춘다.
///
/// 만들 때 권한을 함께 주더라도, 이미 있는 것에는 적용되지 않는다.
/// 새로 만들 때도 umask 에 깎여 뜻한 것보다 좁아질 수 있다.
/// 그래서 만든 뒤에 한 번 더 맞춘다.
///
/// 실제로 겪은 일이다. macOS 를 올리면서 기록 폴더가 지워졌고,
/// 데몬이 다시 만들 때 744 가 되어 사용자가 기록을 열 수 없었다.
/// 폴더는 읽기 권한만으로는 들어갈 수 없다. 실행 권한이 함께 있어야 한다.
enum FilePermissions {

    /// 폴더를 만들고 권한을 맞춘다. 이미 있으면 권한만 맞춘다.
    @discardableResult
    static func ensureDirectory(_ path: String, mode: Int, group: Int? = nil) -> Bool {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: mode])
        }
        guard fm.fileExists(atPath: path) else { return false }
        return apply(mode: mode, group: group, to: path)
    }

    /// 이미 있는 파일의 권한을 맞춘다. 없으면 아무 일도 하지 않는다.
    @discardableResult
    static func ensureFile(_ path: String, mode: Int, group: Int? = nil) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        return apply(mode: mode, group: group, to: path)
    }

    private static func apply(mode: Int, group: Int?, to path: String) -> Bool {
        var attributes: [FileAttributeKey: Any] = [.posixPermissions: mode]
        if let group = group {
            attributes[.groupOwnerAccountID] = group
        }
        do {
            try FileManager.default.setAttributes(attributes, ofItemAtPath: path)
            return true
        } catch {
            return false
        }
    }

    /// 지금 붙어 있는 권한. 읽지 못하면 nil.
    static func mode(of path: String) -> Int? {
        try? FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
    }

    /// 남들이 폴더 안으로 들어갈 수 있는지.
    /// 읽기만 있고 실행이 없으면 이름은 보이지만 파일은 열 수 없다.
    static func isSearchableByEveryone(_ path: String) -> Bool {
        guard let mode = mode(of: path) else { return false }
        return mode & 0o005 == 0o005
    }
}
