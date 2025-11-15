{ lib, ... }: {
	programs.claude-code = let
		mapFiles = base: lib.pipe "${./.}/${base}" [
			builtins.readDir
			builtins.attrNames
			(map (x: lib.nameValuePair
				(lib.strings.removeSuffix ".md" x)
				(builtins.readFile "${./.}/${base}/${x}")
			))
			lib.listToAttrs
		];
	in ({
		enable = true;
		settings = {
			includeCoAuthoredBy = false;
			hooks.Notification = [{
				hooks = [{
					type = "command";
					command = "~/.claude/notify.sh";
				}];
			}];
		};
	} // (lib.genAttrs [ "agents" "commands" ] mapFiles));
}
