#!/bin/bash
# Finder からダブルクリックで実行できるラッパー
cd "$(dirname "$0")"
osascript fix-metadata.applescript
