{ self, lib, ... }:
with lib;
(genAttrs (dirs ./.) (name: import ./${name} { inherit self; }))
