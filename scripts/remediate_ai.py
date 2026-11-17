import os
import json
import time

import requests
from openai import AzureOpenAI

# Configuration from environment variables
api_key = os.environ["AZURE_OPENAI_KEY"]
endpoint = os.environ["AZURE_OPENAI_ENDPOINT"]
deploy_name = os.environ["AZURE_OPENAI_DEPLOY"]
gh_token = os.environ["GITHUB_TOKEN"]
repo = os.environ["GITHUB_REPOSITORY"]
pr_number = os.environ.get("PR_NUMBER")

client = AzureOpenAI(
    api_key=api_key,
    azure_endpoint=endpoint,
    api_version="2025-04-01-preview",
)


def get_ai_fix(check_id, resource, file_path, guideline):
    """Ask Azure OpenAI for a fix for one Checkov finding."""
    prompt = (
        f"Checkov check {check_id} failed on resource '{resource}' in {file_path}.\n"
        f"Checkov guideline: {guideline}\n\n"
        "Provide a concise Terraform HCL fix with a brief explanation. "
        "Format your response as:\n"
        "**Issue:** <one line>\n"
        "**Fix:**\n```hcl\n<corrected block>\n```\n"
        "**Why this matters:** <one sentence>"
    )
    try:
        response = client.chat.completions.create(
            model=deploy_name,
            messages=[
                {"role": "system", "content": "You are a DevSecOps engineer specializing in Terraform and Azure security. Be concise and practical."},
                {"role": "user", "content": prompt},
            ],
            max_completion_tokens=2000,
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"AI API error for {check_id}: {e}")
        return None


def post_pr_comment(body):
    """Post a comment on the pull request."""
    url = f"https://api.github.com/repos/{repo}/issues/{pr_number}/comments"
    headers = {
        "Authorization": f"token {gh_token}",
        "Accept": "application/vnd.github.v3+json",
    }
    response = requests.post(url, headers=headers, json={"body": body}, timeout=15)
    if response.status_code == 201:
        print("PR comment posted.")
        return True
    print(f"Failed to post PR comment: {response.status_code} {response.text}")
    return False


def load_checkov_findings(path):
    """Load failed Checkov checks, one per unique check ID."""
    try:
        with open(path) as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Could not read {path}: {e}")
        return []

    # Checkov returns a list when it scans more than one framework
    if isinstance(data, list):
        data = data[0] if data else {}

    failed = data.get("results", {}).get("failed_checks", [])
    seen, unique = set(), []
    for check in failed:
        cid = check.get("check_id", "")
        if cid and cid not in seen:
            seen.add(cid)
            unique.append(check)
    return unique


def main():
    if not pr_number:
        print("No PR number, skipping comment.")
        return

    findings = load_checkov_findings("checkov-results.json")
    if not findings:
        print("No Checkov findings to process.")
        return

    print(f"Processing {len(findings)} unique finding(s)...")
    sections = [
        "## 🛡 AI Security Remediation\n",
        f"Checkov found **{len(findings)}** unique issue(s). Suggested fixes:\n\n---\n",
    ]

    for i, check in enumerate(findings[:5]):
        check_id = check.get("check_id", "UNKNOWN")
        resource = check.get("resource", "unknown")
        file_path = check.get("file_path", "unknown")
        guideline = check.get("guideline") or check_id

        print(f"  [{i + 1}] Asking AI about {check_id} on {resource}...")
        fix = get_ai_fix(check_id, resource, file_path, guideline)
        if fix:
            sections.append(f"### Finding {i + 1}: `{check_id}`\n")
            sections.append(f"**Resource:** `{resource}` in `{file_path}`\n\n")
            sections.append(fix + "\n\n---\n")
        time.sleep(1)

    if len(findings) > 5:
        sections.append(f"_...and {len(findings) - 5} more. Fix the above first._\n")

    post_pr_comment("".join(sections))


if __name__ == "__main__":
    main()