output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "model_bucket_name" {
  value = data.aws_s3_bucket.models.bucket
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "gpu_scale_up" {
  value = "aws eks update-nodegroup-config --region ${var.region} --cluster-name ${module.eks.cluster_name} --nodegroup-name ${module.eks.eks_managed_node_groups["gpu"].node_group_id} --scaling-config minSize=0,maxSize=1,desiredSize=1"
}
