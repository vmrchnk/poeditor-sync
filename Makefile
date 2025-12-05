.PHONY: all clean build install

BINARY_NAME = poeditor-sync
SCRIPTS_ROOT = .
BUILD_DIR = $(SCRIPTS_ROOT)/.build

all: clean build install

clean:
	cd $(SCRIPTS_ROOT) && swift package clean
	rm -f bin/$(BINARY_NAME)

build:
	cd $(SCRIPTS_ROOT) && swift build --product $(BINARY_NAME) -c release

install:
	mkdir -p bin
	cp $(BUILD_DIR)/release/$(BINARY_NAME) bin/
	chmod +x bin/$(BINARY_NAME)