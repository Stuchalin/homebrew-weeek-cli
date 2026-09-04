#!/usr/bin/env bash
# Regenerates Formula/weeek.rb from the latest weeek-cli GitHub release.
#
# Requires gh (authenticated locally, or GH_TOKEN in CI). Renders the expected
# formula on every run and rewrites Formula/weeek.rb only when the rendered
# content differs, so drifted or manually broken formulas repair themselves on
# the next scheduled run. Before rewriting, release binaries are downloaded and
# their digests are verified against the .sha256 sidecars, so a stale sidecar
# fails here instead of at the user's `brew install`.
set -euo pipefail

SOURCE_REPO="Stuchalin/weeek-cli"
FORMULA="Formula/weeek.rb"
FILES="weeek_darwin_arm64 weeek_darwin_amd64 weeek_linux_arm64 weeek_linux_amd64"

digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

latest_tag=$(gh api "repos/$SOURCE_REPO/releases/latest" --jq .tag_name)
if ! [[ "$latest_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "unexpected latest tag: $latest_tag" >&2
  exit 1
fi
version="${latest_tag#v}"
base="https://github.com/$SOURCE_REPO/releases/download/$latest_tag"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
rendered="$workdir/weeek.rb"

# Appends one per-arch block to the rendered formula and records the sidecar
# checksum in "$workdir/$file.sum" for the binary verification pass.
emit_block() {
  local cond="$1" file="$2" line sum
  line=$(curl -fsSL "$base/$file.sha256")
  sum="${line%% *}"
  if ! [[ "$sum" =~ ^[0-9a-f]{64}$ ]]; then
    echo "bad checksum sidecar for $file: $line" >&2
    exit 1
  fi
  printf '%s\n' "$sum" > "$workdir/$file.sum"
  cat >> "$rendered" <<RUBY
    if $cond
      url "$base/$file"
      sha256 "$sum"

      define_method(:install) do
        bin.install "$file" => "weeek"
      end
    end
RUBY
}

{
  cat <<'RUBY'
# typed: false
# frozen_string_literal: true

class Weeek < Formula
  desc "Zero-dependency Go CLI for the Weeek API"
  homepage "https://github.com/Stuchalin/weeek-cli"
RUBY
  printf '  version "%s"\n' "$version"
  printf '  license "MIT"\n\n  on_macos do\n'
} > "$rendered"
emit_block 'Hardware::CPU.intel?' weeek_darwin_amd64
emit_block 'Hardware::CPU.arm?' weeek_darwin_arm64
printf '  end\n\n  on_linux do\n' >> "$rendered"
emit_block 'Hardware::CPU.intel? && Hardware::CPU.is_64_bit?' weeek_linux_amd64
emit_block 'Hardware::CPU.arm? && Hardware::CPU.is_64_bit?' weeek_linux_arm64
printf '  end\nend\n' >> "$rendered"

if cmp -s "$rendered" "$FORMULA"; then
  echo "formula is up to date ($version)"
  exit 0
fi

echo "formula differs from $latest_tag, verifying release binaries"
for file in $FILES; do
  expected=$(cat "$workdir/$file.sum")
  curl -fsSL -o "$workdir/$file" "$base/$file"
  actual=$(digest "$workdir/$file")
  if [[ "$actual" != "$expected" ]]; then
    echo "checksum mismatch for $file: sidecar $expected, binary $actual" >&2
    exit 1
  fi
done

mv "$rendered" "$FORMULA"
echo "regenerated $FORMULA from $latest_tag"
