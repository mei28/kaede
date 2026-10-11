# Kaede のタスクランナー
# レシピ一覧は `just` または `just --list` で確認。

# 署名に使う自己署名証明書（キーチェーンアクセスで作成したもの）
signing_identity := "Kaede Code Signing"

# azooKey の変換辞書（SwiftPM が取得したパッケージの中にある）
dictionary := ".build/checkouts/AzooKeyKanaKanjiConverter/Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary"

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
    # 英単語の一覧（en10k は頻度順。英語とローマ字の区切りに使う。extra-words はユーザーの語）
    cp Resources/en10k.txt Resources/extra-words.txt dist/Kaede.app/Contents/Resources/
    # 変換辞書（Kaede は Contents/Resources/Dictionary から読む）
    cp -R {{dictionary}} dist/Kaede.app/Contents/Resources/Dictionary
    codesign --force --sign "{{signing_identity}}" --identifier com.mei28.kaede dist/Kaede.app
    @echo "dist/Kaede.app を作成しました（just run で起動）"

# .app を起動する（アクセシビリティの許可は .app に与える）
run: bundle
    open dist/Kaede.app

# 実際に打った行の表（Evaluation/lines.tsv）で、英語と日本語と配列の見分けを数える（layout: ebi、qwerty など）
eval layout="ebi":
    swift run -c release KaedeEval --layout {{layout}}

# 1 行の区切りと変換の結果を出す（表に足す行の下書きに）
eval-show typed layout="ebi":
    swift run -c release KaedeEval --layout {{layout}} --show "{{typed}}"

# 日本語に変換されてしまう英単語や名前を、英単語の一覧に足す（反映は just bundle の後）
add-word word:
    @grep -qxi "{{word}}" Resources/extra-words.txt && echo "{{word}} はもう入っています" || (echo "{{word}}" >> Resources/extra-words.txt && echo "{{word}} を足しました。just bundle で作り直すと反映されます")

# 入力フォームのキーを変える（which: open か insert、combo: ctrl+alt+k のように書く。反映は just restart）
form-key which combo:
    @test "{{which}}" = open -o "{{which}}" = insert || (echo "which は open か insert" && exit 1)
    defaults write com.mei28.kaede {{ if which == "open" { "formOpenKey" } else { "formInsertKey" } }} -string "{{combo}}"
    @echo "just restart で反映されます"

# 日本語を打つ配列を変える（name: none、ebi、eucalyn、oonishi、waddlier。表は dotfiles と同じ。反映は just restart）
layout name:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{name}}" in
        none) rows=("qwertyuiop" "asdfghjkl;" "zxcvbnm,./") ;;
        ebi) rows=("ql,.;fwryp" "aoeiuktnsh" "zxcv/gdmjb") ;;
        eucalyn) rows=("qw,.;mrdyp" "aoeiugtksn" "zxcvfbhjl/") ;;
        oonishi) rows=("qlu,.fwryp" "aoei/ktnsh" "zxcv;gdmjb") ;;
        waddlier) rows=("qle,.fwryp" "aoiu;ktnsh" "zxcvbgdmj/") ;;
        *) echo "name は none、ebi、eucalyn、oonishi、waddlier のどれか"; exit 1 ;;
    esac
    defaults write com.mei28.kaede formLayout -array "${rows[@]}"
    echo "just restart で反映されます"

# 作り直さずに Kaede を起動し直す（許可は外れない）
restart:
    pkill -x Kaede || true
    sleep 1
    open dist/Kaede.app

# 起動中の Kaede を止める（メニューバーの「Kaede を終了」と同じ）
stop:
    pkill -x Kaede || echo "Kaede は起動していません"

# Kaede のログを流し続ける（打った文字は伏せ字になる）
logs:
    log stream --level debug --predicate 'subsystem == "com.mei28.kaede"'

# ビルド成果物を掃除
clean:
    swift package clean
    rm -rf dist
