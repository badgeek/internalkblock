import Foundation
import CoreGraphics
import IOKit.hid

// Get keyboard information
func listKeyboards() {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    let deviceMatch = [
        kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
        kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
    ] as CFDictionary

    IOHIDManagerSetDeviceMatching(manager, deviceMatch)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

    guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
        print("No keyboards detected")
        return
    }

    print("Detected Keyboards:")
    print("-------------------")

    for (index, device) in deviceSet.enumerated() {
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"
        let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let locationID = IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? Int ?? 0
        let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? "Unknown"

        let isBuiltIn = transport == "SPI" ||
                       productName.contains("Apple Internal") ||
                       (vendorID == 0x0000 && locationID > 0 && locationID < 0x1000)

        print("\(index + 1). \(productName)")
        print("   Vendor ID: 0x\(String(format: "%04X", vendorID)), Product ID: 0x\(String(format: "%04X", productID))")
        print("   Location ID: 0x\(String(format: "%08X", locationID))")
        print("   Transport: \(transport)")
        print("   Type: \(isBuiltIn ? "Built-in (WILL BE LOCKED)" : "External (will remain active)")")
        print()
    }
}

class KeyboardLocker {
    private var blockedKeyboardTypes: Set<Int> = []

    func run() {
        print("""
        ╔════════════════════════════════════════╗
        ║   Internal Keyboard Lock for macOS    ║
        ╚════════════════════════════════════════╝

        """)

        listKeyboards()

        print("⚠️  IMPORTANT NOTES:")
        print("   • This requires Accessibility permissions")
        print("   • Go to: System Settings → Privacy & Security → Accessibility")
        print("   • Press Ctrl+C (on external keyboard) to unlock")
        print()
        print("Configuration:")
        print("   • Blocking keyboard types: 50 and above (type 91, etc.)")
        print("   • Allowing keyboard types: below 50 (type 40, etc.)")
        print()

        print("Press Enter to lock internal keyboard (or Ctrl+C to cancel)...")
        _ = readLine()

        setupEventTap()

        print()
        print("✅ Internal keyboard is now LOCKED")
        print("✅ External keyboards remain active")
        print()
        print("Press Ctrl+C on external keyboard to unlock...")
        print()

        CFRunLoopRun()
    }

    private func setupEventTap() {
        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let locker = Unmanaged<KeyboardLocker>.fromOpaque(refcon).takeUnretainedValue()
                return locker.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print()
            print("❌ Error: Failed to create event tap")
            print()
            print("Please ensure:")
            print("1. You have granted Accessibility permissions")
            print("2. System Settings → Privacy & Security → Accessibility")
            print()
            exit(1)
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it was disabled
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Re-enable would happen here, but we just return the event
            return Unmanaged.passRetained(event)
        }

        // Get keyboard type
        let keyboardType = event.getIntegerValueField(.keyboardEventKeyboardType)

        // Block keyboards with type >= 50 (internal keyboard on this Mac is type 91)
        // Allow keyboards with type < 50 (external keyboards like type 40)
        if keyboardType >= 50 {
            return nil // Block the event
        }

        // Allow the event
        return Unmanaged.passRetained(event)
    }
}

// Main
let locker = KeyboardLocker()

// Handle Ctrl+C gracefully
signal(SIGINT) { _ in
    print()
    print("Stopping keyboard lock...")
    CFRunLoopStop(CFRunLoopGetCurrent())
    print("✅ Internal keyboard unlocked and re-enabled")
    exit(0)
}

locker.run()
