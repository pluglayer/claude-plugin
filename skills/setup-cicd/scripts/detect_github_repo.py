#!/usr/bin/env python3
"""Detect whether the current repo has git initialized and a GitHub origin."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


def _run_git(cwd: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def _normalize_origin(origin: str) -> str | None:
    value = origin.strip()
    if value.startswith("https://github.com/"):
        value = value[len("https://github.com/") :]
    elif value.startswith("git@github.com:"):
        value = value[len("git@github.com:") :]
    value = value.removesuffix(".git").strip("/")
    return value if re.fullmatch(r"[^/\s]+/[^/\s]+", value) else None


def main() -> int:
    repo_path = Path(sys.argv[1] if len(sys.argv) > 1 else ".").expanduser().resolve()
    result: dict[str, object] = {"repo_path": str(repo_path), "ok": False}
    if not repo_path.exists():
        result["reason"] = "path does not exist"
        print(json.dumps(result, indent=2))
        return 1
    try:
        inside = _run_git(repo_path, "rev-parse", "--is-inside-work-tree")
    except Exception:
        result["reason"] = "not a git repository"
        print(json.dumps(result, indent=2))
        return 1
    if inside != "true":
        result["reason"] = "not a git repository"
        print(json.dumps(result, indent=2))
        return 1
    try:
        origin = _run_git(repo_path, "remote", "get-url", "origin")
    except Exception:
        result["reason"] = "origin remote is not configured"
        print(json.dumps(result, indent=2))
        return 1
    repo_slug = _normalize_origin(origin)
    if not repo_slug:
        result["reason"] = "origin is not a GitHub remote"
        result["origin_url"] = origin
        print(json.dumps(result, indent=2))
        return 1
    result.update({"ok": True, "origin_url": origin, "repo_slug": repo_slug})
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
