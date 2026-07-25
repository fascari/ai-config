#!/usr/bin/env bash
# Shared helpers for the architecture-gate conformance checks. Sourced by
# conformance.sh; expects ERRORS and WARNS already declared by the caller.
# Not meant to be run directly.

err()  { ERRORS=$((ERRORS+1)); printf 'ERROR  %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/         /'; }
warn() { WARNS=$((WARNS+1));  printf 'WARN   %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/         /'; }
pass() { printf 'PASS   %s\n' "$1"; }

has() { command -v "$1" >/dev/null 2>&1; }
imports() { grep -rqE "$1" --include='*.go' internal cmd pkg 2>/dev/null; }
