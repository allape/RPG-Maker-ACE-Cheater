#!/usr/bin/env bash

export GOOS="windows"
export GOARCH="amd64"

go build -trimpath -o RPG-Maker-ACE-Cheater-Patcher.exe
