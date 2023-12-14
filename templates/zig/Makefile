out ?= /usr/local

build:
	HOME=${HOME:-$PWD} zig build

install:
	HOME=${HOME:-$PWD} zig build --prefix "${out}"
