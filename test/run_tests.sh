#!/bin/bash

# Check if AWS credentials are provided
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: AWS credentials not set"
    echo "Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
    echo "Example:"
    echo "export AWS_ACCESS_KEY_ID=your_access_key"
    echo "export AWS_SECRET_ACCESS_KEY=your_secret_key"
    exit 1
fi

# Set AWS region if not set
if [ -z "$AWS_DEFAULT_REGION" ]; then
    export AWS_DEFAULT_REGION="us-west-1"
fi

# Set environment to test
export TF_VAR_environment="test"

# Run the tests
go test -v ./... 