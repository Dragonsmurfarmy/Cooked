import SwiftUI


struct RootView: View {
    @Environment(TimerViewModel.self) private var viewModel
    @Bindable var store: RecipeStore
    @State private var selectedTab: Tab = .home
    @State private var slideDirection: Edge = .trailing
    @State private var isVoiceRegimeActive = false
    @State private var isKeyboardVisible = false

    enum Tab: Int, Comparable {
        case timer = 0, home = 1, add = 2, settings = 3
        static func < (lhs: Tab, rhs: Tab) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var body: some View {
        ZStack(alignment: .bottom) { // Aligns the navbar to bottom

            Group {
                switch selectedTab {
                case .home:
                    NavigationStack { MainPageView(store: store) }
                case .timer:
                    NavigationStack { TimerView() }
                case .settings:
                    NavigationStack { SettingsView(store: store) }
                case .add:
                    NavigationStack {
                        RecipeFormView(store: store) { _ in
                            slideDirection = .leading
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTab = .home
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
            .id(selectedTab)
            .transition(.asymmetric(
                insertion: .move(edge: slideDirection),
                removal: .move(edge: slideDirection == .trailing ? .leading : .trailing)
            ))

            // Persistent Navbar
            if !isKeyboardVisible {
                VStack(spacing: 0) {
                    customBottomBar
                }
                .background(.thinMaterial)
                .background(ignoresSafeAreaEdges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }

            // Alarm Overlay
            if viewModel.isAlarmActive {
                AlarmOverlay()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .ignoresSafeArea(.keyboard) // Prevents the whole screen from jumping
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
            // Voice toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isVoiceRegimeActive.toggle()
                }
            } label: {
                NavigationBarButton(
                    titleKey: "navigation.voice_regime",
                    systemImage: isVoiceRegimeActive ? "mic.fill" : "mic",
                    isSelected: isVoiceRegimeActive
                )
            }
            .buttonStyle(.plain)

            tabButton(tab: .timer, title: "navigation.timer", icon: "timer")
            tabButton(tab: .home, title: "navigation.home", icon: "house.fill")
            tabButton(tab: .add, title: "navigation.add", icon: "plus")
            tabButton(tab: .settings, title: "navigation.settings", icon: "gearshape")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .clipShape(Capsule())
        .padding(.bottom, 10)
    }

    private func tabButton(tab: Tab, title: LocalizedStringKey, icon: String) -> some View {
        Button {
            if selectedTab != tab {
                slideDirection = tab > selectedTab ? .trailing : .leading
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = tab
                }
            }
        } label: {
            NavigationBarButton(titleKey: title, systemImage: icon, isSelected: selectedTab == tab)
        }
        .buttonStyle(.plain)
    }
}
