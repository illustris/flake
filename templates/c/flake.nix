{
	inputs.nixpkgs.url = github:nixos/nixpkgs;

	outputs = { nixpkgs, ... }: with nixpkgs.lib; {
		packages = genAttrs [
			"x86_64-linux"
		] (system: let
			pkgs = import nixpkgs { inherit system; };
		in rec {
			hello_world = pkgs.callPackage ./. {};
			default = hello_world;
		});
	};
}
