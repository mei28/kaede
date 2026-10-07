/// The 30 letter and punctuation keys a key combo can name, by their QWERTY label.
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
}
