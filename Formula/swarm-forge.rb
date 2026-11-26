class SwarmForge < Formula
    desc "Installer helper for SwarmForge"
    homepage "https://github.com/egll-tech/swarm-forge"
    version "0.1.0"   # ← single source of truth
    url "https://raw.githubusercontent.com/egll-tech/swarm-forge/v#{version}/get-swarm-forge"
    sha256 "26a7c8628084e9381c2d90fcc8c1be6e811ea773e23e0e3e8a1e12780c3a80e3"
  
    def install
      bin.install "get-swarm-forge"
    end
  
    test do
      system "#{bin}/get-swarm-forge", "--help"
    end
  end