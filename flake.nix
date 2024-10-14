{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		firefox-addons = {
			url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { self, nixpkgs, home-manager, ... }: with nixpkgs.lib; with self.lib; let
		pkgsForSystem = system: import nixpkgs {
			inherit system;
			overlays = with self.overlays; [ lib pkgs ];
		};
	in {
		lib = import ./lib {inherit (nixpkgs) lib;};
		packages = genAttrs [
			"x86_64-linux"
			"aarch64-linux"
			"riscv64-linux"
		] (system: let
			pkgs = pkgsForSystem system;
		in (import ./pkgs {inherit pkgs system;}));

		nixosModules = import ./modules {
			lib = nixpkgs.lib // self.lib;
			inherit self;
		};

		overlays = genAttrs (dirs ./overlays) (name:
			import ./overlays/${name} self
		);

		devShells = genAttrs [ "x86_64-linux" ] (system: let
			pkgs = pkgsForSystem system;
		in {
			fpga = pkgs.mkShell {
				packages = with self.packages.${system}; with pkgs; [
					oss-cad-suite-bin vhd2vl
					yosys
					nextpnrWithGui
					icestorm
					dfu-util
				];
			};
			ctf = pkgs.mkShell {
				shellHook = indent ''
					export PS1='>'$PS1
					export _JAVA_AWT_WM_NONREPARENTING=1
				'';
				packages = with pkgs; with python3Packages; ([
					bintools-unwrapped
					ghidra
					pwntools
					radare2
					ropper
				] ++ optionals (!angr.meta.broken) [ angr ]);
			};
		});

		homeConfigurations = genAttrs (dirs ./homeConfigurations/profiles) (name:
			import ./homeConfigurations/profiles/${name} self
		);

		templates = genAttrs (dirs ./templates) ( name: {
			description = name;
			path = ./templates/${name};
		});

		bundlers = genAttrs [
			"x86_64-linux"
			"aarch64-linux"
			"riscv64-linux"
		] (system: let
			pkgs = pkgsForSystem system;
		in import ./bundlers { inherit pkgs; });
	};
}
