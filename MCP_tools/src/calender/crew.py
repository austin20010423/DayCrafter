import mcp
from crewai import Agent, Crew, Process, Task, LLM
from crewai.project import CrewBase, agent, crew, task
from crewai.agents.agent_builder.base_agent import BaseAgent
from typing import List
from pydantic import BaseModel
import os



@CrewBase
class Calender():
    """Calender crew"""

    agents: List[BaseAgent]
    tasks: List[Task]

    @agent
    def calendar_manager(self) -> Agent:
        # Load preferences
        pref_path = 'knowledge/user_preference.txt'
        preferences = ""
        if os.path.exists(pref_path):
             with open(pref_path, 'r', encoding='utf-8') as f:
                 preferences = f.read()

        return Agent(
            config=self.agents_config['calendar_manager'], 
            backstory=self.agents_config['calendar_manager']['backstory'] + f"\n\nUSER PREFERENCES:\n{preferences}",
            mcps = [
                "crewai-amp:research-tools"
            ],
            cache=True,
            verbose=False
        )

    @task
    def execution_task(self) -> Task:
        return Task(
            config=self.tasks_config['execution_task'], 
        )

    @crew
    def crew(self) -> Crew:
        """Creates the Calender crew"""
       
        return Crew(
            agents=self.agents, 
            tasks=self.tasks, 
            process=Process.sequential,
            verbose=False
        )
