# Sinopac Crawler Prod-Equivalent CDK Resource Matrix

## 目的

將 PDF 中出現的正式環境元件，對照到：

- AWS 實體資源
- CDK stack 歸屬
- CDK construct 責任
- 是否參數化
- 是否需現場補件

## 對照表

| Logical Component | Source Evidence | AWS Resource | CDK Stack | Construct Responsibility | Parameterized | External Input Required | Notes |
|---|---|---|---|---|---|---|---|
| Internet entry | PDF 正式環境流程 1-2 | Route53 record / ACM / ALB | EdgeStack | 建立對外入口、listener、target group | Yes | Yes | domain、certificate 來源需補件 |
| App node A | PDF 正式環境流程 2-3 | EC2 instance | ComputeAppStack | 建立應用節點與安全群組 | Yes | Yes | AMI、instance type、磁碟需補件 |
| App node B | PDF 正式環境流程 2-3 | EC2 instance | ComputeAppStack | 建立應用節點與安全群組 | Yes | Yes | 與 App node A 同規格 |
| Database | PDF 正式環境流程 3 | RDS MySQL | DataStack | 建立 DB、subnet group、parameter group | Yes | Yes | engine/version/backup policy 需補件 |
| Crawler file bucket | PDF 正式環境流程 5、9 | S3 bucket | DataStack | 存 raw / parsed files | Yes | Yes | naming、lifecycle、policy 需補件 |
| Exec result bucket | PDF 正式環境流程 6-8 | S3 bucket | DataStack | 存 exec result 並觸發 internal Lambda | Yes | Yes | event routing 細節需補件 |
| Public crawler execution | PDF 正式環境流程 4-5 | Lambda + Layer | ComputeCrawlerStack | 建立 public Lambda 與 layer 關聯 | Yes | Yes | runtime / timeout / artifact 來源需補件 |
| Internal callback | PDF 正式環境流程 6-8 | Lambda + SG | ComputeCrawlerStack | 讀取 S3 結果並回呼平台 API | Yes | Yes | API path、port、VPC 掛載需補件 |
| Container image store | PDF ECR / Fargate 章節 | ECR repository | ComputeCrawlerStack | 提供 crawler image | Yes | No | tag policy 可於 CDK 規劃 |
| Container crawler runtime | PDF Fargate 章節 | ECS Cluster / Task Definition / Fargate | ComputeCrawlerStack | 建立 crawler 任務執行能力 | Yes | Yes | image tag、CPU/memory、subnets 需補件 |
| Logging | PDF CloudWatch log | Log group / alarms | ObservabilityStack | 建立 log retention 與 alarms | Yes | Yes | 命名與 retention 需補件 |
| Shared config | PDF bucket / role / key 指引 | SSM Parameter Store / Secrets Manager | ConfigStack | 管理參數與敏感資訊 | Yes | Yes | secret 來源與 rotation 政策需補件 |

## 使用方式

- 此表作為 PDF 與 CDK 設計之間的盤點基線
- 後續 CDK stack 實作時，應先確認每列是否已有對應 construct
- 現場補件完成後，應優先更新 `External Input Required` 與 `Notes`
