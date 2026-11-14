"""Fail closed when an obligatory job did not succeed."""
import json
import os


def check(jobs):
    return bool(jobs) and all(job.get("result") == "success" for job in jobs.values())


if __name__ == "__main__":
    if not check(json.loads(os.environ["NEEDS_JSON"])):
        raise SystemExit("An obligatory job failed, was cancelled, or was skipped")
