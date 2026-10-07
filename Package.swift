// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kaede",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        // テスト可能なロジック層（キーの組み合わせ、ローマ字の判定、英単語の辞書、打つ文字の分け方）。AppKit に依存しない。
        .target(
            name: "KaedeCore"
        ),
        // 入力フォームを持つ常駐プロセス本体。
        .executableTarget(
            name: "Kaede",
            dependencies: ["KaedeCore"]
        ),
        // KaedeCore のユニットテスト（swift test で実行）。
        .testTarget(
            name: "KaedeCoreTests",
            dependencies: ["KaedeCore"]
        ),
    ]
)
