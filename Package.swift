// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kaede",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        // 0.x の間はマイナー更新で破壊的変更がありうるため upToNextMinor で固定する。
        .package(url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter", .upToNextMinor(from: "0.11.2")),
    ],
    targets: [
        // テスト可能なロジック層（配列、ラン、ローマ字判定、Enter の判断）。AppKit に依存しない。
        .target(
            name: "KaedeCore"
        ),
        // AzooKeyKanaKanjiConverter を包むかな漢字変換の実装。
        .target(
            name: "KaedeConverter",
            dependencies: [
                "KaedeCore",
                .product(name: "KanaKanjiConverterModule", package: "AzooKeyKanaKanjiConverter"),
            ]
        ),
        // イベントタップを持つ常駐プロセス本体。
        .executableTarget(
            name: "Kaede",
            dependencies: ["KaedeCore", "KaedeConverter"]
        ),
        // KaedeCore のユニットテスト（swift test で実行）。
        .testTarget(
            name: "KaedeCoreTests",
            dependencies: ["KaedeCore"]
        ),
        // 実辞書を使う KaedeConverter の結合テスト。
        .testTarget(
            name: "KaedeConverterTests",
            dependencies: ["KaedeConverter"]
        ),
    ]
)
