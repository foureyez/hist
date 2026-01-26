build:
	odin build ./src -out:cmdh -collection:deps=deps -debug

build-release:
	odin build ./src -out:cmdh -collection:deps=deps -o:speed -no-bounds-check -disable-assert

run:
	odin run ./src -out:cmdh -collection:deps=deps -o:speed -sanitize:address 
