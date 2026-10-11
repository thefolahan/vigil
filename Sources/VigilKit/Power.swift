import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt

/// Holds an IOKit power assertion that stops idle sleep while it exists. This
/// is what `caffeinate -i` does, and it needs no special permission.
public final class SleepAssertion {
    private var id: IOPMAssertionID = 0
    public private(set) var isHeld = false

    public init() {}

    deinit { release() }

    public func hold(reason: String) {
        if isHeld {
            IOPMAssertionSetProperty(id, kIOPMAssertionNameKey as CFString, reason as CFString)
            return
        }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        isHeld = result == kIOReturnSuccess
    }

    public func release() {
        guard isHeld else { return }
        IOPMAssertionRelease(id)
        isHeld = false
    }
}

public struct BatteryState: Sendable, Equatable {
    public let percent: Int
    public let onBattery: Bool

    public init(percent: Int, onBattery: Bool) {
        self.percent = percent
        self.onBattery = onBattery
    }
}

public enum SystemHealth {
    /// The charge and power source of the internal battery, or nil on a Mac
    /// without one.
    public static func battery() -> BatteryState? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            let state = description[kIOPSPowerSourceStateKey] as? String
            return BatteryState(percent: current * 100 / maximum, onBattery: state == kIOPSBatteryPowerValue)
        }
        return nil
    }

    /// Whether the built in display is closed.
    public static func lidClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
        return (value as? Bool) ?? false
    }

    /// Seconds since the last keyboard, mouse or trackpad input.
    public static func secondsSinceInput() -> TimeInterval {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
        guard let nanoseconds = (value as? NSNumber)?.uint64Value else { return 0 }
        return TimeInterval(nanoseconds) / 1_000_000_000
    }
}

/// Why lid mode was stopped for safety.
public enum GuardTrip: Sendable, Equatable {
    case heat(ProcessInfo.ThermalState)
    case battery(Int)

    public var message: String {
        switch self {
        case .heat(let state):
            return state == .critical
                ? "The Mac is critically hot, so Vigil let it sleep."
                : "The Mac is running hot, so lid mode was turned off."
        case .battery(let percent):
            return "Battery is down to \(percent)%, so lid mode was turned off."
        }
    }
}

public struct GuardPolicy: Sendable, Equatable {
    /// Lid mode stops below this charge while on battery.
    public var batteryFloor: Int = 25

    public init(batteryFloor: Int = 25) {
        self.batteryFloor = batteryFloor
    }

    /// Whether running with the lid closed is unsafe right now.
    public func trip(thermal: ProcessInfo.ThermalState, battery: BatteryState?) -> GuardTrip? {
        if thermal == .serious || thermal == .critical { return .heat(thermal) }
        if let battery, battery.onBattery, battery.percent < batteryFloor { return .battery(battery.percent) }
        return nil
    }
}

extension ProcessInfo.ThermalState {
    public var label: String {
        switch self {
        case .nominal: return "Cool"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
