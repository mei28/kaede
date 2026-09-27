/// Reads keys through a layout for azooKey, while Kaede keeps the layout it switched with.
public enum Remap {
    /// The key code to send in place of the key, or nil to let the key through unchanged:
    /// keys outside the 30, shortcuts, the symbol layer, and keys the layout leaves in place.
    /// Hammerspoon's keyLayout.lua makes the same exceptions.
    public static func keyCode(for key: RawKey, in layout: Layout) -> UInt16? {
        guard let position = KeyPosition(keyCode: key.keyCode), !key.hasShortcutModifier,
              !key.isSymbolLayer(at: position)
        else { return nil }
        let target = layout.key(at: position)
        return target == position ? nil : target.keyCode
    }
}
