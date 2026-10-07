# Kaede — タスクランナー
# レシピ一覧は `just` または `just --list` で確認。

# 署名に使う自己署名証明書（キーチェーンアクセスで作成したもの）
signing_identity := "Kaede Code Signing"

# デフォルト: レシピ一覧表示
default:
    @just --list

# ユニットテスト実行（TDD のメインループ）
test:
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
    # 英単語のリスト（/usr/share/dict/words に足りない活用形や固有の語を補う。英語の途中の文字を守る辞書に使う）
    cp Resources/en10k.txt Resources/extra-words.txt dist/Kaede.app/Contents/Resources/
    codesign --force --sign "{{signing_identity}}" --identifier com.mei28.kaede dist/Kaede.app
    @echo "dist/Kaede.app を作成しました（just run で起動）"

# .app を起動する（アクセシビリティと入力監視の許可は .app に与える）
run: bundle
    open dist/Kaede.app

# 誤って日本語に切り替わった英単語や名前を、英語として守る語の一覧に足す（反映は just bundle の後）
add-word word:
    @grep -qxi "{{word}}" Resources/extra-words.txt && echo "{{word}} はもう入っています" || (echo "{{word}}" >> Resources/extra-words.txt && echo "{{word}} を足しました。just bundle で作り直すと反映されます")

# 入力フォームのキーを変える（which: open か insert、combo: ctrl+alt+k のように書く。反映は just restart）
form-key which combo:
    @test "{{which}}" = open -o "{{which}}" = insert || (echo "which は open か insert" && exit 1)
    defaults write com.mei28.kaede {{ if which == "open" { "formOpenKey" } else { "formInsertKey" } }} -string "{{combo}}"
    @echo "just restart で反映されます"

# 作り直さずに Kaede を起動し直す（許可は外れない）
restart:
    pkill -x Kaede || true
    sleep 1
    open dist/Kaede.app

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
