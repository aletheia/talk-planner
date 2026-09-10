import SwiftUI

/// Wheel picker for a duration, split into the requested components.
struct DurationPicker: View {
    enum Component: Hashable {
        case hours, minutes, seconds
    }

    @Binding var duration: TimeInterval
    var components: [Component] = [.minutes, .seconds]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(components, id: \.self) { component in
                Picker(label(for: component), selection: binding(for: component)) {
                    ForEach(range(for: component), id: \.self) { value in
                        Text("\(value) \(unit(for: component))").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
        .frame(height: 150)
    }

    // MARK: - Component plumbing

    private var totalSeconds: Int { Int(duration.rounded()) }

    private var hours: Int {
        components.contains(.hours) ? totalSeconds / 3600 : 0
    }

    private var minutes: Int {
        if components.contains(.hours) { return (totalSeconds % 3600) / 60 }
        return totalSeconds / 60
    }

    private var seconds: Int {
        components.contains(.seconds) ? totalSeconds % 60 : 0
    }

    private func binding(for component: Component) -> Binding<Int> {
        Binding(
            get: {
                switch component {
                case .hours: return hours
                case .minutes: return minutes
                case .seconds: return seconds
                }
            },
            set: { newValue in
                var h = hours, m = minutes, s = seconds
                switch component {
                case .hours: h = newValue
                case .minutes: m = newValue
                case .seconds: s = newValue
                }
                duration = TimeInterval(h * 3600 + m * 60 + s)
            }
        )
    }

    private func range(for component: Component) -> [Int] {
        switch component {
        case .hours: return Array(0...8)
        case .minutes: return components.contains(.hours) ? Array(0...59) : Array(0...240)
        case .seconds: return Array(0...59)
        }
    }

    private func label(for component: Component) -> String {
        switch component {
        case .hours: return "Hours"
        case .minutes: return "Minutes"
        case .seconds: return "Seconds"
        }
    }

    private func unit(for component: Component) -> String {
        switch component {
        case .hours: return "h"
        case .minutes: return "min"
        case .seconds: return "sec"
        }
    }
}
