import Foundation
import Testing
@testable import TenazCore

struct DenyListTests {
    let list = try! TivraFixture.denyList()

    @Test func matchesBundlesAndSubdomains() {
        #expect(list.match(bundleId: "com.openai.codex", domain: nil, url: nil, mode: .strict)?.label == "ChatGPT")
        #expect(list.match(bundleId: "COM.ANTHROPIC.CLAUDEFORDESKTOP", domain: nil, url: nil, mode: .strict) != nil)
        #expect(list.match(bundleId: nil, domain: "www.deepl.com", url: nil, mode: .strict)?.label == "DeepL")
        #expect(list.match(bundleId: nil, domain: nil, url: "https://chatgpt.com/c/1", mode: .strict) != nil)
    }

    @Test func doesNotMatchLookalikes() {
        #expect(list.match(bundleId: "company.thebrowser.dia", domain: "www.youtube.com", url: nil, mode: .strict) == nil)
        #expect(list.match(bundleId: nil, domain: "notclaude.ai", url: nil, mode: .strict) == nil)
        #expect(list.match(bundleId: nil, domain: "www.youtube.com", url: nil, mode: .strict) == nil)
        #expect(list.match(bundleId: nil, domain: "x.com", url: "https://x.com/home", mode: .strict) == nil)
    }

    @Test func pathEntriesNeedThePath() {
        #expect(list.match(bundleId: nil, domain: "x.com", url: "https://x.com/i/grok", mode: .strict)?.label == "Grok")
        #expect(list.match(bundleId: nil, domain: "huggingface.co", url: "https://huggingface.co/chat/", mode: .strict) != nil)
        #expect(list.match(bundleId: nil, domain: "huggingface.co", url: "https://huggingface.co/models", mode: .strict) == nil)
        #expect(list.match(bundleId: nil, domain: "www.bing.com", url: "https://www.bing.com/translator", mode: .strict) != nil)
    }

    @Test func practiceModeOnlyForbidsAI() {
        #expect(list.match(bundleId: nil, domain: "wordreference.com", url: nil, mode: .strict) != nil)
        #expect(list.match(bundleId: nil, domain: "wordreference.com", url: nil, mode: .practice) == nil)
        #expect(list.match(bundleId: nil, domain: "deepl.com", url: nil, mode: .practice) == nil)
        #expect(list.match(bundleId: nil, domain: "claude.ai", url: nil, mode: .practice) != nil)
        #expect(list.match(packageName: "com.google.android.apps.translate", mode: .practice) == nil)
        #expect(list.match(packageName: "com.google.android.apps.translate", mode: .strict) != nil)
    }

    @Test func runtimeBundlesAreAddedWithoutDuplicates() {
        let extra = [DenyList.BundleEntry(id: "COM.OPENAI.CODEX", label: "dup", tier: .ai), .init(id: "com.new.app", label: "New", tier: .ai)]
        let merged = list.adding(bundles: extra)
        #expect(merged.bundles.count == list.bundles.count + 1)
        #expect(merged.match(bundleId: "com.new.app", domain: nil, url: nil, mode: .practice)?.label == "New")
    }
}
