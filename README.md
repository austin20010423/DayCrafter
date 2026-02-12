# DayCrafter

An AI-powered calendar and project management application built with Flutter. DayCrafter combines conversational AI with structured task scheduling, Gmail integration, and multi-project organization into a single desktop and mobile experience.

---

## Features

### AI Chat Assistant

- Conversational interface powered by OpenAI GPT for managing tasks and answering questions
- Real-time streaming responses with Markdown rendering
- Web search integration for up-to-date information
- Context-aware short-term memory that retains conversation history per project
- Semantic search across messages and tasks using vector embeddings (ObjectBox HNSW)

### Task and Schedule Planning

- **Direct task creation**: Tell the AI to "add a meeting tomorrow at 2pm" and it creates the calendar event automatically
- **AI-powered planning**: Describe a complex project (e.g. "plan a 3-day conference") and the CrewAI-based MCP backend generates a structured task breakdown with priorities, deadlines, and time estimates
- **Priority levels**: High, Medium, and Low priority with color-coded indicators
- **Task detail editing**: Modify title, description, dates, and priority from a detail dialog

### Gmail Integration

- **Check email**: Ask the AI to check your inbox, search for specific emails, or filter by sender
- **Email summary**: The AI reads your emails and provides a natural language summary
- **Account switching**: Switch between Gmail accounts on the fly via conversational command
- **OAuth 2.0 authentication**: Secure Google sign-in with token refresh; no passwords stored

### Calendar Views

- **Day view**: Hourly time grid with task blocks positioned by start and end time
- **Week view**: 7-day column layout with time-based task rendering
- **Month view**: Traditional monthly grid with date selection and task indicators
- Smooth navigation between views with date-aware highlighting

### Project Management

- Create and manage multiple independent projects
- Each project has its own chat history, tasks, and calendar
- Color-coded project labels with customizable colors
- Emoji-based project icons via built-in emoji picker
- Project search and quick switching from the sidebar

### User Authentication

- Local account system with login, registration, and password recovery
- Password hashing with SHA-256
- Per-user project isolation

### Notifications

- In-app notification overlay for upcoming tasks and reminders
- Time-aware alerts with relative timestamps (e.g. "in 30 minutes")

### Search

- Full-text search across all messages in a project
- Semantic vector search for finding related content by meaning
- Task-specific search with filtering

### Settings and Customization

- **Theme**: Dark and Light mode with a Morandi-inspired color palette
- **Language**: English and Traditional Chinese (zh-TW)
- **Audio**: Sound effects for interactions

---

## Prerequisites

- Flutter SDK (Dart SDK ^3.10.4)
- Xcode (for macOS/iOS builds)
- Python 3.10+ with `uv` or `pip` (for the MCP backend)
- OpenAI API Key
- Google Cloud OAuth 2.0 credentials (for Gmail features)

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/austin20010423/DayCrafter.git
cd DayCrafter
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Generate ObjectBox Database Model

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Configure Flutter Environment

Create a `.env` file in the project root:

```bash
touch .env
```

Add your OpenAI API key:

```env
OPENAI_API_KEY=your_openai_api_key_here
```

Get your API key from the [OpenAI Platform](https://platform.openai.com/account/api-keys).

### 5. Set Up the MCP Backend

The MCP backend lives in the `MCP_tools/` directory and provides task planning and Gmail integration.

```bash
cd MCP_tools

# Create and activate a virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

Create the MCP backend `.env` file:

```bash
cp .env.example .env
```

Edit `MCP_tools/.env` and fill in your keys:

```env
MODEL=gpt-4.1-mini
OPENAI_API_KEY=your_openai_api_key_here
```

### 6. Set Up Gmail Integration (Optional)

To enable Gmail features (check email, switch accounts):

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create or select a project
2. Enable the **Gmail API**
3. Configure the **OAuth consent screen** (External type is fine; publish the app to remove test user restrictions)
4. Create an **OAuth 2.0 Client ID** (Application type: Desktop app)
5. Download the credentials JSON and save it as `MCP_tools/credentials.json`

On first use, the app will open a browser window for Google sign-in. A `token.json` file will be generated automatically for subsequent logins.

### 7. Run the Application

```bash
# Return to the project root
cd ..

# For macOS
flutter run -d macos

# For Chrome (Web)
flutter run -d chrome

# For iOS Simulator
flutter run -d ios

# For Android Emulator
flutter run -d android
```

The MCP backend server starts automatically when the Flutter app launches -- no separate terminal needed.

---

## Project Structure

```
DayCrafter/
├── lib/
│   ├── main.dart                 # App entry point and routing
│   ├── provider.dart             # Central state management (ChangeNotifier)
│   ├── models.dart               # Data models (Project, Message, Task)
│   ├── styles.dart               # Theme definitions and color palettes
│   ├── config/
│   │   └── tools_config.dart     # AI tool definitions (function calling)
│   ├── database/
│   │   └── objectbox_service.dart # ObjectBox database initialization
│   ├── l10n/                     # Localization files (EN, ZH-TW)
│   ├── services/
│   │   ├── audio_service.dart       # Sound effects
│   │   ├── embedding_service.dart   # Vector embedding for semantic search
│   │   ├── local_auth_service.dart  # Local user authentication
│   │   ├── short_term_memory.dart   # Conversation memory per project
│   │   └── task_scheduler.dart      # Priority-based task scheduling
│   └── widgets/
│       ├── auth/                 # Login, Register, Forgot Password screens
│       ├── calendar/             # Day, Week, Month calendar views
│       ├── chat_view.dart        # AI chat interface
│       ├── sidebar.dart          # Project navigation sidebar
│       ├── header.dart           # Top navigation bar
│       ├── settings_view.dart    # Settings panel
│       ├── search_overlay.dart   # Search functionality
│       ├── notification_overlay.dart # Task notifications
│       ├── add_task_dialog.dart   # Manual task creation dialog
│       └── task_detail_dialog.dart # Task detail and editing
├── MCP_tools/
│   ├── mcp_server.py             # FastMCP server (task planning + Gmail)
│   ├── src/calender/             # CrewAI agent definitions and configs
│   ├── credentials.json          # Google OAuth credentials (git-ignored)
│   ├── token.json                # Gmail auth token (git-ignored)
│   └── .env                      # Backend API keys (git-ignored)
└── pubspec.yaml
```

---

## Configuration

### Environment Variables

| Variable | Location | Description | Required |
|---|---|---|---|
| `OPENAI_API_KEY` | `.env` (root) | OpenAI API key for the Flutter frontend | Yes |
| `OPENAI_API_KEY` | `MCP_tools/.env` | OpenAI API key for the CrewAI backend | Yes |
| `MODEL` | `MCP_tools/.env` | OpenAI model name (e.g. `gpt-4.1-mini`) | Yes |

### AI Tools

The app registers the following AI tools via OpenAI function calling:

| Tool | Description |
|---|---|
| `add_calendar_task` | Directly create a task on the calendar with title, time, and priority |
| `task_and_schedule_planer` | Generate a structured task plan using CrewAI agents (MCP) |
| `check_gmail` | Retrieve and summarize recent emails from Gmail (MCP) |
| `switch_gmail_account` | Disconnect current Gmail and prompt re-authentication (MCP) |
| `web_search` | Search the web for real-time information |

---

## Key Dependencies

| Package | Purpose |
|---|---|
| `provider` | State management |
| `objectbox` | Local NoSQL database with vector search (HNSW) |
| `mcp_dart` | Model Context Protocol client for tool integration |
| `chat_gpt_sdk` | OpenAI GPT integration |
| `http` | HTTP client for API communication |
| `table_calendar` | Calendar widget |
| `flutter_markdown` | Markdown rendering in chat |
| `flutter_dotenv` | Environment variable loading |
| `emoji_picker_flutter` | Project icon selection |
| `crypto` | Password hashing |
| `lucide_icons` | Icon set |
| `glass_kit` / `liquid_glass_easy` | Glassmorphism UI effects |
| `window_manager` | Desktop window control |
| `timeago` | Relative time formatting |
| `flutter_colorpicker` | Project color customization |
| `shared_preferences` | Persistent user preferences |
| `path_provider` | File system access |

---

## License

This project is private and not published to pub.dev.
