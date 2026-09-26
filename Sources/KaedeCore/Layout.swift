/// The 30 physical keys whose character depends on the layout, named by their QWERTY label.
public enum KeyPosition: CaseIterable, Sendable {
    case q, w, e, r, t, y, u, i, o, p
    case a, s, d, f, g, h, j, k, l, semicolon
    case z, x, c, v, b, n, m, comma, period, slash

    /// The position of a macOS virtual key code, or nil for keys outside the 30.
    public init?(keyCode: UInt16) {
        guard let position = Self.allCases.first(where: { $0.keyCode == keyCode }) else {
            return nil
        }
        self = position
    }

    /// macOS virtual key code (same values as dotfiles `.hammerspoon/keyLayout.lua`).
    public var keyCode: UInt16 {
        switch self {
        case .q: 0x0c
        case .w: 0x0d
        case .e: 0x0e
        case .r: 0x0f
        case .t: 0x11
        case .y: 0x10
        case .u: 0x20
        case .i: 0x22
        case .o: 0x1f
        case .p: 0x23
        case .a: 0x00
        case .s: 0x01
        case .d: 0x02
        case .f: 0x03
        case .g: 0x05
        case .h: 0x04
        case .j: 0x26
        case .k: 0x28
        case .l: 0x25
        case .semicolon: 0x29
        case .z: 0x06
        case .x: 0x07
        case .c: 0x08
        case .v: 0x09
        case .b: 0x0b
        case .n: 0x2d
        case .m: 0x2e
        case .comma: 0x2b
        case .period: 0x2f
        case .slash: 0x2c
        }
    }

    /// The character printed on the key in QWERTY.
    var qwertyCharacter: Character {
        switch self {
        case .q: "q"
        case .w: "w"
        case .e: "e"
        case .r: "r"
        case .t: "t"
        case .y: "y"
        case .u: "u"
        case .i: "i"
        case .o: "o"
        case .p: "p"
        case .a: "a"
        case .s: "s"
        case .d: "d"
        case .f: "f"
        case .g: "g"
        case .h: "h"
        case .j: "j"
        case .k: "k"
        case .l: "l"
        case .semicolon: ";"
        case .z: "z"
        case .x: "x"
        case .c: "c"
        case .v: "v"
        case .b: "b"
        case .n: "n"
        case .m: "m"
        case .comma: ","
        case .period: "."
        case .slash: "/"
        }
    }

    /// The character the key gives with Shift in QWERTY (US ANSI).
    var qwertyShiftedCharacter: Character {
        switch self {
        case .semicolon: ":"
        case .comma: "<"
        case .period: ">"
        case .slash: "?"
        default: Character(qwertyCharacter.uppercased())
        }
    }
}

/// A keyboard layout, expressed as which QWERTY key each physical key produces.
public struct Layout: Sendable {
    private let target: @Sendable (KeyPosition) -> KeyPosition

    public static let qwerty = Layout(target: { $0 })

    /// Ebi keeps the vowels a o e i u on the left home row (dotfiles `.hammerspoon/ebi.lua`).
    public static let ebi = Layout(target: { position in
        switch position {
        case .q: .q
        case .w: .l
        case .e: .comma
        case .r: .period
        case .t: .semicolon
        case .y: .f
        case .u: .w
        case .i: .r
        case .o: .y
        case .p: .p
        case .a: .a
        case .s: .o
        case .d: .e
        case .f: .i
        case .g: .u
        case .h: .k
        case .j: .t
        case .k: .n
        case .l: .s
        case .semicolon: .h
        case .z: .z
        case .x: .x
        case .c: .c
        case .v: .v
        case .b: .slash
        case .n: .g
        case .m: .d
        case .comma: .m
        case .period: .j
        case .slash: .b
        }
    })

    public func character(at position: KeyPosition, shift: Bool) -> Character {
        let key = target(position)
        return shift ? key.qwertyShiftedCharacter : key.qwertyCharacter
    }
}
