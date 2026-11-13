import AppKit
import SwiftUI

final class Appearance: ObservableObject {
    static let defaultColor = Color(red: 0.57, green: 0.79, blue: 0.65)
    @Published var thickness: Double {
        didSet { defaults.set(thickness, forKey: "contour.thickness"); geometryChanged?() }
    }
    // Réserve uniquement la place du trait et une marge technique d’un point.
    // L’ancien débordement indépendant n’est plus utilisé.
    var margin: Double { thickness + 1 }
    @Published var color: Color {
        didSet {
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            defaults.set([rgb.redComponent, rgb.greenComponent, rgb.blueComponent], forKey: "contour.color")
        }
    }
    var geometryChanged: (() -> Void)?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        thickness = min(4, max(1, defaults.object(forKey: "contour.thickness") as? Double ?? 2.2))
        if let rgb = defaults.array(forKey: "contour.color") as? [Double], rgb.count == 3,
           rgb.allSatisfy({ $0.isFinite && (0...1).contains($0) }) {
            color = Color(red: rgb[0], green: rgb[1], blue: rgb[2])
        } else {
            color = Self.defaultColor
        }
    }

    func reset() {
        thickness = 2.2
        color = Self.defaultColor
    }
}

struct AppearanceView: View {
    @ObservedObject var appearance: Appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Apparence du contour").font(.title2.weight(.semibold))
            Text("Les modifications s’appliquent immédiatement et sont conservées au prochain lancement.")
                .font(.callout).foregroundStyle(.secondary)
            ColorPicker("Couleur de progression", selection: $appearance.color, supportsOpacity: false)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Épaisseur du trait")
                    Spacer()
                    Text(String(format: "%.1f pt", appearance.thickness)).monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $appearance.thickness, in: 1...4, step: 0.1)
                    .accessibilityLabel("Épaisseur du trait")
            }
            Text("Le contour suit l’épaisseur du trait avec 1 point de marge. Les petites zones de chaque côté de l’encoche affichent la jaquette ou l’activité en cours.")
                .font(.callout).foregroundStyle(.secondary)
            Button("Rétablir les valeurs par défaut") { appearance.reset() }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(26)
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
    }
}
