# Coding Assistant (Google ADK + Amazon Bedrock + ECS Fargate)

A basic coding assistant: it writes code, runs it, reads the errors, and fixes them.

- **Agent framework:** Google ADK (`coding_agent/agent.py`)
- **Model:** Claude Haiku 4.5 on Amazon Bedrock, called through LiteLLM (set with `MODEL_ID`)
- **Tools:** `list_files`, `read_file`, `write_file`, `run_command`, all confined to a sandbox workspace
- **UI:** ADK's built-in web chat UI (`adk web`), with live traces of every tool call
- **Hosting:** ECS Fargate (ARM64, 0.5 vCPU / 1 GB), image in ECR, logs in CloudWatch, IAM task role limited to Bedrock invoke

```
Browser ──▶ ECS Fargate task (adk web :8000) ──▶ Amazon Bedrock (Claude)
                │  coding tools run inside the container
                └─▶ CloudWatch Logs
```

## Run
```bash
./run-local.sh     # local test at http://localhost:8000
./deploy.sh        # build → ECR → ECS; prints the public URL
./destroy.sh       # delete everything
```

## Configuration
No secrets are stored in this repo. AWS credentials come from your AWS CLI login locally and from the ECS task role in the cloud.
Your account ID, VPC, subnets and public IP are looked up at deploy time. See `.env.example`:

| Variable | Default | Purpose |
|---|---|---|
| `AWS_REGION` | `us-east-1` | Region for Bedrock and ECS |
| `MODEL_ID` | `bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0` | Bedrock model (LiteLLM format) |
| `WORKSPACE` | `./workspace` (local), `/tmp/workspace` (container) | Folder the file tools are confined to |

Prerequisites: AWS CLI logged in, Docker running, Bedrock model access enabled, Python 3.10+ with `pip install -r requirements.txt` in `.venv`.
