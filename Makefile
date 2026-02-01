build:
	odin build ./src -out:cmdh -collection:deps=deps -debug

build-release:
	odin build ./src -out:cmdh -collection:deps=deps -o:speed -no-bounds-check -disable-assert

run:
	odin run ./src -out:cmdh -collection:deps=deps -o:speed -sanitize:address 

test:
	@echo "Running smoke tests..."
	@chmod +x tests/smoke_test.sh
	@bash tests/smoke_test.sh

clean:
	@echo "Cleaning build artifacts..."
	@rm -f cmdh
	@rm -rf tmp_config
	@rm -f test.db
	@echo "Clean complete"

fmt:
	@echo "Formatting code (if odinfmt is available)..."
	@if command -v odinfmt >/dev/null 2>&1; then \
		find src -name "*.odin" -exec odinfmt -w {} \; ; \
		echo "Formatting complete"; \
	else \
		echo "odinfmt not found, skipping formatting"; \
	fi

install: build-release
	@echo "Installing cmdh to /usr/local/bin..."
	@sudo cp cmdh /usr/local/bin/
	@echo "Installation complete"

.PHONY: build build-release run test clean fmt install
 
