# F5 XC Multi-Cloud Network (MCN) Core Terraform

Terraform configuration that deploys the **core F5 Distributed Cloud (XC) Multi-Cloud Network fabric** and optionally provisions Customer Edge (CE) nodes in AWS GovCloud and Azure Government.

## Glossary

| Term | Meaning |
|------|---------|
| **CE** (Customer Edge) | A virtual machine running the F5 XC software, deployed in your cloud environment. It connects your workloads to the F5 XC global network. |
| **RE** (Regional Edge) | F5-managed PoPs (Points of Presence) that form the XC global backbone. CEs connect to REs for control-plane management and, optionally, data-plane routing. |
| **SLO** (Site Local Outside) | The CE's **outside** network interface (`eth0`). Faces the internet and is used for tunnels to REs and other CEs. |
| **SLI** (Site Local Inside) | The CE's **inside** network interface (`eth1`). Faces your private workload network (LAN). |
| **SMSv2** (Secure Mesh Site v2) | The current-generation XC site type used for CE deployments. |
| **Day-2** | Configuration that can only be applied *after* the CE has booted, registered, and come online — not during initial creation. |

## Concepts

### Site Mesh Groups

A [Site Mesh Group](https://docs.cloud.f5.com/docs-v2/platform/concepts/site) enables direct site-to-site connectivity between CE nodes **without routing traffic through F5 Regional Edges (REs)**. Sites in a mesh group build IPsec or SSL tunnels directly between each other over the SLO (outside) interface.

This module creates a **full mesh** with **data-plane only** connectivity — meaning all member sites can exchange workload traffic directly, but control-plane operations still flow through the REs. Sites are selected into the mesh via a label + virtual site selector pattern.

### Network Segments

[Network Segments](https://docs.cloud.f5.com/docs-v2/multi-cloud-network-connect/how-tos/networking/segmentation) provide logical network isolation across the MCN fabric. A segment extends a consistent network boundary across multiple CE sites — workloads on the same segment at different sites can communicate over the mesh, while workloads on different segments are isolated.

Segments are assigned to the SLI (inside) interface of each CE node. This is a [Day-2 operation](#automated-day-2-provisioners) because the XC API does not allow interface configuration until after the CE registers and its nodes are auto-discovered.

## What This Deploys

### Shared XC Objects (always created)
- **Known Label** (`shared`) — label key + value used to select CE sites into the mesh
- **Virtual Site** (`shared`) — CE-type virtual site with label selector
- **Site Mesh Group** (`system`) — full mesh, data-plane only
- **Network Segment** (`system`) — logical network segmentation

### Optional CE Site Modules
- **[AWS GovCloud CE](https://github.com/Mikej81/xc-ce-aws-gov-tf)** — toggleable via `aws_ce` variable
- **[Azure GovCloud CE](https://github.com/Mikej81/xc-ce-azure-gov-tf)** — toggleable via `azure_ce` variable

## Prerequisites

### Required Tools

Install the following before you begin:

| Tool | Version | Installation |
|------|---------|-------------|
| **Terraform** | >= 1.3 | [Install Terraform](https://developer.hashicorp.com/terraform/install) |
| **git** | any | [Install Git](https://git-scm.com/downloads) |
| **curl** | any | Usually pre-installed on macOS/Linux |
| **jq** | any | `brew install jq` (macOS) or `apt install jq` (Ubuntu) |
| **openssl** | any | Usually pre-installed; needed for P12 credential extraction |
| **AWS CLI** | v2 | [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (only if deploying `aws_ce`) |
| **Azure CLI** | any | [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (only if deploying `azure_ce`) |

Verify your setup:

```bash
terraform -version   # Should show >= 1.3
aws --version        # Only needed for AWS CE
az --version         # Only needed for Azure CE
```

### F5 XC API Credentials (P12 Certificate)

The Volterra Terraform provider authenticates using a P12 certificate file. You must create one in the F5 XC Console:

1. Log into your F5 XC Console (e.g. `https://your-tenant.console.ves.volterra.io`)
2. Navigate to **Administration > Credentials**
3. Click **Create Credentials** and select **API Certificate**
4. Download the `.p12` file and save it to the `./creds/` directory in this repo (this directory is gitignored — your credentials will not be committed)
5. Note the password — you will need it every time you run Terraform

Set the password as an environment variable **in every new terminal session**:

```bash
export VES_P12_PASSWORD="your-p12-password"
```

> **Important:** If you see `Both P12Bundle() and Cert()/Key() are empty` when running `terraform plan`, you forgot to set `VES_P12_PASSWORD`.

### F5 XC API Token (Optional, Recommended)

An API token is used by the Day-2 provisioners that automatically configure segment interfaces and site-to-site connectivity after CE registration. It is not required — the provisioners can fall back to the P12 certificate — but it is recommended because it avoids OpenSSL compatibility issues.

1. Log into your F5 XC Console
2. Navigate to **Administration > Credentials**
3. Click **Create Credentials** and select **API Token**
4. Copy the token — you will add it to your `terraform.tfvars` file in the next section

### SSH Key Pair

Each CE site requires an SSH public key for admin access. If you do not already have one, generate a key pair:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/xc-ce-key
```

This creates two files:
- `~/.ssh/xc-ce-key` — your private key (keep this secret)
- `~/.ssh/xc-ce-key.pub` — your public key (this is what you paste into `terraform.tfvars`)

Print the public key so you can copy it:

```bash
cat ~/.ssh/xc-ce-key.pub
```

### AWS GovCloud Authentication (if deploying `aws_ce`)

You need an AWS GovCloud account with credentials configured. The [AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration) supports several auth methods — the two most common are:

**Option A: Named profile (recommended)**

If you have an AWS CLI profile configured for GovCloud:

```bash
export AWS_PROFILE="your-govcloud-profile"
export AWS_REGION="us-gov-west-1"
```

Set `aws_profile` in `terraform.tfvars` to match your profile name.

**Option B: Access keys**

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-gov-west-1"
```

Leave `aws_profile` as `null` in `terraform.tfvars` to use the default credential chain.

**Required IAM permissions:**

| Permission | Purpose |
|---|---|
| EC2 (full) | Launch CE instance, manage ENIs, EIPs, security groups, key pairs, route tables |
| S3 (read/write) | Stage CE image for import (only if using `ce_image_download_url`) |
| IAM (limited) | Create `vmimport` service role and CE instance profile |

**Finding your VPC and subnet IDs:**

The AWS CE deploys into an *existing* VPC with two subnets. To find these IDs:

```bash
# List VPCs
aws ec2 describe-vpcs --query 'Vpcs[].{ID:VpcId, CIDR:CidrBlock, Name:Tags[?Key==`Name`].Value | [0]}' --output table

# List subnets in a VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-XXXX" \
  --query 'Subnets[].{ID:SubnetId, AZ:AvailabilityZone, CIDR:CidrBlock, Name:Tags[?Key==`Name`].Value | [0]}' --output table
```

You need two subnets:
- **Outside (SLO)** — must have a route to the internet (via an Internet Gateway). This is used for CE registration and tunnel traffic.
- **Inside (SLI)** — your private workload subnet. The CE will be the default gateway for this subnet.

### Azure Government Authentication (if deploying `azure_ce`)

The [AzureRM provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) requires a Service Principal with Contributor access.

**Option A: Create a new Service Principal**

```bash
# Switch to the Azure Government cloud
az cloud set --name AzureUSGovernment
az login

# Create a Service Principal with Contributor role
az ad sp create-for-rbac --name "terraform-xc-mcn" --role Contributor \
  --scopes /subscriptions/<subscription-id>
```

The command will output `appId`, `password`, `tenant` — export them:

```bash
export ARM_CLIENT_ID="<appId from output>"
export ARM_CLIENT_SECRET="<password from output>"
export ARM_TENANT_ID="<tenant from output>"
export ARM_SUBSCRIPTION_ID="<your subscription id>"
export ARM_ENVIRONMENT="usgovernment"
```

**Option B: Use an existing Service Principal**

If you already have credentials, set the same `ARM_*` environment variables shown above.

**Required RBAC:**

| Role | Scope | Purpose |
|---|---|---|
| **Contributor** | Subscription or Resource Group | Create/manage VMs, NICs, NSGs, storage accounts, images, and list storage account keys for VHD upload |

> **Note:** If deploying into an existing resource group, Contributor can be scoped to that resource group instead of the full subscription.

Unlike the AWS CE (which requires existing networking), the Azure CE can **create its own** resource group, VNet, and subnets if you leave the optional `resource_group_name`, `vnet_name`, `outside_subnet_name`, and `inside_subnet_name` fields unset.

## Usage

### 1. Clone the Repository

```bash
git clone https://github.com/Mikej81/xc-mcn-core-tf.git
cd xc-mcn-core-tf
```

### 2. Create Your Variables File

Terraform reads configuration values from a file called `terraform.tfvars`. A template is included:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` in your editor and fill in the required values:

```hcl
# --- Required: F5 XC API ---------------------------------------------------
# Your tenant URL — replace "tenant" with your actual tenant name.
f5xc_api_url      = "https://tenant.console.ves.volterra.io/api"

# Path to the P12 file you downloaded from the XC Console.
f5xc_api_p12_file = "./creds/tenant.console.ves.volterra.io.api-creds.p12"

# --- Optional but recommended: API token for Day-2 automation --------------
# Uncomment and paste the token you created in the Prerequisites section.
# f5xc_api_token = "your-api-token"
```

> **What is `terraform.tfvars`?** It's a file where you define the values for variables declared in the Terraform code. Think of it like a configuration file — the code defines *what* can be configured, and `terraform.tfvars` defines *your specific* values. This file is gitignored, so your credentials stay local.

### 3. Deploy Core Objects Only

If you just want to create the shared MCN objects (labels, virtual site, mesh group, segment) without deploying any CE sites:

```bash
# Set the P12 password (required every new terminal session)
export VES_P12_PASSWORD="your-p12-password"

# Download provider plugins (only needed the first time, or after changing providers)
terraform init

# Preview what Terraform will create (no changes are made yet)
terraform plan

# Create the resources (Terraform will ask you to type "yes" to confirm)
terraform apply
```

### 4. Deploy with CE Sites

To deploy CE sites alongside the core objects, add a CE configuration block to your `terraform.tfvars`. Only the fields you need are required — everything else has sensible defaults.

**AWS GovCloud CE example:**

```hcl
aws_ce = {
  # Required fields
  site_name         = "mcn-aws-gov-ce"        # Name for this site in F5 XC (letters, numbers, hyphens)
  ssh_public_key    = "ssh-rsa AAAA..."        # Contents of ~/.ssh/xc-ce-key.pub
  vpc_id            = "vpc-0123456789abcdef0"  # Your existing VPC ID
  outside_subnet_id = "subnet-0123456789abcdef0"  # SLO subnet (must have internet access)
  inside_subnet_id  = "subnet-0123456789abcdef1"  # SLI subnet (private workloads)

  # Required for AWS authentication
  aws_region  = "us-gov-west-1"
  aws_profile = "govcloud"                     # Must match your AWS CLI profile name

  # Connect this site's inside network to the "prod" segment.
  # This value must match a key in the "segments" variable (default: "prod").
  segment_name = "prod"

  # Optional: deploy a small test VM on the inside subnet for connectivity testing
  deploy_test_vm       = true
  test_vm_remote_cidrs = ["10.0.2.0/24"]       # Remote CIDRs to route via the CE (e.g. Azure SLI subnet)
}
```

**Azure GovCloud CE example:**

```hcl
azure_ce = {
  # Required fields
  site_name      = "mcn-azure-gov-ce"          # Name for this site in F5 XC
  ssh_public_key = "ssh-rsa AAAA..."           # Contents of ~/.ssh/xc-ce-key.pub

  # Connect this site's inside network to the "prod" segment.
  segment_name = "prod"

  # Optional: deploy a small test VM on the inside subnet for connectivity testing
  deploy_test_vm       = true
  test_vm_remote_cidrs = ["172.16.2.0/24"]     # Remote CIDRs to route via the CE (e.g. AWS SLI subnet)
}
```

> **Note:** The Azure CE creates its own resource group, VNet, and subnets by default. To deploy into existing networking, set `resource_group_name`, `vnet_name`, `outside_subnet_name`, and `inside_subnet_name`.

Then run:

```bash
export VES_P12_PASSWORD="your-p12-password"
terraform init      # Re-run init if this is your first time deploying CE modules
terraform plan      # Review what will be created
terraform apply     # Deploy (type "yes" to confirm)
```

### 5. What Happens After Apply

After `terraform apply` completes, each CE site goes through an automated lifecycle. **This takes 30-60 minutes** — that is normal.

| State | Duration | What's Happening |
|-------|----------|------------------|
| WAITING_FOR_REGISTRATION | 5-10 min | VM booted, cloud-init running, CE contacting F5 XC |
| PROVISIONING | 10-20 min | Site registered, container images loading |
| UPGRADING | 15-30 min | Downloading target software version, rebooting |
| ONLINE | -- | Ready for traffic |

You can monitor progress in the F5 XC Console: **Multi-Cloud Network Connect > Overview > Sites**.

The Terraform provisioners will automatically wait for the site to come ONLINE and then configure:
- Public IP assignment on the outside interface
- OS/SW upgrades (if a newer version is available)
- Network segment on the inside interface
- Site-to-site connectivity for the mesh group

**You do not need to do anything manually** — just wait for `terraform apply` to finish.

> **Tip:** If `terraform apply` times out waiting for a site, you can safely re-run `terraform apply` — it will pick up where it left off.

## Day-2 Operations

### Automated Day-2 Provisioners

When deploying CE sites through the included CE modules, public IP assignment, segment interface configuration, and site-to-site connectivity are handled automatically by `terraform_data` provisioners that run after the CE registers. No manual steps are required for the common case.

The provisioners perform the following in order:

1. **Wait for ONLINE** — poll the site status until it reaches `ONLINE` state (up to 60 minutes)
2. **Set public IP** — assign the public IP on the outside interface
3. **Push OS/SW upgrades** — check for available updates and push them if needed (the CE reboots during upgrades)
4. **Configure segment interface** — set the network segment on the inside interface (runs *after* upgrades because an OS upgrade reboot resets interface config)
5. **Enable site-to-site** — enable direct tunnel connectivity on the inside interface

The provisioners also:
- **Retry on conflicts** — automatically retry on `resource_version` conflicts, which are common because the CE updates the site object frequently during registration
- **Authentication** — prefer the API token (`f5xc_api_token`) when set; fall back to extracting credentials from the P12 certificate using OpenSSL

### Manual Alternatives

If you are not using the CE modules, or need to troubleshoot a provisioner failure, you can perform the same steps manually.

#### Option A: XC Console (UI)

1. Navigate to **Multi-Cloud Network Connect > Manage > Site Management > [Secure Mesh Sites v2](https://docs.cloud.f5.com/docs-v2/multi-cloud-network-connect/how-to/site-management/create-secure-mesh-site-v2)**
2. Find your site and click **Edit**
3. Scroll to **Node Information** — you should see the auto-discovered node
4. Click the node to expand it, then edit the **SLI interface**
5. Change `Network Option` from **Site Local Inside Network** to **Segment Network**
6. Select the target segment (e.g. `prod`)
7. Click **Save and Exit**

#### Option B: XC API

First, GET the current site config to capture the auto-discovered node name and existing spec:

```bash
curl -s -H "Authorization: APIToken <token>" \
  "https://<tenant>/api/config/namespaces/system/securemesh_site_v2s/<site-name>" \
  | jq '.spec.node_list'
```

Then PUT the updated site config with the segment interface. The key change is replacing `site_local_inside_network` with `segment_network` on the SLI interface. The `segment_network` value is a flat object reference with `name`, `namespace`, and `tenant`:

> **Important:** The PUT replaces the full spec. You must include the `resource_version` from the GET response and all existing spec fields to avoid dropping configuration or hitting a version mismatch error.

```bash
# 1. Fetch current config
CURRENT=$(curl -s -H "Authorization: APIToken <token>" \
  "https://<tenant>/api/config/namespaces/system/securemesh_site_v2s/<site-name>")

# 2. Update the SLI interface network_option and PUT back
echo "$CURRENT" | jq '
  # Find the SLI interface (eth1) and change its network_option
  (.spec.azure.not_managed.node_list[0].interface_list[] |
    select(.name == "eth1")).network_option = {
      "segment_network": {
        "name": "<segment-name>",
        "namespace": "system",
        "tenant": "<tenant-id>"
      }
    }
  |
  # Build the replace request body
  {
    metadata: {
      name: .metadata.name,
      namespace: .metadata.namespace,
      labels: .metadata.labels,
      description: .metadata.description,
      annotations: .metadata.annotations,
      disable: .metadata.disable
    },
    resource_version: .resource_version,
    spec: .spec
  }
' | curl -s -X PUT \
  -H "Authorization: APIToken <token>" \
  -H "Content-Type: application/json" \
  "https://<tenant>/api/config/namespaces/system/securemesh_site_v2s/<site-name>" \
  -d @-
```

> **Note:** For AWS CE sites, the path within the spec is `spec.aws.not_managed.node_list` instead of `spec.azure.not_managed.node_list`. Adjust the `jq` path accordingly.

### Verify Site Mesh Connectivity

After both CE sites are ONLINE with matching labels, verify the site mesh group is formed:

1. **Console:** Navigate to **Multi-Cloud Network Connect > Networking > Site Mesh Groups** > click your mesh group > check **Topology** tab
2. **API:**

```bash
curl -s -X POST \
  -H "Authorization: APIToken <token>" \
  -H "Content-Type: application/json" \
  "https://<tenant>/api/data/namespaces/system/topology/site_mesh_group/<mesh-name>" \
  -d '{}' | jq '.sites'
```

### Verify Segment Connectivity

Once segment interfaces are configured on both CE sites, verify end-to-end segment routing:

1. **Console:** Navigate to **Multi-Cloud Network Connect > Networking > Segments** > click the segment > check connected sites
2. **Test connectivity:** From a workload on the SLI subnet of one CE, ping or curl a workload on the SLI subnet of the other CE — traffic should route through the segment over the data-plane mesh

## Cleanup

To remove all resources created by Terraform:

```bash
export VES_P12_PASSWORD="your-p12-password"
terraform destroy
```

Terraform will show you everything it plans to delete and ask you to type `yes` to confirm. This removes CE instances, networking resources, IAM roles, F5 XC sites/tokens, and all shared MCN objects.

> **Note:** If you used the image import path (AWS `ce_image_download_url` or Azure `vhd_download_url`), the imported AMI/image and its backing storage are **not** deleted by Terraform. Remove them manually if desired.

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `Both P12Bundle() and Cert()/Key() are empty` | `VES_P12_PASSWORD` not set | Run `export VES_P12_PASSWORD="your-password"` before any `terraform` command |
| `terraform init` fails to download a provider | Network issue or version constraint | Check internet connectivity; run `terraform init -upgrade` to retry |
| `terraform plan` asks for a variable value | Missing from `terraform.tfvars` | Add the variable to your `terraform.tfvars` file |
| Site stuck in `WAITING_FOR_REGISTRATION` | CE cannot reach F5 XC control plane | Verify the SLO subnet has a route to the internet (Internet Gateway in AWS, or outbound NSG rule in Azure) |
| Site stuck in `UPGRADING` for > 45 min | Large software update or slow download | This can be normal on first boot; check the F5 XC Console for status details |
| Day-2 provisioner fails with `RESOURCE_VERSION_MISMATCH` | CE updated the site object between GET and PUT | Re-run `terraform apply` — the provisioners retry automatically (up to 10 times) |
| `could not parse PKCS12 file ... unsupported` | OpenSSL 3.x compatibility issue with the P12 file | The provisioners handle this automatically with the `-legacy` flag; if running manual `curl` commands, extract cert/key with `openssl pkcs12 -legacy` |
| CE tunnels show `NO_PROPOSAL_CHOSEN` | CE version mismatch between sites (different FIPS cipher suites) | Push OS upgrades to all CEs so they run the same version |
| Test VM can't reach remote site | Missing route table entry | Verify the inside subnet has a default route (`0.0.0.0/0`) pointing to the CE's SLI interface as next hop |

## Inputs

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `f5xc_api_url` | yes | -- | F5 XC tenant API URL (e.g. `https://tenant.console.ves.volterra.io/api`) |
| `f5xc_api_p12_file` | yes | -- | Path to API P12 credential file (e.g. `./creds/tenant.api-creds.p12`) |
| `f5xc_api_token` | no | `null` | F5 XC API token for Day-2 provisioners (preferred over P12 for API calls) |
| `mesh_name` | no | `global-network-mesh` | Name for virtual site and site mesh group |
| `site_mesh_label_key` | no | `site-mesh` | Label key for CE site selection |
| `site_mesh_label_value` | no | `global-network-mesh` | Label value for mesh membership |
| `segments` | no | `{ prod = {...} }` | Map of network segments to create (keys are segment names) |
| `ce_image_url` | no | (has a default) | CE image download URL shared across AWS and Azure deployments |
| `aws_ce` | no | `null` | AWS GovCloud CE config object (null = skip). See [Deploy with CE Sites](#4-deploy-with-ce-sites) for fields. |
| `azure_ce` | no | `null` | Azure GovCloud CE config object (null = skip). See [Deploy with CE Sites](#4-deploy-with-ce-sites) for fields. |

## Outputs

| Output | Description |
|--------|-------------|
| `virtual_site_name` | Name of the virtual site |
| `site_mesh_group_name` | Name of the site mesh group |
| `segment_names` | Map of created segment names |
| `site_label` | Label expression CE sites must carry |

## References

- [F5 XC Site Concepts](https://docs.cloud.f5.com/docs-v2/platform/concepts/site) — sites, virtual sites, labels, site mesh groups
- [Networking Concepts](https://docs.cloud.f5.com/docs-v2/platform/concepts/networking) — virtual networks, network connectors
- [Network Segmentation](https://docs.cloud.f5.com/docs-v2/multi-cloud-network-connect/how-tos/networking/segmentation) — creating and managing segments
- [Create Secure Mesh Site v2](https://docs.cloud.f5.com/docs-v2/multi-cloud-network-connect/how-to/site-management/create-secure-mesh-site-v2) — SMSv2 site deployment guide
- [Volterra Terraform Provider](https://registry.terraform.io/providers/volterraedge/volterra/latest/docs) — provider documentation
- [F5 XC API Automation](https://docs.cloud.f5.com/docs-v2/platform/how-to/volt-automation/apis) — API authentication and usage
