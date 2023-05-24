## ECS Execで直接コンテナに入ってデバッグする方法

### 下準備
#### ①SSM実行権限用のポリシーを作成
「ECSTaskExecutionSSMmessages」という名前でポリシー作成

```bash
aws iam create-policy --policy-name ECSTaskExecutionSSMmessages \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource": "*"
      }
    ]
  }'
```

#### ②ECS用のロールに先ほど作成したポリシーを付与
ECS用のロール「y-oka-ecs-dev-task-execution」に作成したポリシーをアタッチ

```bash
ECS_ROLE="y-oka-ecs-dev-task-execution"
POLICY_ARN="arn:aws:iam::<awsのアカウントID>:policy/ECSTaskExecutionSSMmessages"

aws iam attach-role-policy \
  --role-name $ECS_ROLE \
  --policy-arn $POLICY_ARN
```

#### ③ECSでExecができるようにサービス更新

```bash
ECS_CLUSTER="y-oka-ecs-dev"
ECS_SERVICE="y-oka-ecs-dev"

# サービス更新
aws ecs update-service \
  --no-cli-pager \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --enable-execute-command
```

#### ④Exec実行用のタスク作成

```bash
ECS_CLUSTER="y-oka-ecs-dev"
ECS_SERVICE="y-oka-ecs-dev"
ECS_EXEC_CONTAINER="php-fpm"
ECS_TASK_FAMILY="y-oka-ecs-dev"

NETWORK_CONFIG=$(
  aws ecs describe-services \
    --cluster $ECS_CLUSTER \
    --services $ECS_SERVICE | jq '.services[0].networkConfiguration'
)

# タスク起動
task_arn=$(
  aws ecs run-task \
    --no-cli-pager \
    --launch-type FARGATE \
    --enable-execute-command \
    --cluster $ECS_CLUSTER \
    --task-definition $ECS_TASK_FAMILY \
    --network-configuration "${NETWORK_CONFIG}" | jq '.tasks[0].taskArn'
)

echo $task_arn

```

### 実行
#### ⑤ECS Execを実行

```bash
ECS_CLUSTER="y-oka-ecs-dev"
ECS_TASK="8e8211471de642aea9723405f8255fa3"
ECS_EXEC_CONTAINER="php-fpm"

# execコマンド実行
aws ecs execute-command \
  --cluster $ECS_CLUSTER \
  --task $ECS_TASK \
  --container $ECS_EXEC_CONTAINER \
  --interactive \
  --command "/bin/sh"
```

### 後片付け
#### ⑥作成したタスクを終了

```bash
ECS_CLUSTER="y-oka-ecs-dev"
ECS_TASK="8e8211471de642aea9723405f8255fa3"

aws ecs stop-task \
  --no-cli-pager \
  --cluster $ECS_CLUSTER \
  --task $ECS_TASK
```

#### ⑦更新したサービスを元に戻す

```bash
ECS_CLUSTER="y-oka-ecs-dev"
ECS_SERVICE="y-oka-ecs-dev"

aws ecs update-service \
  --no-cli-pager \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --disable-execute-command
```

#### ⑧作成したポリシーをデタッチ＆削除

```bash
POLICY_ARN="arn:aws:iam::xxxxxxxxxxxx:policy/ECSTaskExecutionSSMmessages"

aws iam detach-role-policy \
  --role-name y-oka-ecs-dev-task-execution \
  --policy-arn $POLICY_ARN

aws iam delete-policy --policy-arn $POLICY_ARN
```
