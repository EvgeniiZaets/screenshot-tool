import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isCapturing = false
    @Published var hasPermission = CGPreflightScreenCaptureAccess()
    @Published var shortcutAvailable = true
}

struct HomeView: View {
    @ObservedObject var state: AppState
    let capture: () -> Void
    let openImage: () -> Void
    let openDemo: () -> Void
    let requestPermission: () -> Void
    @AppStorage("includeCursor") private var includeCursor = false
    @AppStorage("closeAfterCopy") private var closeAfterCopy = true
    @AppStorage("showWelcomeOnLaunch") private var showWelcomeOnLaunch = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "viewfinder").font(.system(size: 21, weight: .semibold)).foregroundStyle(Theme.accent)
                Text("screenshoter").font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                Text("MADE FOR MAC").font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.8).foregroundStyle(Theme.secondary)
            }
            .padding(.bottom, 26)

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("A little capture.\nA clearer point.")
                        .font(.system(size: 34, weight: .semibold)).tracking(-1.3).lineSpacing(0)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Grab a region. It’s copied instantly.\nClick the preview to add your thoughts.")
                        .font(.system(size: 13)).foregroundStyle(Theme.secondary).lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5) {
                        Text("Always a shortcut away").font(.system(size: 11)).foregroundStyle(Theme.secondary).padding(.trailing, 6)
                        KeyCap(title: "⇧"); KeyCap(title: "⌘"); KeyCap(title: "2")
                    }
                    .padding(.top, 8)
                }
                Spacer(minLength: 0)
                CaptureIllustration().frame(width: 180, height: 184)
            }

            HStack(spacing: 10) {
                Button(action: capture) {
                    HStack(spacing: 10) {
                        Image(systemName: "viewfinder")
                        Text(state.isCapturing ? "Preparing capture…" : "Capture a region")
                        Spacer()
                        Text("⇧⌘2").opacity(0.65)
                    }
                    .frame(width: 226)
                }
                .buttonStyle(AccentButtonStyle()).disabled(state.isCapturing)
                Button(action: openImage) { Label("Open image", systemImage: "photo") }
                    .buttonStyle(QuietButtonStyle())
                Button("Try editor", action: openDemo).buttonStyle(QuietButtonStyle())
            }
            .padding(.top, 22).padding(.bottom, 22)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: state.hasPermission ? "checkmark.shield" : "lock.shield")
                    .font(.system(size: 19)).foregroundStyle(state.hasPermission ? Theme.accent : Color.orange)
                VStack(alignment: .leading, spacing: 5) {
                    Text(state.hasPermission ? "Ready when you are" : "One permission, then you’re ready")
                        .font(.system(size: 12, weight: .semibold))
                    Text(state.hasPermission
                         ? "Screenshots stay on your Mac. Nothing is uploaded."
                         : "Allow Screen Recording to capture other apps.\nYou can try the editor without granting access.")
                        .font(.system(size: 11)).foregroundStyle(Theme.secondary).lineSpacing(3)
                }
                Spacer()
                if !state.hasPermission {
                    Button("Allow access", action: requestPermission).buttonStyle(QuietButtonStyle())
                }
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border))

            VStack(spacing: 12) {
                preference("Include the pointer in captures", isOn: $includeCursor)
                preference("Close the editor after copying", isOn: $closeAfterCopy)
                preference("Show this window at launch", isOn: $showWelcomeOnLaunch)
            }
            .padding(.top, 18)

            Spacer(minLength: 16)
            HStack {
                Circle().fill(Theme.accent).frame(width: 5, height: 5)
                Text("Lives in your menu bar").font(.system(size: 10)).foregroundStyle(Theme.secondary)
                Spacer()
                Text("CAPTURE  /  ANNOTATE  /  SHARE").font(.system(size: 9, design: .monospaced))
                    .tracking(1).foregroundStyle(Theme.secondary.opacity(0.7))
            }
            if !state.shortcutAvailable {
                Text("⇧⌘2 is in use by another app. Capture from the menu bar or the button above.")
                    .font(.system(size: 11)).foregroundStyle(.orange).padding(.top, 10)
            }
        }
        .padding(28).frame(width: 650, height: 680)
        .background(Theme.background).preferredColorScheme(.dark)
    }

    private func preference(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            Spacer()
            Toggle(title, isOn: isOn).labelsHidden()
                .toggleStyle(.switch).controlSize(.mini).tint(Theme.accent)
        }
    }
}

private struct CaptureIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border))
                .rotationEffect(.degrees(7)).padding(4)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { _ in Circle().fill(Theme.secondary.opacity(0.35)).frame(width: 5, height: 5) }
                    Spacer()
                }
                RoundedRectangle(cornerRadius: 4).fill(Theme.secondary.opacity(0.3)).frame(width: 60, height: 7)
                RoundedRectangle(cornerRadius: 3).fill(Theme.secondary.opacity(0.12)).frame(height: 5)
                RoundedRectangle(cornerRadius: 3).fill(Theme.secondary.opacity(0.12)).frame(width: 88, height: 5)
                HStack {
                    RoundedRectangle(cornerRadius: 5).fill(Theme.accent.opacity(0.13)).frame(width: 55, height: 28)
                    Spacer()
                    Image(systemName: "arrow.up.left").font(.system(size: 31, weight: .medium)).foregroundStyle(Theme.accent)
                }
            }
            .padding(18).background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .padding(10)
            Image(systemName: "cursorarrow").font(.system(size: 27, weight: .medium))
                .foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 4)
                .offset(x: 68, y: 75)
        }
        .accessibilityHidden(true)
    }
}
