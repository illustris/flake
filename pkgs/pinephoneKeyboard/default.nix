{ stdenv, lib, fetchgit, php, ... }:
with lib;
stdenv.mkDerivation rec {
	pname = "pinephone-keyboard";

	version = "1.2";

	src = fetchgit {
		url = "https://megous.com/git/pinephone-keyboard";
		hash = "sha256-iTeFXeDe7jog2QEgKBCoX2dht5W8lzfiVryP2nmWpf0=";
	};

	buildInputs = [ php ];

	installPhase = ''
		mkdir -p $out/bin
		find build -type f -executable | xargs -I{} cp {} $out/bin
	'';
	meta = {
		platforms = [ "aarch64-linux" ];
	};
}
