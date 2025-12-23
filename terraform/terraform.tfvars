#######################################################
# VPC Module
#######################################################

aws_region = "sa-east-1"

vpc_name                         = "pp-main"
vpc_cidr                         = "10.0.0.0/24"
vpc_create_igw                   = true
vpc_enable_nat_gateway           = true
vpc_single_nat_gateway           = true
vpc_create_database_subnet_group = true

vpc_azs = [
  "sa-east-1a",
  "sa-east-1b",
  "sa-east-1c",
]

vpc_public_subnets = [
  "10.0.0.0/27",
  "10.0.0.32/27",
  "10.0.0.64/27",
]

vpc_private_subnets = [
  "10.0.0.96/27",
  "10.0.0.128/27",
  "10.0.0.160/27",
]

vpc_database_subnets = [
  "10.0.0.192/28",
  "10.0.0.208/28",
  "10.0.0.224/28",
]

#######################################################
# EKS Module
#######################################################

eks_name                        = "pp-cluster"
eks_kubernetes_version          = "1.34"
eks_create_cloudwatch_log_group = true
eks_endpoint_public_access      = true
eks_endpoint_private_access     = true
eks_endpoint_public_access_cidrs = [
  "0.0.0.0/0"
]

eks_enabled_log_types = [
  "api",
  "audit",
  "authenticator",
  "controllerManager",
  "scheduler",
]

eks_addons = {
  vpc-cni = {
    before_compute = true
  }
  kube-proxy = {
    before_compute = true
  }
  coredns = {
    before_compute = true
  }
  metrics-server = {}
  # aws-ebs-csi-driver = {}
  # aws-efs-csi-driver = {}
}

eks_access_entries = {
  admin = {
    principal_arn = "arn:aws:iam::691318384583:user/mateus.silva"

    policy_associations = {
      admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}

eks_managed_node_groups = {
  system = {
    name           = "system"
    instance_types = ["m7i-flex.large"]
    min_size       = 0
    desired_size   = 2
    max_size       = 2
    disk_size      = 20
    node_repair_config = {
      enabled = false
    }
    taints = {
      system = {
        key    = "node-role"
        value  = "system"
        effect = "PREFER_NO_SCHEDULE"
      }
    }
    labels = {
      node-role = "system"
    }
  }
}

#######################################################
# EKS Blueprint Module
#######################################################

enable_kube_prometheus_stack = true

kube_prometheus_stack = {
  name          = "kube-prometheus-stack"
  chart_version = "51.2.0"
  repository    = "https://prometheus-community.github.io/helm-charts"
  namespace     = "kube-prometheus-stack"
  values_file   = "helm/kube-prometheus-stack.yaml"
}

#######################################################
# Demo App (Helm Release)
#######################################################

demo_app = {
  name             = "nginx"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "nginx"
  version          = "22.3.9"
  namespace        = "nginx"
  create_namespace = true
  values_file      = "helm/nginx_bitnami.yaml"
}