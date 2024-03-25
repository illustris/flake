{ pkgs, ... }: {
	programs = {
		# this is required for HM to set GPG and SSH agent env vars
		bash.enable = true;
		gpg.enable = true;
	};
	services.gpg-agent = {
		defaultCacheTtl = 60*60*24;
		defaultCacheTtlSsh = 60*60*24;
		enable = true;
		extraConfig = "auto-expand-secmem";
		enableSshSupport = true;
		pinentryPackage = pkgs.pinentry-qt;
	};
}
