{ ... }: {
	programs.gpg.enable = true;
	services.gpg-agent = {
		enable = true;
		defaultCacheTtl = 60*60*24;
		defaultCacheTtlSsh = 60*60*24;
		extraConfig = "auto-expand-secmem";
	};
}
