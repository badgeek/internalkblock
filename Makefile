.PHONY: build clean

build:
	@mkdir -p bin
	swiftc -O -o bin/keyboard_lock_swift KeyboardLock.swift

clean:
	rm -rf bin/
