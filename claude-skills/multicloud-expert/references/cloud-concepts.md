# Cloud Concepts & Cross-Cloud Architecture Mapping

## Core Architectural Equivalencies

| Conceptual Layer | AWS | Azure | GCP | OCI | AliCloud |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Hierarchy Boundary** | Account | Subscription | Project | Compartment | Member Account |
| **Virtual Network** | VPC | VNet | VPC | VCN | VPC |
| **Subnet Isolation** | Subnet (AZ-bound) | Subnet | Subnet (Region-wide) | Subnet (AD-bound) | Subnet |
| **Workload Identity** | IAM Role (IRSA/EKS) | Managed Identity | Workload Identity | Instance Principal | RAM Role |
| **Private Endpoint** | VPC Endpoint | Private Endpoint | Private Service Connect | Service Gateway | Private Endpoint |
| **Object Storage** | S3 | Blob Storage | Cloud Storage (GCS) | Object Storage | OSS |
| **Key Management** | KMS | Key Vault | Cloud KMS | OCI Vault | KMS |

## Universal Network & Identity Rules
1. **Zero-Trust Network Isolation:** Never expose raw database endpoints to public subnets. Keep database and cache workloads in private subnets with Cloud NAT / Egress Gateways.
2. **Workload Identity Over API Keys:** Never bake long-lived cloud API keys into container images or code repositories. Use OIDC federation (AWS IRSA, GCP Workload Identity, Azure Managed Identity).
3. **Cross-Region Replication Cost Trap:** Cross-region data transfer incurs explicit bandwidth billing across all CSPs. Keep compute and storage co-located within the same cloud region.
