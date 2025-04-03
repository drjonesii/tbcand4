package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
	// Get AWS region
	awsRegion := aws.GetRandomStableRegion(t, nil, nil)

	// Test variables
	vpcCIDR := "10.0.0.0/16"
	expectedSubnetCount := 2

	// Get AWS credentials from environment variables
	awsAccessKeyID := os.Getenv("AWS_ACCESS_KEY_ID")
	awsSecretAccessKey := os.Getenv("AWS_SECRET_ACCESS_KEY")

	// Verify AWS credentials are set
	if awsAccessKeyID == "" || awsSecretAccessKey == "" {
		t.Fatal("AWS credentials not found. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables.")
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":     vpcCIDR,
			"environment":  "test",
			"project_name": "turbot-assignment",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":    awsRegion,
			"AWS_ACCESS_KEY_ID":     awsAccessKeyID,
			"AWS_SECRET_ACCESS_KEY": awsSecretAccessKey,
		},
		Lock: false, // Disable state locking for testing
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Get VPC ID
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID, "VPC ID should not be empty")

	// Get public subnet IDs
	publicSubnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Equal(t, expectedSubnetCount, len(publicSubnetIDs), "Should have %d public subnets", expectedSubnetCount)

	// Get public subnet CIDRs
	publicSubnetCIDRs := terraform.OutputList(t, terraformOptions, "public_subnet_cidrs")
	assert.Equal(t, expectedSubnetCount, len(publicSubnetCIDRs), "Should have %d public subnet CIDRs", expectedSubnetCount)

	// Verify subnet CIDRs are within VPC CIDR
	for _, cidr := range publicSubnetCIDRs {
		assert.Contains(t, cidr, "10.0.", "Subnet CIDR should be within VPC CIDR range")
	}

	// Get private subnet IDs
	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	assert.Equal(t, expectedSubnetCount, len(privateSubnetIDs), "Should have %d private subnets", expectedSubnetCount)

	// Get private subnet CIDRs
	privateSubnetCIDRs := terraform.OutputList(t, terraformOptions, "private_subnet_cidrs")
	assert.Equal(t, expectedSubnetCount, len(privateSubnetCIDRs), "Should have %d private subnet CIDRs", expectedSubnetCount)

	// Verify private subnet CIDRs are within VPC CIDR
	for _, cidr := range privateSubnetCIDRs {
		assert.Contains(t, cidr, "10.0.", "Subnet CIDR should be within VPC CIDR range")
	}
}
