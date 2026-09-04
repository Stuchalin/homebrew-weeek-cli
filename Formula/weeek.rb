# typed: false
# frozen_string_literal: true

class Weeek < Formula
  desc "Zero-dependency Go CLI for the Weeek API"
  homepage "https://github.com/Stuchalin/weeek-cli"
  version "0.1.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/Stuchalin/weeek-cli/releases/download/v0.1.0/weeek_darwin_amd64"
      sha256 "be41cb950e634b2bf657bf949e267aa86ccb85e1f3a81b069d22513b49527c27"

      define_method(:install) do
        bin.install "weeek_darwin_amd64" => "weeek"
      end
    end
    if Hardware::CPU.arm?
      url "https://github.com/Stuchalin/weeek-cli/releases/download/v0.1.0/weeek_darwin_arm64"
      sha256 "a897db1d8626751001874c11107447442345e066f43d48cb2bd4011d1b43c20f"

      define_method(:install) do
        bin.install "weeek_darwin_arm64" => "weeek"
      end
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/Stuchalin/weeek-cli/releases/download/v0.1.0/weeek_linux_amd64"
      sha256 "216a4b102a83261383a002c08a8947c141cfa9c83f1c60e7943000b50751ee47"

      define_method(:install) do
        bin.install "weeek_linux_amd64" => "weeek"
      end
    end
    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/Stuchalin/weeek-cli/releases/download/v0.1.0/weeek_linux_arm64"
      sha256 "dadd0a05b08b430d1a6eb0240cd8639b664a6fb9856edade50e4e20b4df1b275"

      define_method(:install) do
        bin.install "weeek_linux_arm64" => "weeek"
      end
    end
  end
end
