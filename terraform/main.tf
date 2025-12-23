#######################################################
# Network (VPC)
#######################################################

module "vpc" {
  source                       = "terraform-aws-modules/vpc/aws"
  version                      = "6.5.1"
  name                         = var.vpc_name
  azs                          = var.vpc_azs
  cidr                         = var.vpc_cidr
  create_database_subnet_group = var.vpc_create_database_subnet_group
  create_igw                   = var.vpc_create_igw
  database_subnets             = var.vpc_database_subnets
  enable_nat_gateway           = var.vpc_enable_nat_gateway
  private_subnets              = var.vpc_private_subnets
  public_subnets               = var.vpc_public_subnets
  single_nat_gateway           = var.vpc_single_nat_gateway
}

#######################################################
# Kubernetes (EKS)
#######################################################

module "eks" {
  source                       = "terraform-aws-modules/eks/aws"
  version                      = "21.10.1"
  name                         = var.eks_name
  kubernetes_version           = var.eks_kubernetes_version
  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = module.vpc.private_subnets
  control_plane_subnet_ids     = module.vpc.private_subnets
  create_cloudwatch_log_group  = var.eks_create_cloudwatch_log_group
  enabled_log_types            = var.eks_enabled_log_types
  endpoint_public_access       = var.eks_endpoint_public_access
  endpoint_private_access      = var.eks_endpoint_private_access
  endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs
  access_entries               = var.eks_access_entries
  addons                       = var.eks_addons
  eks_managed_node_groups      = var.eks_managed_node_groups
}

#######################################################
# Addons (Observability)
#######################################################

module "eks-blueprints-addons" {
  source                       = "aws-ia/eks-blueprints-addons/aws"
  version                      = "1.23.0"
  depends_on                   = [module.eks]
  cluster_name                 = module.eks.cluster_name
  cluster_endpoint             = module.eks.cluster_endpoint
  cluster_version              = module.eks.cluster_version
  oidc_provider_arn            = module.eks.oidc_provider_arn
  enable_kube_prometheus_stack = var.enable_kube_prometheus_stack
  kube_prometheus_stack = {
    name          = var.kube_prometheus_stack.name
    chart_version = var.kube_prometheus_stack.chart_version
    repository    = var.kube_prometheus_stack.repository
    namespace     = var.kube_prometheus_stack.namespace
    values        = [file("${path.module}/${var.kube_prometheus_stack.values_file}")]
  }
}

#######################################################
# Demo app (Helm)
#######################################################

resource "helm_release" "demo_app" {
  name             = var.demo_app.name
  depends_on       = [module.eks]
  repository       = var.demo_app.repository
  chart            = var.demo_app.chart
  version          = var.demo_app.version
  namespace        = var.demo_app.namespace
  create_namespace = var.demo_app.create_namespace
  values           = [file("${path.module}/${var.demo_app.values_file}")]

}