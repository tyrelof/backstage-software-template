# EKS IRSA ServiceAccount Role Setup Guide

This guide walks through how to create and link an IAM Role to a
Kubernetes ServiceAccount for AWS EKS using IRSA (IAM Roles for Service
Accounts).

------------------------------------------------------------------------

## 1️⃣ Get the OIDC Provider

``` bash
aws eks describe-cluster --name <your-cluster-name>   --query "cluster.identity.oidc.issuer" --output text
```

Example output:

    https://oidc.eks.us-east-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E

------------------------------------------------------------------------

## 2️⃣ Create a Trust Policy (`trust.json`)

Replace `<OIDC_ID>`, `<ACCOUNT_ID>`, and `<NAMESPACE>` with your own
values.

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.us-east-2.amazonaws.com/id/<OIDC_ID>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-2.amazonaws.com/id/<OIDC_ID>:sub": "system:serviceaccount:prod:gitlab-job-sa"
        }
      }
    }
  ]
}
```

------------------------------------------------------------------------

## 3️⃣ Create the IAM Role

``` bash
aws iam create-role   --role-name ECRPushRole   --assume-role-policy-document file://trust.json
```

------------------------------------------------------------------------

## 4️⃣ Attach a Policy

For ECR access (push/pull permissions):

``` bash
aws iam attach-role-policy   --role-name ECRPushRole   --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
```

------------------------------------------------------------------------

## 5️⃣ Confirm Role ARN

``` bash
aws iam get-role --role-name ECRPushRole   --query 'Role.Arn' --output text
```

Then place that ARN inside your Helm chart's `values.yaml`:

``` yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/ECRPushRole
```

------------------------------------------------------------------------

## 6️⃣ Deploy with Helm

``` bash
helm install myapp . --namespace prod --create-namespace
kubectl -n prod get sa gitlab-job-sa -o yaml
```

Check that the ServiceAccount annotation exists.

------------------------------------------------------------------------

## 7️⃣ Verify Inside Pod

``` bash
aws sts get-caller-identity
```

Output should show the `ECRPushRole`, confirming that IRSA is correctly
configured.

------------------------------------------------------------------------

**Notes** - ServiceAccount and Pod must be in the same namespace. - Role
applies only to pods using that ServiceAccount. - IRSA provides
least-privilege IAM access per workload.

------------------------------------------------------------------------
