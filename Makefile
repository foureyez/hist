build:
	odin build ./src -out:cmdh -collection:deps=deps -debug

build-release:
	odin build ./src -out:cmdh -collection:deps=deps -o:speed -no-bounds-check -disable-assert

run:
	odin run ./src -out:cmdh -collection:deps=deps -o:speed -sanitize:address 

test:
	@echo "Running smoke tests..."
	@bash tests/smoke_test.sh

clean:
	@echo "Cleaning build artifacts..."
	@rm -f cmdh
	@rm -rf tmp_config

install: build-release
	@echo "Installing cmdh to /usr/local/bin..."
	@install -m 755 cmdh /usr/local/bin/cmdh
	@echo "Installation complete!"

.PHONY: build build-release run test clean install
