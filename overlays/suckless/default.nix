{ ... }:
final: prev: {
	dwm = prev.dwm.overrideAttrs (oldAttrs: {
		src = final.pkgs.fetchFromGitHub {
			owner = "illustris";
			repo = "dwm";
			rev = "3a1972ead4dfc4ee5cdd8251fdbdae4ede756609";
			hash = "sha256-UHt9Otd7CQ6PyNECES4c+avRB005M8LSRCPtwOOKiPg=";
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
