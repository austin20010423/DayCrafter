# DayCrafter - The AI Calendar

AI-powered Project Management and Calendar
## Features

- **AI Project Manager**: Chat-based interface for project planning and task management
- **Multi-project Support**: Create and manage multiple projects with color-coded labels
- **Smart Calendar**: Day, Week, and Month views with task scheduling
- **Task Scheduling**: Automatic priority-based task scheduling
- **Dark/Light Theme**: Morandi color palette with theme switching
- **Multi-language**: English and Traditional Chinese (繁體中文) support
- **OpenAI Integration**: GPT-powered AI responses for project assistance

## 📋 Prerequisites

- Flutter SDK ^3.10.4
- Dart SDK
- OpenAI API Key
- CrewAI Task Planning API: https://github.com/austin20010423/CrewAI-Calendar-API

---

## Installing Flutter on macOS

If you don't have Flutter installed, follow these steps:

### 1. Get the Flutter SDK

**Option A: Using Homebrew (Recommended)**
```bash
brew install --cask flutter
```

**Option B: Manual Download**
1. Download the latest stable release from [flutter.dev](https://docs.flutter.dev/get-started/install/macos).
2. Extract the file to your desired location (e.g., `~/development`):
   ```bash
   cd ~/development
   unzip ~/Downloads/flutter_macos_v3.x.x-stable.zip
   ```
3. Add the `flutter` tool to your path:
   ```bash
   export PATH="$PATH:`pwd`/flutter/bin"
   ```

### 2. iOS & macOS Platform Setup

To build this app for macOS or iOS, you need Xcode:

1. **Install Xcode**: Download from the Mac App Store.
2. **Configure Command Line Tools**:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
3. **Sign License Agreement**:
   ```bash
   sudo xcodebuild -license
   ```

### 3. Verify Installation

Run the following command to check if there are any dependencies you need to install:
```bash
flutter doctor
```

---

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/austin20010423/DayCrafter.git
cd DayCrafter
```

### Step 2: Install Flutter Dependencies

```bash
flutter pub get
```

### Step 3: Generate ObjectBox Database Model

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 4: Configure API Keys

Create a `.env` file in the project root:

```bash
touch .env
```

Add your API keys to the `.env` file:

```env
OPENAI_API_KEY=your_openai_api_key_here
```

> 💡 Get your OpenAI API key from [OpenAI Platform](https://platform.openai.com/account/api-keys)

### Step 5: Set Up the Backend API (Required)

Clone and run the CrewAI Task Planning API:

```bash
# In a separate terminal
git clone https://github.com/austin20010423/CrewAI-Calendar-API.git
cd CrewAI-Calendar-API

# Follow the setup instructions in that repository
# The API should run on http://127.0.0.1:8000
```

### Step 6: Run the Application

```bash
# For macOS
flutter run -d macos

# For Chrome (Web)
flutter run -d chrome

# For iOS Simulator
flutter run -d ios

# For Android Emulator
flutter run -d android
```

---

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `OPENAI_API_KEY` | Your OpenAI API key for AI responses | ✅ Yes |

### Backend API

The app connects to the following endpoints:

| Endpoint | URL | Description |
|----------|-----|-------------|
| Task Planning API | `http://127.0.0.1:8000/run` | CrewAI task generation |

---

## Key Dependencies

- `provider` - State management
- `objectbox` - Local NoSQL database with vector search
- `chat_gpt_sdk` - OpenAI integration
- `flutter_localizations` - i18n support
- `table_calendar` - Calendar widget
- `lucide_icons` - Icon set

---

