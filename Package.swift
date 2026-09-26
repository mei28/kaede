// swift-tools-version: 6.2
import PackageDescription

// With the Zenzai trait, azooKey's modules are built with C++ interop, and every target that
// imports them has to read their C++ headers the same way.
let cxxInterop: [SwiftSetting] = [.interoperabilityMode(.Cxx)]

let package = Package(
    name: "Kaede",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        // 0.x の間はマイナー更新で破壊的変更がありうるため upToNextMinor で固定する。
        .package(url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter", .upToNextMinor(from: "0.11.2"), traits: ["Zenzai"]),
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
            ],
            swiftSettings: cxxInterop
        ),
        // イベントタップを持つ常駐プロセス本体。
        .executableTarget(
            name: "Kaede",
            dependencies: ["KaedeCore", "KaedeConverter"],
            swiftSettings: cxxInterop,
            // just bundle puts llama.framework (linked through the Zenzai trait) in Contents/Frameworks
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        // Claude と Jev に問い合わせる部分（送る内容の組み立てと応答の読み取り）。
        .target(
            name: "KaedeRemote",
            dependencies: ["KaedeCore"]
        ),
        // 変換方式を同じ例文で比べる開発用のコマンド（just eval）。
        .executableTarget(
            name: "KaedeEval",
            dependencies: ["KaedeCore", "KaedeConverter", "KaedeRemote"],
            swiftSettings: cxxInterop
        ),
        // KaedeCore のユニットテスト（swift test で実行）。
        .testTarget(
            name: "KaedeCoreTests",
            dependencies: ["KaedeCore"]
        ),
        // KaedeRemote のユニットテスト（ネットワークは使わない）。
        .testTarget(
            name: "KaedeRemoteTests",
            dependencies: ["KaedeRemote"]
        ),
        // 実辞書を使う KaedeConverter の結合テスト。
        .testTarget(
            name: "KaedeConverterTests",
            dependencies: ["KaedeConverter"],
            swiftSettings: cxxInterop
        ),
    ]
)
