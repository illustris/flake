{ python3Packages, fetchFromGitHub, ... }:
# with lib;
python3Packages.buildPythonPackage rec {
	pname = "proxmove";
	version = "1.2";
	src = fetchFromGitHub {
		owner = "ossobv";
		repo = "proxmove";
		rev = "v${version}";
		hash = "sha256-8xzsmQsogoMrdpf8+mVZRWPGQt9BO0dBT0aKt7ygUe4=";
	};
}
