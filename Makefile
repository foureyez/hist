build:
	odin build ./src -out:cmdh -collection:deps=deps -debug

build-release:
	odin build ./src -out:cmdh -collection:deps=deps -o:speed -no-bounds-check -disable-assert

run:
	odin run ./src -out:cmdh -collection:deps=deps -o:speed -sanitize:address 

test:
	bash tests/smoke_test.sh

clean:
	rm -f cmdh
	rm -rf /tmp/cmdh-test-config

install: build-release
	install -d $(PREFIX)/usr/local/bin
	install -m 755 cmdh $(PREFIX)/usr/local/bin/cmdh

.PHONY: build build-release run test clean install
