{ pkgs, ... }: {
	imports = [
		../../modules/bash
		../../modules/emacs
		../../modules/git
		../../modules/gpg-agent
	];
}
