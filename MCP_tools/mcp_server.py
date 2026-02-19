import sys
import os
import json
import logging
import base64
from contextlib import redirect_stdout
from typing import Optional
from datetime import datetime

# Ensure src modules can be imported
sys.path.append(os.path.join(os.path.dirname(__file__), "src"))

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

from fastmcp import FastMCP
from calender.main import run

# Gmail API imports
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

# Setup logging to stderr so it doesn't interfere with stdout JSON-RPC
logging.basicConfig(stream=sys.stderr, level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger("mcp_server")

# Create the FastMCP server instance
mcp = FastMCP("CalendarMCPServer")

# Gmail API scopes (read-only)
GMAIL_SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']

# Paths for Gmail credentials (relative to this script)
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CREDENTIALS_PATH = os.path.join(_SCRIPT_DIR, 'credentials.json')
_TOKENS_DIR = os.path.join(_SCRIPT_DIR, 'tokens')


def _get_token_path(user_id: str) -> str:
    """Return the token file path for a specific app user."""
    os.makedirs(_TOKENS_DIR, exist_ok=True)
    safe_id = user_id.replace('@', '_at_').replace('.', '_')
    return os.path.join(_TOKENS_DIR, f'token_{safe_id}.json')


def _get_gmail_service(user_id: str = "default"):
    """Authenticate and return a Gmail API service instance for a specific app user."""
    token_path = _get_token_path(user_id)
    creds = None

    # Load existing token
    if os.path.exists(token_path):
        creds = Credentials.from_authorized_user_file(token_path, GMAIL_SCOPES)

    # Refresh or re-authenticate
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception as e:
                logger.error(f"Error refreshing token: {e}")
                raise Exception(
                    "Gmail authentication failed (refresh failed). "
                    "Please run `python3 MCP_tools/setup_auth.py` in your terminal to re-authenticate."
                )
        else:
            # DO NOT run local server here as it blocks the headless process
            raise Exception(
                "Gmail authentication required. "
                "Please run `python3 MCP_tools/setup_auth.py` in your terminal to authenticate."
            )

        # Save token for future use
        with open(token_path, 'w') as token_file:
            token_file.write(creds.to_json())

    return build('gmail', 'v1', credentials=creds)


@mcp.tool()
def task_and_schedule_planer(topic: str) -> str:
    """
    Plan and schedule tasks using the calendar crew agent.
    Use this for ANY task-related request including planning, scheduling, creating, or organizing tasks.

    Args:
        topic: The task description or query from the user
    """
    logger.info(f"Executing task_and_schedule_planer with topic: {topic}")
    
    try:
        # Execute the crew run function, redirecting stdout to stderr to prevent MCP JSON pollution
        with redirect_stdout(sys.stderr):
            result = run(topic)
        
        # The result from run() might be complex, ensure it's a string
        return str(result)
    except Exception as e:
        logger.error(f"Error executing tool: {e}")
        raise


@mcp.tool()
def check_gmail(query: str = "is:inbox", max_results: int = 10, user_id: str = "default") -> str:
    """
    Check Gmail inbox and return recent emails.
    Use this when the user wants to check, read, or search their email.

    Args:
        query: Gmail search query (e.g. 'is:unread', 'from:someone@example.com', 'is:inbox'). Defaults to 'is:inbox'.
        max_results: Maximum number of emails to return. Defaults to 10.
        user_id: The app user identifier to isolate Gmail tokens per account.
    """
    logger.info(f"Executing check_gmail for user='{user_id}' with query='{query}', max_results={max_results}")

    try:
        service = _get_gmail_service(user_id)

        # List messages matching the query
        results = service.users().messages().list(
            userId='me',
            q=query,
            maxResults=max_results,
        ).execute()

        messages = results.get('messages', [])

        if not messages:
            return json.dumps({"emails": [], "total": 0, "message": "No emails found matching your query."})

        email_list = []
        for msg_ref in messages:
            msg = service.users().messages().get(
                userId='me',
                id=msg_ref['id'],
                format='metadata',
                metadataHeaders=['Subject', 'From', 'Date', 'To'],
            ).execute()

            headers = {h['name']: h['value'] for h in msg.get('payload', {}).get('headers', [])}
            snippet = msg.get('snippet', '')
            labels = msg.get('labelIds', [])

            email_list.append({
                "id": msg_ref['id'],
                "subject": headers.get('Subject', '(No Subject)'),
                "from": headers.get('From', 'Unknown'),
                "to": headers.get('To', ''),
                "date": headers.get('Date', ''),
                "snippet": snippet,
                "is_unread": 'UNREAD' in labels,
            })

        return json.dumps({
            "emails": email_list,
            "total": len(email_list),
            "query": query,
        })

    except FileNotFoundError as e:
        return json.dumps({"error": str(e)})
    except Exception as e:
        logger.error(f"Error checking Gmail: {e}")
        return json.dumps({"error": f"Failed to check Gmail: {str(e)}"})


@mcp.tool()
def switch_gmail_account(user_id: str = "default") -> str:
    """
    Switch to a different Gmail account by clearing the saved authentication.
    Use this when the user wants to switch, change, or log out of their current Gmail account.
    After calling this, the next check_gmail call will prompt for a new Google login.

    Args:
        user_id: The app user identifier whose Gmail token should be cleared.
    """
    logger.info(f"Executing switch_gmail_account for user='{user_id}' - clearing saved token")

    try:
        token_path = _get_token_path(user_id)
        if os.path.exists(token_path):
            os.remove(token_path)
            return json.dumps({
                "status": "success",
                "message": "Gmail account disconnected. The next email check will prompt you to log in with a new account."
            })
        else:
            return json.dumps({
                "status": "success",
                "message": "No Gmail account was connected. The next email check will prompt you to log in."
            })
    except Exception as e:
        logger.error(f"Error switching Gmail account: {e}")
        return json.dumps({"error": f"Failed to switch account: {str(e)}"})


@mcp.tool()
def get_location() -> str:
    """
    Get the user's current precise location (latitude, longitude, city, country).
    Use this for context-aware recommendations, weather, or local time.
    """
    logger.info("Executing get_location")
    try:
        import httpx
        # Using ipapi.co for simple geolocation
        response = httpx.get("https://ipapi.co/json/", timeout=5.0)
        if response.status_code == 200:
            data = response.json()
            return json.dumps({
                "city": data.get("city"),
                "region": data.get("region"),
                "country": data.get("country_name"),
                "latitude": data.get("latitude"),
                "longitude": data.get("longitude"),
                "postal": data.get("postal"),
                "timezone": data.get("timezone")
            })
        return json.dumps({"error": "Failed to fetch location data"})
    except Exception as e:
        logger.error(f"Error getting location: {e}")
        return json.dumps({"error": str(e)})


@mcp.tool()
def get_weather(latitude: float, longitude: float) -> str:
    """
    Get the current weather and temperature for a specific location.
    
    Args:
        latitude: Latitude of the location.
        longitude: Longitude of the location.
    """
    logger.info(f"Executing get_weather for lat={latitude}, lon={longitude}")
    try:
        import httpx
        # Use open-meteo for free, no-key weather data
        url = f"https://api.open-meteo.com/v1/forecast?latitude={latitude}&longitude={longitude}&current_weather=true"
        response = httpx.get(url, timeout=5.0)
        
        if response.status_code == 200:
            data = response.json()
            current = data.get("current_weather", {})
            temp = current.get("temperature")
            code = current.get("weathercode")
            
            # Simple WMO Weather interpretation
            status_map = {
                0: "Clear sky",
                1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
                45: "Fog", 48: "Depositing rime fog",
                51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
                61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
                71: "Slight snow fall", 73: "Moderate snow fall", 75: "Heavy snow fall",
                77: "Snow grains",
                80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
                85: "Slight snow showers", 86: "Heavy snow showers",
                95: "Thunderstorm", 96: "Thunderstorm with slight hail", 99: "Thunderstorm with heavy hail"
            }
            
            status = status_map.get(code, "Clear")
            return json.dumps({
                "temperature": temp,
                "unit": "°C",
                "status": status,
                "weather_code": code
            })
        return json.dumps({"error": f"Failed to fetch weather: {response.status_code}"})
    except Exception as e:
        logger.error(f"Error getting weather: {e}")
        return json.dumps({"error": str(e)})


@mcp.tool()
def web_search(query: str) -> str:
    """
    Search the web for up-to-date information.
    Use this for news, weather, traffic, or general knowledge not in the personal knowledge base.

    Args:
        query: The search query string.
    """
    logger.info(f"Executing web_search for query: {query}")
    try:
        from duckduckgo_search import DDGS
        
        results = DDGS().text(query, max_results=5)
        
        if not results:
            return "No results found."
            
        summary = "Web Search Results:\n\n"
        for i, r in enumerate(results):
            title = r.get('title', 'No Title')
            link = r.get('href', '#')
            body = r.get('body', '')
            summary += f"{i+1}. {title}\n   Source: {link}\n   {body}\n\n"
            
        return summary
    except ImportError:
        return "Error: duckduckgo-search package not installed. Please run 'pip install duckduckgo-search'."
    except Exception as e:
        logger.error(f"Error searching web: {e}")
        return f"Error: {str(e)}"


@mcp.tool()
def create_project(name: str, description: str, color_hex: str = "#4F46E5", icon: str = "Folder") -> str:
    """
    Create a new project in the system.
    Use this when the user wants to organize a new area of their life or work.

    Args:
        name: Name of the project.
        description: Brief description of the project goal.
        color_hex: Primary color for the project UI in hex format (e.g., #FF5733).
        icon: Icon name for the project (e.g., Folder, Briefcase, GraduationCap).
    """
    logger.info(f"Generating project creation intent: {name}")
    # This tool returns an "intent" structure that the Flutter side will recognize and execute
    return json.dumps({
        "type": "create_project_intent",
        "name": name,
        "description": description,
        "color_hex": color_hex,
        "icon": icon,
        "timestamp": datetime.now().isoformat()
    })


if __name__ == "__main__":
    logger.info("Starting Calendar MCP Server (FastMCP)...")
    mcp.run()

