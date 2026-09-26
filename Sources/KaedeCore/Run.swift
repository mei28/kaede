/// One recorded key press.
public enum RunElement: Equatable, Sendable {
    /// A layout-dependent key, kept as its physical position so any layout can read it later.
    case stroke(KeyPosition, shift: Bool)
    /// A key whose character no layout changes (space, digits, other symbols).
    case literal(Character)
}

/// The keys typed since the last reset, in order.
public struct Run: Sendable {
    public private(set) var elements: [RunElement] = []

    public init() {}

    /// Builds the run that leaves `qwertyText` on screen: layout keys become strokes (uppercase
    /// letters with Shift), anything else a literal. Used to replay typed text outside the tap.
    public init(typing qwertyText: String) {
        for character in qwertyText {
            let lowered = Character(character.lowercased())
            if let position = KeyPosition.allCases.first(where: { $0.qwertyCharacter == lowered }) {
                append(.stroke(position, shift: character != lowered))
            } else {
                append(.literal(character))
            }
        }
    }

    public mutating func append(_ element: RunElement) {
        elements.append(element)
    }

    /// On an empty run, Backspace deletes text typed before the run, which the run never held.
    public mutating func removeLast() {
        _ = elements.popLast()
    }

    public var strokeCount: Int {
        elements.count { if case .stroke = $0 { true } else { false } }
    }

    /// What the run left on screen: the input source is Roman and nothing remaps the keys.
    public var screenText: String {
        reading(in: .qwerty)
    }

    public func reading(in layout: Layout) -> String {
        String(elements.map { element in
            switch element {
            case let .stroke(position, shift):
                layout.character(at: position, shift: shift)
            case let .literal(character):
                character
            }
        })
    }
}
