{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
	};

	outputs = { self, nixpkgs }: let
		lib = nixpkgs.lib // self.lib;
	in with lib; {
		lib = import ./lib {inherit (nixpkgs) lib;};
		packages = genAttrs [
			"x86_64-linux"
			"aarch64-linux"
			"riscv64-linux"
		] (system: let
			pkgs = import nixpkgs {
				inherit system;
				overlays = [
					(self: super: {lib = super.lib // lib;})
				];
			};
		in (import ./pkgs {inherit pkgs lib system;}));

		devShells = genAttrs [ "x86_64-linux" ] (system: let
			pkgs = import nixpkgs {inherit system;};
		in {
			fpga = pkgs.mkShell {
				packages = with self.packages.${system}; [
					oss-cad-suite-bin vhd2vl
				];
			};
			ctf = pkgs.mkShell {
				shellHook = indent ''
					export PS1='>'$PS1
					export _JAVA_AWT_WM_NONREPARENTING=1
				'';
				packages = with pkgs; with python3Packages; [
					angr
					bintools-unwrapped
					ghidra
					pwntools
					radare2
					ropper
				];
			};
		});
	};
}
