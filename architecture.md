# Infrastructure Architecture

## Resource Dependencies

```mermaid
graph TB
    subgraph "Primary Region"
        VPC[VPC]
        SG[Security Group]
        EC2[EC2 Instance]
        S3_State[S3 State Bucket]
        S3_CIS[S3 CIS Report Bucket]
        S3_Logs[S3 Access Logs]
        DynamoDB[DynamoDB Lock Table]
        KMS_S3[KMS Key - S3]
        KMS_DDB[KMS Key - DynamoDB]
        KMS_CW[KMS Key - CloudWatch]
        IAM_Role[IAM Replication Role]
        CW_Logs[CloudWatch Logs]
        Flow_Logs[VPC Flow Logs]
    end

    subgraph "DR Region"
        S3_State_Replica[S3 State Replica]
        S3_CIS_Replica[S3 CIS Report Replica]
        S3_Logs_Replica[S3 Access Logs Replica]
    end

    %% VPC Dependencies
    VPC --> SG
    SG --> EC2
    VPC --> Flow_Logs
    Flow_Logs --> CW_Logs
    KMS_CW --> CW_Logs

    %% State Management
    S3_State --> DynamoDB
    KMS_S3 --> S3_State
    KMS_DDB --> DynamoDB
    S3_State --> S3_Logs
    S3_CIS --> S3_Logs
    S3_State --> S3_State_Replica
    S3_CIS --> S3_CIS_Replica
    S3_Logs --> S3_Logs_Replica
    IAM_Role --> S3_State
    IAM_Role --> S3_State_Replica
    IAM_Role --> S3_CIS
    IAM_Role --> S3_CIS_Replica
    IAM_Role --> S3_Logs
    IAM_Role --> S3_Logs_Replica

    %% Security Features
    S3_State -.-> |"Encryption"| KMS_S3
    S3_State_Replica -.-> |"Encryption"| KMS_S3
    S3_CIS -.-> |"Encryption"| KMS_S3
    S3_CIS_Replica -.-> |"Encryption"| KMS_S3
    S3_Logs -.-> |"Encryption"| KMS_S3
    S3_Logs_Replica -.-> |"Encryption"| KMS_S3
    DynamoDB -.-> |"Encryption"| KMS_DDB
    S3_State -.-> |"Versioning"| S3_State
    S3_State_Replica -.-> |"Versioning"| S3_State_Replica
    S3_CIS -.-> |"Versioning"| S3_CIS
    S3_CIS_Replica -.-> |"Versioning"| S3_CIS_Replica
    S3_Logs -.-> |"Versioning"| S3_Logs
    S3_Logs_Replica -.-> |"Versioning"| S3_Logs_Replica
    EC2 -.-> |"IMDSv2"| EC2
    EC2 -.-> |"Monitoring"| EC2
```

## Security Features

### KMS Key Management
- Separate KMS keys for S3, DynamoDB, and CloudWatch
- Automatic key rotation enabled
- Custom key policies for access control

### S3 Bucket Protection
- Server-side encryption using customer-managed KMS keys
- Versioning enabled for data protection
- Public access blocks to prevent unauthorized access
- Access logging enabled for audit trails
- Cross-region replication for disaster recovery
- Self-logging for access logs bucket

### Network Security
- VPC Flow Logs with 1-year retention
- CloudWatch logs encrypted with KMS
- Private subnets for sensitive resources
- NAT Gateway for secure outbound access
- No automatic public IP assignment

### Instance Security
- IMDSv2 required with token-based access
- Detailed monitoring enabled
- EBS optimization enabled
- Root volume encryption
- Security group with least privilege
- Latest Amazon Linux 2 AMI

### State Management
- Remote state stored in S3 with encryption
- State locking using DynamoDB with encryption
- Separate KMS keys for different services
- Point-in-time recovery enabled for DynamoDB

### Access Control
- IAM roles with least privilege principle
- Separate roles for replication and access
- KMS key rotation enabled
- Resource tagging for tracking

### Monitoring and Audit
- VPC Flow Logs with 1-year retention
- S3 access logging enabled
- DynamoDB point-in-time recovery
- EC2 detailed monitoring
- Resource tagging for tracking
- Regular security scanning with tfsec 