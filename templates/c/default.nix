{stdenv, cmake, ...}:
stdenv.mkDerivation {
	pname = "hello_world";
	version = "1.0";
	src = ./src;
	nativeBuildInputs = [cmake];
}
