# Cooked

Cooked is a SwiftUI iOS recipe app with a built-in cooking timer, editable recipe library, category management, localization, and a Live Activity widget for timer progress.

## Technologies 
- SwiftUI (UI framework)

- ActivityKit (Live Activities)

- AVFoundation (Timer sounds)

- PhotosUI (Image picking)

## Supported Languages
- English
- Czech

## Features

- Browse recipes in compact or card layout
- Sort recipes by name or favorites
- Filter recipes by category
- Mark recipes as favorites
- Add, edit, and delete recipes
- Import and export recipe data as JSON
- Create custom categories in Settings
- Choose the app language and default portions
- Import custom timer sounds
- Run a cooking timer with play, pause, reset, and sound selection
- Show timer status through notifications and a Live Activity widget

## Project Structure

- `Cooked/` - main iOS app source
- `Cooked/Recipe/` - recipe models, storage, form, detail view, and image handling
- `Cooked/Timer/` - countdown timer, sound picker, and timer-related helpers
- `Cooked/Settings/` - app settings, categories, language, and import/export tools
- `CookedWidget/` - Live Activity widget for the timer
- `CookedTests/` - unit tests
- `CookedUITests/` - UI tests

## Data Storage

The app stores its data locally on device:

- recipes are saved as JSON files in the app Documents directory
- recipe images are stored as separate files in Documents
- settings are saved in UserDefaults
- timer draft data is also persisted locally so unfinished recipes can be restored

On first launch, bundled sample recipes are copied into the app Documents directory so they can be managed the same way as user-created recipes.

## Requirements

### Modifying and testing app
- Xcode
- iOS device or simulator capable of running the Cooked app target

### Using app
- iOS device (iPad/iPhone)

## Getting Started

1. Open `Cooked_app/Cooked.xcodeproj` in Xcode.
2. Select the `Cooked` scheme.
3. Build and run on a simulator or physical device.

## Notes

- The app requests notification permission at launch for timer alerts.
- The widget target provides a timer Live Activity on the Lock Screen and in Dynamic Island.
