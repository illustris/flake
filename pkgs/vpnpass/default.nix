{ writeScriptBin, lib, openvpn, expect, ... }:

writeScriptBin "vpnpass" (
	lib.replaceStrings
		[ "/usr/bin/env expect" "openvpn" ]
		[ "${expect}/bin/expect" "${openvpn}/bin/openvpn" ]
		(builtins.readFile ./vpnpass)
)
