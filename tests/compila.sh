#!/bin/bash
# Compila tutti gli script e mostra gli errori di sintassi.
G=${GODOT:-/home/claude/godot/Godot_v4.7-stable_linux.x86_64}
cd "$(dirname "$0")/.."
for f in scripts/*.gd; do
  timeout 60 $G --headless --path . --check-only --script "$f" 2>&1 | grep -A1 "SCRIPT ERROR\|Parse Error" | grep -v "^--" 
done
true
