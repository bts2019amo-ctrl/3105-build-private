import SwiftUI



enum AppTheme {
    static let accentColorStorageKey = "3105_accent_color_hex"
    static let defaultAccentHex = "#3885FF"

    static var accent: Color {
        Color(hex: UserDefaults.standard.string(forKey: accentColorStorageKey) ?? defaultAccentHex)
    }
    
    static let pageBackground = Color.clear
    
    static let consoleBackground = Color.clear
    
    static let glassFill = Color.white.opacity(0.14)
    
    static let glassStroke = Color.white.opacity(0.28)
    
    static let pageInset: CGFloat = 16
    
    static let rowIconSize: CGFloat = 17
    
    static let rowIconFrame: CGFloat = 28
    
    static let fileRowIconSize: CGFloat = 17
    
    static let fileRowIconFrame: CGFloat = 30
    
    static let fileRowHeight: CGFloat = 60
    
    static let appIconSize: CGFloat = 32
    
    static let emptyIconSize: CGFloat = 30
    
    static let selectionIconSize: CGFloat = 18
    
}



struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.80), AppTheme.accent.opacity(0.28), Color.black.opacity(0.60)], startPoint: .topLeading, endPoint: .bottomTrailing)
            
                .ignoresSafeArea()
            
            Circle().fill(AppTheme.accent.opacity(0.30)).frame(width: 260, height: 260).blur(radius: 55).offset(x: 150, y: -260)
            Circle().fill(AppTheme.accent.opacity(0.20)).frame(width: 300, height: 300).blur(radius: 70).offset(x: -150, y: 270)
            
            Color.black.opacity(0.08).ignoresSafeArea()
            
        }
        
        .allowsHitTesting(false)
        
    }
    
}



extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        let color = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return AppTheme.defaultAccentHex }
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

struct AppRowIcon: View {
    
    let systemName: String
    
    var tint: Color = AppTheme.accent
    
    var symbolSize: CGFloat = AppTheme.rowIconSize
    
    var frameSize: CGFloat = AppTheme.rowIconFrame
    

    
    var body: some View {
        
        ZStack {
            
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.opacity(0.12))
            
            Image(systemName: systemName).font(.system(size: symbolSize, weight: .medium)).foregroundStyle(tint)
            
        }
        
        .frame(width: frameSize, height: frameSize)
        
        .accessibilityHidden(true)
        
    }
    
}



struct AppSearchField: View {
    
    @Binding var text: String
    
    let prompt: String
    
    let clearLabel: String
    
    var body: some View {
        
        HStack(spacing: 8) {
            
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).accessibilityHidden(true)
            
            TextField(prompt, text: $text).font(.body).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
            
            if !text.isEmpty {
                
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(.tertiary) }.buttonStyle(.plain).accessibilityLabel(clearLabel)
                
            }
            
        }
        
        .padding(.horizontal, 11).frame(minHeight: 36)
        
        .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        
        .padding(.horizontal, AppTheme.pageInset).padding(.vertical, 8).background(.bar)
        
    }
    
}



struct LiquidGlassToggleStyle: ToggleStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        
        Button {
            
            withAnimation(.easeOut(duration: 0.18)) { configuration.isOn.toggle() }
            
        } label: {
            
            HStack(spacing: 8) {
                
                configuration.label.font(.caption.weight(.semibold)).foregroundStyle(.primary)
                
                ZStack {
                    
                    Capsule(style: .continuous).fill(.ultraThinMaterial)
                    
                        .overlay { Capsule(style: .continuous).fill(configuration.isOn ? AppTheme.accent.opacity(0.62) : Color.white.opacity(0.10)) }
                    
                        .overlay { Capsule(style: .continuous).stroke(Color.white.opacity(configuration.isOn ? 0.60 : 0.30), lineWidth: 1) }
                    
                    Circle().fill(.regularMaterial)
                    
                        .overlay { Circle().stroke(Color.white.opacity(0.72), lineWidth: 0.8) }
                    
                        .shadow(color: .black.opacity(0.24), radius: 4, y: 2)
                    
                        .frame(width: 22, height: 22).offset(x: configuration.isOn ? 10 : -10)
                    
                }
                
                .frame(width: 42, height: 26)
                
                .shadow(color: configuration.isOn ? AppTheme.accent.opacity(0.30) : .clear, radius: 8)
                
            }.contentShape(Rectangle())
            
        }
        
        .buttonStyle(.plain)
        
        .accessibilityRepresentation { Toggle(configuration) }
        
    }
    
}



struct AppLogo: View {
    
    var size: CGFloat = 44
    
    var body: some View {
        
        Group {
            
            if let icon = UIImage(named: "AppIcon60x60") ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:)) ?? UIImage(named: "AppIcon") {
                
                Image(uiImage: icon).resizable().scaledToFill()
                
            } else {
                
                Image(systemName: "slider.horizontal.3").font(.title2.weight(.semibold)).foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity).background(AppTheme.accent)
                
            }
            
        }
        
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)).accessibilityHidden(true)
        
    }
    
}
































































































