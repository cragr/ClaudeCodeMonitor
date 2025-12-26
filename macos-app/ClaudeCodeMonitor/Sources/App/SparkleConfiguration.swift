import Foundation

/// Sparkle update configuration
enum SparkleConfiguration {
    /// URL to the appcast XML file
    static let feedURL = URL(string: "https://raw.githubusercontent.com/cragr/ClaudeCodeMonitor/main/appcast.xml")!

    /// EdDSA public key for verifying update signatures
    /// Generate with: ./bin/generate_keys from Sparkle
    /// TODO: Replace with actual public key before first release
    static let edPublicKey = "REPLACE_WITH_YOUR_ED25519_PUBLIC_KEY"
}
