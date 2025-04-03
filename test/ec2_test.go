package test

import (
	"os"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestEC2Module(t *testing.T) {
	// Get AWS region
	awsRegion := aws.GetRandomStableRegion(t, nil, nil)

	// Get AWS credentials from environment variables
	awsAccessKeyID := os.Getenv("AWS_ACCESS_KEY_ID")
	awsSecretAccessKey := os.Getenv("AWS_SECRET_ACCESS_KEY")

	// Verify AWS credentials are set
	if awsAccessKeyID == "" || awsSecretAccessKey == "" {
		t.Fatal("AWS credentials not found. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables.")
	}

	// First, create VPC and get its outputs
	vpcOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":     "10.0.0.0/16",
			"environment":  "test",
			"project_name": "turbot-assignment",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":    awsRegion,
			"AWS_ACCESS_KEY_ID":     awsAccessKeyID,
			"AWS_SECRET_ACCESS_KEY": awsSecretAccessKey,
		},
		Lock: false,
	})

	defer terraform.Destroy(t, vpcOptions)

	terraform.InitAndApply(t, vpcOptions)

	// Get VPC and subnet IDs
	vpcID := terraform.Output(t, vpcOptions, "vpc_id")
	privateSubnetIDs := terraform.OutputList(t, vpcOptions, "private_subnet_ids")
	assert.NotEmpty(t, privateSubnetIDs, "Should have at least one private subnet")

	// Now create EC2 instance
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/ec2",
		Vars: map[string]interface{}{
			"vpc_id":                  vpcID,
			"subnet_id":               privateSubnetIDs[0],
			"ami_id":                  "ami-0c55b159cbfafe1f0", // Amazon Linux 2 AMI
			"instance_type":           "t2.micro",
			"allowed_ssh_cidr_blocks": []string{"192.168.0.0/16"},
			"environment":             "test",
			"project_name":            "turbot-assignment",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":    awsRegion,
			"AWS_ACCESS_KEY_ID":     awsAccessKeyID,
			"AWS_SECRET_ACCESS_KEY": awsSecretAccessKey,
		},
		Lock: false,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Get instance ID
	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	assert.NotEmpty(t, instanceID, "Instance ID should not be empty")

	// Get instance private IP
	privateIP := terraform.Output(t, terraformOptions, "instance_private_ip")
	assert.NotEmpty(t, privateIP, "Private IP should not be empty")

	// Test SSM connectivity
	t.Log("Waiting for SSM agent to be ready...")
	aws.WaitForSsmInstance(t, awsRegion, instanceID, 10*time.Minute)

	// Test IAM role
	instanceProfile := terraform.Output(t, terraformOptions, "instance_profile_name")
	assert.NotEmpty(t, instanceProfile, "Instance profile name should not be empty")

	// Test security group
	securityGroupID := terraform.Output(t, terraformOptions, "security_group_id")
	assert.NotEmpty(t, securityGroupID, "Security group ID should not be empty")

	// Verify security group rules using AWS SDK
	ec2Client := aws.NewEc2Client(t, awsRegion)
	result, err := ec2Client.DescribeSecurityGroups(&ec2.DescribeSecurityGroupsInput{
		GroupIds: []string{securityGroupID},
	})
	assert.NoError(t, err)
	assert.Len(t, result.SecurityGroups, 1, "Should find exactly one security group")

	securityGroup := result.SecurityGroups[0]
	assert.Len(t, securityGroup.IpPermissions, 1, "Should have exactly one ingress rule")
	assert.Len(t, securityGroup.IpPermissionsEgress, 1, "Should have exactly one egress rule")

	// Verify ingress rule
	ingressRule := securityGroup.IpPermissions[0]
	assert.Equal(t, int32(22), *ingressRule.FromPort, "SSH port should be 22")
	assert.Equal(t, int32(22), *ingressRule.ToPort, "SSH port should be 22")
	assert.Equal(t, "tcp", *ingressRule.IpProtocol, "Protocol should be TCP")
	assert.Equal(t, []string{"192.168.0.0/16"}, ingressRule.IpRanges[0].CidrIp, "CIDR blocks should match")

	// Verify egress rule
	egressRule := securityGroup.IpPermissionsEgress[0]
	assert.Equal(t, int32(0), *egressRule.FromPort, "Egress from port should be 0")
	assert.Equal(t, int32(0), *egressRule.ToPort, "Egress to port should be 0")
	assert.Equal(t, "-1", *egressRule.IpProtocol, "Protocol should be all")
	assert.Equal(t, []string{"10.0.0.0/16"}, egressRule.IpRanges[0].CidrIp, "CIDR blocks should match VPC CIDR")
}
