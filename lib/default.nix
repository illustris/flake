{ lib, ... }:
with lib;
rec {
	# Ternary operator
	# Exaample:
	# tern false 1 2 => 2
	# tern true 1 2 => 1
	tern = pred: x: y: if pred then x else y;

	# Right-associate and chain following single-operand functions
	# Example:
	# right f g h 1 => f(g(h(1)))
	right = f: g: tern (isFunction g)
		(right (x: f(g(x))))
		(f(g));

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
		assert ( right (replaceStrings ["\t"] [""]) last lines  == "");
		concatStringsSep "\n" (
			map (line: substring (1 + right stringLength last lines) (stringLength line) line) lines
		)
	);

	# Takes an attrset of colmena targets
	# Returns an attrset of nixosConfigurations
	colmenaToNixos = colmena: mapAttrs
		(n: module: let
			nixpkgs = module.nixpkgs
				or colmena.nodeNixpkgs.${n}
				or colmena.meta.nixpkgs;
		in (import "${nixpkgs.path}/nixos/lib/eval-config.nix" {
			inherit (nixpkgs) system;
			modules = [
				module
				# stop errors about "deployment" not existing
				{options.deployment = mkOption {type = types.attrs;};}
			];
		})
		) (removeAttrs colmena [ "meta" ]);

	# Get toplevel for each attr in nixosConfigurations
	nixosToDrv = mapAttrs (_: v: v.config.system.build.toplevel);

	# Returns the same as the above function, with the an additional "all" attribute
	# useful for easily building all colmena targets with nix build
	# nix build .#systems.all
	nixosToDrv' = configs: let attrs = nixosToDrv configs; in {
		all = (head (attrValues configs)).pkgs.linkFarm
			"all-targets"
			(mapAttrsToList (name: path: {inherit name path;}) attrs);
	} // attrs;

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
			( right
				(concatStringsSep " ")
				(map (x: tern (hasInfix "#" x) "" "nixpkgs#" + x))
				packages
			)
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
			"xargs -I{} -P${toString parallel} ${runOn {inherit user;} "{}" c}"
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
		waitForPorts = right map waitForPort;
	};

	# Takes a path and returns the list of names of non-hidden directories there
	# Example:
	# dirs ../pkgs => [ "btop-static" "oss-cad-suite-bin" "vhd2vl" "vpnpass" ]
	dirs = right attrNames (filterAttrs (n: v: v == "directory" && !hasPrefix "." n)) builtins.readDir;

	# Takes a prefix, a list of targets, and a generator function; returns an attrset of targets
	# The generator function must accept an attrset of kwargs forwarded from mapCluster, an index,
	# and one element of the "targets" list
	#
	# Example generator function:
	# gen = args: n: target: {
	# 	imports = [ ./common ];
	# 	deployment.targetHost = target;
	# }
	#
	# An optional "nameFunction" attribute can be passed. It must accept the same arguments as the
	# generator function, and return the name of the node as a string
	#
	# Example usage:
	# mapCluster {
	# 	prefix = "test";
	# 	targets = ipRange [1 2 3 4] 2;
	# 	nameFunction = _: n: _: "${prefix}-${tern (mod n 2 == 0) "even" "odd"}-${toString n}"
	# } gen # gen defined above
	# =>
	# {
	# 	test-odd-1 = {
	# 		imports = [ ./common ];
	# 		deployment.targetHost = "1.2.3.4";
	# 	};
	# 	test-even-2 = {
	# 		imports = [ ./common ];
	# 		deployment.targetHost = "1.2.3.5";
	# 	};
	# }
	mapCluster = {
		prefix,
		nameFunction ? (args: n: target: "${args.prefix}-${builtins.toString n}"),
		targets,
		...
	}@args: generator:
		listToAttrs ( imap1
			(n: target: nameValuePair
				(nameFunction args n target)
				(generator args n target)
			)
			targets
		);
}
