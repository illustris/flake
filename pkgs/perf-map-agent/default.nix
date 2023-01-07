{ stdenv, lib, fetchFromGitHub, cmake, jdk, flamegraph, makeWrapper, ... }:
with lib;
stdenv.mkDerivation rec {
	name = "perf-map-agent";

	version = "unstable-2018-10-22";

	src = fetchFromGitHub {
		owner = "jvm-profiling-tools";
		repo = "perf-map-agent";
		rev = "master";
		hash = "sha256-j+kB2gy0h9gFNCvgLNHBgiSuJJeJfgzud/Mmv+iaG4Y=";
	};

	nativeBuildInputs = [ cmake makeWrapper ];
	propagatedBuildInputs = [ jdk ];

	preFixup = ''
		for n in $(find $out/bin -type f -executable); do
			wrapProgram "$n" \
				--prefix JAVA_HOME : ${jdk.home} \
				--prefix FLAMEGRAPH_DIR : ${flamegraph}/bin
		done
	'';

	installPhase = indent ''
		rm ../bin/create-links-in
		mkdir -p $out
		mv ../bin out $out/
	'';

	meta = {
		description = "A java agent to generate /tmp/perf-<pid>.map files for JIT-compiled methods for use with perf tools";
		homepage = "https://github.com/jvm-profiling-tools/perf-map-agent";
		license = licenses.gpl2;
		maintainers = with maintainers; [ illustris ];
		platforms = platforms.linux;
	};
}
