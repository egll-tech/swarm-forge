class SwarmForge < Formula
  desc "SwarmForge tools"
  homepage "https://github.com/egll-tech/swarm-forge"
  version "0.1.2"
  url "https://github.com/egll-tech/swarm-forge/archive/refs/tags/v#{version}.tar.gz"
  sha256 "2b25465bd58e6dc37d675de24c41fe06efe967bc12a51d50dded9625900458fa"

  def install
    scripts = Dir["bin/*"]
    scripts = Dir["#{tap.path}/bin/*"] if scripts.empty? && tap
    odie "swarm-forge: bin/ has no scripts to install" if scripts.empty?

    bin.install scripts
  end

  test do
    system "#{bin}/get-swarm-forge", "--help"
  end
end
