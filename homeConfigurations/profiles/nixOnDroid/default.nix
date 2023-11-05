{ inputs, overlays, ... }:

inputs.home-manager.lib.homeManagerConfiguration {
	pkgs = import inputs.nixpkgs {
		system = "x86_64-linux";
		overlays = inputs.nixpkgs.lib.attrValues overlays;
	};
	modules = [
		./home.nix
	];
}
