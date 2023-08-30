{ ... }: {
	programs.gpg.enable = true;
	services.gpg-agent = {
		defaultCacheTtl = 60*60*24;
		defaultCacheTtlSsh = 60*60*24;
		enable = true;
		extraConfig = "auto-expand-secmem";
		enableSshSupport = true;
	};
}
