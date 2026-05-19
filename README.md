# Apple Music Metadata Fix

Apple Music で購入した楽曲ファイル（`.m4a`）に **曲名・アーティスト・アルバム名のタグが書き込まれていない**問題を、まとめて修復する macOS 用 AppleScript です。

*A macOS AppleScript tool that fixes missing `title`/`artist`/`album` tags in `.m4a` files purchased from Apple Music.*

---

## 日本語

### 何が起きているのか

Apple Music / iTunes Store で楽曲を購入すると、ごく稀に（あるいは環境によっては毎回）、ダウンロードされた `.m4a` ファイルに `title`、`artist`、`album` といったメインのタグが書き込まれないことがあります。

Apple Music アプリ上では正しく表示されます — クラウド側のデータベースに情報があるからです。しかしファイル自体にはタグが無いため、以下のような場面で問題が起きます：

- 他のメディアプレイヤー（VLC、Finder のプレビュー等）で曲名が表示されない
- DJ ソフト（rekordbox、Serato 等）で正しい情報が取り込めない
- ファイルを別の Mac やデバイスに移したときにメタデータが失われる

手動の回避策は「Apple Music アプリで曲を右クリック → 情報を見る → OK」を1曲ずつ実行することですが、購入のたびに発生すると大変です。このスクリプトはそれを自動化します。

### 仕組み

1. `ffprobe` で Apple Music ライブラリ配下の `.m4a` をスキャンし、`title` タグが空のファイルを列挙
2. Music.app に対し、該当トラックの name/artist/album を「ダミー値 → 元の値」と二段階で設定
3. Music.app は「値が変更された」と認識し、クラウド DB の情報をファイルへ書き戻す

直接ファイルを書き換える方式ではなく **Music.app に書き込ませる**方式なので、Apple の公式ツールが行う処理と完全に同じ結果になります。

### 前提条件

- macOS（Apple Music アプリが入っているもの）
- [Homebrew](https://brew.sh/) と `ffmpeg`（`ffprobe` が必要）
  ```bash
  brew install ffmpeg
  ```

### インストール

```bash
git clone https://github.com/sacrifice-nico/apple-music-metadata-fix.git
cd apple-music-metadata-fix
chmod +x fix-metadata.command
```

### 使い方

1. Finder で `fix-metadata.command` をダブルクリック
2. 初回実行時、macOS から「osascript が Music を制御することを許可しますか？」と聞かれるので **OK** を選択
3. メタデータ欠損ファイルの一覧が表示されるので **「実行」**
4. 完了ダイアログが出れば終了

### リスクと既知の制限

- **ダミー値経由の書き込み**：name/artist/album を一瞬「元の値 + 空白」に変更してから元に戻す方式のため、スクリプトがその間に強制終了した場合、トラック名末尾に空白が残る可能性があります。再実行で直りますが、重要な編集中は避けてください。
- **DJ ソフトとの相互作用**：rekordbox や Serato などがファイルに独自タグを書き込んでいる場合、Music.app による書き戻しでそれらが失われる可能性があります。心配な場合は事前にバックアップを取るか、DJ ソフトを終了させてから実行してください。修復後は DJ ソフト側で「タグを再読み込み」する必要があります。
- **iCloud Music Library の状態に依存**：Music.app のクラウド DB に正しい情報が無い場合は修復できません。

### ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

### 商標について

本プロジェクトは Apple Inc. と提携・後援関係にありません。Apple Music は Apple Inc. の商標です。

---

## English

### The Problem

When you purchase music from Apple Music / iTunes Store, the downloaded `.m4a` files occasionally (or, for some users, consistently) lack the `title`, `artist`, and `album` tags in their metadata.

The Music app displays everything correctly because the information lives in Apple's cloud database — but the file itself has no tags. This causes problems when:

- Playing in other media players (VLC, Finder Preview, etc.) — no track title shown
- Importing into DJ software (rekordbox, Serato) — wrong/missing info
- Moving files to other devices — metadata is lost

The manual workaround is to right-click each track in Music.app → Get Info → OK, but doing this for every purchase is tedious. This script automates it.

### How It Works

1. Uses `ffprobe` to scan all `.m4a` files under the Apple Music library and identify those with empty `title` tags
2. Tells Music.app to set name/artist/album to a temporary value, then back to the original
3. Music.app interprets this as a change and writes the cloud DB metadata to the file

This approach uses Music.app's own write mechanism rather than touching the file directly, so the result is identical to what Apple's official UI produces.

### Requirements

- macOS with the Music app
- [Homebrew](https://brew.sh/) and `ffmpeg` (provides `ffprobe`)
  ```bash
  brew install ffmpeg
  ```

### Installation

```bash
git clone https://github.com/sacrifice-nico/apple-music-metadata-fix.git
cd apple-music-metadata-fix
chmod +x fix-metadata.command
```

### Usage

1. Double-click `fix-metadata.command` in Finder
2. On first run, macOS will ask whether `osascript` may control the Music app — click **OK**
3. A list of files with missing metadata is shown — click **実行** (Run)
4. A completion dialog appears

> **Note:** Dialogs are currently in Japanese. Pull requests to make them locale-aware are welcome.

### Risks & Known Limitations

- **Dummy-value write trick**: The script briefly sets name/artist/album to `"<original> "` (with trailing space) and then back. If the script is killed during this window, a trailing space may remain on the track name. Re-running the script will fix it. Avoid running during critical editing.
- **DJ software interaction**: If DJ software like rekordbox or Serato has written its own tags into the file, Music.app's write-back may overwrite them. Back up if concerned, and quit DJ apps before running. After fixing, reload tags inside your DJ software.
- **Depends on iCloud Music Library**: If Music.app's cloud database doesn't have the correct info, nothing can be restored.

### License

MIT License - see [LICENSE](LICENSE)

### Trademark Notice

This project is not affiliated with or endorsed by Apple Inc. Apple Music is a trademark of Apple Inc.
