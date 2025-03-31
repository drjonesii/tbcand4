# Infrastructure Architecture

```mermaid
graph TD
    subgraph "VPC Module"
        VPC[VPC] --> IGW[Internet Gateway]
        IGW --> RT[Route Table]
        VPC --> Sub1[Public Subnet 1]
        VPC --> Sub2[Public Subnet 2]
        RT --> Sub1
        RT --> Sub2
    end

    subgraph "Security Module"
        SG[Security Group] --> VPC
    end

    subgraph "EC2 Module"
        EC2[EC2 Instance] --> Sub1
        EC2 --> SG
    end

    subgraph "S3 Module"
        StateBucket[S3 State Bucket] --> DynamoDB[DynamoDB Lock Table]
        CISBucket[CIS Report Bucket]
        EC2 --> CISBucket
    end

    subgraph "Terraform State"
        StateBucket --> TFState[Terraform State]
        DynamoDB --> TFState
    end

    style VPC fill:#f9f,stroke:#333,stroke-width:2px
    style EC2 fill:#bbf,stroke:#333,stroke-width:2px
    style SG fill:#bfb,stroke:#333,stroke-width:2px
    style StateBucket fill:#fbb,stroke:#333,stroke-width:2px
    style CISBucket fill:#fbb,stroke:#333,stroke-width:2px
```

## Resource Dependencies

1. **VPC Module**
   - VPC is the foundation for all networking
   - Internet Gateway provides internet connectivity
   - Route Table defines network routing
   - Public Subnets are created in different AZs

2. **Security Module**
   - Security Group depends on VPC
   - Defines inbound and outbound rules

3. **EC2 Module**
   - EC2 Instance depends on:
     - Public Subnet for network placement
     - Security Group for access control

4. **S3 Module**
   - State Bucket and DynamoDB for Terraform state management
   - CIS Report Bucket for storing benchmark results
   - EC2 Instance uploads reports to CIS Bucket

5. **Terraform State**
   - Managed by S3 and DynamoDB
   - Ensures state locking and versioning 