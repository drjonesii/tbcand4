package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestS3Module(t *testing.T) {
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
	aws.AssertS3BucketExists(t, "us-west-1", stateBucketName)
	aws.AssertS3BucketExists(t, "us-west-1", cisBucketName)
}
