// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kaede",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        // テスト可能なロジック層（配列、キーの並び、ローマ字の判定、切り替えの判断）。AppKit に依存しない。
        .target(
            name: "KaedeCore"
        ),
        // イベントタップを持つ常駐プロセス本体。
        .executableTarget(
            name: "Kaede",
            dependencies: ["KaedeCore", "KaedeRemote"]
        ),
        // Jev に問い合わせる部分（送る内容の組み立てと応答の読み取り、キーチェーン）。
        .target(
            name: "KaedeRemote",
            dependencies: ["KaedeCore"]
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
