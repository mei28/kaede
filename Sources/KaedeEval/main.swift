import Foundation
import KaedeConverter
import KaedeCore

// Compares ways of converting typed lines on the examples in Evaluation/corpus.tsv.
// Run from the repository root: `just eval <method>`.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("kaede-eval: \(message)\n".utf8))
    exit(1)
}

let methods = ["rules", "zenzai"]
let arguments = CommandLine.arguments.dropFirst()
guard arguments.count == 1, let method = arguments.first, methods.contains(method) else {
    fail("usage: kaede-eval <\(methods.joined(separator: "|"))>")
}

let root = URL(filePath: FileManager.default.currentDirectoryPath)
let corpus: [CorpusEntry]
let lexicon: EnglishLexicon
do {
    corpus = try Corpus.parse(String(contentsOf: root.appending(path: "Evaluation/corpus.tsv"), encoding: .utf8))
    lexicon = try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + ["en10k.txt", "extra-words.txt"].map {
        root.appending(path: "Resources/\($0)").path(percentEncoded: false)
    })
} catch {
    fail("could not read the corpus or word lists: \(error)")
}
let dictionary = root.appending(path: ".build/checkouts/AzooKeyKanaKanjiConverter/Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary")

let zenzaiWeight = root.appending(path: "Models/zenz-v3.1-small.gguf")

func azooKey(zenzai: Bool) -> AzooKeyConverter {
    AzooKeyConverter(
        dictionaryDirectory: dictionary,
        memoryDirectory: FileManager.default.temporaryDirectory,
        zenzaiWeight: zenzai ? zenzaiWeight : nil
    )
}

let converter: any LineConverting = switch method {
case "rules": RulesLineConverter(planner: EnterPlanner(lexicon: lexicon), converter: azooKey(zenzai: false))
case "zenzai": RulesLineConverter(planner: EnterPlanner(lexicon: lexicon), converter: azooKey(zenzai: true))
default: fail("unknown method \(method)")
}

// One untimed conversion first, so loading models and opening connections is not billed to line 1
do {
    _ = try await converter.convert(corpus[0].typed)
} catch {
    fail("warm-up failed: \(error)")
}

var results: [EvaluationResult] = []
let clock = ContinuousClock()
for (index, entry) in corpus.enumerated() {
    let started = clock.now
    let output: String
    do {
        output = try await converter.convert(entry.typed)
    } catch {
        fail("line \(index + 1) failed: \(error)")
    }
    let result = EvaluationResult(intended: entry.intended, output: output, duration: clock.now - started)
    results.append(result)
    let mark = output == entry.intended ? "OK" : "NG"
    print("[\(mark)] #\(index + 1) \(result.duration)")
    print("  出力: \(output)")
    if output != entry.intended {
        print("  意図: \(entry.intended)")
    }
}

let summary = Scoring.summary(of: results)
print("")
print("方式: \(method)")
print("完全一致: \(summary.exactMatches)/\(summary.total)")
print("文字誤り率: \(String(format: "%.1f", summary.characterErrorRate * 100))%")
print("時間: 中央値 \(summary.medianLatency)、最大 \(summary.maxLatency)")
