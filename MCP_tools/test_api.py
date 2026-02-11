import urllib.request
import json
import os
import time

def test_api():
    url = "http://127.0.0.1:8000/run"
    
    # Try to read from input_task.txt if it exists
    task_content = "Plan a schedule for learning Rust next weekend."
    if os.path.exists("input_task.txt"):
        with open("input_task.txt", "r", encoding="utf-8") as f:
            content = f.read().strip()
            if content:
                task_content = content

    print(f"Sending task: {task_content[:50]}...")
    
    data = {"input_task": task_content}
    headers = {"Content-Type": "application/json"}

    try:
        req = urllib.request.Request(url, json.dumps(data).encode("utf-8"), headers)
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode("utf-8"))
            print("\n--- Success ---")
            print(json.dumps(result, indent=2))
    except urllib.error.URLError as e:
        print(f"\nError: Could not connect to API at {url}")
        print("Make sure the server is running: 'uvicorn api:app --reload'")
        print(f"Details: {e}")
    except Exception as e:
        print(f"\nAn error occurred: {e}")

if __name__ == "__main__":
    # test api time
    start_time = time.time()
    test_api()
    end_time = time.time()
    print(f"\nTotal time: {end_time - start_time} seconds")
