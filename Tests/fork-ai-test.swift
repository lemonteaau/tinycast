// The fork's catalogued reasoning efforts for gateways, kept out of upstream's ai-provider-test.
import Foundation

@main
@MainActor
struct ForkAITests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static let turn = AIRequest(messages: [AIMessage(role: .user, text: "hi")])

    static func main() {
        aFlattenedCatalogIsRead()
        aFlattenedCatalogDeclaresAGatewaysLevels()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static let flattened = Data(
        """
        {"data":[{"id":"global:deepseek-v4.1-flash","name":"Deepseek-V4.1-Flash",
                  "only_reasoning":true,"reasoning_effort":"high",
                  "reasoning_default_effort":"max",
                  "reasoning_supported_efforts":["low","high","max"]}]}
        """.utf8)

    static func aFlattenedCatalogIsRead() {
        let model = (try? AIModelDiscovery.decode(flattened, shape: .openAI))?.first
        expect(
            model?.reasoningOptions == .init(efforts: ["low", "high", "max"], defaultEffort: "max"),
            "a gateway's flattened reasoning fields are read as the same catalog")

        let nested = Data(
            """
            {"data":[{"id":"m","reasoning":{"supported_efforts":["low"],"default_effort":"low"},
                      "reasoning_supported_efforts":["high"]}]}
            """.utf8)
        expect(
            (try? AIModelDiscovery.decode(nested, shape: .openAI))?.first?.reasoningOptions
                == .init(efforts: ["low"], defaultEffort: "low"),
            "OpenRouter's nested reasoning object wins over the flattened spelling")
    }

    static func aFlattenedCatalogDeclaresAGatewaysLevels() {
        let catalog = (try? AIModelDiscovery.decode(flattened, shape: .openAI)) ?? []
        let url = URL(string: "https://gateway.example/v1")!
        var gateway = AIConnection(
            provider: .openAICompatible, baseURL: url.absoluteString,
            models: ["global:deepseek-v4.1-flash"])
        gateway.adoptCatalog(catalog)
        expect(
            gateway.reasoningOptions(for: "global:deepseek-v4.1-flash")?.efforts
                == ["default", "low", "high", "max", "none"],
            "a gateway's flattened efforts become its declared levels")

        func body(_ effort: String) -> [String: Any] {
            AIRequestBody.make(
                turn,
                configuration: AIHTTPConfiguration(
                    provider: gateway.provider, baseURL: url, model: "global:deepseek-v4.1-flash",
                    effort: effort,
                    disablesThinking: effort == AIConnection.ReasoningOptions.noEffort
                        && gateway.takesThinkingField))
        }
        expect(
            body("max")["reasoning_effort"] as? String == "max" && body("max")["reasoning"] == nil,
            "a gateway receives the catalogued effort as reasoning_effort")
        expect(
            body("default")["reasoning_effort"] == nil,
            "the synthesized Default names no effort, so the gateway keeps its own")
    }
}
