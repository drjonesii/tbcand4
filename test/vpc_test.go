package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
	awsRegion := os.Getenv("AWS_DEFAULT_REGION")
	if awsRegion == "" {
		awsRegion = "us-west-1"
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":     "10.0.0.0/16",
			"environment":  "test",
			"project_name": "turbot-assignment",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
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

	// Test core VPC outputs
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID, "VPC ID should not be empty")

	// Test subnet outputs
	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	assert.Equal(t, 2, len(privateSubnetIDs), "Should have 2 private subnets")

	publicSubnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Equal(t, 2, len(publicSubnetIDs), "Should have 2 public subnets")
}
