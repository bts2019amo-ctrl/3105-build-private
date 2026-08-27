import SwiftUI

struct PremiumLiquidGlassToggleStyle: ToggleStyle {
    private let width: CGFloat = 54
    private let height: CGFloat = 32
    private let knob: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.78)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: configuration.isOn
                                        ? [AppTheme.accent.opacity(0.98), Color(red: 0.03, green: 0.18, blue: 0.68).opacity(0.90)]
                                        : [Color.white.opacity(0.26), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(configuration.isOn ? 0.52 : 0.38), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .padding(.horizontal, 2)
                            .padding(.top, 2)
                            .frame(height: 13)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .clipShape(Capsule(style: .continuous))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.95), Color.white.opacity(0.20)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.black.opacity(configuration.isOn ? 0.16 : 0.30), lineWidth: 0.8)
                            .padding(1)
                    }

                Circle()
                    .fill(.regularMaterial)
                    .overlay {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.80), Color.white.opacity(0.16), .clear],
                                    center: .topLeading,
                                    startRadius: 1,
                                    endRadius: 18
                                )
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(1.0), Color.white.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.34), lineWidth: 0.7)
                            .padding(2)
                    }
                    .shadow(color: .black.opacity(0.38), radius: 5, y: 3)
                    .shadow(color: configuration.isOn ? AppTheme.accent.opacity(0.48) : .white.opacity(0.12), radius: 3, y: -1)
                    .frame(width: knob, height: knob)
                    .offset(x: configuration.isOn ? 10 : -10)
                    .scaleEffect(configuration.isOn ? 1.03 : 1.0)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(PremiumLiquidGlassPressStyle())
        .accessibilityRepresentation { Toggle(configuration) }
    }
}

private struct PremiumLiquidGlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
