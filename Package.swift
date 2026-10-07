// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kaede",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        // かな漢字変換。0.x の間はマイナー更新で破壊的変更がありうるため upToNextMinor で固定する。
        // Zenzai（traits）は使わないので、C++ との連携も要らない。
        .package(url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter", .upToNextMinor(from: "0.11.2")),
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
        // azooKey の変換エンジンでローマ字を変換する部分。
        .target(
            name: "KaedeConverter",
            dependencies: [
                "KaedeCore",
                .product(name: "KanaKanjiConverterModule", package: "AzooKeyKanaKanjiConverter"),
            ]
        ),
        // KaedeCore のユニットテスト（swift test で実行）。
        .testTarget(
            name: "KaedeCoreTests",
            dependencies: ["KaedeCore"]
        ),
        // KaedeConverter のテスト（取得済みのパッケージの辞書で、実際に変換する）。
        .testTarget(
            name: "KaedeConverterTests",
            dependencies: ["KaedeConverter"]
        ),
    ]
)
