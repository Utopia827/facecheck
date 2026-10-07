import SwiftUI

struct IntroView: View {
    var onContinue: () -> Void

    private let igGradient = AngularGradient(
        colors: [
            Color(red: 0.99, green: 0.69, blue: 0.27),
            Color(red: 0.96, green: 0.29, blue: 0.36),
            Color(red: 0.84, green: 0.16, blue: 0.56),
            Color(red: 0.51, green: 0.23, blue: 0.81),
            Color(red: 0.99, green: 0.69, blue: 0.27),
        ],
        center: .center
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .stroke(igGradient, lineWidth: 5)
                    .frame(width: 148, height: 148)
                Circle()
                    .fill(Color(white: 0.96))
                    .frame(width: 128, height: 128)
                Image(systemName: "face.smiling")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 36)

            Text("Take a video selfie")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.black)
                .padding(.bottom, 10)

            Text("We'll ask you to turn your head in a few directions. This helps us confirm that you're a real person.")
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.4))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 20) {
                TipRow(symbol: "lightbulb", text: "Find a spot with good lighting")
                TipRow(symbol: "eyeglasses", text: "Take off glasses, hats or masks")
                TipRow(symbol: "iphone", text: "Hold your phone at eye level")
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.igBlue, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.bottom, 12)

            Text("Your video selfie is only used to confirm it's you.")
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.55))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .background(Color.white.ignoresSafeArea())
    }
}

private struct TipRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(.black)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.black)
        }
    }
}
