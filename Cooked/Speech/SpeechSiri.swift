//
//  SpeechSiri.swift
//  Cooked
//
//  Created by Tomáš Kříž on 09.06.2026.
//

import AppIntents
import Foundation

// MARK: - Recipe Entities
struct RecipeAppEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe")
    static var defaultQuery = RecipeAppEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct RecipeAppEntityQuery: EntityStringQuery {
    func entities(for identifiers: [RecipeAppEntity.ID]) async throws -> [RecipeAppEntity] {
        let identifierSet = Set(identifiers)
        return loadRecipeEntities().filter { identifierSet.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [RecipeAppEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }

        return loadRecipeEntities().filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    func suggestedEntities() async throws -> [RecipeAppEntity] {
        loadRecipeEntities()
    }

    private func loadRecipeEntities() -> [RecipeAppEntity] {
        RecipeStore().recipes
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { RecipeAppEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

// MARK: - Timer Duration Enum
// ✅ This AppEnum completely satisfies the compiler macro requirements for phrase interpolation!
enum TimerDuration: Int, AppEnum {
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case twentyMinutes = 20
    case thirtyMinutes = 30
    case fortyFiveMinutes = 45
    case oneHour = 60

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Timer Duration"
    
    static var caseDisplayRepresentations: [TimerDuration: DisplayRepresentation] = [
        .fiveMinutes: "5 minutes",
        .tenMinutes: "10 minutes",
        .fifteenMinutes: "15 minutes",
        .twentyMinutes: "20 minutes",
        .thirtyMinutes: "30 minutes",
        .fortyFiveMinutes: "45 minutes",
        .oneHour: "1 hour"
    ]
}

// MARK: - Intents
struct OpenRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Recipe"
    static var description = IntentDescription("Opens a recipe in Cooked.")
    static var openAppWhenRun = true

    @Parameter(title: "Recipe")
    var recipe: RecipeAppEntity

    init() {
        self.recipe = RecipeAppEntity(id: "", name: "")
    }

    init(recipe: RecipeAppEntity) {
        self.recipe = recipe
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(recipe.id, forKey: "pending_app_intent_open_recipe_id")
        return .result(dialog: "Opening \(recipe.name)")
    }
}

struct SetCookingTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Cooking Timer"
    static var description = IntentDescription("Sets and starts the Cooked timer.")
    static var openAppWhenRun = true


    @Parameter(title: "Duration")
    var duration: TimerDuration

    init() {
        self.duration = .fiveMinutes
    }

    init(duration: TimerDuration) {
        self.duration = duration
    }

    func perform() async throws -> some IntentResult {
        // Extract the raw minutes integer value from our enum choice and convert to seconds
        let seconds = max(duration.rawValue * 60, 1)
        
        UserDefaults.standard.set(seconds, forKey: "pending_app_intent_timer_seconds")
        return .result(dialog: "Setting timer for \(formattedDuration(seconds: seconds))")
    }

    private func formattedDuration(seconds: Int) -> String {
        Duration.seconds(seconds).formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .wide, maximumUnitCount: 2)
        )
    }
}

// MARK: - Shortcuts
struct CookedShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenRecipeIntent(),
            phrases: [
                "Open \(\.$recipe) in \(.applicationName)",
                "Show \(\.$recipe) in \(.applicationName)"
            ],
            shortTitle: "Open Recipe",
            systemImageName: "book"
        )

        AppShortcut(
            intent: SetCookingTimerIntent(),
            phrases: [
                "Set \(.applicationName) timer for \(\.$duration)",
                "Start \(.applicationName) timer for \(\.$duration)"
            ],
            shortTitle: "Set Timer",
            systemImageName: "timer"
        )
    }
}

// MARK: - Command Store
enum CookedAppIntentCommandStore {
    static func consumePendingOpenRecipeID() -> String? {
        let key = "pending_app_intent_open_recipe_id"
        let value = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        return value
    }

    static func consumePendingTimerSeconds() -> Int? {
        let key = "pending_app_intent_timer_seconds"
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }

        let value = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        return value
    }
}
