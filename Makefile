.PHONY: build

ODIN_BUILD_FLAGS := -debug
DEPS_BUILD_MODE := debug

release-all: 
	@echo "Building in RELEASE mode..."
	$(MAKE) build-deps DEPS_BUILD_MODE="RELEASE"
	$(MAKE) build ODIN_BUILD_FLAGS="-o:speed -no-bounds-check -disable-assert" 

release: 
	@echo "Building in RELEASE mode..."
	$(MAKE) build ODIN_BUILD_FLAGS="-o:speed -no-bounds-check -disable-assert" 

debug: build
	@echo "Building in DEBUG mode..."
	$(MAKE) build 

build: 
	@echo "Building hist"
	odin build ./src -out:histv2 $(ODIN_BUILD_FLAGS)

build-deps:
	./scripts/build_deps.sh $(DEPS_BUILD_MODE)

test:
	odin test ./src/db 

run:
	odin run ./src -out:histv2 -o:speed -sanitize:address 
