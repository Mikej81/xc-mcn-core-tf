# --------------------------------------------------------------------------
# F5 XC API
# --------------------------------------------------------------------------

variable "f5xc_api_url" {
  type        = string
  description = "F5 XC API URL (e.g. https://tenant.console.ves.volterra.io/api)"
}

variable "f5xc_api_p12_file" {
  type        = string
  description = "Path to the F5 XC API P12 credential file"
}

# --------------------------------------------------------------------------
# Naming
# --------------------------------------------------------------------------

variable "mesh_name" {
  type        = string
  default     = "global-network-mesh"
  description = "Name used for the virtual site and site mesh group"
}

# --------------------------------------------------------------------------
# Label used to bind CE sites into the mesh
# --------------------------------------------------------------------------

variable "site_mesh_label_key" {
  type        = string
  default     = "site-mesh"
  description = "Known label key applied to CE sites to select them into a mesh group"
}

variable "site_mesh_label_value" {
  type        = string
  default     = "global-network-mesh"
  description = "Label value that CE sites must carry to join this mesh"
}

# --------------------------------------------------------------------------
# CE Image
# --------------------------------------------------------------------------

variable "ce_image_url" {
  type        = string
  default     = "https://vesio.blob.core.windows.net/releases/rhel/9/x86_64/images/securemeshV2/azure/f5xc-ce-9.2024.44-20250102054713.vhd.gz"
  description = "CE image download URL shared across AWS and Azure deployments"
}

# --------------------------------------------------------------------------
# Network Segments
# --------------------------------------------------------------------------

variable "segments" {
  type = map(object({
    description        = optional(string, "")
    internet_connected = optional(bool, false)
  }))
  default = {
    prod = {
      description        = "Production network segment"
      internet_connected = false
    }
  }
  description = "Map of network segments to create. Key is the segment name."
}

# --------------------------------------------------------------------------
# AWS GovCloud CE Site (optional)
# Set to null to disable. Provide the object to deploy.
# --------------------------------------------------------------------------

variable "aws_ce" {
  type = object({
    site_name             = string
    ssh_public_key        = string
    vpc_id                = string
    outside_subnet_id     = string
    inside_subnet_id      = string
    aws_region            = optional(string, "us-gov-west-1")
    aws_profile           = optional(string, null)
    ami_id                = optional(string, null)
    ce_image_download_url = optional(string, null)
    s3_bucket_name        = optional(string, null)
    instance_type         = optional(string, "m5.2xlarge")
    disk_size_gb          = optional(number, 128)
    slo_security_group_id = optional(string, null)
    sli_security_group_id = optional(string, null)
    slo_private_ip        = optional(string, null)
    sli_private_ip        = optional(string, null)
    create_eip            = optional(bool, true)
    deploy_test_vm        = optional(bool, false)
    test_vm_instance_type = optional(string, "t3.micro")
    test_vm_private_ip    = optional(string, null)
    test_vm_remote_cidrs  = optional(list(string), [])
    tags                  = optional(map(string), {})
  })
  default     = null
  description = "AWS GovCloud CE site configuration. Set to null to skip deployment."
}

# --------------------------------------------------------------------------
# Azure GovCloud CE Site (optional)
# Set to null to disable. Provide the object to deploy.
# --------------------------------------------------------------------------

variable "azure_ce" {
  type = object({
    site_name                  = string
    ssh_public_key             = string
    location                   = optional(string, "usgovvirginia")
    resource_group_name        = optional(string, null)
    vnet_name                  = optional(string, null)
    vnet_address_space         = optional(string, "10.0.0.0/16")
    outside_subnet_name        = optional(string, null)
    outside_subnet_cidr        = optional(string, "10.0.1.0/24")
    inside_subnet_name         = optional(string, null)
    inside_subnet_cidr         = optional(string, "10.0.2.0/24")
    image_id                   = optional(string, null)
    vhd_download_url           = optional(string, null)
    vhd_storage_account_name   = optional(string, null)
    vhd_storage_container_name = optional(string, "f5xc-ce-images")
    vhd_blob_name              = optional(string, null)
    instance_type              = optional(string, "Standard_D8s_v4")
    os_disk_size_gb            = optional(number, 128)
    slo_security_group_id      = optional(string, null)
    sli_security_group_id      = optional(string, null)
    slo_private_ip             = optional(string, null)
    sli_private_ip             = optional(string, null)
    create_public_ip           = optional(bool, true)
    deploy_test_vm             = optional(bool, false)
    test_vm_size               = optional(string, "Standard_B2s")
    tags                       = optional(map(string), {})
  })
  default     = null
  description = "Azure GovCloud CE site configuration. Set to null to skip deployment."
}
