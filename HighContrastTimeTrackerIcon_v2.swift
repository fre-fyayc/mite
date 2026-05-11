
import SwiftUI

struct HighContrastTimeTrackerIcon: View {
    // Accessibility: Support for high contrast and dark mode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background Layer: Darker, more defined "Glass"
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.3), 
                        Color.black.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                // Solid border for clear definition (Accessibility)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.blue, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 8)

            VStack(spacing: 14) {
                // Main Clock Face
                ZStack {
                    // High Contrast Outer Ring
                    Circle()
                        .stroke(Color.blue.opacity(0.5), lineWidth: 6)
                        .frame(width: 70, height: 70)
                    
                    // High Visibility Progress Arc
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    // Inner Clock with white hands for contrast
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 50, height: 50)
                    
                    // Hands - High Contrast (White on Dark)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: 20)
                        .offset(y: -10)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: 14)
                        .offset(y: -7)
                        .rotationEffect(.degrees(110), anchor: .bottom)
                    
                    // Center Dot
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 5, height: 5)
                }

                // Control Bar (Play/Pause) - Clear separation
                HStack(spacing: 15) {
                    Image(systemName: "backward.fill")
                    Image(systemName: "play.fill")
                        .font(.title3.bold())
                    Image(systemName: "forward.fill")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                )
            }
        }
        .frame(width: 128, height: 128)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time Tracker App Icon")
        .accessibilityHint("Zeigt eine dunkle Glasuhr mit Fortschrittsanzeige.")
    }
}

struct HighContrastTimeTrackerIcon_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HighContrastTimeTrackerIcon()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            HighContrastTimeTrackerIcon()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
        }
    }
}
