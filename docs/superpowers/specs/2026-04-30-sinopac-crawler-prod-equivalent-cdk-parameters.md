# Sinopac Crawler Prod-Equivalent CDK Parameters

## 目的

定義 CDK 實作前必須確認的：

- deployment context
- infrastructure parameters
- naming convention
- secret / config 來源
- 現場補件欄位

## Environment Context

| Key | Required | Example | Source |
|---|---|---|---|
| environmentName | Yes | `prod-equivalent` | deployment context |
| awsAccountId | Yes | `123456789012` | target account |
| awsRegion | Yes | `ap-northeast-1` | target region |
| projectName | Yes | `crawler` | naming seed |

## Infrastructure Parameters

| Key | Required | Example | Used By |
|---|---|---|---|
| vpcCidr | Yes | `10.10.0.0/16` | NetworkStack |
| publicSubnetCidrs | Yes | `10.10.0.0/24,10.10.1.0/24` | NetworkStack |
| privateAppSubnetCidrs | Yes | `10.10.10.0/24,10.10.11.0/24` | NetworkStack |
| privateDataSubnetCidrs | Yes | `10.10.20.0/24,10.10.21.0/24` | NetworkStack |
| domainName | Yes | `crawlerportal.example.com` | EdgeStack |
| hostedZoneId | Yes | `Z123456789` | EdgeStack |
| certificateArn | Conditional | `arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxx` | EdgeStack |
| ec2InstanceType | Yes | `t3.large` | ComputeAppStack |
| ec2AmiId | Yes | `ami-xxxxxxxx` | ComputeAppStack |
| ec2RootVolumeGiB | Yes | `100` | ComputeAppStack |
| appInstanceCount | Yes | `2` | ComputeAppStack |
| rdsInstanceClass | Yes | `db.t3.medium` | DataStack |
| rdsEngineVersion | Yes | `8.0.x` | DataStack |
| crawlerDataBucketName | Yes | `crawler-prod-data-123456789012-ap-northeast-1` | DataStack |
| execResultBucketName | Yes | `crawler-prod-exec-result-123456789012-ap-northeast-1` | DataStack |
| lambdaRuntime | Yes | `python3.8` | ComputeCrawlerStack |
| lambdaTimeoutSeconds | Yes | `900` | ComputeCrawlerStack |
| lambdaMemoryMiB | Yes | `1024` | ComputeCrawlerStack |
| ecsTaskCpu | Yes | `1024` | ComputeCrawlerStack |
| ecsTaskMemoryMiB | Yes | `2048` | ComputeCrawlerStack |
| crawlerImageTag | Yes | `latest` 或 release tag | ComputeCrawlerStack |
| logRetentionDays | Yes | `30` | ObservabilityStack |

## Naming Convention

Pattern:

`<project>-<environment>-<component>`

Examples:

- `crawler-prod-equivalent-vpc`
- `crawler-prod-equivalent-alb`
- `crawler-prod-equivalent-app-sg`
- `crawler-prod-equivalent-rds`

Rules:

- 所有名稱必須可讀且可預測
- 需要全域唯一的資源名稱，應加上 account / region / suffix
- 不以人工手填名稱作為主要依賴

## Secret And Config Sources

| Logical Secret | Store | Example Name | Consumer |
|---|---|---|---|
| database credentials | Secrets Manager | `/crawler/prod-equivalent/db` | EC2 app / migration tooling |
| application config | SSM Parameter Store | `/crawler/prod-equivalent/app/config` | EC2 app |
| crawler runtime config | SSM Parameter Store | `/crawler/prod-equivalent/crawler/config` | Lambda / ECS task |
| internal callback auth | Secrets Manager | `/crawler/prod-equivalent/internal-callback` | Internal Lambda |
| smtp settings | Secrets Manager | `/crawler/prod-equivalent/smtp` | EC2 app |

## Field Collection Checklist

- Confirm actual VPC and subnet segmentation from prod
- Confirm ALB listeners, health checks, and target ports
- Confirm EC2 AMI, instance type, and storage sizing
- Confirm RDS engine, version, storage, and backup settings
- Confirm actual bucket naming, encryption, lifecycle, and policy rules
- Confirm Lambda layer artifacts, timeout, memory, and VPC attachment
- Confirm ECS task family, image source, CPU/memory, and network placement
- Confirm CloudWatch log group names and retention policy
- Confirm IAM role policy boundaries for EC2, Lambda, and ECS
- Confirm internal API callback path, port, and authentication method

## Recommended CDK Input Model

- `cdk.context.json` 或 deployment pipeline 提供環境名稱與非敏感設定
- Secrets Manager 管理帳密與敏感憑證
- Parameter Store 管理 bucket 名稱、endpoint、非敏感應用參數
- 各 stack 不直接讀取本地明文設定檔
