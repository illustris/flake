{
	description = "A simple Hello World application in Go";

	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

	outputs = { self, nixpkgs }: {
		packages = nixpkgs.lib.genAttrs [
			"x86_64-linux"
			"aarch64-linux"
			"riscv64-linux"
		] (system: let
			pkgs = nixpkgs.legacyPackages.${system};
		in rec {
			hello = pkgs.callPackage ./. {};
			default = hello;
		});
	};
}
