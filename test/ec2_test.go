package test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestEC2Module(t *testing.T) {
	// Get AWS region
	awsRegion := aws.GetRandomStableRegion(t, nil, nil)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/ec2",
		Vars: map[string]interface{}{
			"vpc_id":                  "vpc-12345678",
			"subnet_id":               "subnet-12345678",
			"ami_id":                  "ami-0c55b159cbfafe1f0",
			"instance_type":           "t2.micro",
			"allowed_ssh_cidr_blocks": []string{"192.168.0.0/16"},
			"environment":             "test",
			"project_name":            "turbot-assignment",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
		Lock: false, // Disable state locking for testing
	})

	// Ensure we clean up resources after the test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
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
	aws.WaitForSsmInstance(t, awsRegion, instanceID, 10*time.Minute)
}
