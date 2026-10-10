# Kaede

[English](README.en.md)

英語とローマ字を続けて英字のまま打つと、日本語と英語が並んだ文章にして元のアプリに入れる macOS のアプリです。
入力モードを切り替えずに書けます。

```
kyouhagoogledekensaku        → 今日は google で検索
pythonnobug                  → python の bug
sikasinoatoallyouneedislove  → しかしのあと all you need is love
thisisapen.                  → this is a pen.
```

作者が自分のために作っているアプリです。
作者の環境（後述の Hammerspoon の設定）を前提にしている部分があります。

## 動き

1. ⌃⌥K で窓を開き、英語とローマ字を混ぜて打ちます。空白は入れても入れなくてもかまいません。
2. 打つと、窓の下半分に変換の結果が出ます。
3. ⌘↩ で、その結果を元のアプリのカーソル位置に入れます。文字はキー入力として送り、クリップボードには触れません。改行は Shift+Enter として送ります。

変換はすべて手元で行い、ネットワークには何も送りません。
英語の部分は、英単語の一覧とローマ字の読みの規則で見つけます。
日本語の部分は、[azooKey](https://github.com/azooKey/AzooKeyKanaKanjiConverter) の変換エンジンで変換します。

結果の整え方:

- 日本語の中の空白は消し、英語の単語の間の空白は残します。空白なしの英語は単語に分けます。
- 日本語と英語の境目には半角の空白を入れます。
- 日本語の中の `, . ? ! -` を「、。？！ー」にします。句読点の組み合わせは設定で選べます。
- 大文字で始めた語は英語にします（`Tokyo`、`We are`）。

## 変換を直す

変換が外れたときは、Tab で変換を選ぶ場面に入ります。

| キー | 動き |
|---|---|
| ← → | 前後の文節や英語の部分に移る |
| Shift+← → | 文節を 1 文字縮める、伸ばす |
| ↓ ↑、Space | 候補を選ぶ |
| 1〜9 | 番号の候補にして次へ進む |
| Enter、Tab | 決めて書く場面に戻る |
| Esc、BackSpace | この場面で選んだものを取り消す |

日本語になった部分を英語に戻すには、Tab の直後に ↑ を押します。
候補の一覧の最後に、打った英字を単語に分けた形（`weare` なら we are）が出ます。

## 必要なもの

- macOS 26
- Xcode（Swift 6.2 以降）と [just](https://github.com/casey/just)
- アクセシビリティの許可（キーを送るため）

窓を開いたときに英字の入力ソースでなければ、Kaede は左 cmd の単押しを送ります。
作者の Hammerspoon の設定（左 cmd の単押しで英字、右 cmd の単押しで azooKey）が前提です。

## ビルド

```sh
just test      # テスト
just bundle    # dist/Kaede.app を作る
just run       # 作って起動する
```

`just bundle` は「Kaede Code Signing」という名前の証明書で署名します。
同じ証明書で署名し続けると、作り直してもアクセシビリティの許可が残ります。
証明書がなければ、`just signing_identity=- bundle` でアドホック署名にできます（作り直すたびに許可を付け直します）。

## 設定

メニューバーの葉のアイコン、または窓の歯車から開きます。
窓を開くキーと入れるキー、文字の大きさ、日本語の句読点、ログイン時の起動を変えられます。

## ライセンス

Kaede のコードは [MIT License](LICENSE) です。

`Resources/en10k.txt` は Kaede のライセンスの対象外です。
[google-10000-english](https://github.com/first20hours/google-10000-english) の `google-10000-english-no-swears.txt` をそのまま使っています。
Google Web Trillion Word Corpus から作られた一覧で、配布元は教育、個人、研究での利用を認め、商用では Linguistic Data Consortium の許諾を勧めています。

ビルドのときに取得する依存:

- [AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)（MIT License）。`.app` に写す辞書（azooKey_dictionary_storage）は Apache License 2.0 です。

## 参考にしたもの

- [Meltype](https://github.com/yksr-melt/Meltype)：英単語だけを英字に残して日本語と混ぜて打つ考え方
- [Nospace](https://nospace.ryotarai.dev/)：窓に打って変換し、元のアプリに入れる形
- [azooKey](https://github.com/azooKey/azooKey-Desktop)：変換を選ぶときのキーの操作

どれもコードは使っていません。
