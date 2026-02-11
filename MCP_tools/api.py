import sys
import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv
from typing import Optional, Dict, Any
import uuid

# Ensure src modules can be imported
sys.path.append(os.path.join(os.path.dirname(__file__), "src"))

# Load environment variables
load_dotenv()

from calender.main import run

app = FastAPI(title="Calendar Agent API", description="API for scheduling tasks using CrewAI agents.")

class TaskRequest(BaseModel):
    input_task: str


class MCPRequest(BaseModel):
    # Accept either a simple input string or a dict of inputs
    input: Optional[str] = None
    inputs: Optional[Dict[str, Any]] = None


def _extract_input_from_mcp(req: MCPRequest) -> str:
    # Priority: input -> inputs.topic -> inputs.input_task -> inputs.get('topic')
    if req.input:
        return req.input
    if req.inputs:
        # common keys used in this repo
        for key in ("topic", "input_task", "task", "text"):
            if key in req.inputs:
                return str(req.inputs[key])
        # fallback to the stringified inputs
        return str(req.inputs)
    raise ValueError("No input provided in MCP request")

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/run")
async def run_task(request: TaskRequest):
    """
    Run the calendar crew with a given task.
    """
    try:
        # result is likely a string or a CrewOutput object. 
        # API requires a serializable format.
        result = run(request.input_task)
        
        # If result is complex, we might need to str() it or extract logic
        return {"status": "success", "result": str(result)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/mcp/invoke")
async def mcp_invoke(request: MCPRequest):
    """
    Minimal MCP-compatible invoke endpoint.

    Expected JSON examples:
    - {"input": "Schedule a meeting..."}
    - {"inputs": {"topic": "Schedule a meeting..."}}
    """
    try:
        input_text = _extract_input_from_mcp(request)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        result = run(input_text)

        response = {
            "mcp_version": "1.0",
            "id": str(uuid.uuid4()),
            "outputs": {
                "type": "json",
                "content": {
                    "status": "success",
                    "result": str(result),
                },
            },
        }

        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    host = os.getenv("API_HOST", "0.0.0.0")
    port = int(os.getenv("API_PORT", 8000))
    uvicorn.run(app, host=host, port=port)
