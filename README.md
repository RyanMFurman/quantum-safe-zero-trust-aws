
# Quantum-Safe Zero Trust Device Identity & Attestation System

> **Post-quantum ready device identity pipeline built on AWS with automated certificate lifecycle management and compliance monitoring**

## System Architecture Overview

Simple Architecture Diagram

1. High-Level System Architecture
This diagram shows how a device moves from the outside world into your secure AWS environment.

Code snippet

graph LR
    subgraph "External"
        D[IoT Device]
    end

    subgraph "Entry Point (API Layer)"
        AG[API Gateway]
        L_ON[Onboarding Lambda]
        L_AT[Attestation Lambda]
    end

    subgraph "Security & Identity"
        PCA[ACM Private CA]
        KMS[KMS Encryption]
        DDB[(Device Registry)]
    end

    subgraph "Storage"
        S3[Certificate Buckets]
    end

    %% Flow
    D -->|1. Enroll| AG
    AG --> L_ON
    L_ON -->|2. Issue Cert| PCA
    PCA -->|3. Save| S3
    L_ON -->|4. Log Identity| DDB
    
    D -->|5. Verify| AG
    AG --> L_AT
    L_AT -->|6. Check Status| DDB
    
    KMS -.->|Protects| S3
    KMS -.->|Protects| DDB

    style D fill:#f9f,stroke:#333,stroke-width:2px
    style AG fill:#bbf,stroke:#333,stroke-width:2px
    style PCA fill:#dfd,stroke:#333,stroke-width:2px
2. The "Hybrid" Identity (The Core Innovation)
This explains specifically what is happening inside the "Quantum-Safe" part of the diagram. It shows how we combine Old + New security.

Code snippet

graph TD
    subgraph "The Device's Key Bundle"
        K1[RSA Key: Works with Today's Tech]
        K2[Kyber Key: Resists Quantum Attacks]
    end

    K1 & K2 --> CSR[One Certificate Request]
    
    subgraph "The Identity Result"
        Cert[X.509 Digital Certificate]
        Ext[PQC Extension: OID 1.3.6.1.4.1...]
    end

    CSR -->|Signed by CA| Cert
    Cert -->|Contains| Ext
    Ext -->|Carries| K2

    style K2 fill:#ff9,stroke:#f66,stroke-width:3px
    style Ext fill:#ff9,stroke:#f66,stroke-width:3px
3. The "Challenge-Response" Flow
This is how the Attestation Lambda actually proves a device isn't an impostor.

Code snippet

sequenceDiagram
    autonumber
    participant Device
    participant Lambda
    participant DB as DynamoDB

    Device->>Lambda: "I want to connect"
    Lambda->>Device: Challenge: "Sign this random number"
    Device->>Device: Sign with Private Key
    Device->>Lambda: Send Signed Answer
    Lambda->>DB: Get Device's Public Key
    DB-->>Lambda: Public Key + PQC Status
    Lambda->>Lambda: Verify Signature
    Note over Lambda: If Match: Access Granted
    Lambda-->>Device: 200 OK (Verified)
4. Compliance State Machine
This diagram shows the "Lifecycle" of a device in your system.

Code snippet

stateDiagram-v2
    [*] --> Unregistered
    Unregistered --> Onboarding
    
    state Onboarding {
        direction LR
        CheckPQC --> HasKyber: Yes
        CheckPQC --> NoKyber: No
    }

    HasKyber --> PQC_Ready: Compliant
    NoKyber --> Legacy: Warning (Action Required)
    
    PQC_Ready --> Expired: Time passes
    Legacy --> Expired: Time passes
    Expired --> Onboarding: Renewal

**Built with AWS managed services, Terraform, and NIST-recommended post-quantum cryptography**

---

##  Overview

This project implements a **fully automated, enterprise-grade Zero Trust identity system** for IoT/device fleets using AWS managed services and post-quantum cryptography (PQC). 

The system provisions device credentials, validates PQC readiness, issues X.509 certificates via AWS ACM Private CA, performs cryptographic attestation challenges, and monitors compliance states across the device lifecycle.

**Key Innovation:** Embeds Kyber-512 post-quantum public keys as X.509 certificate extensions, enabling **hybrid cryptographic identity** that is quantum-resistant while remaining backward compatible with existing PKI infrastructure.

---

## Core Features

### Identity & Certificate Management
- **Device Onboarding API** - REST endpoints for secure device registration
- **Hybrid RSA + PQC Key Generation** - Kyber-512 post-quantum keys embedded in CSRs
- **Automated Certificate Issuance** - AWS ACM PCA integration with subordinate CA chain
- **Certificate Lifecycle Management** - S3-driven event pipeline for CSR processing

### Security & Compliance
-  **PQC Capability Detection** - Extracts and validates Kyber-512 public keys from certificate extensions
-  **Challenge-Response Attestation** - Cryptographic proof of device identity
-  **Compliance State Tracking** - Real-time classification (`pqc_ok` vs `legacy`)
-  **Zero Trust Architecture** - Least privilege IAM policies, KMS encryption, private subnets

### Observability
- **CloudWatch Dashboard** - Fleet-wide monitoring with custom PQC compliance metrics
- **Structured Logging** - Lambda execution traces with detailed CSR parsing output
- **Automated Alarms** - Error detection and notification for pipeline failures

---

##  Architecture

```mermaid
graph TB
    subgraph "Device Layer"
        Device[IoT Device]
    end
    
    subgraph "API Layer"
        APIGW[API Gateway]
        OnboardLambda[Onboard Lambda]
        AttestLambda[Attestation Lambda]
    end
    
    subgraph "Certificate Pipeline"
        S3[S3 CSR Bucket]
        IssuerLambda[Cert Issuer Lambda]
        PCA[ACM Private CA]
        S3Out[S3 Cert Bucket]
    end
    
    subgraph "Data & Monitoring"
        DDB[(DynamoDB<br/>Device Registry)]
        CW[CloudWatch<br/>Dashboard]
    end
    
    subgraph "Security"
        IAM[IAM Roles]
        KMS[KMS Keys]
    end
    
    Device -->|1. POST /onboard| APIGW
    APIGW --> OnboardLambda
    OnboardLambda -->|2. Upload CSR| S3
    S3 -->|3. S3 Event Trigger| IssuerLambda
    IssuerLambda -->|4. Issue Cert| PCA
    PCA -->|5. Certificate| IssuerLambda
    IssuerLambda -->|6. Store Cert| S3Out
    IssuerLambda -->|7. Update State| DDB
    
    Device -->|8. POST /attest| APIGW
    APIGW --> AttestLambda
    AttestLambda -->|9. Check State| DDB
    AttestLambda -->|10. Verify Signature| AttestLambda
    
    OnboardLambda -.->|Logs| CW
    IssuerLambda -.->|Logs + Metrics| CW
    AttestLambda -.->|Logs + Metrics| CW
    
    IAM -.->|Enforce Permissions| OnboardLambda
    IAM -.->|Enforce Permissions| IssuerLambda
    IAM -.->|Enforce Permissions| AttestLambda
    KMS -.->|Encrypt| S3
    KMS -.->|Encrypt| DDB
```

### Architecture Highlights

| Layer | Services | Purpose |
|-------|----------|---------|
| **API & Compute** | API Gateway, Lambda (Python 3.9) | RESTful device endpoints, serverless processing |
| **PKI** | ACM Private CA (Root + Subordinate) | Certificate authority hierarchy, cert issuance |
| **Cryptography** | KMS, Kyber-512 (liboqs) | Key management, PQC key generation |
| **Storage** | S3, DynamoDB | CSR/certificate artifacts, device compliance state |
| **Networking** | VPC, Private Subnets | Zero Trust network segmentation |
| **Observability** | CloudWatch Dashboards, Logs, Metrics | Real-time monitoring, custom PQC metrics |

---

## End-to-End Workflow

###  Device Onboarding
1. Device generates hybrid keypair (RSA-2048 + Kyber-512)
2. Device creates CSR with PQC public key embedded in X.509 extension (`1.3.6.1.4.1.2.267.7.6.5`)
3. CSR uploaded to S3 bucket via API Gateway `/onboard` endpoint
4. S3 event triggers `cert_issuer` Lambda
5. Lambda extracts PQC extension, validates Kyber-512 public key
6. Lambda calls ACM PCA `IssueCertificate` with custom template
7. Certificate saved to S3 output bucket
8. Device compliance state (`pqc_ok` or `legacy`) stored in DynamoDB
9. CloudWatch metrics emitted for compliance tracking

### Device Attestation
1. Device requests challenge via `/attest` endpoint
2. Lambda generates random challenge nonce
3. Device signs challenge using RSA private key
4. Lambda retrieves device state from DynamoDB
5. Lambda verifies signature using RSA public key from certificate
6. Lambda compares signature algorithm to compliance state
7. Returns attestation result (`pqc_ok` or `legacy` with reasoning)

### Compliance Monitoring
- CloudWatch dashboard displays:
  - **PQC Compliance Pie Chart** - Fleet-wide distribution of `pqc_ok` vs `legacy`
  - **Lambda Invocations** - Onboarding and attestation request rates
  - **Certificate Issuance** - ACM PCA metrics showing successful/failed cert creation
  - **API Gateway Errors** - 4xx/5xx response tracking
  - **DynamoDB Operations** - Read/write throughput and throttle detection

---

##  Technology Stack

### AWS Services
- **Compute**: Lambda (Python 3.9), API Gateway (REST)
- **PKI**: ACM Private CA (Root + Subordinate CA)
- **Storage**: S3 (CSR ingestion, certificate output), DynamoDB (device registry)
- **Security**: IAM (least privilege roles), KMS (hybrid RSA-ECC key), VPC (private subnets)
- **Monitoring**: CloudWatch (dashboards, logs, metrics, alarms)

### Cryptography
- **Classical**: RSA-2048 (CSR signing key)
- **Post-Quantum**: Kyber-512 (NIST Round 3 finalist, ML-KEM)
- **Libraries**: `liboqs`, `pqcrypto`, `cryptography`, `pyasn1`

### Infrastructure as Code
- **Terraform** - Modular design with separate dev/prod environments
- **Modules**: VPC, IAM, KMS, S3, Lambda, PCA, API Gateway, DynamoDB, CloudWatch

---

##  Project Structure

```
quantum-safe-zero-trust-aws/
├── modules/                       # Terraform modules (reusable infrastructure components)
│   ├── vpc/                       # VPC, subnets, route tables, security groups
│   ├── iam/                       # IAM roles and policies (device, admin, issuance)
│   ├── kms/                       # KMS hybrid RSA-ECC key for PCA signing
│   ├── s3/                        # S3 buckets (CSR input, certificate output)
│   ├── pca/                       # ACM Private CA (root + subordinate CA)
│   ├── lambda/                    # Onboarding Lambda function
│   ├── lambda_cert_issuer/        # Certificate issuance Lambda (CSR processor)
│   ├── attestation_validator/     # Attestation Lambda (challenge-response)
│   ├── apigw/                     # API Gateway REST API (/onboard, /attest)
│   ├── device_identity/           # DynamoDB table for device compliance state
│   ├── pqc/                       # PQC key generation utilities (Kyber-512)
│   └── pqc_monitoring/            # CloudWatch dashboard and alarms
│
├── envs/                          # Environment-specific configurations
│   ├── dev/                       # Development environment
│   │   ├── main.tf                # Root Terraform config (module orchestration)
│   │   ├── terraform.tfstate      # State file (local backend)
│   │   └── payload.json           # Test API payloads
│   └── prod/                      # Production environment (future)
└── README.md                      # This file
```

---

##  Quick Start

### Prerequisites
- AWS CLI configured with credentials (`aws configure`)
- Terraform >= 1.5
- Python 3.9+
- `liboqs` and `pqcrypto` libraries installed

### Deployment

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/quantum-safe-zero-trust-aws.git
   cd quantum-safe-zero-trust-aws
   ```

2. **Initialize Terraform**
   ```bash
   cd envs/dev
   terraform init
   ```

3. **Deploy infrastructure**
   ```bash
   terraform plan
   terraform apply -auto-approve
   ```

4. **Retrieve API Gateway endpoint**
   ```bash
   terraform output -json | jq -r '.api_gateway_url.value'
   ```

5. **Test device onboarding**
   ```bash
   cd ../../scripts
   python3 device_client.py --mode onboard --api-url <API_GATEWAY_URL>
   ```

6. **Test device attestation**
   ```bash
   python3 device_client.py --mode attest --api-url <API_GATEWAY_URL>
   ```

7. **View CloudWatch dashboard**
   - Navigate to CloudWatch console → Dashboards → `pqc-compliance-dashboard`

---

##  Testing & Validation

### Manual Testing
```bash
# Onboard a device
python3 scripts/device_client.py --mode onboard --device-id test-device-001

# Run attestation challenge
python3 scripts/device_client.py --mode attest --device-id test-device-001

# Check DynamoDB for device state
aws dynamodb get-item \
  --table-name quantum-device-registry \
  --key '{"device_id": {"S": "test-device-001"}}'
```

### Viewing Logs
```bash
# Onboarding Lambda logs
aws logs tail /aws/lambda/quantum-onboard-lambda --follow

# Certificate Issuer logs
aws logs tail /aws/lambda/quantum-cert-issuer-lambda --follow

# Attestation Lambda logs
aws logs tail /aws/lambda/quantum-attestation-lambda --follow
```

### Monitoring Metrics
Access the CloudWatch dashboard to view:
- Lambda invocation counts and error rates
- API Gateway request/response metrics
- PQC compliance distribution (pie chart)
- Certificate issuance success rates

---

## Sample Output

### Successful Onboarding
```json
{
  "statusCode": 200,
  "body": {
    "message": "Device onboarded successfully",
    "device_id": "test-device-001",
    "csr_uploaded": true,
    "certificate_arn": "arn:aws:acm-pca:us-east-1:123456789012:certificate-authority/abc123/certificate/xyz789",
    "compliance_state": "pqc_ok"
  }
}
```

### Successful Attestation
```json
{
  "statusCode": 200,
  "body": {
    "message": "Attestation successful",
    "device_id": "test-device-001",
    "challenge_verified": true,
    "compliance_state": "pqc_ok",
    "signature_algorithm": "RSA-PSS"
  }
}
```

### DynamoDB Device Record
```json
{
  "device_id": "test-device-001",
  "compliance_state": "pqc_ok",
  "pqc_pubkey_size": 800,
  "certificate_arn": "arn:aws:acm-pca:...",
  "last_attested": "2025-12-25T15:30:00Z",
  "onboarded_at": "2025-12-25T15:25:00Z"
}
```

---

## What I Learned

### Technical Skills Developed
- **AWS Multi-Service Integration** - Connecting API Gateway, Lambda, S3, DynamoDB, KMS, and ACM PCA with proper IAM permissions
- **X.509 Certificate Extensions** - Embedding custom data (PQC keys) in ASN.1 DER format
- **Post-Quantum Cryptography** - Practical implementation of Kyber-512 key encapsulation mechanism
- **Infrastructure as Code** - Modular Terraform design for reusable, environment-agnostic infrastructure
- **Zero Trust Architecture** - Least privilege IAM policies, private networking, encryption at rest/in-transit

### Debugging & Problem-Solving
- **API Gateway Integration Issues** - Fixed Lambda permission errors, request validators, and deployment stage propagation
- **ASN.1 Encoding Challenges** - Debugged PEM/DER encoding issues in CSR parsing
- **IAM Policy Complexity** - Resolved trust relationships, resource-based policies, and permission boundaries
- **CloudWatch Metrics** - Implemented custom metrics for PQC compliance tracking

### Security & Compliance Mindset
- **NIST SP 800-208 Alignment** - Followed NIST recommendations for PQC migration strategies
- **Compliance State Management** - Built audit trail for device cryptographic posture
- **Certificate Lifecycle Automation** - Eliminated manual PKI operations

---

## Future Enhancements

### Production Readiness
- [ ] Move secrets from S3 to AWS Secrets Manager
- [ ] Implement certificate rotation automation (EventBridge + Lambda)
- [ ] Add CloudHSM for hardware-backed key storage
- [ ] Enable CloudTrail for complete audit logging

### Security Hardening
- [ ] Implement API Gateway throttling and rate limiting
- [ ] Add AWS WAF for DDoS protection
- [ ] Use Dilithium/SPHINCS+ for PQC signature verification (not just Kyber KEMs)
- [ ] Add mutual TLS (mTLS) for device authentication

### Scalability
- [ ] Use Step Functions for orchestration (replace direct Lambda calls)
- [ ] Implement DynamoDB streams for event-driven compliance updates
- [ ] Add SQS/SNS for asynchronous CSR processing
- [ ] Multi-region deployment with Route 53 failover

### DevOps Maturity
- [ ] CI/CD pipeline (GitHub Actions or AWS CodePipeline)
- [ ] Automated testing (unit tests, integration tests with LocalStack)
- [ ] Infrastructure validation (Checkov, tfsec, Terraform Sentinel)
- [ ] Cost monitoring dashboards

---

##  Resources & References

### Standards & Specifications
- [NIST SP 800-208: Recommendation for Stateful Hash-Based Signature Schemes](https://csrc.nist.gov/publications/detail/sp/800-208/final)
- [NIST Post-Quantum Cryptography Standardization](https://csrc.nist.gov/projects/post-quantum-cryptography)
- [RFC 5280: Internet X.509 Public Key Infrastructure](https://www.rfc-editor.org/rfc/rfc5280)

### AWS Documentation
- [AWS Certificate Manager Private CA](https://docs.aws.amazon.com/acm-pca/latest/userguide/PcaWelcome.html)
- [AWS Lambda with Python](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)

### Cryptography Libraries
- [liboqs - Open Quantum Safe](https://github.com/open-quantum-safe/liboqs)
- [pqcrypto - Rust PQC Library](https://github.com/rustpq/pqcrypto)
- [pyca/cryptography](https://cryptography.io/en/latest/)

---

##  Contributing

This is a portfolio project, but feedback and suggestions are welcome! Feel free to:
- Open issues for bugs or feature requests
- Submit pull requests for improvements
- Share your own PQC implementation ideas

---

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Ryan Furman**
- LinkedIn: [linkedin.com/in/ryan-furman-594470314](https://linkedin.com/in/ryan-furman-594470314)
- Email: rfurman3803@gmail.com
- Location: Euless, TX

**Certifications:** CCNA, AWS Cloud Practitioner, ITIL 4 Foundation, CompTIA A+/Cloud+/Project+, LPI Linux Essentials

---

## Acknowledgments

- AWS for comprehensive managed services documentation
- Open Quantum Safe (OQS) project for `liboqs` library
- NIST for post-quantum cryptography standardization efforts
- Terraform community for IaC best practices

---

