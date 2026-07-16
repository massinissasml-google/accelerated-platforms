# Cloud Workstations Reference Architecture

This document describes the reference architecture for deploying Cloud Workstations (CWS) for ComfyUI and creative workloads inside an enterprise environment, such as Canal+. It details identity federation, network layout, tenant project isolation, and integration with Vertex AI services.

## Architecture Diagram

The diagram below shows how the different projects, network components, and identity providers connect to provide a secure developer workspace:

```mermaid
graph TB
    subgraph External_Identity ["Identity Provider (External)"]
        Okta["Okta SSO (Canal+ IdP)"]
    end

    subgraph GCP_Org ["Google Cloud Organization"]
        CloudIdentity["Google Cloud Identity (Federated)"]
        
        subgraph Host_Project ["Network Host Project (Shared VPC)"]
            SharedVPC["Shared VPC Network"]
            Subnet["Workstations Subnet <br>(Private Google Access)"]
            CloudNAT["Cloud NAT / Cloud Router"]
            PSC_Vertex["Private Service Connect (PSC)<br>for Vertex AI"]
        end

        subgraph Service_Project ["CWS Service Project"]
            GWS_Cluster["Cloud Workstations Cluster"]
            GWS_Config_CPU["Workstation Config (CPU)"]
            GWS_Config_GPU["Workstation Config (GPU/Nvidia)"]
            
            AR["Artifact Registry <br>(comfyui-images)"]
            SecretManager["Secret Manager <br>(git-token, api-keys)"]
            CloudBuild["Cloud Build <br>(Image Compilation)"]
            GCS_Models["Cloud Storage <br>(comfyui-models)"]
        end

        subgraph Tenant_Project ["Google-Managed Tenant Project"]
            GWS_ControlPlane["GWS Control Plane"]
            GWS_VM_CPU["Workstation VM (CPU) <br>Runs ComfyUI Container"]
            GWS_VM_GPU["Workstation VM (GPU) <br>Runs ComfyUI Nvidia Container"]
            PD_User["Persistent Disk (/home) <br>(RETAIN policy)"]
        end
        
        subgraph AI_Services ["AI & ML Services"]
            VertexAI["Vertex AI Platform <br>(Gemini / Imagen 3 / Custom Endpoints)"]
        end
    end

    %% User Access Flow
    User["Developer / Creative User"] -->|1. Authenticate| Okta
    Okta -->|2. Assert Identity| CloudIdentity
    User -->|3. Access Workstation URL| IAP["Identity-Aware Proxy (IAP)"]
    IAP -->|4. Verify IAM Permissions| CloudIdentity
    IAP -->|5. Proxy Connection| GWS_ControlPlane
    GWS_ControlPlane -->|6. Connect| GWS_VM_CPU
    GWS_ControlPlane -->|6. Connect| GWS_VM_GPU

    %% Network & Peering
    GWS_VM_CPU -.->|VPC Peering| Subnet
    GWS_VM_GPU -.->|VPC Peering| Subnet
    GWS_VM_CPU === PD_User
    GWS_VM_GPU === PD_User

    %% Service Connections
    Subnet -->|Private Google Access| GCS_Models
    Subnet -->|Private Google Access| AR
    Subnet -->|Private Access via PSC| PSC_Vertex
    PSC_Vertex === VertexAI
    
    %% CI/CD flow
    CloudBuild -->|Pull base images / Push custom images| AR
    CloudBuild -->|Read secrets| SecretManager
    GWS_Config_CPU -->|Reference image| AR
    GWS_Config_GPU -->|Reference image| AR
```

## Architectural Design

### 1. Identity Federation (Okta & Cloud Identity)
* **Identity Provider (IdP)**: Corporate user accounts are managed in an external IdP (Okta). Okta is federated with Google Cloud Identity to enable single sign-on.
* **Identity-Aware Proxy (IAP)**: IAP acts as the gatekeeper for all workstation traffic. It intercepts requests, validates the federated credentials, checks IAM access permissions (`roles/workstations.user`), and forwards the connection.

### 2. Multi-Project and Peering Layout
* **Host Project (Shared VPC)**: Centralizes networking. The workstation VMs consume internal IP addresses in a Shared VPC subnet. 
  * **Private Google Access**: Configured on the subnet, allowing VMs to talk to Google APIs (such as Artifact Registry and Cloud Storage) privately without using external IP addresses.
* **Service Project**: Contains the workstation configurations and build pipelines.
* **Google-Managed Tenant Project**: Isolates GKE clusters and persistent storage volumes managed by Google. Network connectivity between the tenant VMs and the Shared VPC subnet is established automatically using VPC Network Peering.

### 3. Machine Learning (Vertex AI Integration)
* **API Access**: ComfyUI workloads execute API calls to Vertex AI models.
* **Private Service Connect (PSC)**: To maintain a completely private networking space, a PSC endpoint is deployed inside the Shared VPC. Vertex AI API traffic is directed to this endpoint, ensuring data never transits over the public internet.
* **Access Control**: Workstation service accounts are assigned the `roles/aiplatform.user` role to authenticate using Google Application Default Credentials (ADC).

---

For additional information on Cloud Workstations network security and deployment patterns, see:
* [Cloud Workstations architecture](https://cloud.google.com/workstations/docs/architecture)
* [Shared VPC overview](https://cloud.google.com/vpc/docs/shared-vpc)
* [Private Service Connect overview](https://cloud.google.com/vpc/docs/private-service-connect)

