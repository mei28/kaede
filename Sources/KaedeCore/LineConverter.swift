/// Turns a whole typed line (as it shows in QWERTY) into the sentence to put on screen.
/// The evaluation tool compares implementations of this on the same examples.
public protocol LineConverting {
    func convert(_ typed: String) async throws -> String
}

/// What the event tap does today: rule-based segmentation, then kana-kanji conversion.
public struct RulesLineConverter<Converter: KanaKanjiConverting>: LineConverting {
    let planner: EnterPlanner
    let converter: Converter

    public init(planner: EnterPlanner, converter: Converter) {
        self.planner = planner
        self.converter = converter
    }

    public func convert(_ typed: String) throws -> String {
        switch planner.plan(Run(typing: typed)) {
        case .pass:
            typed
        case let .convert(pieces):
            try Replacement(deleteCount: typed.count, pieces: pieces).text(using: converter)
        }
    }
}
