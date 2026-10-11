import Foundation
import KaedeConverter
import KaedeCore

// Counts how well the converter tells English from Japanese and QWERTY from the user's layout,
// on Evaluation/lines.tsv: typed<TAB>expected segmentation<TAB>intended Japanese (not scored).
// Run from the repository root (`just eval`).

let arguments = Array(CommandLine.arguments.dropFirst())

func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

func stop(_ message: String) -> Never {
    FileHandle.standardError.write(Data("kaede-eval: \(message)\n".utf8))
    exit(1)
}

let layouts: [String: KeyboardLayout] = ["qwerty": .qwerty, "ebi": .ebi, "eucalyn": .eucalyn, "oonishi": .oonishi, "waddlier": .waddlier]
let layoutName = option("--layout") ?? "ebi"
guard let layout = layouts[layoutName] else {
    stop("unknown layout \(layoutName); one of \(layouts.keys.sorted())")
}

let root = URL(filePath: FileManager.default.currentDirectoryPath)
let lexicon: EnglishLexicon
do {
    lexicon = try EnglishLexicon(contentsOfFiles: ["en10k.txt", "extra-words.txt"].map { root.appending(path: "Resources/\($0)").path(percentEncoded: false) })
} catch {
    stop("cannot read the word lists in Resources/ (run from the repository root): \(error)")
}
let segmenter = LineSegmenter(lexicon: lexicon)
let worker = ConversionWorker(
    dictionaryDirectory: root.appending(path: ".build/checkouts/AzooKeyKanaKanjiConverter/Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary"),
    memoryDirectory: FileManager.default.temporaryDirectory,
    lexicon: lexicon
)

func notation(_ typed: String) -> String {
    SegmentNotation.notation(of: segmenter.segments(of: typed[...], layout: layout))
}

func converted(_ typed: String) async -> String {
    do {
        return try await worker.convert(typed, style: .touten, layout: layout).text
    } catch {
        stop("converting \(typed) failed: \(error)")
    }
}

if let typed = option("--show") {
    print(notation(typed))
    print(await converted(typed))
    exit(0)
}

/// The pieces of a notation: ja(…), en(…), en/L(…), num(…), mark(…), text(…), or one punctuation mark.
func pieces(_ notation: String) -> [String] {
    let pattern = /(ja|en\/L|en|num|mark|text)\(.*?\)(?= |$)|\S/
    return notation.matches(of: pattern).map { String($0.output.0) }
}

/// The kind of a piece, for counting hits by kind.
func kind(_ piece: String) -> String {
    if piece.hasPrefix("en/L(") { return "en/L" }
    if piece.hasPrefix("en(") { return "en" }
    if piece.hasPrefix("ja(") { return piece.contains("L:") ? "ja/L" : "ja" }
    if piece.count == 1 { return "punctuation" }
    return "other"
}

let table: String
do {
    table = try String(contentsOf: root.appending(path: "Evaluation/lines.tsv"), encoding: .utf8)
} catch {
    stop("cannot read Evaluation/lines.tsv: \(error)")
}
var lines = 0
var exact = 0
var expectedByKind: [String: Int] = [:]
var hitByKind: [String: Int] = [:]
for row in table.split(separator: "\n") where !row.hasPrefix("#") {
    let fields = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    guard fields.count >= 2 else {
        stop("a line needs typed<TAB>expected: \(row)")
    }
    let (typed, expected) = (fields[0], fields[1])
    let actual = notation(typed)
    lines += 1
    var unmatched = pieces(actual)
    for piece in pieces(expected) {
        expectedByKind[kind(piece), default: 0] += 1
        if let index = unmatched.firstIndex(of: piece) {
            hitByKind[kind(piece), default: 0] += 1
            unmatched.remove(at: index)
        }
    }
    if actual == expected {
        exact += 1
        print("OK  \(typed)")
    } else {
        print("NG  \(typed)\n    expected \(expected)\n    actual   \(actual)")
    }
    print("    \(await converted(typed))")
}
print("\nlayout \(layoutName): \(exact)/\(lines) lines exact")
for kind in expectedByKind.keys.sorted() {
    print("  \(kind): \(hitByKind[kind, default: 0])/\(expectedByKind[kind, default: 0]) pieces")
}
