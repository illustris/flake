{ packages, ... }:
final: prev: {
	illustris = packages.${prev.system};
	# Hyprlock 0.9.6 leaves SHM captures in XDG_RUNTIME_DIR until it fills up.
	hyprlock = prev.hyprlock.overrideAttrs (old: {
		patches = (old.patches or [ ]) ++ [ ./hyprlock-shm.patch ];
		passthru = (old.passthru or { }) // {
			tests = (old.passthru.tests or { }) // {
				shmPool = final.callPackage ./hyprlock-shm-test.nix { };
			};
		};
	});
}
