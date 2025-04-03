import os
import pytest
import json
import subprocess
from pathlib import Path

@pytest.fixture(scope="session")
def terraform_output():
    """Fixture to get Terraform output values."""
    # Get the project root directory
    project_root = Path(__file__).parent.parent
    
    try:
        # Run terraform output -json
        result = subprocess.run(
            ["terraform", "output", "-json"],
            cwd=project_root,
            capture_output=True,
            text=True,
            check=True
        )
        
        # Parse the JSON output
        output = json.loads(result.stdout)
        
        # Convert the output to a more usable format
        return {
            key: value.get("value")
            for key, value in output.items()
        }
        
    except subprocess.CalledProcessError as e:
        pytest.fail(f"Failed to get Terraform output: {e.stderr}")
    except json.JSONDecodeError as e:
        pytest.fail(f"Failed to parse Terraform output: {str(e)}")

@pytest.fixture(scope="session", autouse=True)
def setup_aws_credentials():
    """Fixture to ensure AWS credentials are set up."""
    required_vars = ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_DEFAULT_REGION"]
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        pytest.skip(f"Missing required AWS environment variables: {', '.join(missing_vars)}") 