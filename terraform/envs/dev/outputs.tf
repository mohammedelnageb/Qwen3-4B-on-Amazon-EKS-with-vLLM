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

output "inference_scale_up" {
  value = "aws eks update-nodegroup-config --region ${var.region} --cluster-name ${module.eks.cluster_name} --nodegroup-name ${split(":", module.eks.eks_managed_node_groups["inference"].node_group_id)[1]} --scaling-config minSize=0,maxSize=1,desiredSize=1"
}

output "inference_scale_down" {
  value = "aws eks update-nodegroup-config --region ${var.region} --cluster-name ${module.eks.cluster_name} --nodegroup-name ${split(":", module.eks.eks_managed_node_groups["inference"].node_group_id)[1]} --scaling-config minSize=0,maxSize=1,desiredSize=0"
}

output "install_lb_controller" {
  description = "Helm command to install the AWS Load Balancer Controller"
  value       = "helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=${module.eks.cluster_name} --set serviceAccount.name=aws-load-balancer-controller --set region=${var.region} --set vpcId=${module.vpc.vpc_id} --set nodeSelector.role=system"
}
