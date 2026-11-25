class SwarmForge < Formula
    desc "Installer helper for SwarmForge"
    homepage "https://github.com/egll-tech/swarm-forge"
    version "0.0.1"   # ← single source of truth
    url "https://raw.githubusercontent.com/egll-tech/swarm-forge/v#{version}/get-swarm-forge"
    sha256 "REPLACE_ME"
  
    def install
      bin.install "get-swarm-forge"
    end
  
    test do
      system "#{bin}/get-swarm-forge", "--help"
    end
  end