import AppKit
import SwiftUI

/// What the form shows besides the text: the converted text, the keys, and whether it is empty.
@MainActor
final class FormModel: ObservableObject {
    @Published var isEmpty = true
    @Published var preview = ""
    /// False while the text has changed since the preview was converted.
    @Published var previewIsCurrent = true
    /// Choosing conversions: the units of the preview, the selected one and its candidates, with
    /// ranges in UTF-16 offsets of the preview.
    @Published var isChoosing = false
    @Published var unitRanges: [Range<Int>] = []
    @Published var selectedRange: Range<Int>?
    @Published var candidates: [String] = []
    @Published var candidateIndex: Int?
    @Published var fontSize: CGFloat
    @Published var insertSymbols: String
    @Published var openSymbols: String
    var close: () -> Void = {}
    /// Opens the settings; nil until there are settings to open.
    var openSettings: (() -> Void)?

    init(insertSymbols: String, openSymbols: String, fontSize: CGFloat) {
        self.insertSymbols = insertSymbols
        self.openSymbols = openSymbols
        self.fontSize = fontSize
    }
}

/// The form: the text, the converted text under it, a close button, and a strip with the keys.
struct FormView: View {
    @ObservedObject var model: FormModel
    /// The text view Kaede configured, in its scroll view.
    let editor: NSScrollView

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                EditorView(scrollView: editor)
                if model.isEmpty {
                    Text("ここに書いて、\(model.insertSymbols) で入れる")
                        .font(.system(size: model.fontSize))
                        .foregroundStyle(.tertiary)
                        // The text container's inset and line fragment padding
                        .padding(.leading, 9)
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 14)
            .padding(.leading, 14)
            .padding(.trailing, 34)
            .padding(.bottom, 6)
            .overlay(alignment: .topTrailing) {
                Button(action: model.close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("閉じる（書きかけは残ります）")
                .padding(10)
            }
            Divider().opacity(0.4).padding(.horizontal, 14)
            PreviewView(model: model)
            if model.isChoosing, !model.candidates.isEmpty {
                CandidateList(candidates: model.candidates, index: model.candidateIndex)
            }
            Divider().opacity(0.6)
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.maple)
                Spacer()
                if model.isChoosing {
                    KeyHint(symbols: "←→", label: "移る")
                    KeyHint(symbols: "⇧←→", label: "区切り")
                    KeyHint(symbols: "↑↓", label: "候補")
                    KeyHint(symbols: "↩", label: "決める")
                    KeyHint(symbols: "esc", label: "やめる")
                } else {
                    KeyHint(symbols: "⇥", label: "変換を選ぶ")
                    KeyHint(symbols: model.insertSymbols, label: "入れる")
                    KeyHint(symbols: model.openSymbols, label: "閉じる")
                }
                if let openSettings = model.openSettings {
                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("設定")
                }
            }
            .font(.system(size: 11))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
}

/// The converted text, which the insert key puts into the app. Faint until it catches up with
/// the text.
private struct PreviewView: View {
    @ObservedObject var model: FormModel

    var body: some View {
        ScrollView {
            Group {
                if model.isEmpty {
                    Text("変換した結果がここに出ます")
                        .foregroundStyle(.tertiary)
                } else {
                    Text(marked)
                        .foregroundStyle(model.previewIsCurrent ? .primary : .secondary)
                        .textSelection(.enabled)
                }
            }
            .font(.system(size: model.fontSize))
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // Lines up with the text above: its padding, inset and line fragment padding
            .padding(.leading, 23)
            .padding(.trailing, 34)
            .padding(.vertical, 10)
        }
    }
}

extension PreviewView {
    /// While choosing, the units underlined and the selected one coloured, as an input method
    /// marks its phrases.
    private var marked: AttributedString {
        var text = AttributedString(model.preview)
        guard model.isChoosing else { return text }
        func range(_ offsets: Range<Int>) -> Range<AttributedString.Index>? {
            Range(NSRange(location: offsets.lowerBound, length: offsets.count), in: text)
        }
        for unit in model.unitRanges.compactMap(range) {
            text[unit].underlineStyle = .single
        }
        if let selected = model.selectedRange.flatMap(range) {
            text[selected].backgroundColor = Color.maple.opacity(0.25)
            text[selected].underlineStyle = .thick
        }
        return text
    }
}

/// The selected unit's candidates, numbered, nine at a time, the one showing coloured.
private struct CandidateList: View {
    let candidates: [String]
    let index: Int?

    private static let pageSize = 9

    var body: some View {
        let page = (index ?? 0) / Self.pageSize
        let shown = candidates.indices.dropFirst(page * Self.pageSize).prefix(Self.pageSize)
        HStack(spacing: 6) {
            ForEach(Array(shown), id: \.self) { position in
                HStack(spacing: 3) {
                    Text("\(position - page * Self.pageSize + 1)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(candidates[position])
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(position == index ? Color.maple.opacity(0.25) : Color.clear))
            }
            Spacer(minLength: 0)
            if candidates.count > Self.pageSize {
                Text("\(page + 1)/\((candidates.count + Self.pageSize - 1) / Self.pageSize)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .padding(.horizontal, 17)
        .padding(.bottom, 6)
    }
}

private struct EditorView: NSViewRepresentable {
    let scrollView: NSScrollView

    func makeNSView(context: Context) -> NSScrollView {
        scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}
}

private struct KeyHint: View {
    let symbols: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(symbols)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

extension Color {
    /// The red of a maple leaf (楓).
    static let maple = Color(red: 0.86, green: 0.27, blue: 0.20)
}
