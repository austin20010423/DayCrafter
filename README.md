# DayCrafter - AI Calendar Frontend

An AI-powered project management and calendar application built with Flutter.

## 🚀 Features

- **AI Project Manager**: Chat-based interface for project planning and task management
- **Multi-project Support**: Create and manage multiple projects with color-coded labels
- **Task Planning API**: Integration with backend task planning service
- **OpenAI Integration**: GPT-powered AI responses for project assistance
- **Animated UI**: Modern bouncing dots "Agent thinking" animation during API calls

## 📋 Prerequisites

- Flutter SDK ^3.10.4
- Dart SDK
- OpenAI API Key (for AI responses)
- Task Planning Backend Server (optional, runs on `http://127.0.0.1:8000`)

## 🛠️ Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd calendar_frontend

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## ⚙️ Configuration

### OpenAI API Key

The app requires an OpenAI API key for AI responses. Set it via environment variable when running:

```bash
flutter run --dart-define=OPENAI_API_KEY=your_actual_api_key_here
```

**Current Issue**: The app shows `"Failed to connect to AI service"` because the API key is not configured. Get your key from [OpenAI Platform](https://platform.openai.com/account/api-keys).

### Task Planning Backend

The app calls a task planning API at `http://127.0.0.1:8000/run`. Make sure your backend server is running if you want task cards to appear.

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point
├── models.dart            # Data models (Project, Message)
├── provider.dart          # State management (DayCrafterProvider)
├── styles.dart            # App styling constants
└── widgets/
    ├── chat_view.dart     # Main chat interface with thinking animation
    ├── empty_state.dart   # Empty state widget
    ├── header.dart        # App header
    ├── name_entry.dart    # User name entry screen
    ├── project_modal.dart # Project creation modal
    └── sidebar.dart       # Project sidebar navigation
```

## 🎨 Key Components

### Thinking Animation (`chat_view.dart`)
- `_BouncingDots`: Modern bouncing dots animation widget
- `_buildLoadingBubble()`: Shows "Agent thinking" with animation during API calls
- Animation triggers when `isLoading = true` in provider

### State Management (`provider.dart`)
- `sendMessage()`: Handles message sending and triggers API calls
- `_getTasks()`: Calls task planning backend
- `_getAiResponse()`: Calls OpenAI for AI responses
- `isLoading`: Boolean that controls the thinking animation

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Failed to connect to AI service" | Configure OpenAI API key via `--dart-define` |
| "Failed to connect to task planning service" | Start your backend on port 8000 |
| Animation not showing | Check that `isLoading` is being set in `sendMessage()` |

## 📦 Dependencies

- `provider` - State management
- `chat_gpt_sdk` - OpenAI integration  
- `http` - HTTP requests
- `lucide_icons` - Icon set
- `shared_preferences` - Local storage
- `table_calendar` - Calendar widget
- `glass_kit` / `liquid_glass_easy` - Glass UI effects

## 📝 License

This project is private and not published to pub.dev.
