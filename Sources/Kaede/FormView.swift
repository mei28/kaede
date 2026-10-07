import AppKit
import SwiftUI

/// What the form shows besides the text: the keys, and whether it is empty.
@MainActor
final class FormModel: ObservableObject {
    @Published var isEmpty = true
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

/// The form: the text, a close button, and a strip with the keys.
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
            Divider().opacity(0.6)
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.maple)
                Spacer()
                KeyHint(symbols: model.insertSymbols, label: "入れる")
                KeyHint(symbols: model.openSymbols, label: "閉じる")
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
