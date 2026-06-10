//
//  Speech.swift
//  Cooked
//
//  Created by Tomáš Kříž on 20.04.2026.
//

import SwiftUI


struct RootView: View {
    @Environment(TimerViewModel.self) private var viewModel
    @Environment(\.scenePhase) private var scenePhase
    
    @Bindable var store: RecipeStore
    
    @State private var selectedTab: Tab = .home
    @State private var slideDirection: Edge = .trailing
    @State private var isVoiceRegimeActive = false
    @State private var selectedRecipe: Recipe?
    @State private var voiceController = VoiceController()
    @State private var hasShownVoiceRegimeInfo = false
    @State private var isShowingVoiceRegimeInfo = false
    @State private var isKeyboardVisible = false
    
    private let bottomBarReservedHeight: CGFloat = 200

    enum Tab: Int, Comparable {
        case timer = 0, home = 1, add = 2, settings = 3
        static func < (lhs: Tab, rhs: Tab) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        MainPageView(store: store)
                            .safeAreaPadding(.bottom, isKeyboardVisible ? 0 : bottomBarReservedHeight)
                            .navigationDestination(item: $selectedRecipe) { recipe in
                                RecipeDetailView(recipe: recipe, store: store)
                            }
                    }
                case .timer:
                    NavigationStack {
                        TimerView()
                            .safeAreaPadding(.bottom, isKeyboardVisible ? 0 : bottomBarReservedHeight)
                    }
                case .settings:
                    NavigationStack {
                        SettingsView(store: store)
                            .safeAreaPadding(.bottom, isKeyboardVisible ? 0 : bottomBarReservedHeight)
                    }
                case .add:
                    NavigationStack {
                        RecipeFormView(store: store) { _ in
                            slideDirection = .leading
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTab = .home
                            }
                        }
                        .safeAreaPadding(.bottom, isKeyboardVisible ? 0 : bottomBarReservedHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
            .id(selectedTab)
            .transition(.asymmetric(
                insertion: .move(edge: slideDirection),
                removal: .move(edge: slideDirection == .trailing ? .leading : .trailing)
            ))

            // Hide navbar when keyboard appears
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
            if (viewModel.isAlarmActive && scenePhase == .active) {
                AlarmOverlay()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .ignoresSafeArea(.keyboard)
        .environment(\.locale, Locale(identifier: store.currentLanguageIdentifier))
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeIn(duration: 0.2)) { isKeyboardVisible = false }
        }
        .onAppear {
            processPendingAppIntentCommands()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                processPendingAppIntentCommands()
            }
        }
    }

    private var customBottomBar: some View {
        HStack {
            // Voice toggle
            Button {
                if !hasShownVoiceRegimeInfo {
                    hasShownVoiceRegimeInfo = true
                    isShowingVoiceRegimeInfo = true
                }

                Task {
                    if !voiceController.isListening {
                        let granted = await voiceController.requestPermissions()
                        if granted {
                            voiceController.startListening()
                        }
                    } else {
                        voiceController.stopListening()
                    }
                }

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
        .onChange(of: voiceController.isListening) { _, listening in
            withAnimation { isVoiceRegimeActive = listening }
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

    private func processPendingAppIntentCommands() {
        if let recipeID = CookedAppIntentCommandStore.consumePendingOpenRecipeID() {
            openRecipe(id: recipeID)
        }

        if let seconds = CookedAppIntentCommandStore.consumePendingTimerSeconds() {
            setTimer(seconds: seconds)
        }
    }

    private func openRecipe(id: String) {
        guard let recipe = store.recipes.first(where: { $0.id.uuidString == id }) else { return }

        slideDirection = .leading
        selectedTab = .home
        selectedRecipe = recipe
    }

    private func setTimer(seconds: Int) {
        let duration = TimeInterval(max(seconds, 1))

        slideDirection = .trailing
        selectedTab = .timer
        viewModel.selectDuration(duration)
        viewModel.start()
    }
    
    
}
