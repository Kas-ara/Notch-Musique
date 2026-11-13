import SwiftUI

final class NotchLayout: ObservableObject {
    @Published var expanded = false
    @Published var width: CGFloat = 190
    @Published var height: CGFloat = 34
    @Published var renderActive = true
    var expandedWidth: CGFloat { max(340, width) }
    var expandedHeight: CGFloat { height + 133 }
    var hoverChanged: ((Bool) -> Void)?
}

// Tracé ouvert en haut : cette portion serait masquée par le bord de l’écran.
// La progression suit le côté gauche, le bas arrondi, puis le côté droit.
struct NotchContour: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(10.0, rect.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - r), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

struct NotchView: View {
    @ObservedObject var model: SpotifyModel
    @ObservedObject var layout: NotchLayout
    @ObservedObject var appearance: Appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var accent: Color { appearance.color }
    private var visualWidth: CGFloat { layout.expanded ? layout.expandedWidth : layout.width }
    private var visualHeight: CGFloat { layout.expanded ? layout.expandedHeight : layout.height }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if model.playing && layout.renderActive {
                    TimelineView(.periodic(from: .now, by: layout.expanded ? 1 : 0.5)) { context in
                        contour(at: context.date)
                    }
                } else {
                    contour(at: .now)
                }
            }
            .frame(width: visualWidth, height: visualHeight)

            if layout.expanded {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Group {
                            if let artwork = model.artwork {
                                Image(nsImage: artwork).resizable().scaledToFill()
                            } else {
                                ZStack {
                                    Color.white.opacity(0.08)
                                    Image(systemName: "music.note").foregroundStyle(accent)
                                }
                            }
                        }
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(model.artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.48)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    if let message = model.message {
                        Text(message).font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                    } else {
                        HStack(spacing: 20) {
                            Group {
                                if model.playing && layout.renderActive {
                                    TimelineView(.periodic(from: .now, by: 1)) { context in
                                        Text(model.times(at: context.date))
                                    }
                                } else {
                                    Text(model.times(at: .now))
                                }
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.40))
                            Spacer(minLength: 0)
                            control("backward.end.fill", label: "Morceau précédent", command: .previous)
                            control(model.playing ? "pause.fill" : "play.fill", label: model.playing ? "Pause" : "Lecture", command: .playpause)
                            control("forward.end.fill", label: "Morceau suivant", command: .next)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 15)
                .padding(.bottom, 20)
                .frame(width: layout.expandedWidth, height: 133, alignment: .top)
                .padding(.top, layout.height)
                .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.94, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onHover { layout.hoverChanged?($0) }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.9), value: layout.expanded)
    }

    private func contour(at date: Date) -> some View {
        ZStack {
            NotchBackground().fill(.black)
            NotchContour().stroke(.white.opacity(model.available ? 0.12 : 0.05), lineWidth: 1)
            NotchContour()
                .trim(from: 0, to: model.progress(at: date))
                .stroke(accent.opacity(model.playing ? 0.85 : 0.32), style: StrokeStyle(lineWidth: appearance.thickness, lineCap: .round))
        }
        .padding(.horizontal, appearance.thickness / 2 + 0.5)
        .padding(.bottom, appearance.thickness / 2 + 0.5)
    }

    private func control(_ symbol: String, label: String, command: SpotifyModel.Command) -> some View {
        Button { model.command(command) } label: {
            Image(systemName: symbol).font(.system(size: 13)).frame(width: 22, height: 25)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.available)
        .help(label)
        .accessibilityLabel(label)
    }
}

struct NotchBackground: Shape {
    func path(in rect: CGRect) -> Path {
        var p = NotchContour().path(in: rect)
        p.closeSubpath()
        return p
    }
}
