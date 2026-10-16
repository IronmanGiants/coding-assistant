"""Basic coding assistant built with Google ADK, using Claude on Amazon Bedrock via LiteLLM."""
import os
import subprocess
from pathlib import Path

from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm

# Any Bedrock model LiteLLM supports, prefixed with "bedrock/".
MODEL_ID = os.getenv("MODEL_ID", "bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0")

# All file and shell access is confined to this folder.
WORKSPACE = Path(os.getenv("WORKSPACE", "/tmp/workspace")).resolve()
WORKSPACE.mkdir(parents=True, exist_ok=True)


def _safe_path(path: str) -> Path:
    p = (WORKSPACE / path).resolve()
    if p != WORKSPACE and WORKSPACE not in p.parents:
        raise ValueError(f"Path {path!r} is outside the workspace")
    return p


def list_files(path: str = ".") -> dict:
    """List files and folders in the workspace.

    Args:
        path: Folder relative to the workspace root.
    """
    try:
        root = _safe_path(path)
        files = sorted(str(p.relative_to(WORKSPACE)) for p in root.rglob("*") if p.is_file())
        return {"status": "success", "files": files[:200]}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def read_file(path: str) -> dict:
    """Read a text file from the workspace.

    Args:
        path: File path relative to the workspace root.
    """
    try:
        return {"status": "success", "content": _safe_path(path).read_text()[:20000]}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def write_file(path: str, content: str) -> dict:
    """Create or overwrite a file in the workspace.

    Args:
        path: File path relative to the workspace root.
        content: Full file content to write.
    """
    try:
        p = _safe_path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
        return {"status": "success", "message": f"Wrote {len(content)} chars to {path}"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def run_command(command: str) -> dict:
    """Run a shell command (e.g. `python main.py`, `pytest`) in the workspace. 60 second limit.

    Args:
        command: The shell command to run.
    """
    try:
        r = subprocess.run(command, shell=True, cwd=WORKSPACE, capture_output=True, text=True, timeout=60)
        return {"status": "success", "exit_code": r.returncode,
                "stdout": r.stdout[-8000:], "stderr": r.stderr[-8000:]}
    except subprocess.TimeoutExpired:
        return {"status": "error", "message": "Command timed out after 60 seconds"}


root_agent = Agent(
    name="coding_assistant",
    model=LiteLlm(model=MODEL_ID),
    description="A basic coding assistant that writes, runs and fixes code.",
    instruction="""You are a helpful coding assistant working in a sandboxed workspace folder.
- When asked to build something, write the code with write_file, then run it with run_command to verify it works.
- If it fails, read the error, fix the code and run it again.
- Use list_files and read_file to inspect existing code before changing it.
- Keep explanations short and show the final result.""",
    tools=[list_files, read_file, write_file, run_command],
)
