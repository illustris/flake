{
	description = "Template for packages";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
		illustris = {
			url = "github:illustris/flake";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { self, nixpkgs, illustris, ... }: with self.lib; rec {
		lib = import ./lib { lib = nixpkgs.lib // illustris.lib; };

		packages = genAttrs [
			"x86_64-linux"
			"aarch64-linux"
		] (system: let
			pkgs = import nixpkgs {
				inherit system;
				overlays = [(_: _: {inherit lib;})];
			};
		in (import ./pkgs {inherit pkgs lib system;}));
	};
}
