.PHONY: all clean build install

BINARY_NAME = poeditor-sync

all: clean build install

clean:
	swift package clean
	rm -rf .build
	rm -f bin/$(BINARY_NAME)

build:
	swift build -c release

install:
	mkdir -p bin
	cp .build/release/$(BINARY_NAME) bin/
	chmod +x bin/$(BINARY_NAME)