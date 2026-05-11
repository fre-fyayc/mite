import SwiftUI

struct GlassTimeTrackerIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                        .blur(radius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.6), Color.clear, Color.white.opacity(0.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 10)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: [.cyan, .blue]), center: .center),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Capsule()
                        .fill(Color.primary.opacity(0.8))
                        .frame(width: 2, height: 18)
                        .offset(y: -9)

                    Capsule()
                        .fill(Color.primary.opacity(0.8))
                        .frame(width: 2, height: 12)
                        .offset(y: -6)
                        .rotationEffect(.degrees(90), anchor: .bottom)
                }

                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.5)))
            }
        }
        .frame(width: 128, height: 128)
        .padding()
    }
}

struct GlassTimeTrackerIcon_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2).edgesIgnoringSafeArea(.all)
            GlassTimeTrackerIcon()
        }
    }
}
