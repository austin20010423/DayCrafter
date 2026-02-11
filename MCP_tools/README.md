# Calender Crew

A **CrewAI**-powered project designed to intelligently deconstruct complex topics into actionable, prioritized tasks. This system leverages a team of AI agents to break down high-level goals, conduct external research, and create a strategic execution roadmap.

## 🤖 Agents

The crew consists of three specialized agents, each with a distinct role in the planning process:

1.  **Task Deconstructor** (`{topic} Operations Architect`)
    *   **Goal**: Deconstruct complex objectives into granular, manageable, and actionable sub-tasks.
    *   **Role**: Breaks down high-level goals into technical and operational steps to ensure no detail is missed.

2.  **Intelligence Scout** (`{topic} External Intelligence Lead`)
    *   **Goal**: Gather and synthesize relevant external data, links, and resources (papers, websites, etc.).
    *   **Role**: Finds high-value external context to validate internal projects and inform the team.

3.  **Strategic Prioritizer** (`{topic} Strategic Coordinator`)
    *   **Goal**: Rank tasks by impact, urgency, and feasibility to create an execution roadmap.
    *   **Role**: Optimizes the order of operations for maximum efficiency and creates the final schedule.

## 🛠️ Installation

**Prerequisites:**
*   Python **>=3.10 <3.14**
*   [UV](https://docs.astral.sh/uv/) (Dependency Manager)

1.  **Install uv** (if not already installed):
    ```bash
    pip install uv
    ```

2.  **Install dependencies**:
    Navigate to the project root and run:
    ```bash
    crewai install
    ```

3.  **Environment Setup**:
    Create a `.env` file in the root directory and add your OpenAI API key:
    ```env
    OPENAI_API_KEY=your_api_key_here
    ```
    *Note: You can duplicate `.env.example` if available.*

## 🚀 Usage

### 1. Running via CLI

To run the crew locally, you can use the `crewai` CLI. The project uses `input_task.txt` as the default input source when running the main script explicitly.

```bash
crewai run
```
*Note: Ensure you have your task defined in `src/calender/main.py` or `input_task.txt` depending on your setup.*

Alternatively, run the Python script directly (which reads from `input_task.txt`):
```bash
python src/calender/main.py
```

### 2. Running via API Server

This project includes a **FastAPI** server that allows you to trigger the crew remotely and integrate it into other applications.

1.  **Start the API server**:
    ```bash
    python api.py
    ```
    The server will start on `http://0.0.0.0:8000` (default port).

2.  **Run a Task**:
    Send a `POST` request to the `/run` endpoint with your task description.

    **Example using curl**:
    ```bash
    curl -X POST "http://localhost:8000/run" \
         -H "Content-Type: application/json" \
         -d '{"input_task": "Plan a marketing campaign for a new coffee brand"}'
    ```

    **Response**:
    The API will return the status and the result of the execution.

## 📂 Output

The final result, which includes the prioritized roadmap, is saved to:
`result/output.json`

**Example Output Format:**
```json
[
    {
        "dateOnCalender": "2023-10-27",
        "DueDate": "2023-11-01",
        "task": "Market Research Phase 1",
        "priority": 1,
        "links": "http://example.com/market-report",
        "Discription": "Analyze competitor landscape...",
        "TimeToComplete": 5
    }
]
```

## 📦 Project Structure

*   `src/calender/config/agents.yaml`: Configuration for the agents.
*   `src/calender/config/tasks.yaml`: Configuration for the tasks.
*   `src/calender/crew.py`: The main crew definition logic.
*   `src/calender/main.py`: Entry point for CLI execution.
*   `api.py`: FastAPI application entry point.
*   `input_task.txt`: Input file for local testing.
