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
	// First create VPC
	vpcOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":     "10.0.0.0/16",
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

	defer terraform.Destroy(t, vpcOptions)
	terraform.InitAndApply(t, vpcOptions)

	vpcID := terraform.Output(t, vpcOptions, "vpc_id")
	privateSubnetIDs := terraform.OutputList(t, vpcOptions, "private_subnet_ids")

	// Then create EC2 instance
	ec2Options := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/ec2",
		Vars: map[string]interface{}{
			"vpc_id":        vpcID,
			"subnet_id":     privateSubnetIDs[0],
			"instance_type": "t3.micro",
			"environment":   "test",
			"project_name":  "turbot-assignment",
		},
		BackendConfig: map[string]interface{}{
			"bucket":       "tbcand4-terraform-state",
			"key":          "test/infrastructure/terraform.tfstate",
			"region":       "us-west-1",
			"encrypt":      true,
			"use_lockfile": true,
		},
	})

	defer terraform.Destroy(t, ec2Options)
	terraform.InitAndApply(t, ec2Options)

	// Test EC2 outputs
	instanceID := terraform.Output(t, ec2Options, "instance_id")
	assert.NotEmpty(t, instanceID, "Instance ID should not be empty")

	securityGroupID := terraform.Output(t, ec2Options, "security_group_id")
	assert.NotEmpty(t, securityGroupID, "Security group ID should not be empty")

	// Create AWS SDK v2 client
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(os.Getenv("AWS_DEFAULT_REGION")),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider("", "", "")),
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
	instanceProfile := terraform.Output(t, ec2Options, "instance_profile_name")
	assert.NotEmpty(t, instanceProfile, "Instance profile name should not be empty")

	// Test S3 access policy
	s3PolicyName := terraform.Output(t, ec2Options, "s3_policy_name")
	assert.NotEmpty(t, s3PolicyName, "S3 policy name should not be empty")

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
