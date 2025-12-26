import Foundation

/// Represents pricing for a specific Claude model
struct ModelPricing {
    /// Price per 1M input tokens in USD
    let input: Double
    /// Price per 1M output tokens in USD
    let output: Double
    /// Price per 1M cache read tokens in USD
    let cacheRead: Double
    /// Price per 1M cache write tokens in USD
    let cacheWrite: Double
}

/// Cloud provider pricing tiers for Claude models
enum PricingProvider: String, CaseIterable {
    case anthropic = "anthropic"
    case awsBedrock = "aws_bedrock"
    case googleVertex = "google_vertex"

    /// Human-readable display name for the provider
    var displayName: String {
        switch self {
        case .anthropic:
            return "Anthropic"
        case .awsBedrock:
            return "AWS Bedrock"
        case .googleVertex:
            return "Google Vertex AI"
        }
    }

    /// Returns pricing for the specified model
    /// - Parameter modelId: Model identifier (e.g., "claude-opus-4-5")
    /// - Returns: ModelPricing with per-1M-token rates in USD
    func pricing(for modelId: String) -> ModelPricing {
        // Normalize model name by removing prefixes and converting to lowercase
        let normalized = normalizeModelName(modelId)

        // Get base Anthropic pricing
        let basePricing = anthropicBasePricing(for: normalized)

        // Apply provider-specific adjustments
        switch self {
        case .anthropic:
            return basePricing
        case .awsBedrock:
            // AWS Bedrock uses same pricing as Anthropic
            return basePricing
        case .googleVertex:
            // Google Vertex AI has 10% premium
            return ModelPricing(
                input: basePricing.input * 1.1,
                output: basePricing.output * 1.1,
                cacheRead: basePricing.cacheRead * 1.1,
                cacheWrite: basePricing.cacheWrite * 1.1
            )
        }
    }

    /// Calculates total cost for token usage
    /// - Parameters:
    ///   - model: Model identifier
    ///   - inputTokens: Number of input tokens
    ///   - outputTokens: Number of output tokens
    ///   - cacheReadTokens: Number of cache read tokens
    ///   - cacheWriteTokens: Number of cache write tokens
    /// - Returns: Total cost in USD
    func calculateCost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        cacheWriteTokens: Int
    ) -> Double {
        let pricing = self.pricing(for: model)

        // Convert token counts to millions and multiply by per-1M pricing
        let inputCost = Double(inputTokens) / 1_000_000.0 * pricing.input
        let outputCost = Double(outputTokens) / 1_000_000.0 * pricing.output
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000.0 * pricing.cacheRead
        let cacheWriteCost = Double(cacheWriteTokens) / 1_000_000.0 * pricing.cacheWrite

        return inputCost + outputCost + cacheReadCost + cacheWriteCost
    }

    // MARK: - Private Helpers

    /// Normalizes model name to canonical form
    private func normalizeModelName(_ modelId: String) -> String {
        // Remove common prefixes and convert to lowercase
        let lowercased = modelId.lowercased()

        // Handle various formats:
        // - claude-opus-4-5
        // - claude-3-5-sonnet-20241022
        // - opus-4-5
        // - claude-sonnet-4-5

        // Extract the model tier (opus, sonnet, haiku)
        if lowercased.contains("opus") {
            if lowercased.contains("4-5") || lowercased.contains("4.5") {
                return "opus-4-5"
            }
        } else if lowercased.contains("sonnet") {
            if lowercased.contains("4-5") || lowercased.contains("4.5") {
                return "sonnet-4-5"
            } else if lowercased.contains("3-5") || lowercased.contains("3.5") {
                return "sonnet-3-5"
            }
        } else if lowercased.contains("haiku") {
            if lowercased.contains("4-5") || lowercased.contains("4.5") {
                return "haiku-4-5"
            } else if lowercased.contains("3-5") || lowercased.contains("3.5") {
                return "haiku-3-5"
            }
        }

        return lowercased
    }

    /// Returns base Anthropic pricing for normalized model name
    private func anthropicBasePricing(for normalizedModel: String) -> ModelPricing {
        switch normalizedModel {
        case "opus-4-5":
            return ModelPricing(
                input: 5.0,
                output: 25.0,
                cacheRead: 0.50,
                cacheWrite: 6.25
            )
        case "sonnet-4-5":
            return ModelPricing(
                input: 3.0,
                output: 15.0,
                cacheRead: 0.30,
                cacheWrite: 3.75
            )
        case "haiku-4-5":
            return ModelPricing(
                input: 1.0,
                output: 5.0,
                cacheRead: 0.10,
                cacheWrite: 1.25
            )
        case "sonnet-3-5":
            return ModelPricing(
                input: 3.0,
                output: 15.0,
                cacheRead: 0.30,
                cacheWrite: 3.75
            )
        case "haiku-3-5":
            return ModelPricing(
                input: 0.8,
                output: 4.0,
                cacheRead: 0.08,
                cacheWrite: 1.0
            )
        default:
            // Default to Sonnet 4.5 pricing for unknown models
            return ModelPricing(
                input: 3.0,
                output: 15.0,
                cacheRead: 0.30,
                cacheWrite: 3.75
            )
        }
    }
}
