#!/usr/bin/env python
import sys
import warnings
import time

from calender.crew import Calender

warnings.filterwarnings("ignore", category=SyntaxWarning, module="pysbd")


def run(input_task):
    """
    Run the crew.
    """
    inputs = {
        'topic': input_task,
    }

    try:
        return Calender().crew().kickoff(inputs=inputs)

    except Exception as e:
        raise Exception(f"An error occurred while running the crew: {e}")


def train(input_task):
    """
    Train the crew for a given number of iterations.
    """
    inputs = {
        "topic": input_task,
    }
    try:
        Calender().crew().train(n_iterations=int(sys.argv[1]), filename=sys.argv[2], inputs=inputs)

    except Exception as e:
        raise Exception(f"An error occurred while training the crew: {e}")

def replay():
    """
    Replay the crew execution from a specific task.
    """
    try:
        Calender().crew().replay(task_id=sys.argv[1])

    except Exception as e:
        raise Exception(f"An error occurred while replaying the crew: {e}")

def test(input_task):
    """
    Test the crew execution and returns the results.
    """
    inputs = {
        "topic": input_task,
    }

    try:
        Calender().crew().test(n_iterations=int(sys.argv[1]), eval_llm=sys.argv[2], inputs=inputs)

    except Exception as e:
        raise Exception(f"An error occurred while testing the crew: {e}")

def run_with_trigger():
    """
    Run the crew with trigger payload.
    """
    import json

    if len(sys.argv) < 2:
        raise Exception("No trigger payload provided. Please provide JSON payload as argument.")

    try:
        trigger_payload = json.loads(sys.argv[1])
    except json.JSONDecodeError:
        raise Exception("Invalid JSON payload provided as argument")

    inputs = {
        "crewai_trigger_payload": trigger_payload,
        "topic": ""
    }

    try:
        result = Calender().crew().kickoff(inputs=inputs)
        return result
    except Exception as e:
        raise Exception(f"An error occurred while running the crew with trigger: {e}")



if __name__ == "__main__":

    input_task = """Module 2: Working with ggplot2 via R
After reading the first two chapters of Wickham's book
, please work through the exercises that he lists in Chapter 
2. For full credit, please post three screen shots or image files of your practice work by Sunday evening. Please feel free to post any questions you have about the exercises on this thread, or in the Community Forum. You are welcome to answer other students' 
questions if you have come across similar issues and found a way to work through the problem (this will count towards your three responses).
For practice assignments such as this one, points are awarded for completing the exercises and putting in the effort to do the work rather than for mastery of the work. Points are only deducted if the work is incomplete or does not fulfill the assignment.
Please also watch the following short video to learn more about my grading philosophy, especially with the GGplot2 assignments, which might feel really new and confusing at first.  
If you have questions or need help, please feel free to email me, and I look forward to seeing what you come up with this week."""

    print("Running crew...")
    start_time = time.time()
    run(input_task)
    end_time = time.time()
    # time in minute and second
    print(f"\nTime: {int((end_time - start_time) / 60)} minutes {int((end_time - start_time) % 60)} seconds")
    print("Crew run completed.")
