PREFIX ?= /usr/local
BIN := .build/release/socr

.PHONY: build install uninstall clean

build:
	swift build -c release

install: build
	install -d $(PREFIX)/bin
	install -m 755 $(BIN) $(PREFIX)/bin/socr

uninstall:
	rm -f $(PREFIX)/bin/socr

clean:
	rm -rf .build
