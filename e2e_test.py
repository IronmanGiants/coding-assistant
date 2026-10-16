"""End-to-end test: runs root_agent locally against Bedrock and prints each step.

Usage:  .venv/bin/python e2e_test.py "your prompt here"
"""
import asyncio
import os
import sys
import warnings

warnings.filterwarnings("ignore")
os.environ.setdefault("AWS_REGION_NAME", "us-east-1")
os.environ.setdefault("WORKSPACE", os.path.join(os.path.dirname(__file__), "workspace"))

from google.adk.runners import InMemoryRunner
from google.genai import types

from coding_agent.agent import root_agent

PROMPT = sys.argv[1] if len(sys.argv) > 1 else "Write fib.py that prints the first 10 Fibonacci numbers, then run it."


async def main():
    runner = InMemoryRunner(agent=root_agent, app_name="e2e")
    session = await runner.session_service.create_session(app_name="e2e", user_id="tester")
    message = types.Content(role="user", parts=[types.Part(text=PROMPT)])

    async for event in runner.run_async(user_id="tester", session_id=session.id, new_message=message):
        for part in event.content.parts if event.content else []:
            if part.function_call:
                print(f"TOOL CALL   -> {part.function_call.name}({list(part.function_call.args)})")
            if part.function_response:
                print(f"TOOL RESULT <- {str(part.function_response.response)[:200]}")
            if part.text:
                print(f"REPLY: {part.text}")


asyncio.run(main())
