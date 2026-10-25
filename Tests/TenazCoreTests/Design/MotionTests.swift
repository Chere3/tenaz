import Testing
@testable import TenazCore

struct MotionTests {
    @Test(arguments: MotionToken.allCases)
    func reducedWhenFlagSet(_ token: MotionToken) {
        #expect(token.curve(reduceMotion: true) == .crossfade(duration: 0.20))
        #expect(token.curve(reduceMotion: false) == token.curve)
    }

    @Test func tokensMatchTheDesignDoc() {
        #expect(MotionToken.tap.curve == .spring(duration: 0.18, bounce: 0))
        #expect(MotionToken.pop.curve == .spring(duration: 0.45, bounce: 0.45))
        #expect(MotionToken.float.curve == .loop(duration: 2.8))
    }
}
