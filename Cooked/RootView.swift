import SwiftUI


struct RootView: View {
    @Environment(TimerViewModel.self) private var viewModel
    @Bindable var store: RecipeStore
    @State private var selectedTab: Tab = .home // enum pro sledování aktivní záložky

    enum Tab {
        case voice, timer, home, add, settings
    }

    var body: some View {
        ZStack {
            // OBSAH PODLE ZVOLENÉHO TABU
            NavigationStack {
                Group {
                    switch selectedTab {
                    case .home:
                        MainPageView(store: store)
                    case .timer:
                        TimerView()
                    case .settings:
                        SettingsView(store: store)
                    case .add:
                        RecipeFormView(store: store) { newRecipe in
                            store.saveRecipe(newRecipe, newImageData: nil)
                            selectedTab = .home // po uložení se vrať domů
                        }
                    case .voice:
                        Text("Voice Regime") // Vaše budoucí view
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    // Tímto zajistíme, že panel nezakryje obsah ScrollView
                    customBottomBar
                }
            }

            // ALARM OVERLAY (vždy úplně nahoře)
            if viewModel.isAlarmActive {
                AlarmOverlay()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1) // Jistota, že bude nad vším
            }
        }
    }

    // PŘESUNUTÝ PANEL Z MAINPAGEVIEW
    private var customBottomBar: some View {
        HStack {
            tabButton(tab: .voice, title: "navigation.voice_regime", icon: "mic")
            tabButton(tab: .timer, title: "navigation.timer", icon: "timer")
            tabButton(tab: .home, title: "navigation.home", icon: "house.fill")
            tabButton(tab: .add, title: "navigation.add", icon: "plus")
            tabButton(tab: .settings, title: "navigation.settings", icon: "gearshape")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private func tabButton(tab: Tab, title: LocalizedStringKey, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            NavigationBarButton(titleKey: title, systemImage: icon, isSelected: selectedTab == tab)
        }
        .buttonStyle(.plain)
    }
}
