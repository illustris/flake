{ ... }:
final: prev: {
	dwm = prev.dwm.overrideAttrs (oldAttrs: {
		src = final.pkgs.fetchFromGitHub {
			owner = "illustris";
			repo = "dwm";
			rev = "7df55abebad6a70236a6d6fc62fd475476fd77f6";
			hash = "sha256-Cfdv+r271etL5nYkd4U2nRE/zCW7PaHkDC11eeGqLy4=";
		};
	});
	st = prev.st.overrideAttrs (oldAttrs: {
		src = final.pkgs.fetchFromGitHub {
			owner = "illustris";
			repo = "st";
			rev = "fa363487355fe0b27d82e7247577802ac66e4b0f";
			hash = "sha256-KLh4yGSq7pf6F+mWZvH6slN+Qa1/LkjWbhFTxQ2vYng=";
		};
	});
}
