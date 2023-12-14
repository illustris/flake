{
	description = "A simple Hello World application in Zig";

	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

	outputs = { self, nixpkgs }: {
		packages = nixpkgs.lib.genAttrs [
			"x86_64-linux"
			"aarch64-linux"
			"riscv64-linux"
		] (system: let
			pkgs = nixpkgs.legacyPackages.${system};
		in rec {
			hello = pkgs.callPackage ({ stdenv, zig, lib, ... }: stdenv.mkDerivation {
				name = "hello";
				src = lib.cleanSourceWith {
					filter = name: type: !(
						lib.hasSuffix ".nix" (toString name)
						|| lib.hasSuffix ".lock" (toString name)
					);
					src = lib.cleanSource self;
				};
				buildInputs = with pkgs; [ zig ];
			}) {};
			default = hello;
		});
	};
}
