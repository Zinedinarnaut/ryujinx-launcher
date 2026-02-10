import Foundation

struct ControllerInputSnapshot: Hashable {
    var leftStickX: Float = 0
    var leftStickY: Float = 0
    var rightStickX: Float = 0
    var rightStickY: Float = 0
    var dpadX: Float = 0
    var dpadY: Float = 0
    var leftTrigger: Float = 0
    var rightTrigger: Float = 0
    var leftShoulder: Bool = false
    var rightShoulder: Bool = false
    var buttonA: Bool = false
    var buttonB: Bool = false
    var buttonX: Bool = false
    var buttonY: Bool = false
    var buttonMenu: Bool = false
    var buttonOptions: Bool = false
    var buttonHome: Bool = false
    var leftThumbstickButton: Bool = false
    var rightThumbstickButton: Bool = false
    var touchpadButton: Bool = false
    var touchpadPrimaryX: Float = 0
    var touchpadPrimaryY: Float = 0
    var touchpadSecondaryX: Float = 0
    var touchpadSecondaryY: Float = 0
}

struct ControllerInfo: Identifiable, Hashable {
    let id: UUID
    let name: String
    let vendorName: String?
    let productCategory: String
    let isAttachedToDevice: Bool
    let batteryLevel: Float?
    let batteryState: String?
    let supportsHaptics: Bool
    let supportsLight: Bool
    let supportsDualSense: Bool
    let input: ControllerInputSnapshot
}

enum DualSenseTriggerMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case feedback = "Feedback"
    case weapon = "Weapon"
    case vibration = "Vibration"
    case slopeFeedback = "Slope"

    var id: String { rawValue }
}

struct DualSenseTriggerSettings: Hashable {
    var mode: DualSenseTriggerMode = .off
    var startPosition: Float = 0.1
    var endPosition: Float = 0.8
    var strength: Float = 0.7
    var startStrength: Float = 0.2
    var endStrength: Float = 0.8
    var amplitude: Float = 0.7
    var frequency: Float = 0.5
}

enum TriggerSide {
    case left
    case right
}
