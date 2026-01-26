build:
	odin build . -out:cmdh -collection:deps=deps -debug

build-release:
	odin build . -out:cmdh -collection:deps=deps -o:speed -no-bounds-check -disable-assert

run:
	odin run . -out:cmdh -collection:deps=deps -o:speed -sanitize:address 
