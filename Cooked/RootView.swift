import SwiftUI


struct RootView: View {
    @Environment(TimerViewModel.self) private var viewModel
    @Bindable var store: RecipeStore
    @State private var selectedTab: Tab = .home // enum pro sledování aktivní záložky
    @State private var isKeyboardVisible = false

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
                        NavigationStack{
                            RecipeFormView(store: store) { _ in
                                selectedTab = .home
                            }
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("button.cancel") {
                                        selectedTab = .home
                                    }
                                }
                            }
                        }
                    case .voice:
                        Text("Voice Regime") //TBD
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if !isKeyboardVisible { // Appearance condition
                        customBottomBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }

            // ALARM OVERLAY (vždy úplně nahoře)
            if viewModel.isAlarmActive {
                AlarmOverlay()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1) // Jistota, že bude nad vším
            }
        }
        .environment(\.locale, Locale(identifier: store.currentLanguageIdentifier))
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeIn(duration: 0.2)) { isKeyboardVisible = false }
        }
    }

    
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
