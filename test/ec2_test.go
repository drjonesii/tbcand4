package test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestEC2Module(t *testing.T) {
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/ec2",
		Vars: map[string]interface{}{
			"vpc_id":          "vpc-12345678",                                 // Mock VPC ID
			"subnet_ids":      []string{"subnet-12345678", "subnet-87654321"}, // Mock subnet IDs
			"security_groups": []string{"sg-12345678"},                        // Mock security group ID
			"environment":     "test",
			"project_name":    "turbot-assignment",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Get instance ID
	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	assert.NotEmpty(t, instanceID, "Instance ID should not be empty")

	// Get instance public IP
	publicIP := terraform.Output(t, terraformOptions, "instance_public_ip")
	assert.NotEmpty(t, publicIP, "Public IP should not be empty")

	// Get instance private IP
	privateIP := terraform.Output(t, terraformOptions, "instance_private_ip")
	assert.NotEmpty(t, privateIP, "Private IP should not be empty")

	// Wait for instance to be running
	aws.WaitForSsmInstance(t, "us-west-1", instanceID, 10*time.Minute)
}
