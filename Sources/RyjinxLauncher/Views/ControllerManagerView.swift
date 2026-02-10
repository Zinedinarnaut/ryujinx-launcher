import SwiftUI

struct ControllerManagerView: View {
    @ObservedObject var viewModel: ControllerManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controllers")
                .font(.custom("Avenir Next", size: 15).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            if viewModel.controllers.isEmpty {
                Text("No controllers connected")
                    .font(.custom("Avenir Next", size: 12).weight(.medium))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    .background(Theme.panel)
                    .cornerRadius(12)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    controllerList
                        .frame(width: 220)

                    controllerDetails
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Theme.panelAlt)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }

    private var controllerList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.controllers) { controller in
                    ControllerCard(info: controller, isSelected: controller.id == viewModel.selectedControllerID) {
                        viewModel.selectController(controller.id)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 360)
    }

    private var controllerDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let controller = viewModel.selectedController {
                ControllerInfoView(controller: controller)
                ControllerInputView(input: controller.input, supportsDualSense: controller.supportsDualSense)
                ControllerHapticsView(viewModel: viewModel, supportsHaptics: controller.supportsHaptics)
                ControllerLightbarView(viewModel: viewModel, supportsLight: controller.supportsLight)

                if controller.supportsDualSense {
                    DualSenseTriggerView(title: "Left Trigger", settings: $viewModel.leftTriggerSettings) {
                        viewModel.applyLeftTrigger()
                    }
                    DualSenseTriggerView(title: "Right Trigger", settings: $viewModel.rightTriggerSettings) {
                        viewModel.applyRightTrigger()
                    }
                }
            } else {
                Text("Select a controller to view details")
                    .font(.custom("Avenir Next", size: 12).weight(.medium))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            }
        }
    }
}

private struct ControllerCard: View {
    let info: ControllerInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(info.name)
                .font(.custom("Avenir Next", size: 13).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)

            Text(info.productCategory)
                .font(.custom("Avenir Next", size: 11).weight(.medium))
                .foregroundStyle(Theme.textMuted)

            if let level = info.batteryLevel {
                Text("Battery: \(Int(level * 100))% \(info.batteryState ?? "")")
                    .font(.custom("Avenir Next", size: 11).weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("Battery: n/a")
                    .font(.custom("Avenir Next", size: 11).weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(info.supportsDualSense ? "DualSense features" : "Standard controller")
                .font(.custom("Avenir Next", size: 10).weight(.medium))
                .foregroundStyle(info.supportsDualSense ? Theme.textSecondary : Theme.textMuted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Theme.textPrimary.opacity(0.6) : Theme.border.opacity(0.4), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

private struct ControllerInfoView: View {
    let controller: ControllerInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Controller Info")
                .font(.custom("Avenir Next", size: 13).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("Vendor: \(controller.vendorName ?? "Unknown")")
                .font(.custom("Avenir Next", size: 12).weight(.medium))
                .foregroundStyle(Theme.textSecondary)

            Text("Category: \(controller.productCategory)")
                .font(.custom("Avenir Next", size: 12).weight(.medium))
                .foregroundStyle(Theme.textSecondary)

            Text("Attached: \(controller.isAttachedToDevice ? "Yes" : "No")")
                .font(.custom("Avenir Next", size: 12).weight(.medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(10)
        .background(Theme.panel)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct ControllerInputView: View {
    let input: ControllerInputSnapshot
    let supportsDualSense: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live Input")
                .font(.custom("Avenir Next", size: 13).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Left Stick: \(format(input.leftStickX)), \(format(input.leftStickY))")
                    Text("Right Stick: \(format(input.rightStickX)), \(format(input.rightStickY))")
                    Text("D-Pad: \(format(input.dpadX)), \(format(input.dpadY))")
                    Text("Triggers: L \(format(input.leftTrigger))  R \(format(input.rightTrigger))")
                }
                .font(.custom("Menlo", size: 11))
                .foregroundStyle(Theme.textSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("A \(bool(input.buttonA))  B \(bool(input.buttonB))  X \(bool(input.buttonX))  Y \(bool(input.buttonY))")
                    Text("L1 \(bool(input.leftShoulder))  R1 \(bool(input.rightShoulder))")
                    Text("Menu \(bool(input.buttonMenu))  Options \(bool(input.buttonOptions))  Home \(bool(input.buttonHome))")
                    Text("L3 \(bool(input.leftThumbstickButton))  R3 \(bool(input.rightThumbstickButton))")
                    if supportsDualSense {
                        Text("Touchpad \(bool(input.touchpadButton))")
                    }
                }
                .font(.custom("Menlo", size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        }
        .padding(10)
        .background(Theme.panel)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }

    private func format(_ value: Float) -> String {
        String(format: "%+.2f", value)
    }

    private func bool(_ value: Bool) -> String {
        value ? "On" : "Off"
    }
}

private struct ControllerHapticsView: View {
    @ObservedObject var viewModel: ControllerManagerViewModel
    let supportsHaptics: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Haptics Test")
                .font(.custom("Avenir Next", size: 13).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            if supportsHaptics {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Intensity")
                            .font(.custom("Avenir Next", size: 11).weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                        Slider(value: $viewModel.hapticIntensity, in: 0...1)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sharpness")
                            .font(.custom("Avenir Next", size: 11).weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                        Slider(value: $viewModel.hapticSharpness, in: 0...1)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.custom("Avenir Next", size: 11).weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                        Slider(value: $viewModel.hapticDuration, in: 0.1...1.5)
                    }

                    Button("Play") {
                        viewModel.playHaptics()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                Text("Haptics not supported on this controller")
                    .font(.custom("Avenir Next", size: 11).weight(.medium))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(10)
        .background(Theme.panel)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct ControllerLightbarView: View {
    @ObservedObject var viewModel: ControllerManagerViewModel
    let supportsLight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lightbar")
                .font(.custom("Avenir Next", size: 13).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            if supportsLight {
                HStack(spacing: 12) {
                    ColorPicker("", selection: $viewModel.lightbarColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 44)

                    Button("Apply") {
                        viewModel.setLightbarColor()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                Text("Lightbar not supported")
                    .font(.custom("Avenir Next", size: 11).weight(.medium))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(10)
        .background(Theme.panel)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct DualSenseTriggerView: View {
    let title: String
    @Binding var settings: DualSenseTriggerSettings
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Avenir Next", size: 13).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Picker("Mode", selection: $settings.mode) {
                ForEach(DualSenseTriggerMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Group {
                if settings.mode == .feedback {
                    sliderRow(label: "Start", value: $settings.startPosition)
                    sliderRow(label: "Strength", value: $settings.strength)
                } else if settings.mode == .weapon {
                    sliderRow(label: "Start", value: $settings.startPosition)
                    sliderRow(label: "End", value: $settings.endPosition)
                    sliderRow(label: "Strength", value: $settings.strength)
                } else if settings.mode == .vibration {
                    sliderRow(label: "Start", value: $settings.startPosition)
                    sliderRow(label: "Amplitude", value: $settings.amplitude)
                    sliderRow(label: "Frequency", value: $settings.frequency)
                } else if settings.mode == .slopeFeedback {
                    sliderRow(label: "Start", value: $settings.startPosition)
                    sliderRow(label: "End", value: $settings.endPosition)
                    sliderRow(label: "Start Strength", value: $settings.startStrength)
                    sliderRow(label: "End Strength", value: $settings.endStrength)
                }
            }

            Button("Apply Trigger") {
                onApply()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(10)
        .background(Theme.panel)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }

    private func sliderRow(label: String, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label): \(String(format: "%.2f", value.wrappedValue))")
                .font(.custom("Avenir Next", size: 11).weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Slider(value: value, in: 0...1)
        }
    }
}
