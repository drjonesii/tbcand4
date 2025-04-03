package test

import (
	"os"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/ec2"
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

	// Test NAT Gateway
	natGatewayID := terraform.Output(t, terraformOptions, "nat_gateway_id")
	assert.NotEmpty(t, natGatewayID, "NAT Gateway ID should not be empty")

	// Test VPC Flow Logs
	flowLogsID := terraform.Output(t, terraformOptions, "flow_logs_id")
	assert.NotEmpty(t, flowLogsID, "VPC Flow Logs ID should not be empty")

	// Test VPC Endpoints
	endpointIDs := terraform.OutputList(t, terraformOptions, "vpc_endpoint_ids")
	assert.NotEmpty(t, endpointIDs, "VPC Endpoint IDs should not be empty")

	// Verify required endpoints exist
	requiredEndpoints := []string{"ssm", "ec2messages", "ssmmessages"}
	ec2Client := aws.NewEc2Client(t, awsRegion)
	for _, endpoint := range requiredEndpoints {
		found := false
		for _, id := range endpointIDs {
			result, err := ec2Client.DescribeVpcEndpoints(&ec2.DescribeVpcEndpointsInput{
				VpcEndpointIds: []string{id},
			})
			assert.NoError(t, err)
			if len(result.VpcEndpoints) > 0 {
				serviceName := *result.VpcEndpoints[0].ServiceName
				if strings.Contains(serviceName, endpoint) {
					found = true
					break
				}
			}
		}
		assert.True(t, found, "Required VPC endpoint for %s should exist", endpoint)
	}

	// Test route tables
	publicRouteTableID := terraform.Output(t, terraformOptions, "public_route_table_id")
	assert.NotEmpty(t, publicRouteTableID, "Public route table ID should not be empty")

	privateRouteTableID := terraform.Output(t, terraformOptions, "private_route_table_id")
	assert.NotEmpty(t, privateRouteTableID, "Private route table ID should not be empty")

	// Verify route tables have correct routes
	publicSubnet := aws.GetSubnetById(t, publicSubnetIDs[0], awsRegion)
	assert.Equal(t, publicRouteTableID, *publicSubnet.RouteTableId, "Public subnet should be associated with public route table")

	privateSubnet := aws.GetSubnetById(t, privateSubnetIDs[0], awsRegion)
	assert.Equal(t, privateRouteTableID, *privateSubnet.RouteTableId, "Private subnet should be associated with private route table")
}
