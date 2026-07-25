#!/usr/bin/env bash
# Frontend layout check (W8) — repo-layout convention only, NOT a React/frontend
# code-quality gate. This repo's architecture-gate covers the Go backend; no
# React rule set exists yet in ai-config. This file only confirms that a
# browser frontend, if one exists, is self-contained under web/ rather than at
# the repo root, so the Go gate's assumptions about cmd/, internal/, pkg/ stay
# valid. Sourced by conformance.sh; expects ROOT already cd'ed into, and
# err()/warn()/pass() already defined. Not meant to be run directly.

# W8 full-stack layout: frontend self-contained under web/, not at repo root
if [ -f package.json ]; then
  warn "W8 package.json at repo root — a browser frontend must be self-contained under web/ (web/app source, web/static generated)"
elif [ -f web/package.json ]; then pass "W8 frontend self-contained under web/"; fi
