import os
import json
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request

# Configuration
GMAIL_SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CREDENTIALS_PATH = os.path.join(_SCRIPT_DIR, 'credentials.json')
_TOKENS_DIR = os.path.join(_SCRIPT_DIR, 'tokens')

def setup_auth(user_id="default"):
    """
    Runs the local server flow to authenticate the user and save the token.
    """
    print(f"Starting authentication for user: {user_id}")
    
    if not os.path.exists(CREDENTIALS_PATH):
        print(f"Error: credentials.json not found at {CREDENTIALS_PATH}")
        print("Please verify your Google Cloud credentials file.")
        return

    # Create tokens directory if it doesn't exist
    os.makedirs(_TOKENS_DIR, exist_ok=True)
    
    safe_id = user_id.replace('@', '_at_').replace('.', '_')
    token_path = os.path.join(_TOKENS_DIR, f'token_{safe_id}.json')

    creds = None
    # Load existing token if available
    if os.path.exists(token_path):
        try:
            creds = Credentials.from_authorized_user_file(token_path, GMAIL_SCOPES)
            print("Found existing token.")
        except Exception as e:
            print(f"Error loading existing token: {e}")

    # If valid, we are done
    if creds and creds.valid:
        print("Token is already valid!")
        return

    # If expired, try refresh
    if creds and creds.expired and creds.refresh_token:
        print("Token expired, refreshing...")
        try:
            creds.refresh(Request())
            print("Token refreshed successfully.")
        except Exception as e:
            print(f"Error refreshing token: {e}")
            creds = None

    # If still not valid, start new flow
    if not creds or not creds.valid:
        print("Launching browser for authentication...")
        flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_PATH, GMAIL_SCOPES)
        creds = flow.run_local_server(port=0)
        print("Authentication successful.")

    # Save the token
    with open(token_path, 'w') as token_file:
        token_file.write(creds.to_json())
    
    print(f"Token saved to: {token_path}")
    print("You can now restart your app and use Gmail features.")

if __name__ == "__main__":
    setup_auth()
