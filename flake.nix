{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
	};

	outputs = { self, nixpkgs }: let legacyPackages = import nixpkgs { system = "x86_64-linux"; }; in {
		packages.x86_64-linux =  import pkgs/all_packages.nix { pkgs = legacyPackages; };

		devShells.x86_64-linux.fpga = legacyPackages.mkShell { packages = with self.packages.x86_64-linux; [
			oss-cad-suite-bin vhd2vl
		];};

		hydraJobs.example = self.packages;
	};
}
