-- Apple Music Metadata Fix
--
-- Apple Music で購入した m4a のうち、ファイルに title/artist/album タグや
-- アートワークが書き込まれていないものを検出し、Music.app 経由でクラウドDBの
-- メタデータをファイルへ書き戻す。"Get Info → OK" を手動で実行しているのと
-- 同じ動作をスクリプトで一括処理する。
--
-- 仕組み:
--   1. ffprobe で title タグが空、またはアートワーク（attached_pic）が無い
--      m4a を Music ライブラリ配下から列挙
--   2. 各ファイルに対応する Music.app のトラックを特定
--   3. タグ欠損: name/artist/album を一時的に別の値にしてから元に戻すことで
--      Music.app に確実に「変更」として認識させ、ファイルへ書き戻させる
--   4. アートワーク欠損: Music.app が保持しているアートワークのデータを
--      読み出して同じトラックに再代入し、ファイルへ埋め込ませる
--      （name/artist/album の書き戻しではアートワークは埋め込まれないため、
--        こちらは独立した処理が必要）
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

-- スキャン結果のフラグ（T=タグ欠損 / A=アートワーク欠損）を表示用の文字列にする
on flagLabel(flagStr)
	if flagStr contains "T" and flagStr contains "A" then return "タグ+アートワーク"
	if flagStr contains "T" then return "タグ"
	return "アートワーク"
end flagLabel

on run
	set ffprobePath to findFfprobe()
	if ffprobePath is "" then
		display dialog "ffprobe が見つかりません。" & linefeed & linefeed & "Homebrew でインストールしてください:" & linefeed & "  brew install ffmpeg" buttons {"OK"} default button "OK" with title "Apple Music Metadata Fix" with icon stop
		return
	end if

	set musicDir to (POSIX path of (path to music folder)) & musicSubPath

	-- ffprobe で title タグが空、またはアートワークが無い m4a を列挙。
	-- 1ファイル1回の ffprobe 呼び出しで両方を判定し、"フラグ<TAB>パス" を出力する。
	-- アートワークは m4a の covr atom が video ストリーム（attached_pic）として
	-- 現れるので、codec_type=video の有無で判定できる。
	set findCmd to "find " & quoted form of musicDir & ¬
		" -name '*.m4a' -type f -print0 | while IFS= read -r -d '' f; do " & ¬
		"info=$(" & quoted form of ffprobePath & ¬
		" -v error -show_entries 'format_tags=title:stream=codec_type' -of default=nw=1 \"$f\" 2>/dev/null); " & ¬
		"title=$(printf '%s\\n' \"$info\" | grep '^TAG:title=' | head -1 | cut -d= -f2-); " & ¬
		"art=$(printf '%s\\n' \"$info\" | grep -c '^codec_type=video'); " & ¬
		"flags=''; " & ¬
		"[ -z \"$title\" ] && flags='T'; " & ¬
		"[ \"$art\" = '0' ] && flags=\"${flags}A\"; " & ¬
		"if [ -n \"$flags\" ]; then printf '%s\\t%s\\n' \"$flags\" \"$f\"; fi; " & ¬
		"done"

	with timeout of 3600 seconds
		try
			set scanResult to do shell script findCmd
		on error errMsg
			display dialog "スキャン中にエラーが発生しました:" & linefeed & linefeed & errMsg buttons {"OK"} default button "OK" with title "Apple Music Metadata Fix" with icon stop
			return
		end try
	end timeout

	if scanResult is "" then
		display dialog "メタデータ・アートワークの欠損ファイルは見つかりませんでした。" buttons {"OK"} default button "OK" with title "Apple Music Metadata Fix"
		return
	end if

	-- "フラグ<TAB>パス" をパース（空行は除外）
	set missingPaths to {}
	set missingFlags to {}
	repeat with ln in (paragraphs of scanResult)
		set lnStr to ln as string
		if lnStr is not "" then
			set AppleScript's text item delimiters to tab
			set parts to text items of lnStr
			set AppleScript's text item delimiters to ""
			if (count of parts) ≥ 2 then
				set end of missingFlags to item 1 of parts
				set end of missingPaths to item 2 of parts
			end if
		end if
	end repeat
	set missingCount to count of missingPaths

	if missingCount is 0 then
		display dialog "メタデータ・アートワークの欠損ファイルは見つかりませんでした。" buttons {"OK"} default button "OK" with title "Apple Music Metadata Fix"
		return
	end if

	-- プレビューメッセージを構築
	set previewLines to {}
	repeat with i from 1 to missingCount
		if i > 8 then exit repeat
		set fullPath to item i of missingPaths
		-- musicDir を取り除いて短くする
		if fullPath starts with musicDir then
			set shortPath to text ((length of musicDir) + 1) thru -1 of fullPath
		else
			set shortPath to fullPath
		end if
		set end of previewLines to "  • [" & flagLabel(item i of missingFlags) & "] " & shortPath
	end repeat
	set AppleScript's text item delimiters to linefeed
	set previewText to previewLines as text
	set AppleScript's text item delimiters to ""

	set confirmMsg to (missingCount as string) & " 件の欠損ファイルを検出しました。" & linefeed & linefeed & previewText
	if missingCount > 8 then
		set confirmMsg to confirmMsg & linefeed & "  ... 他 " & ((missingCount - 8) as string) & " 件"
	end if
	set confirmMsg to confirmMsg & linefeed & linefeed & "Music.app でタグ／アートワークを書き戻しますか？"

	set userChoice to button returned of (display dialog confirmMsg buttons {"キャンセル", "実行"} default button "実行" with title "Apple Music Metadata Fix")
	if userChoice is "キャンセル" then return

	set tagFixedCount to 0
	set artFixedCount to 0
	set artUnavailableCount to 0
	set notFoundCount to 0
	set errorCount to 0

	tell application "Music"
		repeat with i from 1 to missingCount
			set pStr to item i of missingPaths
			set flagStr to item i of missingFlags
			try
				set targetAlias to (POSIX file pStr) as alias
				set matchedTracks to (every file track of library playlist 1 whose location is targetAlias)
				if (count of matchedTracks) is 0 then
					set notFoundCount to notFoundCount + 1
				else
					set t to item 1 of matchedTracks

					if flagStr contains "T" then
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

						set tagFixedCount to tagFixedCount + 1
					end if

					if flagStr contains "A" then
						-- Music.app が持っているアートワークを読み出して再代入すると
						-- ファイルの covr atom へ書き込まれる
						if (count of artworks of t) > 0 then
							try
								set artData to data of artwork 1 of t
								set data of artwork 1 of t to artData
								set artFixedCount to artFixedCount + 1
							on error
								-- クラウド側にもアートワークが無い／取得できない
								set artUnavailableCount to artUnavailableCount + 1
							end try
						else
							set artUnavailableCount to artUnavailableCount + 1
						end if
					end if
				end if
			on error errMsg
				set errorCount to errorCount + 1
				log "Error on " & pStr & ": " & errMsg
			end try
		end repeat
	end tell

	set resultMsg to "完了" & linefeed & linefeed & ¬
		"タグ修復: " & (tagFixedCount as string) & " 件" & linefeed & ¬
		"アートワーク修復: " & (artFixedCount as string) & " 件" & linefeed & ¬
		"アートワーク取得不可: " & (artUnavailableCount as string) & " 件" & linefeed & ¬
		"トラック未発見: " & (notFoundCount as string) & " 件" & linefeed & ¬
		"エラー: " & (errorCount as string) & " 件"
	display dialog resultMsg buttons {"OK"} default button "OK" with title "Apple Music Metadata Fix"
end run
