class SwarmForge < Formula
  desc "SwarmForge tools"
  homepage "https://github.com/egll-tech/swarm-forge"
  version "0.1.1"
  url "https://github.com/egll-tech/swarm-forge/archive/refs/tags/v#{version}.tar.gz"
  sha256 "26a7c8628084e9381c2d90fcc8c1be6e811ea773e23e0e3e8a1e12780c3a80e3"

  def install
    bin.install Dir["bin/*"]
  end

  test do
    system "#{bin}/get-swarm-forge", "--help"
  end
end
