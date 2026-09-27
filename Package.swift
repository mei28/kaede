// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kaede",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        // テスト可能なロジック層（配列、ラン、ローマ字判定、Enter の判断）。AppKit に依存しない。
        .target(
            name: "KaedeCore"
        ),
        // イベントタップを持つ常駐プロセス本体。
        .executableTarget(
            name: "Kaede",
            dependencies: ["KaedeCore", "KaedeRemote"]
        ),
        // Claude と Jev に問い合わせる部分（送る内容の組み立てと応答の読み取り）。
        .target(
            name: "KaedeRemote",
            dependencies: ["KaedeCore"]
        ),
        // 語ごとの正解の表で、切り替えの良し悪しを Jev の答えで数える開発用のコマンド（just eval）。
        .executableTarget(
            name: "KaedeEval",
            dependencies: ["KaedeCore", "KaedeRemote"]
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
    ]
)
