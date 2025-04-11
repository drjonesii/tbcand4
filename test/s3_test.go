package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestS3Module(t *testing.T) {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/s3",
		Vars: map[string]interface{}{
			"environment":  "test",
			"project_name": "turbot-assignment",
		},
		BackendConfig: map[string]interface{}{
			"bucket":       "tbcand4-terraform-state",
			"key":          "test/infrastructure/terraform.tfstate",
			"region":       "us-west-1",
			"encrypt":      true,
			"use_lockfile": true,
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test state bucket
	stateBucketName := terraform.Output(t, terraformOptions, "terraform_state_bucket_name")
	assert.NotEmpty(t, stateBucketName, "State bucket name should not be empty")
}
