import XCTest
@testable import ClaudeCodeMonitor

final class PricingProviderTests: XCTestCase {
    func testAllProviderCases() {
        let providers = PricingProvider.allCases
        XCTAssertEqual(providers.count, 3)
        XCTAssertTrue(providers.contains(.anthropic))
        XCTAssertTrue(providers.contains(.awsBedrock))
        XCTAssertTrue(providers.contains(.googleVertex))
    }

    func testProviderDisplayNames() {
        XCTAssertEqual(PricingProvider.anthropic.displayName, "Anthropic")
        XCTAssertEqual(PricingProvider.awsBedrock.displayName, "AWS Bedrock")
        XCTAssertEqual(PricingProvider.googleVertex.displayName, "Google Vertex AI")
    }

    func testAnthropicOpus45Pricing() {
        let pricing = PricingProvider.anthropic.pricing(for: "claude-opus-4-5")
        XCTAssertEqual(pricing.input, 5.0)
        XCTAssertEqual(pricing.output, 25.0)
        XCTAssertEqual(pricing.cacheRead, 0.50)
        XCTAssertEqual(pricing.cacheWrite, 6.25)
    }

    func testAnthropicSonnet45Pricing() {
        let pricing = PricingProvider.anthropic.pricing(for: "claude-sonnet-4-5")
        XCTAssertEqual(pricing.input, 3.0)
        XCTAssertEqual(pricing.output, 15.0)
        XCTAssertEqual(pricing.cacheRead, 0.30)
        XCTAssertEqual(pricing.cacheWrite, 3.75)
    }

    func testAnthropicHaiku45Pricing() {
        let pricing = PricingProvider.anthropic.pricing(for: "claude-haiku-4-5")
        XCTAssertEqual(pricing.input, 1.0)
        XCTAssertEqual(pricing.output, 5.0)
        XCTAssertEqual(pricing.cacheRead, 0.10)
        XCTAssertEqual(pricing.cacheWrite, 1.25)
    }

    func testVertexOpus45Pricing() {
        let pricing = PricingProvider.googleVertex.pricing(for: "claude-opus-4-5")
        XCTAssertEqual(pricing.input, 5.50, accuracy: 0.001)
        XCTAssertEqual(pricing.output, 27.50, accuracy: 0.001)
        XCTAssertEqual(pricing.cacheRead, 0.55, accuracy: 0.001)
        XCTAssertEqual(pricing.cacheWrite, 6.875, accuracy: 0.001)
    }

    func testVertexSonnet45Pricing() {
        let pricing = PricingProvider.googleVertex.pricing(for: "claude-sonnet-4-5")
        XCTAssertEqual(pricing.input, 3.30, accuracy: 0.001)
        XCTAssertEqual(pricing.output, 16.50, accuracy: 0.001)
        XCTAssertEqual(pricing.cacheRead, 0.33, accuracy: 0.001)
        XCTAssertEqual(pricing.cacheWrite, 4.125, accuracy: 0.001)
    }

    func testAWSBedrockMatchesAnthropicPricing() {
        let anthropicPricing = PricingProvider.anthropic.pricing(for: "claude-sonnet-4-5")
        let bedrockPricing = PricingProvider.awsBedrock.pricing(for: "claude-sonnet-4-5")
        XCTAssertEqual(bedrockPricing.input, anthropicPricing.input)
        XCTAssertEqual(bedrockPricing.output, anthropicPricing.output)
        XCTAssertEqual(bedrockPricing.cacheRead, anthropicPricing.cacheRead)
        XCTAssertEqual(bedrockPricing.cacheWrite, anthropicPricing.cacheWrite)
    }

    func testCostCalculation() {
        let cost = PricingProvider.anthropic.calculateCost(
            model: "claude-sonnet-4-5",
            inputTokens: 1_000_000,
            outputTokens: 500_000,
            cacheReadTokens: 200_000,
            cacheWriteTokens: 100_000
        )
        XCTAssertEqual(cost, 10.935, accuracy: 0.001)
    }
}
