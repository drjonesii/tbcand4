package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestS3Module(t *testing.T) {
	// Get AWS region from environment variable or use default
	awsRegion := os.Getenv("AWS_REGION")
	if awsRegion == "" {
		awsRegion = "us-west-1"
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "..",
		Vars: map[string]interface{}{
			"environment":  "test",
			"project_name": "turbot-assignment",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Get state bucket name
	stateBucketName := terraform.Output(t, terraformOptions, "terraform_state_bucket_name")
	assert.NotEmpty(t, stateBucketName, "State bucket name should not be empty")

	// Get CIS report bucket name
	cisBucketName := terraform.Output(t, terraformOptions, "cis_report_bucket_name")
	assert.NotEmpty(t, cisBucketName, "CIS report bucket name should not be empty")

	// Verify buckets exist
	aws.AssertS3BucketExists(t, awsRegion, stateBucketName)
	aws.AssertS3BucketExists(t, awsRegion, cisBucketName)
}
