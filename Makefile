build:
	odin build . -out:cmdh -collection:deps=deps

build-release:
	odin build . -out:cmdh -collection:deps=deps -o:speed
