# macOS Keyboard Lock

A simple utility to lock the internal keyboard on macOS while keeping external keyboards active. Useful when placing an external keyboard on top of your MacBook.

## Requirements

- macOS
- Accessibility permissions (System Settings → Privacy & Security → Accessibility)

## Building

```bash
make build
```

## Usage

```bash
./bin/keyboard_lock_swift
```

1. Grant Accessibility permissions when prompted
2. Press Enter to lock the internal keyboard
3. Press Ctrl+C (on external keyboard) to unlock

## How It Works

The utility creates a CGEvent tap that intercepts keyboard events and filters them based on keyboard type:
- Keyboard types >= 50 are blocked (internal keyboards, typically type 91)
- Keyboard types < 50 are allowed (external keyboards, typically type 40)

## License

Public Domain
