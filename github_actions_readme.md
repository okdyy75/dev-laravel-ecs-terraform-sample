
## GitHub Actions CI解説

### ECSデプロイCI
ベースは以前いた会社の鈴木さんが作ったもので、鈴木さんに感謝！

タスク定義用Dockerfileとソース本体が変更されたら（'ecs/**'、'web/**'）ECSをデプロイするようにしている。

ちなみにjob間のECRのURLを渡すのにoutputが使えない（※）のでartifactを使って渡している。

**Warn**
ECRのURLを渡すのにoutputが使えないのは、ECRのURLにAWSのアカウントIDが含まれており（例：************.dkr.ecr.ap-northeast-1.amazonaws.com）、それが秘匿情報としてマスキングされているためoutputで受け渡せない。なのでoutputを使いたい場合は`uses: aws-actions/configure-aws-credentials`の引数に`mask-aws-account-id: 'false'`を設定するとjob間の受け渡しにoutputが使えるようになる。ただしAWSのアカウントIDはマスキングされなくなるので注意

.github/workflows/deploy_ecs_dev.yml

```yml
name: Deploy ECS to Develop

on:
  push:
    paths:
      - 'ecs/**'
      - 'web/**'
    branches:
      - develop

env:
  APP_ENV: dev
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: ap-northeast-1
  ECR_PHP_REPOSITORY: y-oka-ecs/dev/php-fpm
  ECR_NGINX_REPOSITORY: y-oka-ecs/dev/nginx
  ECS_TASK_DEFINITION: ecs/dev/task_definition/y-oka-ecs.json
  ECS_CLUSTER: y-oka-ecs-dev
  ECS_SERVICE: y-oka-ecs-dev

jobs:

  #
  # Build PHP
  #

  build-php:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:

      #
      # Setup Application
      #

      - name: Checkout Project
        uses: actions/checkout@v2

      #
      # Build Image & Push to ECR
      #

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1 # https://github.com/aws-actions/configure-aws-credentials
        with:
          aws-access-key-id: ${{ env.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ env.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1 # https://github.com/aws-actions/amazon-ecr-login

      - name: Build, tag, and push image to Amazon ECR
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/${{ env.ECR_PHP_REPOSITORY }}:$IMAGE_TAG -f ecs/dev/container/php-fpm/Dockerfile .
          docker push $ECR_REGISTRY/${{ env.ECR_PHP_REPOSITORY }}:$IMAGE_TAG

          # artifact for render task definition
          echo $ECR_REGISTRY/${{ env.ECR_PHP_REPOSITORY }}:$IMAGE_TAG > php_image_path.txt

      - uses: actions/upload-artifact@v1
        with:
          name: artifact_php
          path: php_image_path.txt

      - name: Logout of Amazon ECR
        if: always()
        run: docker logout ${{ steps.login-ecr.outputs.registry }}


  #
  # Build Nginx
  #

  build-nginx:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Checkout Project
        uses: actions/checkout@v2

      #
      # Build Image & Push to ECR
      #

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1 # https://github.com/aws-actions/configure-aws-credentials
        with:
          aws-access-key-id: ${{ env.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ env.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1 # https://github.com/aws-actions/amazon-ecr-login

      - name: Build, tag, and push image to Amazon ECR
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/${{ env.ECR_NGINX_REPOSITORY }}:$IMAGE_TAG -f ecs/dev/container/nginx/Dockerfile .
          docker push $ECR_REGISTRY/${{ env.ECR_NGINX_REPOSITORY }}:$IMAGE_TAG

          # artifact for render task definition
          echo $ECR_REGISTRY/${{ env.ECR_NGINX_REPOSITORY }}:$IMAGE_TAG > nginx_image_path.txt

      - uses: actions/upload-artifact@v1
        with:
          name: artifact_nginx
          path: nginx_image_path.txt

      - name: Logout of Amazon ECR
        if: always()
        run: docker logout ${{ steps.login-ecr.outputs.registry }}


  #
  # Deploy to ECS
  #

  deploy-ecs:
    needs: [build-php, build-nginx]
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Checkout Project
        uses: actions/checkout@v2

      # download artifacts
      - uses: actions/download-artifact@v1
        with:
          name: artifact_php
      - uses: actions/download-artifact@v1
        with:
          name: artifact_nginx
      - name: Set Output from Artifacts
        id: artifact-image
        run: |
          echo "php-image=`cat artifact_php/php_image_path.txt`" >> "$GITHUB_OUTPUT"
          echo "nginx-image=`cat artifact_nginx/nginx_image_path.txt`" >> "$GITHUB_OUTPUT"

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1 # https://github.com/aws-actions/configure-aws-credentials
        with:
          aws-access-key-id: ${{ env.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ env.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Render TaskDefinition for php-image
        id: render-php-container
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: ${{ env.ECS_TASK_DEFINITION }}
          container-name: php-fpm
          image: ${{ steps.artifact-image.outputs.php-image }}

      - name: Render TaskDefinition for nginx-image
        id: render-nginx-container
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: ${{ steps.render-php-container.outputs.task-definition }}
          container-name: nginx
          image: ${{ steps.artifact-image.outputs.nginx-image }}

      - name: Deploy to ECS TaskDefinition
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: ${{ steps.render-nginx-container.outputs.task-definition }}
          cluster: ${{ env.ECS_CLUSTER }}
          service: ${{ env.ECS_SERVICE }}
```

### ECS Exec command CI
GitHub ActionsのGUIから手動で実行する。

commandにはコンテナに渡す Docker CMDを指定する  
https://docs.docker.jp/engine/reference/builder.html#cmd

たとえばSeederを実行したい場合は`"php","/var/www/web/laravel/artisan","db:seed","--class=UserSeeder","--force"`のように実行する

CI実行後は「Open Run Task URL」からURLをクリック。タスク詳細を開いてログから実行状況を確認する

.github/workflows/ecs_exec_cmd_dev.yml

```yml
name: ECS Execute Command to Develop

on:
  workflow_dispatch:
    inputs:
      command:
        description: 'execute command(ex: "php","/var/www/web/laravel/artisan","xxxx")'
        required: true

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: ap-northeast-1
  ECS_CLUSTER: y-oka-ecs-dev
  ECS_SERVICE: y-oka-ecs-dev
  ECS_TASK_FAMILY: y-oka-ecs-dev

jobs:

  #
  # ECS Execute Command
  #

  ecs-execute-cmd:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1 # https://github.com/aws-actions/configure-aws-credentials
        with:
          aws-access-key-id: ${{ env.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ env.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: ECS Run Task for Exec Command
        id: run-task-for-exec-command
        run: |
          network_config=$(
            aws ecs describe-services \
              --cluster ${{ env.ECS_CLUSTER }} \
              --services ${{ env.ECS_SERVICE }} | jq '.services[0].networkConfiguration'
          )
          task_arn=$(
            aws ecs run-task \
              --cluster ${{ env.ECS_CLUSTER }} \
              --launch-type "FARGATE" \
              --network-configuration "${network_config}"  \
              --overrides '{
                "containerOverrides": [
                  {
                    "name": "php-fpm",
                    "command": [${{ github.event.inputs.command }}]
                  }
                ]
              }' \
              --task-definition ${{ env.ECS_TASK_FAMILY }} | jq -r '.tasks[0].taskArn'
          )
          task_id=$(echo $task_arn | cut -d "/" -f 3)
          task_url="https://${{ env.AWS_REGION }}.console.aws.amazon.com/ecs/v2/clusters/${{ env.ECS_CLUSTER }}/tasks/${task_id}/configuration"
          echo "task_url=${task_url}" >> "$GITHUB_OUTPUT"

      - name: Open Run Task URL
        run: echo ${{ steps.run-task-for-exec-command.outputs.task_url }}

      - name: Logout of Amazon ECR
        if: always()
        run: docker logout ${{ steps.login-ecr.outputs.registry }}
```


### TerraformデプロイCI
terraformファイルが更新されたら（'terraform/**'）CIからterraform applyするようにしている。  
apply時に必要なtfvarsの環境変数が増えたら、GitHub Actions Secretにも追加して、このCIファイルも更新する

.github/workflows/deploy_terraform_dev.yml

```yml
name: Deploy Terraform to Develop

on:
  push:
    paths:
      - 'terraform/**'
    branches:
      - develop

env:
  APP_ENV: dev
  TF_VERSION: 1.4.6
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: ap-northeast-1
  APP_KEY: ${{ secrets.DEV_APP_KEY }}
  DB_USERNAME: ${{ secrets.DEV_DB_USERNAME }}
  DB_PASSWORD: ${{ secrets.DEV_DB_PASSWORD }}

jobs:

  #
  # Terraform Apply
  #

  terrafom-apply:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:

      - name: Checkout Project
        uses: actions/checkout@v2

      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1 # https://github.com/aws-actions/configure-aws-credentials
        with:
          aws-access-key-id: ${{ env.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ env.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform setup
        run: |
          cp terraform/example.tfvars terraform/environments/dev/dev.tfvars
          cd terraform/environments/dev/
          sed -ie 's|app_key=".*"|app_key="${{ env.APP_KEY }}"|' dev.tfvars
          sed -ie 's|db_username=".*"|db_username="${{ env.DB_USERNAME }}"|' dev.tfvars
          sed -ie 's|db_password=".*"|db_password="${{ env.DB_PASSWORD }}"|' dev.tfvars

      - name: Terraform init
        working-directory: terraform/environments/dev
        run: |
          terraform init

      - name: Terraform apply
        working-directory: terraform/environments/dev
        run: |
          terraform apply -var-file=dev.tfvars -auto-approve -no-color
```


### TerraformプランCI
developブランチにマージする前に、トピックブランチから手動実行して確認する

```yml
name: Terraform Plan to Develop

on: workflow_dispatch

env:
  APP_ENV: dev
  TF_VERSION: 1.4.6
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_REGION: ap-northeast-1
  APP_KEY: ${{ secrets.DEV_APP_KEY }}
  DB_USERNAME: ${{ secrets.DEV_DB_USERNAME }}
  DB_PASSWORD: ${{ secrets.DEV_DB_PASSWORD }}

jobs:

  #
  # Terraform Plan
  #

  terrafom-plan:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:

      - name: Checkout Project
        uses: actions/checkout@v2

      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1 # https://github.com/aws-actions/configure-aws-credentials
        with:
          aws-access-key-id: ${{ env.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ env.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform setup
        run: |
          cp terraform/example.tfvars terraform/environments/dev/dev.tfvars
          cd terraform/environments/dev
          sed -ie 's|app_key=".*"|app_key="${{ env.APP_KEY }}"|' dev.tfvars
          sed -ie 's|db_username=".*"|db_username="${{ env.DB_USERNAME }}"|' dev.tfvars
          sed -ie 's|db_password=".*"|db_password="${{ env.DB_PASSWORD }}"|' dev.tfvars

      - name: Terraform init
        working-directory: terraform/environments/dev
        run: |
          terraform init

      - name: Terraform plan
        working-directory: terraform/environments/dev
        run: |
          terraform plan -var-file=dev.tfvars -no-color
```