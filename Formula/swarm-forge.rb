class SwarmForge < Formula
  desc "SwarmForge tools"
  homepage "https://github.com/egll-tech/swarm-forge"
  version "0.1.1"
  url "https://github.com/egll-tech/swarm-forge/archive/refs/tags/v#{version}.tar.gz"
  sha256 "f4734287649ba5e1fbb79d51095ad9b37d77bdead998c7cb9e8c4772d911041f"

  def install
    bin.install Dir["bin/*"]
  end

  test do
    system "#{bin}/get-swarm-forge", "--help"
  end
end
