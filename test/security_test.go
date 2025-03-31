package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestSecurityModule(t *testing.T) {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/security",
		Vars: map[string]interface{}{
			"vpc_id":       "vpc-12345678", // Mock VPC ID for testing
			"environment":  "test",
			"project_name": "turbot-assignment",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Get security group ID
	sgID := terraform.Output(t, terraformOptions, "security_group_id")
	assert.NotEmpty(t, sgID, "Security group ID should not be empty")
}
