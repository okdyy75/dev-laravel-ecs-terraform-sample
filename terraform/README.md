
## Terraform設定

### 実行環境・必要なツール
- terraform
- aws cli
- session-manager-plugin

```
$ terraform -v
Terraform v1.4.6
on darwin_amd64

$ aws --version
aws-cli/2.11.16 Python/3.11.3 Darwin/22.4.0 exe/x86_64 prompt/off
```

### 事前設定

```bash
# tfstate管理用にS3バケット作成
aws s3 mb s3://y-oka-ecs-dev

# ECRリポジトリ作成
aws ecr create-repository --repository-name y-oka-ecs/dev/nginx
aws ecr create-repository --repository-name y-oka-ecs/dev/php-fpm

# tfvarsコピー
cp example.tfvars ./environments/dev/dev.tfvars

# terraform初期化
terraform init
```

### terraformコマンド
```
export AWS_PROFILE=dev-user

# 計画
terraform plan -var-file=dev.tfvars

# デプロイ
terraform apply -var-file=dev.tfvars

# 破棄
terraform destroy -var-file=dev.tfvars
```
