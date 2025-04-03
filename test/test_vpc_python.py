import pytest
import boto3
from botocore.exceptions import ClientError

def test_vpc_exists(terraform_output):
    """Test that the VPC exists and has the correct configuration."""
    ec2 = boto3.client('ec2')
    
    try:
        vpc = ec2.describe_vpcs(VpcIds=[terraform_output['vpc_id']])['Vpcs'][0]
        
        # Test VPC CIDR block
        assert vpc['CidrBlock'] == terraform_output['vpc_cidr']
        
        # Test VPC DNS settings
        assert vpc['EnableDnsHostnames'] is True
        assert vpc['EnableDnsSupport'] is True
        
        # Test VPC tags
        tags = {tag['Key']: tag['Value'] for tag in vpc['Tags']}
        assert tags['Name'] == f"{terraform_output['project_name']}-vpc"
        assert tags['Environment'] == terraform_output['environment']
        
    except ClientError as e:
        pytest.fail(f"Failed to describe VPC: {str(e)}")

def test_vpc_flow_logs_enabled(terraform_output):
    """Test that VPC Flow Logs are enabled."""
    ec2 = boto3.client('ec2')
    
    try:
        flow_logs = ec2.describe_flow_logs(
            Filter=[
                {
                    'Name': 'resource-id',
                    'Values': [terraform_output['vpc_id']]
                }
            ]
        )['FlowLogs']
        
        assert len(flow_logs) > 0
        assert flow_logs[0]['TrafficType'] == 'ALL'
        
    except ClientError as e:
        pytest.fail(f"Failed to describe flow logs: {str(e)}")

def test_vpc_public_subnets(terraform_output):
    """Test that public subnets exist and have correct configuration."""
    ec2 = boto3.client('ec2')
    
    try:
        for subnet_id in terraform_output['public_subnet_ids']:
            subnet = ec2.describe_subnets(SubnetIds=[subnet_id])['Subnets'][0]
            
            # Test subnet is in the VPC
            assert subnet['VpcId'] == terraform_output['vpc_id']
            
            # Test subnet has auto-assign public IP enabled
            assert subnet['MapPublicIpOnLaunch'] is True
            
            # Test subnet tags
            tags = {tag['Key']: tag['Value'] for tag in subnet['Tags']}
            assert tags['Name'].startswith(f"{terraform_output['project_name']}-public")
            assert tags['Environment'] == terraform_output['environment']
            
    except ClientError as e:
        pytest.fail(f"Failed to describe subnet: {str(e)}") 