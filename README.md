# Apple Music Metadata Fix

Apple Music で購入した楽曲ファイル（`.m4a`）に **曲名・アーティスト・アルバム名のタグやアートワークが書き込まれていない**問題を、まとめて修復する macOS 用 AppleScript です。

*A macOS AppleScript tool that fixes missing `title`/`artist`/`album` tags and missing cover artwork in `.m4a` files purchased from Apple Music.*

---

## 日本語

### 何が起きているのか

Apple Music / iTunes Store で楽曲を購入すると、ごく稀に（あるいは環境によっては毎回）、ダウンロードされた `.m4a` ファイルに `title`、`artist`、`album` といったメインのタグ、および**アートワーク（`covr` atom）**が書き込まれないことがあります。

Apple Music アプリ上では正しく表示されます — クラウド側のデータベースに情報があるからです。しかしファイル自体にはタグもアートワークも無いため、以下のような場面で問題が起きます：

- 他のメディアプレイヤー（VLC、Finder のプレビュー等）で曲名やジャケットが表示されない
- DJ ソフト（rekordbox、Serato 等）で正しい情報が取り込めない
- ファイルを別の Mac やデバイスに移したときにメタデータが失われる

手動の回避策は「Apple Music アプリで曲を右クリック → 情報を見る → OK」を1曲ずつ実行することですが、購入のたびに発生すると大変です。このスクリプトはそれを自動化します。

### 仕組み

1. `ffprobe` で Apple Music ライブラリ配下の `.m4a` をスキャンし、**`title` タグが空**または**アートワークが無い**ファイルを列挙（m4a のアートワークは `attached_pic` の video ストリームとして現れるので、その有無で判定）
2. タグ欠損：Music.app に対し、該当トラックの name/artist/album を「ダミー値 → 元の値」と二段階で設定。Music.app は「値が変更された」と認識し、クラウド DB の情報をファイルへ書き戻す
3. アートワーク欠損：Music.app が保持しているアートワークのデータを読み出し、同じトラックへ再代入することでファイルに埋め込ませる

**注意**：name/artist/album の書き戻しではアートワークは埋め込まれません。両者は独立した処理なので、タグだけ入っていてアートワークが無いファイルも検出・修復できます。

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
3. 欠損ファイルの一覧が表示されるので **「実行」**（各行に `[タグ]` / `[アートワーク]` / `[タグ+アートワーク]` のどれが欠けているか表示されます）
4. 完了ダイアログが出れば終了

### リスクと既知の制限

- **ダミー値経由の書き込み**：name/artist/album を一瞬「元の値 + 空白」に変更してから元に戻す方式のため、スクリプトがその間に強制終了した場合、トラック名末尾に空白が残る可能性があります。再実行で直りますが、重要な編集中は避けてください。
- **DJ ソフトとの相互作用**：rekordbox や Serato などがファイルに独自タグを書き込んでいる場合、Music.app による書き戻しでそれらが失われる可能性があります。心配な場合は事前にバックアップを取るか、DJ ソフトを終了させてから実行してください。修復後は DJ ソフト側で「タグを再読み込み」する必要があります。
- **iCloud Music Library の状態に依存**：Music.app のクラウド DB に正しい情報が無い場合は修復できません。
- **アートワークが取得できない場合**：Music.app 側にアートワークが無い（自分でリッピングしたファイル等）トラックは埋め込めません。完了ダイアログの「アートワーク取得不可」に計上されます。
- **埋め込まれるアートワークの解像度**：Music.app がキャッシュしている画像がそのまま埋め込まれます（購入曲では概ね 1200×1200 JPEG）。

### ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

### 商標について

本プロジェクトは Apple Inc. と提携・後援関係にありません。Apple Music は Apple Inc. の商標です。

---

## English

### The Problem

When you purchase music from Apple Music / iTunes Store, the downloaded `.m4a` files occasionally (or, for some users, consistently) lack the `title`, `artist`, and `album` tags in their metadata — and often the **cover artwork (`covr` atom)** as well.

The Music app displays everything correctly because the information lives in Apple's cloud database — but the file itself has neither tags nor artwork. This causes problems when:

- Playing in other media players (VLC, Finder Preview, etc.) — no track title or cover shown
- Importing into DJ software (rekordbox, Serato) — wrong/missing info
- Moving files to other devices — metadata is lost

The manual workaround is to right-click each track in Music.app → Get Info → OK, but doing this for every purchase is tedious. This script automates it.

### How It Works

1. Uses `ffprobe` to scan all `.m4a` files under the Apple Music library and identify those with an **empty `title` tag** or **no embedded artwork** (in an m4a, artwork shows up as an `attached_pic` video stream, so its presence is what gets checked)
2. Missing tags: tells Music.app to set name/artist/album to a temporary value, then back to the original. Music.app interprets this as a change and writes the cloud DB metadata to the file
3. Missing artwork: reads the artwork data Music.app holds for the track and assigns it back to the same track, which makes Music.app embed it into the file

**Note:** writing back name/artist/album does *not* embed artwork. The two are handled independently, so files that have tags but no cover art are detected and fixed too.

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
3. A list of affected files is shown, each labeled with what is missing — `[タグ]` (tags), `[アートワーク]` (artwork), or `[タグ+アートワーク]` (both) — click **実行** (Run)
4. A completion dialog appears

> **Note:** Dialogs are currently in Japanese. Pull requests to make them locale-aware are welcome.

### Risks & Known Limitations

- **Dummy-value write trick**: The script briefly sets name/artist/album to `"<original> "` (with trailing space) and then back. If the script is killed during this window, a trailing space may remain on the track name. Re-running the script will fix it. Avoid running during critical editing.
- **DJ software interaction**: If DJ software like rekordbox or Serato has written its own tags into the file, Music.app's write-back may overwrite them. Back up if concerned, and quit DJ apps before running. After fixing, reload tags inside your DJ software.
- **Depends on iCloud Music Library**: If Music.app's cloud database doesn't have the correct info, nothing can be restored.
- **Artwork may be unavailable**: Tracks for which Music.app itself holds no artwork (e.g. your own rips) cannot get art embedded. These are counted as「アートワーク取得不可」in the completion dialog.
- **Embedded artwork resolution**: Whatever image Music.app has cached is embedded as-is (typically 1200×1200 JPEG for purchased tracks).

### License

MIT License - see [LICENSE](LICENSE)

### Trademark Notice

This project is not affiliated with or endorsed by Apple Inc. Apple Music is a trademark of Apple Inc.
