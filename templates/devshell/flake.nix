{
	description = "Template for devshells";

	inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

	outputs = { self, nixpkgs, ... }: with self.lib; rec {
		lib = import ./lib { inherit (nixpkgs) lib; };

		devShells = genAttrs [
			"x86_64-linux"
			"aarch64-linux"
			"riscv64-linux"
		] (system: let
			pkgs = import nixpkgs {
				inherit system;
				overlays = [(_: _: {inherit lib;})];
			};
		in {
			default = pkgs.callPackage ./shell.nix {};
		});
	};
}
