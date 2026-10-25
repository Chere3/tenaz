import Foundation

/// Command-line modes used by scripts/verify.sh and the overnight builder.
/// `--tenaz-snapshot <screen> --out <png>`: render one screen off-screen to a PNG and exit (no permissions needed).
/// `--tenaz-smoke <surface>`: show an intrusive surface with fake content, close it within 3 s, log it, exit.
/// `--tenaz-selftest <name>`: run a scripted check and print the result, then exit.
/// `--tenaz-login-item on|off|status`: register/unregister the open-at-login item, print its status, exit.
struct LaunchArguments {
    var snapshot: String?
    var output: String?
    var smoke: String?
    var selftest: String?
    var loginItem: String?

    static let current = LaunchArguments(arguments: CommandLine.arguments)

    init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        snapshot = value(after: "--tenaz-snapshot")
        output = value(after: "--out")
        smoke = value(after: "--tenaz-smoke")
        selftest = value(after: "--tenaz-selftest")
        loginItem = value(after: "--tenaz-login-item")
    }

    var isAutomation: Bool { snapshot != nil || smoke != nil || selftest != nil || loginItem != nil }
}
