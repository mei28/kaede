# Kaede — タスクランナー
# レシピ一覧は `just` または `just --list` で確認。

# 署名に使う自己署名証明書（キーチェーンアクセスで作成したもの）
signing_identity := "Kaede Code Signing"

# SwiftPM が取得した azooKey の変換辞書（テストもここを読む）
dictionary := ".build/checkouts/AzooKeyKanaKanjiConverter/Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary"

# デフォルト: レシピ一覧表示
default:
    @just --list

# ユニットテスト実行（TDD のメインループ）
test: zenzai-model
    swift test

# ビルド（デバッグ）
build:
    swift build

# 署名済みの .app を作る。同じ証明書で署名し続けるので、再ビルドしても TCC の許可が残る
bundle:
    swift build -c release
    rm -rf dist/Kaede.app
    mkdir -p dist/Kaede.app/Contents/MacOS dist/Kaede.app/Contents/Resources
    cp .build/release/Kaede dist/Kaede.app/Contents/MacOS/Kaede
    cp Packaging/Info.plist dist/Kaede.app/Contents/Info.plist
    # 変換辞書（Kaede は Contents/Resources/Dictionary から読む）
    cp -R {{dictionary}} dist/Kaede.app/Contents/Resources/Dictionary
    # 英単語のリスト（/usr/share/dict/words に足りない活用形や固有の語を補う）
    cp Resources/en10k.txt Resources/extra-words.txt dist/Kaede.app/Contents/Resources/
    # Zenzai の trait で結びつく llama.cpp（署名済みの framework をそのまま入れる）
    mkdir -p dist/Kaede.app/Contents/Frameworks
    cp -R .build/release/llama.framework dist/Kaede.app/Contents/Frameworks/
    codesign --force --sign "{{signing_identity}}" --identifier com.mei28.kaede dist/Kaede.app
    @echo "dist/Kaede.app を作成しました（just run で起動）"

# .app を起動する（アクセシビリティと入力監視の許可は .app に与える）
run: bundle
    open dist/Kaede.app

# Zenzai の重み（zenz-v3.1-small、CC BY-SA 4.0）を Models/ に取得する（既にあれば何もしない）
zenzai-model:
    mkdir -p Models
    test -f Models/zenz-v3.1-small.gguf || curl -fL -o Models/zenz-v3.1-small.gguf https://huggingface.co/Miwa-Keita/zenz-v3.1-small-gguf/resolve/main/ggml-model-Q5_K_M.gguf

# 変換方式を Evaluation/corpus.tsv の例文で比べる（方式: rules, zenzai）
eval method: zenzai-model
    swift run -c release KaedeEval {{method}}

# 起動中の Kaede を止める（メニューも Dock アイコンもないため）
stop:
    pkill -x Kaede || echo "Kaede は起動していません"

# Kaede のログを流し続ける（打った文字は伏せ字になる）
logs:
    log stream --level debug --predicate 'subsystem == "com.mei28.kaede"'

# ビルド成果物を掃除
clean:
    swift package clean
    rm -rf dist
