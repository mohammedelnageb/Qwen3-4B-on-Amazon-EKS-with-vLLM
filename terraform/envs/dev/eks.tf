module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  # Public API endpoint, restricted to your IP
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.admin_cidrs

  # Gives the IAM user that runs Terraform cluster-admin access
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }
    aws-mountpoint-s3-csi-driver = {
      most_recent              = true
      service_account_role_arn = aws_iam_role.mountpoint_s3.arn
      # Node plugin must also run on the tainted inference node
      configuration_values = jsonencode({
        node = {
          tolerateAllTaints = true
        }
      })
    }
  }

  eks_managed_node_groups = {
    # Always on: Prometheus, Grafana, Open WebUI, model download Job
    system = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 2
      desired_size = 1

      # Room for the model download (~8 GB) and container images
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }

      labels = {
        role = "system"
      }
    }

    # vLLM on CPU: scale 0 <-> 1 manually (desired_size changes are ignored after creation)
    # Later, for GPU: ami_type = "AL2023_x86_64_NVIDIA", instance_types = ["g6.xlarge"]
    inference = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.inference_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = 0
      max_size     = 1
      desired_size = var.inference_desired_size

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 60 # vLLM CPU image + logs
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }

      labels = {
        role = "inference"
      }

      # Only pods that tolerate this taint (vLLM) land on the inference node
      taints = {
        inference = {
          key    = "workload"
          value  = "inference"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
}
