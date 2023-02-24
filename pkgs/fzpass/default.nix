{ writeScriptBin, lib, bash, fzf, ... }:
# TODO: fix xdotool click to enter
(writeScriptBin "fzpass" (
	lib.replaceStrings
		[ "/usr/bin/env bash" "fzf" ]
		[ "${bash}/bin/bash" "${fzf}/bin/fzf" ]
		(builtins.readFile ./fzpass)
)).overrideAttrs (old: {
	meta = old.meta // {
		platforms = [
			"x86_64-linux"
			"aarch64-linux"
		];
	};
})
