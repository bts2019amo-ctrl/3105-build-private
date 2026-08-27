import SwiftUI





enum GamePatchVersion: String, CaseIterable, Identifiable {

    case normal

    case max



    var id: String { rawValue }



    var title: String {

        switch self {

        case .normal: return "FREE FIRE"

        case .max: return "FREE FIRE MAX"

        }

    }



    var subtitle: String {

        switch self {

        case .normal: return "Versão Normal"

        case .max: return "Versão MAX"

        }

    }



    var assetName: String {

        switch self {

        case .normal: return "free_fire_normal"

        case .max: return "free_fire_max"

        }

    }



    var accent: Color {

        switch self {

        case .normal: return AppTheme.accent

        case .max: return AppTheme.accent

        }

    }

}



struct GameSelectionView: View {

    var body: some View {

        NavigationStack {

            ScrollView(showsIndicators: false) {

                VStack(alignment: .leading, spacing: 22) {

                    VStack(alignment: .leading, spacing: 6) {

                        Text("HS")

                            .font(.system(size: 14, weight: .black, design: .rounded))

                            .tracking(2)

                            .foregroundStyle(AppTheme.accent)

                        Text("Escolha sua versão")

                            .font(.system(size: 30, weight: .black, design: .rounded))

                            .foregroundStyle(.white)

                        Text("Selecione o Free Fire para abrir somente os patches compatíveis.")

                            .font(.subheadline)

                            .foregroundStyle(.white.opacity(0.66))

                    }

                    .padding(.horizontal, 20)



                    VStack(spacing: 16) {

                        ForEach(GamePatchVersion.allCases) { version in

                            NavigationLink {

                                PatchProjectsView(gameFilter: version)

                            } label: {

                                GameVersionCard(version: version)

                            }

                            .buttonStyle(.plain)

                        }

                    }

                    .padding(.horizontal, 16)

                }

                .padding(.vertical, 24)

            }

            .background(Color.clear)

            .navigationTitle("HS")

            .navigationBarTitleDisplayMode(.inline)

            .preferredColorScheme(.dark)

            .toolbarColorScheme(.dark, for: .navigationBar)

        }

    }

}



private struct GameVersionCard: View {

    let version: GamePatchVersion

    @State private var isPressed = false



    var body: some View {

        HStack(spacing: 16) {

            ZStack {

                RoundedRectangle(cornerRadius: 24, style: .continuous)

                    .fill(version.accent.opacity(0.18))

                Image(version.assetName)

                    .resizable()

                    .scaledToFit()

                    .padding(10)

                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            }

            .frame(width: 92, height: 92)



            VStack(alignment: .leading, spacing: 6) {

                Text(version.title)

                    .font(.system(size: 19, weight: .black, design: .rounded))

                    .foregroundStyle(.white)

                Text(version.subtitle)

                    .font(.subheadline.weight(.semibold))

                    .foregroundStyle(version.accent)

                Text("Toque para ver os patches")

                    .font(.caption)

                    .foregroundStyle(.white.opacity(0.58))

            }

            Spacer()

            Image(systemName: "chevron.right")

                .font(.headline.weight(.bold))

                .foregroundStyle(version.accent)

        }

        .padding(16)

        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))

        .overlay {

            RoundedRectangle(cornerRadius: 30, style: .continuous)

                .stroke(version.accent.opacity(0.55), lineWidth: 1)

        }

        .shadow(color: version.accent.opacity(0.22), radius: 20, y: 10)

        .scaleEffect(isPressed ? 0.98 : 1)

        .animation(.easeOut(duration: 0.18), value: isPressed)

        .simultaneousGesture(

            DragGesture(minimumDistance: 0)

                .onChanged { _ in isPressed = true }

                .onEnded { _ in isPressed = false }

        )

    }

}



#Preview {

    GameSelectionView()

}

