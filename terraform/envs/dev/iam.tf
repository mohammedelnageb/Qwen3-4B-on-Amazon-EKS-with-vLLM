# ===========================================================================
# IRSA roles for EKS add-ons (EBS CSI, Mountpoint for S3 CSI)
# ===========================================================================
data "aws_iam_policy_document" "irsa_ebs_csi" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.irsa_ebs_csi.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "irsa_mountpoint_s3" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:s3-csi-driver-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mountpoint_s3" {
  name               = "${var.name}-mountpoint-s3"
  assume_role_policy = data.aws_iam_policy_document.irsa_mountpoint_s3.json
}

# Read-only access to the model bucket (vLLM only reads weights)
data "aws_iam_policy_document" "mountpoint_s3" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.models.arn]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.models.arn}/*"]
  }
}

resource "aws_iam_role_policy" "mountpoint_s3" {
  name   = "model-bucket-read"
  role   = aws_iam_role.mountpoint_s3.id
  policy = data.aws_iam_policy_document.mountpoint_s3.json
}

# ===========================================================================
# EKS Pod Identity role for the model download Job
# (namespace: llm, service account: model-downloader)
# ===========================================================================
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "model_downloader" {
  name               = "${var.name}-model-downloader"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

data "aws_iam_policy_document" "model_downloader" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.models.arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${data.aws_s3_bucket.models.arn}/*"]
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [data.aws_secretsmanager_secret.hf_token.arn]
  }
}

resource "aws_iam_role_policy" "model_downloader" {
  name   = "model-bucket-write-and-hf-token"
  role   = aws_iam_role.model_downloader.id
  policy = data.aws_iam_policy_document.model_downloader.json
}

resource "aws_eks_pod_identity_association" "model_downloader" {
  cluster_name    = module.eks.cluster_name
  namespace       = var.llm_namespace
  service_account = "model-downloader"
  role_arn        = aws_iam_role.model_downloader.arn
}
