{
	lib,
	buildGoModule,
	...
}:

buildGoModule rec {
	pname = "hello";
	version = "0.1.0";
	src = ./src;
	vendorHash = null;
	ldflags = [
		"-X=main.version=${version}"
	];
	env.CGO_ENABLED = 0;
	meta.mainProgram = pname;
}
