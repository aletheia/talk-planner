import SwiftUI

/// Two concentric depleting rings: the outer one for the whole talk, the inner
/// one for the current agenda item, with arbitrary content in the middle.
struct DualGaugeView<Center: View>: View {
    /// Remaining fraction of the whole talk, 0...1.
    var outerValue: Double
    /// Remaining fraction of the current segment, 0...1.
    var innerValue: Double
    var outerTint: Color
    var innerTint: Color
    var lineWidth: CGFloat = 8
    var ringGap: CGFloat = 4
    @ViewBuilder var center: () -> Center

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let innerSize = size - 2 * (lineWidth + ringGap)
            ZStack {
                ring(value: outerValue, tint: outerTint)
                    .frame(width: size, height: size)
                ring(value: innerValue, tint: innerTint)
                    .frame(width: innerSize, height: innerSize)
                center()
                    .frame(width: innerSize - 2 * lineWidth - 6, height: innerSize - 2 * lineWidth - 6)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func ring(value: Double, tint: Color) -> some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: value)
        }
    }
}
