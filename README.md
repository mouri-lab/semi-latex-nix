# semi-latex-nix

Nix を利用した再現性の高い LaTeX ビルド環境です。
複数の論文テンプレート（ゼミ資料、卒論、修論、学会報告など）を統一的なコマンドで管理できます。

## 動作環境

以下のいずれかが必要です（上から優先）:

1. **Nix (推奨)** - Flakes が有効な Nix 環境
2. **Docker** - `sakuramourilab/semi-latex-builder` イメージを自動取得
3. **ローカル LaTeX** - `latexmk` がインストールされている環境
   - 非推奨ですが、Nix や Docker が利用できない場合の最終手段として使用できます。
   - その場合、flake.nix に記載されているパッケージ相当の LaTeX 環境を手動で構築する必要があります。

## 使い方

プロジェクトのルートディレクトリで `make` コマンドを使用します。
環境は自動検出されるため、Nix/Docker/ローカルを意識する必要はありません。

**semi-latex-nix ディレクトリの外にあるプロジェクトもビルドできます。** 
相対パスまたは絶対パスで指定してください。

### 1. 基本的なビルド (PDF作成)

ディレクトリを指定してビルドします。

```bash
# semi-latex-nix 内のプロジェクト
make build sample/semi-sample
make build my-seminar-paper

# semi-latex-nix 外のプロジェクト
make build ../my-thesis
make build /path/to/my-project
```

### 2. 自動ビルド (Watchモード)

ファイルを保存するたびに自動で再ビルドします。プレビューしながら執筆するのに便利です。
終了するには `Ctrl+C` を押してください。

```bash
make watch sample/semi-sample
```

### 3. お掃除 (Clean)

生成された中間ファイル（`.aux`, `.log`, `.pdf` など）を削除します。

```bash
make clean sample/semi-sample
```

### 4. 全テスト

全てのサンプルプロジェクトが一括でビルドできるか確認します。
外部プロジェクトのビルドテストも含まれます。

```bash
make test
```

### 5. Docker イメージの更新

Docker 環境を使用している場合、最新のイメージを取得できます。

```bash
make docker-pull
```

## 環境について

### Nix 環境 (推奨)

Nix がインストールされている場合、`nix develop` で自動的にビルド環境に入ります。
完全に再現可能なビルドが保証されます。

```bash
# Nix shell に入る（手動）
nix develop

# または make コマンドで自動的に Nix 環境が使用される
make build sample/semi-sample
```

### Docker 環境

Nix がない場合、Docker が自動的に使用されます。
初回実行時に `sakuramourilab/semi-latex-builder` イメージが自動的にダウンロードされます。

**外部ディレクトリのビルド**: semi-latex-nix 外のプロジェクトをビルドする場合、
Docker は必要なディレクトリを自動的にマウントします（スタイルファイルとプロジェクトディレクトリの両方）。

```bash
# 事前にイメージを取得する場合
make docker-pull

# ビルド（自動的に Docker が使用される）
make build sample/semi-sample
```

## ディレクトリ構成

- `Makefile`: ビルドスクリプトの本体
- `.latexmkrc`: latexmk の共通設定
- `flake.nix`: 依存パッケージの定義 (TeX Live full など)
- `style/`: 共通のスタイルファイル (`.cls`, `.sty`, `.bst`)
- `sample/`: 各種 LaTeX プロジェクトのサンプル

## テスト

`make test` コマンドは、内部サンプルプロジェクトに加えて外部プロジェクトのビルドもテストします。

外部プロジェクトのテストを実行するには、`../external-test-project` に簡単な LaTeX プロジェクトを配置してください：

```bash
# テスト用外部プロジェクトのセットアップ
mkdir -p ../external-test-project
cat > ../external-test-project/test.tex << 'EOF'
\documentclass{article}
\begin{document}
\title{External Project Test}
\maketitle
This is a test document.
\end{document}
EOF

# テスト実行
make test
```

外部プロジェクトが存在しない場合、テストはスキップされます。
