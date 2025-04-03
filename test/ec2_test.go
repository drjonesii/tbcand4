package test

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestEC2Module(t *testing.T) {
	// Get AWS region
	awsRegion := os.Getenv("AWS_DEFAULT_REGION")
	if awsRegion == "" {
		awsRegion = "us-west-2" // Default region
	}

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
			"vpc_id":        vpcID,
			"subnet_id":     privateSubnetIDs[0],
			"ami_id":        "ami-0c55b159cbfafe1f0", // Amazon Linux 2 AMI
			"instance_type": "t2.micro",
			"environment":   "test",
			"project_name":  "turbot-assignment",
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

	// Create AWS SDK v2 client
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(awsRegion),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(awsAccessKeyID, awsSecretAccessKey, "")),
	)
	assert.NoError(t, err)

	ec2Client := ec2.NewFromConfig(cfg)

	// Test SSM connectivity
	t.Log("Waiting for SSM agent to be ready...")
	// Wait for instance to be running
	maxAttempts := 30
	for i := 0; i < maxAttempts; i++ {
		result, err := ec2Client.DescribeInstances(context.TODO(), &ec2.DescribeInstancesInput{
			InstanceIds: []string{instanceID},
		})
		assert.NoError(t, err)
		assert.Len(t, result.Reservations, 1, "Should find exactly one reservation")
		assert.Len(t, result.Reservations[0].Instances, 1, "Should find exactly one instance")

		state := result.Reservations[0].Instances[0].State.Name
		if state == ec2types.InstanceStateNameRunning {
			break
		}
		if i == maxAttempts-1 {
			t.Fatal("Instance did not reach running state in time")
		}
		time.Sleep(10 * time.Second)
	}

	// Test IAM role
	instanceProfile := terraform.Output(t, terraformOptions, "instance_profile_name")
	assert.NotEmpty(t, instanceProfile, "Instance profile name should not be empty")

	// Test S3 access policy
	s3PolicyName := terraform.Output(t, terraformOptions, "s3_policy_name")
	assert.NotEmpty(t, s3PolicyName, "S3 policy name should not be empty")

	// Test security group
	securityGroupID := terraform.Output(t, terraformOptions, "security_group_id")
	assert.NotEmpty(t, securityGroupID, "Security group ID should not be empty")

	// Verify security group rules using AWS SDK
	result, err := ec2Client.DescribeSecurityGroups(context.TODO(), &ec2.DescribeSecurityGroupsInput{
		GroupIds: []string{securityGroupID},
	})
	assert.NoError(t, err)
	assert.Len(t, result.SecurityGroups, 1, "Should find exactly one security group")

	securityGroup := result.SecurityGroups[0]

	// Verify ingress rules
	assert.Len(t, securityGroup.IpPermissions, 1, "Should have exactly one ingress rule")
	ingressRule := securityGroup.IpPermissions[0]
	assert.Equal(t, int32(443), *ingressRule.FromPort, "SSM port should be 443")
	assert.Equal(t, int32(443), *ingressRule.ToPort, "SSM port should be 443")
	assert.Equal(t, "tcp", *ingressRule.IpProtocol, "Protocol should be TCP")

	// Verify egress rule
	assert.Len(t, securityGroup.IpPermissionsEgress, 1, "Should have exactly one egress rule")
	egressRule := securityGroup.IpPermissionsEgress[0]
	assert.Equal(t, int32(0), *egressRule.FromPort, "Egress from port should be 0")
	assert.Equal(t, int32(0), *egressRule.ToPort, "Egress to port should be 0")
	assert.Equal(t, "-1", *egressRule.IpProtocol, "Protocol should be all")
}
