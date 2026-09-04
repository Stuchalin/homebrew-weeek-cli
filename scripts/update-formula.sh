#!/usr/bin/env bash
# Regenerates Formula/weeek.rb from the latest weeek-cli GitHub release.
#
# Requires gh (authenticated locally, or GH_TOKEN in CI). Exits 0 without
# changes when the formula already matches the latest release. With --force,
# regenerates the formula even if the version matches; useful to repair
# manual edits to the formula body.
set -euo pipefail

SOURCE_REPO="Stuchalin/weeek-cli"
FORMULA="Formula/weeek.rb"
FORCE=0
if [[ "${1:-}" == "--force" ]]; then
  FORCE=1
fi

latest_tag=$(gh api "repos/$SOURCE_REPO/releases/latest" --jq .tag_name)
if ! [[ "$latest_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "unexpected latest tag: $latest_tag" >&2
  exit 1
fi
version="${latest_tag#v}"

current=$(sed -n 's/^[[:space:]]*version "\([0-9.]*\)"$/\1/p' "$FORMULA")
if [[ -z "$current" ]]; then
  echo "no version found in $FORMULA" >&2
  exit 1
fi

if [[ "$current" == "$version" && "$FORCE" -eq 0 ]]; then
  echo "formula is up to date ($version)"
  exit 0
fi

base="https://github.com/$SOURCE_REPO/releases/download/$latest_tag"
for file in weeek_darwin_arm64 weeek_darwin_amd64 weeek_linux_arm64 weeek_linux_amd64; do
  checksum_line=$(curl -fsSL "$base/$file.sha256")
  checksum="${checksum_line%% *}"
  if ! [[ "$checksum" =~ ^[0-9a-f]{64}$ ]]; then
    echo "bad checksum for $file: $checksum_line" >&2
    exit 1
  fi
  eval "sum_${file#weeek_}=\$checksum"
done

cat > "$FORMULA" <<RUBY
# typed: false
# frozen_string_literal: true

class Weeek < Formula
  desc "Zero-dependency Go CLI for the Weeek API"
  homepage "https://github.com/Stuchalin/weeek-cli"
  version "$version"
  license "MIT"

  on_macos do
    if Hardware::CPU.intel?
      url "$base/weeek_darwin_amd64"
      sha256 "$sum_darwin_amd64"

      define_method(:install) do
        bin.install "weeek_darwin_amd64" => "weeek"
      end
    end
    if Hardware::CPU.arm?
      url "$base/weeek_darwin_arm64"
      sha256 "$sum_darwin_arm64"

      define_method(:install) do
        bin.install "weeek_darwin_arm64" => "weeek"
      end
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "$base/weeek_linux_amd64"
      sha256 "$sum_linux_amd64"

      define_method(:install) do
        bin.install "weeek_linux_amd64" => "weeek"
      end
    end
    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "$base/weeek_linux_arm64"
      sha256 "$sum_linux_arm64"

      define_method(:install) do
        bin.install "weeek_linux_arm64" => "weeek"
      end
    end
  end
end
RUBY

echo "regenerated $FORMULA from $latest_tag (was $current)"
