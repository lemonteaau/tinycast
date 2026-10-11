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
        theSynthesizedSwitchNamesNoEffort()
        aGatewayCatalogEffortIsSent()
        aFlattenedCatalogIsRead()

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func theSynthesizedSwitchNamesNoEffort() {
        let url = URL(string: "https://api.fusioncode.app/v1")!
        let gateway = AIConnection(provider: .openAI, baseURL: url.absoluteString, models: ["m"])
        let switched = gateway.httpConfiguration(baseURL: url, model: "m", effort: "default")
        expect(
            switched.effort == nil && !switched.disablesThinking,
            "the synthesized Default names no effort at all")
        expect(
            gateway.httpConfiguration(baseURL: url, model: "m", effort: "none").disablesThinking,
            "the synthesized None still turns thinking off")
    }

    static func aGatewayCatalogEffortIsSent() {
        let url = URL(string: "https://gateway.example/v1")!
        let gateway = AIConnection(
            provider: .openAICompatible, baseURL: url.absoluteString, models: ["m", "manual"],
            reasoningOptions: [
                "m": .init(efforts: ["low", "medium", "high", "max"], defaultEffort: "high")
            ])
        expect(
            gateway.reasoningOptions(for: "m")?.efforts == ["low", "medium", "high", "max"],
            "a gateway's published efforts replace the synthesized switch")

        let picked = AIRequestBody.make(
            turn, configuration: gateway.httpConfiguration(baseURL: url, model: "m", effort: "max"))
        expect(
            picked["reasoning_effort"] as? String == "max" && picked["reasoning"] == nil
                && picked["thinking"] == nil,
            "a gateway receives the catalogued effort as reasoning_effort")

        let stale = AIRequestBody.make(
            turn,
            configuration: gateway.httpConfiguration(baseURL: url, model: "m", effort: "default"))
        expect(
            stale["reasoning_effort"] as? String == "high",
            "an effort the catalog never listed falls back to its advertised default")

        let manual = AIRequestBody.make(
            turn,
            configuration: gateway.httpConfiguration(
                baseURL: url, model: "manual", effort: "default"))
        expect(
            manual["reasoning_effort"] == nil && manual["thinking"] == nil,
            "a model the catalog said nothing about is sent no effort")

        let router = AIConnection(
            provider: .openRouter, models: ["m"],
            reasoningOptions: ["m": .init(efforts: ["low", "high"], defaultEffort: "high")])
        let routed = AIRequestBody.make(
            turn,
            configuration: router.httpConfiguration(
                baseURL: URL(string: AIProviderKind.openRouter.defaultBaseURL)!, model: "m",
                effort: "low"))
        expect(
            (routed["reasoning"] as? [String: String])?["effort"] == "low"
                && routed["reasoning_effort"] == nil,
            "OpenRouter keeps its own reasoning object")
    }

    static func aFlattenedCatalogIsRead() {
        let flattened = Data(
            """
            {"data":[{"id":"global:deepseek-v4.1-flash","name":"Deepseek-V4.1-Flash",
                      "only_reasoning":true,"reasoning_effort":"high",
                      "reasoning_default_effort":"max",
                      "reasoning_supported_efforts":["low","high","max"]}]}
            """.utf8)
        let model = (try? AIModelDiscovery.decode(flattened, shape: .openAI))?.first
        expect(
            model?.reasoningOptions == .init(efforts: ["low", "high", "max"], defaultEffort: "max"),
            "a gateway's flattened reasoning fields are read as the same catalog")
        let url = URL(string: "https://gateway.example/v1")!
        let gateway = AIConnection(
            provider: .openAICompatible, baseURL: url.absoluteString,
            models: ["global:deepseek-v4.1-flash"],
            reasoningOptions: model.flatMap { model in
                model.reasoningOptions.map { [model.id: $0] }
            })
        let defaulted = AIRequestBody.make(
            turn,
            configuration: gateway.httpConfiguration(
                baseURL: url, model: "global:deepseek-v4.1-flash", effort: "default"))
        expect(
            defaulted["reasoning_effort"] as? String == "max",
            "a saved Default resolves to the gateway's advertised default and is sent")
    }
}
