import Testing

@testable import CalenbarCore

struct AppVersionTests {
    @Test(arguments: [
        ("0.2.0", "0.1.0", true),
        ("v0.2.0", "0.1.9", true),
        ("0.10.0", "0.9.0", true),
        ("1.0", "0.9.9", true),
        ("0.1.0", "0.1.0", false),
        ("0.1.0", "0.2.0", false),
        ("1.0.0", "1.0", false),
    ])
    func newerComparison(candidate: String, current: String, isNewer: Bool) {
        #expect(AppVersion(candidate)?.isNewer(than: AppVersion(current)!) == isNewer)
    }

    @Test func rejectsGarbage() {
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("") == nil)
    }

    @Test func displayDropsThePrefix() {
        #expect(AppVersion("v1.2.3")?.description == "1.2.3")
    }
}
