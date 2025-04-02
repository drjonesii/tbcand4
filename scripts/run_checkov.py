#!/usr/bin/env python3
"""
Script to run Checkov against Terraform code.
This script provides a convenient way to run Checkov with predefined settings.
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Run Checkov against Terraform code")
    parser.add_argument(
        "--directory", "-d",
        default=".",
        help="Directory containing Terraform files (default: current directory)"
    )
    parser.add_argument(
        "--framework", "-f",
        default="terraform",
        choices=["terraform", "terraform_plan"],
        help="Framework to scan (default: terraform)"
    )
    parser.add_argument(
        "--output", "-o",
        default="cli",
        choices=["cli", "json", "junitxml", "html"],
        help="Output format (default: cli)"
    )
    parser.add_argument(
        "--output-file",
        help="Output file path (required for json, junitxml, html outputs)"
    )
    parser.add_argument(
        "--soft-fail",
        action="store_true",
        help="Exit with 0 even if there are findings"
    )
    parser.add_argument(
        "--skip-check",
        action="append",
        help="Skip specific checks (can be used multiple times)"
    )
    parser.add_argument(
        "--skip-path",
        action="append",
        help="Skip specific paths (can be used multiple times)"
    )
    return parser.parse_args()

def build_checkov_command(args):
    """Build the Checkov command based on arguments."""
    cmd = ["checkov", "-d", args.directory, "--framework", args.framework]
    
    if args.output != "cli":
        cmd.extend(["--output", args.output])
        if args.output_file:
            cmd.extend(["--output-file", args.output_file])
    
    if args.soft_fail:
        cmd.append("--soft-fail")
    
    if args.skip_check:
        for check in args.skip_check:
            cmd.extend(["--skip-check", check])
    
    if args.skip_path:
        for path in args.skip_path:
            cmd.extend(["--skip-path", path])
    
    return cmd

def main():
    """Main function to run Checkov."""
    args = parse_args()
    
    # Ensure the directory exists
    directory = Path(args.directory).resolve()
    if not directory.exists():
        print(f"Error: Directory '{directory}' does not exist.")
        sys.exit(1)
    
    # Build the command
    cmd = build_checkov_command(args)
    
    # Run Checkov
    try:
        result = subprocess.run(cmd, check=False)
        sys.exit(result.returncode)
    except subprocess.CalledProcessError as e:
        print(f"Error running Checkov: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nCheckov scan interrupted.")
        sys.exit(130)

if __name__ == "__main__":
    main() 