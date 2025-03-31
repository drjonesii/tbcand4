package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":     "10.0.0.0/16",
			"environment":  "test",
			"project_name": "turbot-assignment",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Get VPC ID
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID, "VPC ID should not be empty")

	// Get public subnet IDs
	publicSubnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Equal(t, 2, len(publicSubnetIDs), "Should have 2 public subnets")

	// Get public subnet CIDRs
	publicSubnetCIDRs := terraform.OutputList(t, terraformOptions, "public_subnet_cidrs")
	assert.Equal(t, 2, len(publicSubnetCIDRs), "Should have 2 public subnet CIDRs")

	// Verify subnet CIDRs are within VPC CIDR
	for _, cidr := range publicSubnetCIDRs {
		assert.Contains(t, cidr, "10.0.", "Subnet CIDR should be within VPC CIDR range")
	}
}
