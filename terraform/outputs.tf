data "kubernetes_service_v1" "demo_app" {
  metadata {
    name      = "demo-app"
    namespace = "nginx"
  }

  depends_on = [helm_release.demo_app]
}

locals {
  demo_app_lb_hostname = try(data.kubernetes_service_v1.demo_app.status[0].load_balancer[0].ingress[0].hostname, null)
  demo_app_lb_ip       = try(data.kubernetes_service_v1.demo_app.status[0].load_balancer[0].ingress[0].ip, null)
  demo_app_address     = coalesce(local.demo_app_lb_hostname, local.demo_app_lb_ip, "")
}

output "demo_app_service_url" {
  description = "URL to access the demo-app (empty until provisioned)"
  value       = local.demo_app_address != "" ? "http://${local.demo_app_address}" : ""
}

output "kubectl_context_command" {
  description = "Command to update local kubeconfig context for this EKS cluster"
  value       = "aws eks update-kubeconfig --name ${var.eks_name}"
}

output "eks_cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = module.eks.cluster_version
}

output "eks_eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks.eks_managed_node_groups
}
output "vpc_azs" {
  description = "A list of availability zones specified as argument to this module"
  value       = module.vpc.azs
}

output "vpc_database_subnet_arns" {
  description = "List of ARNs of database subnets"
  value       = module.vpc.database_subnet_arns
}

output "vpc_igw_arn" {
  description = "The ARN of the Internet Gateway"
  value       = module.vpc.igw_arn
}

output "vpc_igw_id" {
  description = "The ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "vpc_nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_public_ips
}

output "vpc_natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "vpc_private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = module.vpc.private_route_table_ids
}

output "vpc_private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = module.vpc.private_subnet_arns
}

output "vpc_public_route_table_ids" {
  description = "List of IDs of public route tables"
  value       = module.vpc.public_route_table_ids
}

output "vpc_public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = module.vpc.public_subnet_arns
}

output "vpc_vpc_arn" {
  description = "The ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "vpc_vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}
