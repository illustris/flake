{ stdenv, lib, fetchFromGitHub, flex, bison, iverilog ? null, verilog ? null, ... }:
with lib;
assert iverilog != null || verilog != null;
stdenv.mkDerivation rec {
	name = "vnd2vl";

	version = "2018-09-01";

	src = fetchFromGitHub {
		owner = "ldoolitt";
		repo = "vhd2vl";
		rev = "master";
		hash = "sha256-Fmlnts7Oei2ApO+ocObA277/C/HQqpEYkmgkQuMVap8=";
	};

	buildInputs = [ flex bison (if isDerivation iverilog then iverilog else verilog) ];

	patchPhase = ''
		substituteInPlace translated_examples/test.v \
			--replace "default : code[9:2] <= (a) + (b);" "default : code[9:2] <= a + b;" \
			--replace "assign code1[1:0] = a[6:5] ^ ({a[4],b[6]});" "assign code1[1:0] = a[6:5] ^ {a[4],b[6]};"
		substituteInPlace translated_examples/fifo.v \
			--replace "(add_RD)" "add_RD"
	'';

	installPhase = ''
		mkdir -p $out/bin
		mv src/vhd2vl $out/bin/
	'';
	meta = {
		# TODO: fix on aarch64
		platforms = [ "x86_64-linux" ];
	};
}
