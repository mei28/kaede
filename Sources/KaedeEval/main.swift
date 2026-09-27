import Foundation
import KaedeCore
import KaedeRemote

// Types the words of Evaluation/words.tsv into the switching engine with Jev's real answers,
// and counts how the switches went. Run from the repository root: `just eval`.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("kaede-eval: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 1 else {
    fail("usage: kaede-eval (no arguments)")
}

let root = URL(filePath: FileManager.default.currentDirectoryPath)
let words: [WordCase]
let lexicon: EnglishLexicon
do {
    words = try WordTable.parse(String(contentsOf: root.appending(path: "Evaluation/words.tsv"), encoding: .utf8))
    let bundledLists = ["en10k.txt", "extra-words.txt"].map { root.appending(path: "Resources/\($0)").path(percentEncoded: false) }
    lexicon = try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledLists)
} catch {
    fail("could not read the word table or the word lists: \(error)")
}

let apiKey: String
do {
    guard let key = try Keychain.apiKey(named: "jev") else {
        fail("no jev API key in the keychain; store it with `just set-key jev`")
    }
    apiKey = key
} catch {
    fail("could not read the jev API key: \(error)")
}

/// The terminal the user types in most; the app is part of what Jev judges from.
let application = "com.github.wez.wezterm"
let romanSource = "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman"
/// Questions in flight at once while fetching the answers.
let parallelQuestions = 8

struct Fetched: Sendable {
    var word: Int
    var keys: String
    var answer: TimedJudgment
    var inputTokens: Int
}

/// Asks Jev every question the engine may ask about every word, once each.
func fetchAnswers() async throws -> [Fetched] {
    let request = JevSwitchRequest(apiKey: apiKey)
    let transport = URLSessionTransport()
    let questions = words.enumerated().flatMap { index, word in
        Simulation.questions(for: word).map { (word: index, question: $0) }
    }
    return try await withThrowingTaskGroup(of: Fetched.self) { group in
        var fetched: [Fetched] = []
        for (position, item) in questions.enumerated() {
            if position >= parallelQuestions, let done = try await group.next() {
                fetched.append(done)
            }
            group.addTask {
                let clock = ContinuousClock()
                let started = clock.now
                let (data, status) = try await transport.send(
                    request.urlRequest(question: item.question, application: application, inputSource: romanSource)
                )
                let (judgment, inputTokens) = try JevSwitchResponse.read(data, status: status, offered: item.question.options)
                let answer = TimedJudgment(judgment: judgment, latency: clock.now - started)
                return Fetched(word: item.word, keys: item.question.keys, answer: answer, inputTokens: inputTokens)
            }
        }
        for try await done in group {
            fetched.append(done)
        }
        return fetched
    }
}

let fetched: [Fetched]
do {
    fetched = try await fetchAnswers()
} catch {
    fail("asking Jev failed: \(error)")
}

var answers = Array(repeating: [String: TimedJudgment](), count: words.count)
for item in fetched {
    answers[item.word][item.keys] = item.answer
}
let rule = DictionaryRule(lexicon: lexicon)
let results = words.indices.map { Simulation.run(words[$0], rule: rule, answers: answers[$0]) }

for result in results where result.verdict != .correct {
    let what = switch result.verdict {
    case .wrongSwitch: "誤って切り替えた"
    case .missed: "切り替えそこねた"
    case .correct: preconditionFailure("correct words are not listed")
    }
    let switched = result.switchedTo.map { "\($0.rawValue) に \(result.keysAtSwitch!) 打鍵目で" } ?? "切り替えず"
    print("[NG] \(what): \(result.word.keys)（正解 \(result.word.answer.rawValue)、\(switched)）直前: \"\(result.word.textBefore)\"")
}

func milliseconds(_ duration: Duration) -> Int {
    Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
}

let summary = WordEvaluationSummary(results: results, rule: rule)
let keysToSwitch = summary.keysToSwitch.sorted()
let latencies = fetched.map(\.answer.latency).sorted()
print("")
print("語: \(words.count)（英語 \(summary.englishWords)、日本語 \(summary.japaneseWords)）、アプリ \(application)")
print("英語を誤って日本語に切り替えた: \(summary.englishSwitched) / \(summary.englishWords)")
print("日本語を正しく切り替えた: \(summary.japaneseSwitched) / \(summary.japaneseWords)（配列の取り違え \(summary.japaneseWrongLayout)、切り替えそこね \(summary.japaneseMissed)）")
if !keysToSwitch.isEmpty {
    let mean = Double(keysToSwitch.reduce(0, +)) / Double(keysToSwitch.count)
    print("切り替えまでの打鍵数: 中央値 \(keysToSwitch[keysToSwitch.count / 2])、平均 \(String(format: "%.1f", mean))")
}
print("問い合わせ: 打鍵の流れで聞いた数 \(summary.questionsAsked)、前もって聞いた数 \(fetched.count)、入力トークン 合計 \(fetched.map(\.inputTokens).reduce(0, +))")
print("答えまでの時間: 中央値 \(milliseconds(latencies[latencies.count / 2])) ms、最大 \(milliseconds(latencies[latencies.count - 1])) ms")
print("辞書の規則だけの正解: \(summary.ruleCorrect) / \(words.count)")
