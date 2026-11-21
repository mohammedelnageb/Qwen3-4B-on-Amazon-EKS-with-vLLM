# Runbook: Qwen3-4B on EKS with vLLM (CPU phase)

Region: us-east-1 · Account: 058264225887 · Cluster: qwen-eks

## 0. First time only

### 0.1 Put the files in WSL
```bash
cd ~
cp /mnt/c/Users/<WinUser>/Downloads/qwen-eks-vllm.zip .
unzip -o qwen-eks-vllm.zip        # keeps your existing terraform.tfvars files
```

### 0.2 Persistent stack (already applied: model bucket, HF token secret, budget)
```bash
cd ~/qwen-eks-vllm/terraform/persistent
terraform init && terraform apply   # no changes expected
```

### 0.3 Dev stack variables
```bash
cd ~/qwen-eks-vllm/terraform/envs/dev
curl -s https://checkip.amazonaws.com
aws eks describe-cluster-versions --region us-east-1 \
  --query 'clusterVersions[?defaultVersion==`true`].clusterVersion' --output text
nano terraform.tfvars
```
```hcl
admin_cidrs            = ["<your-ip>/32"]
kubernetes_version     = "<version from the command above>"
inference_desired_size = 0
```

## 1. Infrastructure (~15-20 min, billing starts)
```bash
cd ~/qwen-eks-vllm/terraform/envs/dev
terraform init -upgrade
terraform validate
terraform plan
terraform apply
aws eks update-kubeconfig --region us-east-1 --name qwen-eks
kubectl get nodes                                   # 1 system node, Ready
```

## 2. AWS Load Balancer Controller
```bash
helm repo add eks https://aws.github.io/eks-charts && helm repo update
terraform output -raw install_lb_controller | bash
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
```

## 3. Base resources + model
```bash
cd ~/qwen-eks-vllm/k8s
kubectl apply -f base/                              # namespace, gp3 StorageClass, S3 volume
kubectl apply -f model-job/model-downloader.yaml    # only needed once: the model stays in S3
kubectl -n llm logs -f job/model-downloader         # wait for "Done:"
```

## 4. Secrets (once per new cluster)
```bash
kubectl -n llm create secret generic vllm-api-key --from-literal=key=$(openssl rand -hex 16)
kubectl -n llm create secret generic openwebui-secret --from-literal=key=$(openssl rand -hex 32)
```

## 5. vLLM on the CPU inference node
```bash
terraform -chdir=../terraform/envs/dev output -raw inference_scale_up | bash
kubectl get nodes -w                                # wait for the m7i.2xlarge node, then Ctrl+C
kubectl apply -f vllm/vllm.yaml
kubectl -n llm logs -f deploy/vllm                  # wait for "Application startup complete"
```

### Test the API (optional)
```bash
kubectl -n llm port-forward svc/vllm 8000:8000 &
KEY=$(kubectl -n llm get secret vllm-api-key -o jsonpath='{.data.key}' | base64 -d)
curl -s localhost:8000/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Hello!"}]}'
kill %1
```

## 6. Open WebUI + public URL
```bash
kubectl apply -f openwebui/openwebui.yaml -f openwebui/ingress.yaml
kubectl -n llm get ingress openwebui -w             # wait for ADDRESS (2-3 min)
```
- Open `http://<ADDRESS>` and sign up first: the first account becomes admin.
- Share the URL. New users start as "pending": approve them in Admin Panel -> Users.
- It is HTTP only (no domain yet): tell users not to reuse real passwords.

## Pause without destroying (saves ~$0.40/h)
```bash
terraform -chdir=$HOME/qwen-eks-vllm/terraform/envs/dev output -raw inference_scale_down | bash
```

## Teardown at the end of the session (order matters)
The ALB and the Open WebUI EBS volume are created by Kubernetes, not Terraform.
Delete them first, or `terraform destroy` fails on the VPC and the volume keeps billing.
```bash
cd ~/qwen-eks-vllm/k8s
kubectl delete -f openwebui/ingress.yaml            # deletes the ALB
kubectl delete -f openwebui/openwebui.yaml          # deletes the EBS volume
sleep 90
cd ../terraform/envs/dev && terraform destroy
```

### Check nothing is left
```bash
aws eks list-clusters
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId'
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
```
All should return `[]`.
