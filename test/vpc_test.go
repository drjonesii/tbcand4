package test

import (
	"context"
	"os"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
	// Get AWS region
	awsRegion := os.Getenv("AWS_DEFAULT_REGION")
	if awsRegion == "" {
		awsRegion = "us-west-2" // Default region
	}

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

	// Test S3 Endpoint
	s3EndpointID := terraform.Output(t, terraformOptions, "s3_endpoint_id")
	assert.NotEmpty(t, s3EndpointID, "S3 Endpoint ID should not be empty")

	s3EndpointDNSEntry := terraform.Output(t, terraformOptions, "s3_endpoint_dns_entry")
	assert.NotEmpty(t, s3EndpointDNSEntry, "S3 Endpoint DNS Entry should not be empty")

	// Create AWS SDK v2 client
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(awsRegion),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(awsAccessKeyID, awsSecretAccessKey, "")),
	)
	assert.NoError(t, err)

	ec2Client := ec2.NewFromConfig(cfg)

	// Verify S3 endpoint
	result, err := ec2Client.DescribeVpcEndpoints(context.TODO(), &ec2.DescribeVpcEndpointsInput{
		VpcEndpointIds: []string{s3EndpointID},
	})
	assert.NoError(t, err)
	assert.Len(t, result.VpcEndpoints, 1, "Should find exactly one S3 endpoint")

	s3Endpoint := result.VpcEndpoints[0]
	assert.Equal(t, "Gateway", string(s3Endpoint.VpcEndpointType), "S3 endpoint should be a Gateway endpoint")
	assert.True(t, strings.Contains(*s3Endpoint.ServiceName, "s3"), "Service name should contain 's3'")

	// Test route tables
	publicRouteTableID := terraform.Output(t, terraformOptions, "public_route_table_id")
	assert.NotEmpty(t, publicRouteTableID, "Public route table ID should not be empty")

	privateRouteTableID := terraform.Output(t, terraformOptions, "private_route_table_id")
	assert.NotEmpty(t, privateRouteTableID, "Private route table ID should not be empty")

	// Verify route tables have correct routes using AWS SDK
	publicRouteTable, err := ec2Client.DescribeRouteTables(context.TODO(), &ec2.DescribeRouteTablesInput{
		RouteTableIds: []string{publicRouteTableID},
	})
	assert.NoError(t, err)
	assert.Len(t, publicRouteTable.RouteTables, 1, "Should find exactly one public route table")

	// Check for internet gateway route
	foundIGWRoute := false
	for _, route := range publicRouteTable.RouteTables[0].Routes {
		if route.GatewayId != nil && *route.GatewayId == "igw-*" {
			foundIGWRoute = true
			break
		}
	}
	assert.True(t, foundIGWRoute, "Public route table should have a route to internet gateway")

	// Check for S3 gateway endpoint route in public route table
	foundS3Route := false
	for _, route := range publicRouteTable.RouteTables[0].Routes {
		if route.GatewayId != nil && strings.Contains(*route.GatewayId, "vpce-") {
			foundS3Route = true
			break
		}
	}
	assert.True(t, foundS3Route, "Public route table should have a route to S3 gateway endpoint")

	// Check private route table
	privateRouteTable, err := ec2Client.DescribeRouteTables(context.TODO(), &ec2.DescribeRouteTablesInput{
		RouteTableIds: []string{privateRouteTableID},
	})
	assert.NoError(t, err)
	assert.Len(t, privateRouteTable.RouteTables, 1, "Should find exactly one private route table")

	// Check for NAT gateway route
	foundNATRoute := false
	for _, route := range privateRouteTable.RouteTables[0].Routes {
		if route.NatGatewayId != nil && *route.NatGatewayId == natGatewayID {
			foundNATRoute = true
			break
		}
	}
	assert.True(t, foundNATRoute, "Private route table should have a route to NAT gateway")

	// Check for S3 gateway endpoint route in private route table
	foundS3Route = false
	for _, route := range privateRouteTable.RouteTables[0].Routes {
		if route.GatewayId != nil && strings.Contains(*route.GatewayId, "vpce-") {
			foundS3Route = true
			break
		}
	}
	assert.True(t, foundS3Route, "Private route table should have a route to S3 gateway endpoint")

	// Verify subnet associations
	publicSubnet, err := ec2Client.DescribeSubnets(context.TODO(), &ec2.DescribeSubnetsInput{
		SubnetIds: []string{publicSubnetIDs[0]},
	})
	assert.NoError(t, err)
	assert.Len(t, publicSubnet.Subnets, 1, "Should find exactly one public subnet")

	// Check public subnet route table association
	publicRouteTableAssoc, err := ec2Client.DescribeRouteTables(context.TODO(), &ec2.DescribeRouteTablesInput{
		Filters: []types.Filter{
			{
				Name:   aws.String("association.subnet-id"),
				Values: []string{publicSubnetIDs[0]},
			},
		},
	})
	assert.NoError(t, err)
	assert.Len(t, publicRouteTableAssoc.RouteTables, 1, "Should find exactly one route table for public subnet")
	assert.Equal(t, publicRouteTableID, *publicRouteTableAssoc.RouteTables[0].RouteTableId, "Public subnet should be associated with public route table")

	// Check private subnet route table association
	privateRouteTableAssoc, err := ec2Client.DescribeRouteTables(context.TODO(), &ec2.DescribeRouteTablesInput{
		Filters: []types.Filter{
			{
				Name:   aws.String("association.subnet-id"),
				Values: []string{privateSubnetIDs[0]},
			},
		},
	})
	assert.NoError(t, err)
	assert.Len(t, privateRouteTableAssoc.RouteTables, 1, "Should find exactly one route table for private subnet")
	assert.Equal(t, privateRouteTableID, *privateRouteTableAssoc.RouteTables[0].RouteTableId, "Private subnet should be associated with private route table")
}
