{ lib, ... }:
with lib;
rec {
	# Tired of nix's annoying two-space indent restriction on multiline strings?
	# This function removes extra indentation from multiline strings.
	# Example:
	# y = {
	# 	x = indent ''
	# 		for x in l:
	# 			print(x)
	# 	'';
	# };
	# y.x => "for x in l:\n\tprint(x)\n"
	indent = txt: let
		lines = splitString "\n" txt;
	in (
		# unexpected chars in last line of multiline string
		assert ((replaceChars ["\t"] [""] (last lines)) == "");
		concatStringsSep "\n" (
			map (line: substring (1 + stringLength (last lines)) (stringLength line) line) lines
		)
	);

	# Useful functions for generating scripts.
	# Beware: because these are doing simple string substitution to generate shell scripts
	# with no input validation, you can very easily shoot yourself in the foot.
	scriptBuilder = {
		pkgs ? null,
		debug ? false,
		env ? {}
	}: rec {
		# Takes a nested list of commands and generates a script
		# Example:
		# mkScript [ "ls" "id" ] => "set -x\nset -e\nls\nid\n"
		mkScript = name: cmds: pkgs.writeScriptBin name (scriptBody cmds);
		scriptBody = cmds: concatStringsSep "\n" (flatten (
			(optionals debug [
				"set -x"
				"set -e"
			])
			++ [cmds ""]
		));
		# Run a script or command inside a nix shell.
		# Takes a list of packages and a script as imputs.
		# The list of packages follow the standard flake syntax.
		# If a flake is not specified for a pakcage, nixpkgs is used by defautl
		# Example:
		# nixShell [ "hello" "nixpkgs#cowsay" ] "hello | cowsay"
		# => "nix shell nixpkgs#hello nixpkgs#cowsay -c sh -c 'hello | cowsay'"
		nixShell = packages: cmd: concatStringsSep " " [
			"nix shell"
			(concatStringsSep " " (map (x: concatStringsSep "#" (
				(optionals (!(hasInfix "#" x)) ["nixpkgs"])
				++ [x]
			)) packages))
			"-c sh -c ${escapeShellArg cmd}"
		];
		# Run a command on a given machine as a given user.
		# If no user is specified, it runs as root.
		# Example:
		# runOn {} "8.8.8.8" "id" => "ssh root@8.8.8.8 'id'"
		runOn = { user ? "root" }: n: c: "ssh ${user}@${n} ${escapeShellArg c}";
		# alias to avoid frequent use of "runOn {}"
		runRootOn = runOn {};
		# Takes a list of commands and pipes each to the next
		# Example:
		# mkPipe [ "ls" "grep test" "xargs ls" ] => "ls | grep test | xargs ls"
		mkPipe = concatStringsSep " | ";
		# Run a command on a list of nodes in parallel.
		# Takes parallel count and user as optional arguemtns.
		# Example:
		# runOnAll {} [ "1.1.1.1" "2.2.2.2" ] "id"
		# => "echo 1.1.1.1 2.2.2.2 | tr ' ' '\n' | xargs -I{} -P5 ssh root@{} 'id'"
		runOnAll = { parallel ? 5, user ? "root" }: nodes: c: mkPipe [
			"echo ${concatStringsSep " " nodes}"
			"tr ' ' '\\n'"
			"xargs -I{} -P${builtins.toString parallel} ${runOn {inherit user;} "{}" c}"
		];
		# alias to avoid frequent use of "runOnAll {}"
		runRootOnAll = runOnAll {};
		# Wait for a port to open up on a specified target.
		# Example:
		# waitForPort 8.8.8.8 53 => "while true; do nc -z 8.8.8.8 53 && break; sleep 5; done"
		waitForPort = n: p: "while true; do nc -z ${n} ${toString p} && break; sleep 5; done";
		# wait for multiple ports
		# Example:
		# waitForPorts "1.1.1.1" [22 53] => [
		#   "while true; do nc -z 1.1.1.1 22 && break; sleep 5; done"
		#   "while true; do nc -z 1.1.1.1 53 && break; sleep 5; done"
		# ]
		waitForPorts = n: (map (waitForPort n));
	};
}
