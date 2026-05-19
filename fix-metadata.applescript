-- Apple Music Metadata Fix
--
-- Apple Music で購入した m4a のうち、ファイルに title/artist/album タグが
-- 書き込まれていないものを検出し、Music.app 経由でクラウドDBのメタデータを
-- ファイルへ書き戻す。"Get Info → OK" を手動で実行しているのと同じ動作を
-- スクリプトで一括処理する。
--
-- 仕組み:
--   1. ffprobe で title タグが空の m4a を Music ライブラリ配下から列挙
--   2. 各ファイルに対応する Music.app のトラックを特定
--   3. name/artist/album を一時的に別の値にしてから元に戻すことで
--      Music.app に確実に「変更」として認識させ、ファイルへ書き戻させる
--
-- Repository: https://github.com/sacrifice-nico/apple-music-metadata-fix

property musicSubPath : "Music/Media.localized/Music/"

-- ffprobe のインストール先候補（Homebrew Apple Silicon / Intel / MacPorts）
property ffprobeCandidates : {"/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe", "/opt/local/bin/ffprobe"}

on findFfprobe()
	repeat with p in ffprobeCandidates
		try
			do shell script "test -x " & quoted form of (p as string)
			return p as string
		end try
	end repeat
	-- ログインシェル経由で PATH 解決を試みる
	try
		set foundPath to do shell script "/bin/bash -lc 'command -v ffprobe' 2>/dev/null"
		if foundPath is not "" then return foundPath
	end try
	return ""
end findFfprobe

on run
	set ffprobePath to findFfprobe()
	if ffprobePath is "" then
		display dialog "ffprobe が見つかりません。" & linefeed & linefeed & "Homebrew でインストールしてください:" & linefeed & "  brew install ffmpeg" buttons {"OK"} default button "OK" with title "Apple Music Metadata Fix" with icon stop
		return
	end if

	set musicDir to (POSIX path of (path to music folder)) & musicSubPath

	-- ffprobe で title タグが空の m4a を列挙
	set findCmd to "find " & quoted form of musicDir & ¬
		" -name '*.m4a' -type f -print0 | while IFS= read -r -d '' f; do " & ¬
		"title=$(" & quoted form of ffprobePath & ¬
		" -v error -show_entries format_tags=title -of default=nw=1:nk=1 \"$f\" 2>/dev/null); " & ¬
		"if [ -z \"$title\" ]; then echo \"$f\"; fi; done"

	with timeout of 3600 seconds
		try
			set scanResult to do shell script findCmd
		on error errMsg
			display dialog "スキャン中にエラーが発生しました:" & linefeed & linefeed & errMsg buttons {"OK"} default button "OK" with title "Apple Music Metadata Fix" with icon stop
			return
		end try
	end timeout

	if scanResult is "" then
		display dialog "メタデータ欠損のファイルは見つかりませんでした。" buttons {"OK"} default button "OK" with title "Apple Music Metadata Fix"
		return
	end if

	set missingPaths to paragraphs of scanResult
	-- 空行を除外
	set cleanedPaths to {}
	repeat with p in missingPaths
		set pStr to p as string
		if pStr is not "" then set end of cleanedPaths to pStr
	end repeat
	set missingPaths to cleanedPaths
	set missingCount to count of missingPaths

	-- プレビューメッセージを構築
	set previewLines to {}
	repeat with i from 1 to (count of missingPaths)
		if i > 8 then exit repeat
		set fullPath to item i of missingPaths
		-- musicDir を取り除いて短くする
		if fullPath starts with musicDir then
			set shortPath to text ((length of musicDir) + 1) thru -1 of fullPath
		else
			set shortPath to fullPath
		end if
		set end of previewLines to "  • " & shortPath
	end repeat
	set AppleScript's text item delimiters to linefeed
	set previewText to previewLines as text
	set AppleScript's text item delimiters to ""

	set confirmMsg to (missingCount as string) & " 件のメタデータ欠損ファイルを検出しました。" & linefeed & linefeed & previewText
	if missingCount > 8 then
		set confirmMsg to confirmMsg & linefeed & "  ... 他 " & ((missingCount - 8) as string) & " 件"
	end if
	set confirmMsg to confirmMsg & linefeed & linefeed & "Music.app でタグを書き戻しますか？"

	set userChoice to button returned of (display dialog confirmMsg buttons {"キャンセル", "実行"} default button "実行" with title "Apple Music Metadata Fix")
	if userChoice is "キャンセル" then return

	set fixedCount to 0
	set notFoundCount to 0
	set errorCount to 0

	tell application "Music"
		repeat with p in missingPaths
			set pStr to p as string
			try
				set targetAlias to (POSIX file pStr) as alias
				set matchedTracks to (every file track of library playlist 1 whose location is targetAlias)
				if (count of matchedTracks) is 0 then
					set notFoundCount to notFoundCount + 1
				else
					set t to item 1 of matchedTracks
					set tName to name of t
					set tArtist to artist of t
					set tAlbum to album of t

					-- 確実に「変更」として認識させるためダミー値を経由
					set name of t to (tName & " ")
					set name of t to tName
					set artist of t to (tArtist & " ")
					set artist of t to tArtist
					set album of t to (tAlbum & " ")
					set album of t to tAlbum

					set fixedCount to fixedCount + 1
				end if
			on error errMsg
				set errorCount to errorCount + 1
				log "Error on " & pStr & ": " & errMsg
			end try
		end repeat
	end tell

	set resultMsg to "完了" & linefeed & linefeed & ¬
		"修復: " & (fixedCount as string) & " 件" & linefeed & ¬
		"トラック未発見: " & (notFoundCount as string) & " 件" & linefeed & ¬
		"エラー: " & (errorCount as string) & " 件"
	display dialog resultMsg buttons {"OK"} default button "OK" with title "Apple Music Metadata Fix"
end run
