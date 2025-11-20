# semi-latex-nix

Nix を利用した再現性の高い LaTeX ビルド環境です。
複数の論文テンプレート（ゼミ資料、卒論、修論、学会報告など）を統一的なコマンドで管理できます。

## 動作環境

- Nix (Flakes enabled)

## 使い方

プロジェクトのルートディレクトリで `make` コマンドを使用します。

### 1. 基本的なビルド (PDF作成)

ディレクトリを指定してビルドします。

```bash
make build sample/semi-sample
make build my-seminar-paper
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

```bash
make test
```

## ディレクトリ構成

- `Makefile`: ビルドスクリプトの本体
- `.latexmkrc`: latexmk の共通設定
- `flake.nix`: 依存パッケージの定義 (TeX Live full など)
- `style/`: 共通のスタイルファイル (`.cls`, `.sty`, `.bst`)
- `sample/`: 各種 LaTeX プロジェクトのサンプル
