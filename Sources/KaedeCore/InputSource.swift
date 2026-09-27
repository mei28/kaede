/// The selected input source, as far as Kaede cares. Only the app knows the source IDs.
public enum InputSource: Sendable {
    /// The Roman source Kaede watches.
    case roman
    case azooKey
    case other
}
