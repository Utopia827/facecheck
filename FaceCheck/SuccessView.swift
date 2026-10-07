import SwiftUI

struct SuccessView: View {
    var onDone: () -> Void

    @State private var ring: CGFloat = 0
    @State private var tick: CGFloat = 0
    @State private var textShown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .trim(from: 0, to: ring)
                    .stroke(Color.doneGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                CheckShape()
                    .trim(from: 0, to: tick)
                    .stroke(Color.doneGreen, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    .padding(34)
            }
            .frame(width: 120, height: 120)
            .padding(.bottom, 32)

            Group {
                Text("You're all set")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.bottom, 8)
                Text("Thanks for confirming it's you.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.4))
            }
            .opacity(textShown ? 1 : 0)
            .offset(y: textShown ? 0 : 8)

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.igBlue, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.45)) { ring = 1 }
            withAnimation(.easeOut(duration: 0.3).delay(0.4)) { tick = 1 }
            withAnimation(.easeOut(duration: 0.3).delay(0.6)) { textShown = true }
        }
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.12))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.12))
        return p
    }
}
