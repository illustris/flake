{ pkgs, ... }@args:
with pkgs.lib;

genAttrs (dirs ./.) (name: import (./. + "/${name}") args)
