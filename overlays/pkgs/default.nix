{ packages, ... }:
final: prev: {
	illustris = packages.${prev.system};
}
