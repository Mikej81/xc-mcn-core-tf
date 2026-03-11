# --------------------------------------------------------------------------
# AWS GovCloud CE Site
# --------------------------------------------------------------------------

module "aws_ce" {
  count  = var.aws_ce != null ? 1 : 0
  source = "../xc-ce-aws-gov-tf"

  f5xc_api_url      = var.f5xc_api_url
  f5xc_api_p12_file = var.f5xc_api_p12_file

  site_name             = var.aws_ce.site_name
  ssh_public_key        = var.aws_ce.ssh_public_key
  vpc_id                = var.aws_ce.vpc_id
  outside_subnet_id     = var.aws_ce.outside_subnet_id
  inside_subnet_id      = var.aws_ce.inside_subnet_id
  aws_region            = var.aws_ce.aws_region
  aws_profile           = var.aws_ce.aws_profile
  ami_id                = var.aws_ce.ami_id
  ce_image_download_url = coalesce(var.aws_ce.ce_image_download_url, var.ce_image_url)
  s3_bucket_name        = var.aws_ce.s3_bucket_name
  instance_type         = var.aws_ce.instance_type
  disk_size_gb          = var.aws_ce.disk_size_gb
  slo_security_group_id = var.aws_ce.slo_security_group_id
  sli_security_group_id = var.aws_ce.sli_security_group_id
  slo_private_ip        = var.aws_ce.slo_private_ip
  sli_private_ip        = var.aws_ce.sli_private_ip
  create_eip            = var.aws_ce.create_eip
  deploy_test_vm        = var.aws_ce.deploy_test_vm
  test_vm_instance_type = var.aws_ce.test_vm_instance_type
  test_vm_private_ip    = var.aws_ce.test_vm_private_ip
  test_vm_remote_cidrs  = var.aws_ce.test_vm_remote_cidrs
  tags                  = var.aws_ce.tags

  # MCN integration — from core config
  site_mesh_label_key   = var.site_mesh_label_key
  site_mesh_label_value = var.site_mesh_label_value

  depends_on = [
    volterra_virtual_site.mesh,
    volterra_site_mesh_group.mesh,
  ]
}

# --------------------------------------------------------------------------
# Azure GovCloud CE Site
# --------------------------------------------------------------------------

module "azure_ce" {
  count  = var.azure_ce != null ? 1 : 0
  source = "../xc-ce-azure-gov-tf"

  f5xc_api_url      = var.f5xc_api_url
  f5xc_api_p12_file = var.f5xc_api_p12_file

  site_name                  = var.azure_ce.site_name
  ssh_public_key             = var.azure_ce.ssh_public_key
  location                   = var.azure_ce.location
  resource_group_name        = var.azure_ce.resource_group_name
  vnet_name                  = var.azure_ce.vnet_name
  vnet_address_space         = var.azure_ce.vnet_address_space
  outside_subnet_name        = var.azure_ce.outside_subnet_name
  outside_subnet_cidr        = var.azure_ce.outside_subnet_cidr
  inside_subnet_name         = var.azure_ce.inside_subnet_name
  inside_subnet_cidr         = var.azure_ce.inside_subnet_cidr
  vhd_download_url           = coalesce(var.azure_ce.vhd_download_url, var.ce_image_url)
  vhd_storage_account_name   = var.azure_ce.vhd_storage_account_name
  vhd_storage_container_name = var.azure_ce.vhd_storage_container_name
  vhd_blob_name              = var.azure_ce.vhd_blob_name
  instance_type              = var.azure_ce.instance_type
  os_disk_size_gb            = var.azure_ce.os_disk_size_gb
  slo_security_group_id      = var.azure_ce.slo_security_group_id
  sli_security_group_id      = var.azure_ce.sli_security_group_id
  slo_private_ip             = var.azure_ce.slo_private_ip
  sli_private_ip             = var.azure_ce.sli_private_ip
  create_public_ip           = var.azure_ce.create_public_ip
  deploy_test_vm             = var.azure_ce.deploy_test_vm
  test_vm_size               = var.azure_ce.test_vm_size
  tags                       = var.azure_ce.tags

  # MCN integration — from core config
  site_mesh_label_key   = var.site_mesh_label_key
  site_mesh_label_value = var.site_mesh_label_value

  depends_on = [
    volterra_virtual_site.mesh,
    volterra_site_mesh_group.mesh,
  ]
}
