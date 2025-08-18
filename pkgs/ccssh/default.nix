{ writeShellApplication, curl, jq, gnugrep, gawk, perlPackages, ... }:

writeShellApplication {
	name = "ccssh";

	runtimeInputs = [
		curl
		jq
		gnugrep
		gawk
		perlPackages.AppClusterSSH
	];

	text = builtins.readFile ./ccssh;

	meta.description = "Clustered SSH with Consul service discovery";
}
