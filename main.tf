##############################################################################
# base-ocp-vpc-module
##############################################################################

locals {
  # Input variable validation
  # tflint-ignore: terraform_unused_declarations
  validate_cos_inputs = (var.use_existing_cos == false && var.cos_name == null) ? tobool("A value must be passed for var.cos_name if var.use_existing_cos is false.") : true
  # tflint-ignore: terraform_unused_declarations
  validate_existing_cos_inputs = (var.use_existing_cos == true && var.existing_cos_id == null) ? tobool("A value must be passed for var.existing_cos_id if var.use_existing_cos is true.") : true
  # tflint-ignore: terraform_unused_declarations
  validate_kp_inputs = (var.existing_key_protect_instance_guid == null && var.existing_key_protect_root_key_id != null) || (var.existing_key_protect_root_key_id != null && var.existing_key_protect_instance_guid == null) ? tobool("To enable encryption, values must be passed for both var.existing_key_protect_instance_guid and var.existing_key_protect_root_key_id. Set them both to null to create cluster without encryption (not recommended).") : true

  # If encryption enabled generate kms config to be passed to cluster
  kms_config = var.existing_key_protect_instance_guid != null && var.existing_key_protect_root_key_id != null ? {
    crk_id           = var.existing_key_protect_root_key_id
    instance_id      = var.existing_key_protect_instance_guid
    private_endpoint = var.key_protect_use_private_endpoint
  } : null
}

module "ocp_base" {
  source                          = "terraform-ibm-modules/base-ocp-vpc/ibm"
  version                         = "3.10.2"
  cluster_name                    = var.cluster_name
  ocp_version                     = var.ocp_version
  resource_group_id               = var.resource_group_id
  region                          = var.region
  tags                            = var.cluster_tags
  access_tags                     = var.access_tags
  force_delete_storage            = var.force_delete_storage
  vpc_id                          = var.vpc_id
  vpc_subnets                     = var.vpc_subnets
  worker_pools                    = var.worker_pools
  cluster_ready_when              = var.cluster_ready_when
  cos_name                        = var.cos_name
  use_existing_cos                = var.use_existing_cos
  existing_cos_id                 = var.existing_cos_id
  ocp_entitlement                 = var.ocp_entitlement
  disable_public_endpoint         = var.disable_public_endpoint
  ignore_worker_pool_size_changes = var.ignore_worker_pool_size_changes
  kms_config                      = local.kms_config
  ibmcloud_api_key                = var.ibmcloud_api_key
  addons                          = var.addons
  verify_worker_network_readiness = var.verify_worker_network_readiness
}

##############################################################################
# observability-agents-module
##############################################################################

locals {
  # Locals
  run_observability_agents_module = (local.provision_logdna_agent == true || local.provision_sysdig_agent) ? true : false
  provision_logdna_agent          = var.logdna_instance_name != null ? true : false
  provision_sysdig_agent          = var.sysdig_instance_name != null ? true : false
  logdna_resource_group_id        = var.logdna_resource_group_id != null ? var.logdna_resource_group_id : var.resource_group_id
  sysdig_resource_group_id        = var.sysdig_resource_group_id != null ? var.sysdig_resource_group_id : var.resource_group_id
  # Some input variable validation (approach based on https://stackoverflow.com/a/66682419)
  logdna_validate_condition = var.logdna_instance_name != null && var.logdna_ingestion_key == null
  logdna_validate_msg       = "A value for var.logdna_ingestion_key must be passed when providing a value for var.logdna_instance_name"
  # tflint-ignore: terraform_unused_declarations
  logdna_validate_check     = regex("^${local.logdna_validate_msg}$", (!local.logdna_validate_condition ? local.logdna_validate_msg : ""))
  sysdig_validate_condition = var.sysdig_instance_name != null && var.sysdig_access_key == null
  sysdig_validate_msg       = "A value for var.sysdig_access_key must be passed when providing a value for var.sysdig_instance_name"
  # tflint-ignore: terraform_unused_declarations
  sysdig_validate_check = regex("^${local.sysdig_validate_msg}$", (!local.sysdig_validate_condition ? local.sysdig_validate_msg : ""))
}

module "observability_agents" {
  count                     = local.run_observability_agents_module == true ? 1 : 0
  source                    = "terraform-ibm-modules/observability-agents/ibm"
  version                   = "1.12.2"
  cluster_id                = module.ocp_base.cluster_id
  cluster_resource_group_id = var.resource_group_id
  logdna_enabled            = local.provision_logdna_agent
  logdna_instance_name      = var.logdna_instance_name
  logdna_ingestion_key      = var.logdna_ingestion_key
  logdna_resource_group_id  = local.logdna_resource_group_id
  logdna_agent_version      = var.logdna_agent_version
  logdna_agent_tags         = var.logdna_agent_tags
  sysdig_enabled            = local.provision_sysdig_agent
  sysdig_instance_name      = var.sysdig_instance_name
  sysdig_access_key         = var.sysdig_access_key
  sysdig_resource_group_id  = local.sysdig_resource_group_id
  sysdig_agent_version      = var.sysdig_agent_version
  sysdig_agent_tags         = var.sysdig_agent_tags
}
