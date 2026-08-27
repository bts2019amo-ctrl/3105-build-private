import SwiftUI



struct PremiumLiquidGlassToggleStyle: ToggleStyle {
    
    private let width: CGFloat = 56
    
    private let height: CGFloat = 34
    
    private let knob: CGFloat = 28
    

    
    func makeBody(configuration: Configuration) -> some View {
        
        Button {
            
            withAnimation(.easeOut(duration: 0.18)) {
                
                configuration.isOn.toggle()
                
            }
            
        } label: {
            
            ZStack {
                
                Capsule(style: .continuous)
                
                    .fill(.ultraThinMaterial)
                
                    .overlay {
                        
                        Capsule(style: .continuous)
                        
                            .fill(configuration.isOn ? AppTheme.accent.opacity(0.42) : Color.white.opacity(0.055))
                        
                    }
                
                    .overlay {
                        
                        Capsule(style: .continuous)
                        
                            .stroke(Color.white.opacity(configuration.isOn ? 0.42 : 0.24), lineWidth: 1)
                        
                    }
                
                    .overlay {
                        
                        Capsule(style: .continuous)
                        
                            .fill(LinearGradient(colors: [Color.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                        
                            .padding(2)
                        
                            .frame(height: 13)
                        
                            .frame(maxHeight: .infinity, alignment: .top)
                        
                            .clipShape(Capsule(style: .continuous))
                        
                    }
                
                    .shadow(color: configuration.isOn ? AppTheme.accent.opacity(0.22) : .clear, radius: 6, y: 2)
                

                
                Circle()
                
                    .fill(.thinMaterial)
                
                    .overlay {
                        
                        Circle()
                        
                            .fill(LinearGradient(colors: [Color.white.opacity(0.42), configuration.isOn ? AppTheme.accent.opacity(0.22) : Color.white.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                        
                    }
                
                    .overlay {
                        
                        Circle().stroke(Color.white.opacity(0.58), lineWidth: 0.8)
                        
                    }
                
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                
                    .shadow(color: configuration.isOn ? AppTheme.accent.opacity(0.30) : .clear, radius: 5)
                
                    .frame(width: knob, height: knob)
                
                    .offset(x: configuration.isOn ? 11 : -11)
                
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
        
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
        
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
        
    }
    
}



























































