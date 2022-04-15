{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
	};

	outputs = { self, nixpkgs }: {
		packages.x86_64-linux = let
			legacyPackages = import nixpkgs { system = "x86_64-linux"; };
		in import pkgs/all_packages.nix { pkgs = legacyPackages; };
		#defaultPackage.x86_64-linux = self.packages.x86_64-linux.hello;
	};
}
