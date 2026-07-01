# Sinopac Crawler Prod-Equivalent CDK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 產出一套可實作 AWS CDK（TypeScript）的規劃與文件基線，用於新建與既有 prod 行為等價的 crawler 正式環境。

**Architecture:** 採多 stack 的 CDK app 架構，將既有正式環境拆為網路、邊界、資料、應用運算、crawler 運算、觀測與設定七個責任明確的 stacks。先完成文件、參數、命名與 stack 邊界定義，再進入後續 CDK 程式實作。

**Tech Stack:** Markdown、Mermaid、AWS CDK v2（TypeScript）、Route53、ACM、ALB、EC2、RDS、S3、Lambda、ECS Fargate、ECR、CloudWatch、SSM Parameter Store、Secrets Manager

---

## File Structure

### Existing Files

- `docs/sinopac-crawler-prod-equivalent-cdk/spec.md`
  - 已確認的設計規格來源

### Files To Create

- `docs/sinopac-crawler-prod-equivalent-cdk/plan.md`
  - 本 implementation plan
- `docs/sinopac-crawler-prod-equivalent-cdk/resource-matrix.md`
  - PDF 元件與 CDK stack / AWS 資源的對照表
- `docs/sinopac-crawler-prod-equivalent-cdk/parameters.md`
  - 參數、命名、secret 與現場補件清單整理

### Files To Modify

- `docs/sinopac-crawler-prod-equivalent-cdk/spec.md`
  - 視需要補上 cross-stack reference、部署順序、規劃修正

## CDK Project Bootstrap Tasks

1. 建立 `infra/` 專案目錄
2. 初始化 `package.json`
3. 安裝 `aws-cdk-lib`、`constructs`、`typescript`、`ts-node`
4. 建立 `cdk.json`
5. 建立 `bin/app.ts`
6. 建立 `lib/stacks/` 與 `lib/constructs/`
7. 建立環境設定模組 `lib/config/env-config.ts`
8. 建立命名模組 `lib/config/naming.ts`

## Implementation Sequence

1. `ConfigStack`
2. `NetworkStack`
3. `DataStack`
4. `ComputeAppStack`
5. `ComputeCrawlerStack`
6. `EdgeStack`
7. `ObservabilityStack`

每個 stack 完成後都必須：

- `cdk synth`
- 審查產出的 CloudFormation template
- 確認 naming / tagging / IAM boundary

## Validation Checklist

- `cdk synth` 成功
- stack tags 一致
- bucket encryption 開啟
- SG 規則符合最小權限
- Lambda 與 ECS 均有 log group / retention
- RDS 僅位於 private data subnet
- ALB 只暴露必要 listener
- secret 未以 plain text 出現在 template context

## Task 1: 建立資源對照矩陣文件

**Files:**
- Create: `docs/sinopac-crawler-prod-equivalent-cdk/resource-matrix.md`
- Modify: `docs/sinopac-crawler-prod-equivalent-cdk/spec.md`
- Test: 無自動化測試；使用 `rg` 與人工審閱驗證欄位完整性

- [ ] **Step 1: 建立對照矩陣文件骨架**

```md
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
```

- [ ] **Step 2: 填入正式環境核心元件**

```md
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
| Shared config | PDF bucket / role / key 指引 | SSM / Secrets Manager | ConfigStack | 管理參數與敏感資訊 | Yes | Yes | secret 來源與 rotation 政策需補件 |
```

- [ ] **Step 3: 檢查每個元件是否都有 stack 歸屬**

Run:

```bash
rg -n "^\| .* \| .* \| .* \| .* \| .* \| .* \| .* \| .* \|$" docs/sinopac-crawler-prod-equivalent-cdk/resource-matrix.md
```

Expected:

- 每一列都符合八欄格式
- 無遺漏 `CDK Stack` 或 `Construct Responsibility`

- [ ] **Step 4: 補充設計文件中的矩陣引用段落**

在 `docs/sinopac-crawler-prod-equivalent-cdk/spec.md` 追加：

```md
## 資源盤點依據

正式環境元件與 CDK stack 歸屬，進一步整理於：

- `docs/sinopac-crawler-prod-equivalent-cdk/resource-matrix.md`

後續實作與現場補件，均以該矩陣為盤點基線。
```

- [ ] **Step 5: Commit**

```bash
git add docs/sinopac-crawler-prod-equivalent-cdk/resource-matrix.md docs/sinopac-crawler-prod-equivalent-cdk/spec.md
git commit -m "docs: add prod-equivalent resource matrix"
```

## Task 2: 建立參數與命名規格文件

**Files:**
- Create: `docs/sinopac-crawler-prod-equivalent-cdk/parameters.md`
- Modify: `docs/sinopac-crawler-prod-equivalent-cdk/spec.md`
- Test: 無自動化測試；用 `rg` 驗證章節與參數 key 完整性

- [ ] **Step 1: 建立參數規格文件骨架**

```md
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
```

- [ ] **Step 2: 填入 deployment context 與基礎設施參數**

```md
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
| certificateArn | Conditional | `arn:aws:acm:...` | EdgeStack |
| ec2InstanceType | Yes | `t3.large` | ComputeAppStack |
| ec2AmiId | Yes | `ami-xxxxxxxx` | ComputeAppStack |
| ec2RootVolumeGiB | Yes | `100` | ComputeAppStack |
| rdsInstanceClass | Yes | `db.t3.medium` | DataStack |
| rdsEngineVersion | Yes | `8.0.x` | DataStack |
| crawlerDataBucketName | Yes | `crawler-prod-data-...` | DataStack |
| execResultBucketName | Yes | `crawler-prod-exec-result-...` | DataStack |
| lambdaRuntime | Yes | `python3.8` | ComputeCrawlerStack |
| lambdaTimeoutSeconds | Yes | `900` | ComputeCrawlerStack |
| ecsTaskCpu | Yes | `1024` | ComputeCrawlerStack |
| ecsTaskMemoryMiB | Yes | `2048` | ComputeCrawlerStack |
| crawlerImageTag | Yes | `latest` or release tag | ComputeCrawlerStack |
| logRetentionDays | Yes | `30` | ObservabilityStack |
```

- [ ] **Step 3: 定義命名規則與 secret 來源**

```md
## Naming Convention

Pattern:

`<project>-<environment>-<component>`

Examples:

- `crawler-prod-equivalent-vpc`
- `crawler-prod-equivalent-alb`
- `crawler-prod-equivalent-app-sg`

## Secret And Config Sources

| Logical Secret | Store | Example Name | Consumer |
|---|---|---|---|
| database credentials | Secrets Manager | `/crawler/prod-equivalent/db` | EC2 app / migration tooling |
| application config | SSM Parameter Store | `/crawler/prod-equivalent/app/config` | EC2 app |
| crawler runtime config | SSM Parameter Store | `/crawler/prod-equivalent/crawler/config` | Lambda / ECS task |
| internal callback auth | Secrets Manager | `/crawler/prod-equivalent/internal-callback` | Internal Lambda |
```

- [ ] **Step 4: 補充現場補件欄位整理**

```md
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
```

- [ ] **Step 5: 驗證關鍵參數名稱是否一致**

Run:

```bash
rg -n "environmentName|awsAccountId|awsRegion|projectName|vpcCidr|domainName|ec2InstanceType|rdsInstanceClass|crawlerImageTag" docs/sinopac-crawler-prod-equivalent-cdk/parameters.md
```

Expected:

- 所有關鍵參數名稱均可被搜尋到
- 命名與設計文件中描述一致

- [ ] **Step 6: Commit**

```bash
git add docs/sinopac-crawler-prod-equivalent-cdk/parameters.md docs/sinopac-crawler-prod-equivalent-cdk/spec.md
git commit -m "docs: define prod-equivalent cdk parameters"
```

## Task 3: 補完 CDK 實作邊界與 cross-stack 規劃

**Files:**
- Modify: `docs/sinopac-crawler-prod-equivalent-cdk/spec.md`
- Test: 使用 `rg` 檢查 stack 名稱與 cross-stack 關鍵字是否存在

- [ ] **Step 1: 在設計文件加入 cross-stack reference 區段**

在 `docs/sinopac-crawler-prod-equivalent-cdk/spec.md` 追加：

```md
## Cross-Stack Reference Strategy

- `NetworkStack` 輸出：
  - VPC
  - subnets
  - shared security groups
  - endpoint 相關資訊
- `EdgeStack` 依賴：
  - `NetworkStack` 的 public subnets
  - `ComputeAppStack` 的 target attachments
- `DataStack` 依賴：
  - `NetworkStack` 的 data subnets 與 SG
- `ComputeAppStack` 依賴：
  - `NetworkStack` 的 app subnets / SG
  - `DataStack` 的 RDS endpoint / secret reference
- `ComputeCrawlerStack` 依賴：
  - `NetworkStack` 的 private subnets / SG
  - `DataStack` 的 bucket references
  - `ConfigStack` 的參數與 secret references
- `ObservabilityStack` 依賴：
  - 其他 stacks 的 log group names、alarm targets
```

- [ ] **Step 2: 在設計文件加入部署順序**

追加：

```md
## Deployment Order

1. `ConfigStack`
2. `NetworkStack`
3. `DataStack`
4. `ComputeAppStack`
5. `ComputeCrawlerStack`
6. `EdgeStack`
7. `ObservabilityStack`

說明：

- `ConfigStack` 先建立全域參數與 secret 容器
- `NetworkStack` 提供後續所有 stack 的底層網路
- `DataStack` 建立資料與 bucket 依賴
- `ComputeAppStack` 與 `ComputeCrawlerStack` 建立主要運算元件
- `EdgeStack` 最後綁定對外入口到實際 app targets
- `ObservabilityStack` 在元件名稱與 log group 明確後建立 alarm / dashboard
```

- [ ] **Step 3: 加入 IaC 邊界與 handoff 說明**

追加：

```md
## IaC Boundary And Handoff

CDK 專案負責：

- 建立 AWS 資源
- 產出可審計的 stack 差異
- 將環境差異收斂到參數與 secret

CDK 專案不負責：

- 部署 Java WAR
- build / push crawler image
- 打包 Lambda 商業邏輯 artifact
- 匯入正式資料

上述項目需由後續 deployment pipeline 或作業手冊承接。
```

- [ ] **Step 4: 驗證規劃段落是否齊全**

Run:

```bash
rg -n "Cross-Stack Reference Strategy|Deployment Order|IaC Boundary And Handoff|ConfigStack|NetworkStack|ComputeCrawlerStack" docs/sinopac-crawler-prod-equivalent-cdk/spec.md
```

Expected:

- 三個區段名稱皆存在
- 主要 stack 名稱可被搜尋到

- [ ] **Step 5: Commit**

```bash
git add docs/sinopac-crawler-prod-equivalent-cdk/spec.md
git commit -m "docs: refine cdk stack boundaries and deployment order"
```

## Task 4: 建立 CDK 專案初始化與實作順序計畫

**Files:**
- Modify: `docs/sinopac-crawler-prod-equivalent-cdk/plan.md`
- Test: 以人工審閱確認每個 stack 都有對應初始化與實作順序

- [ ] **Step 1: 補充 CDK app 初始化任務清單**

在本 plan 新增：

```md
## CDK Project Bootstrap Tasks

1. 建立 `infra/` 專案目錄
2. 初始化 `package.json`
3. 安裝 `aws-cdk-lib`、`constructs`、`typescript`、`ts-node`
4. 建立 `cdk.json`
5. 建立 `bin/app.ts`
6. 建立 `lib/stacks/` 與 `lib/constructs/`
7. 建立環境設定模組 `lib/config/env-config.ts`
8. 建立命名模組 `lib/config/naming.ts`
```

- [ ] **Step 2: 補充實作優先順序**

新增：

```md
## Implementation Sequence

1. `ConfigStack`
2. `NetworkStack`
3. `DataStack`
4. `ComputeAppStack`
5. `ComputeCrawlerStack`
6. `EdgeStack`
7. `ObservabilityStack`

每個 stack 完成後都必須：

- `cdk synth`
- 審查產出的 CloudFormation template
- 確認 naming / tagging / IAM boundary
```

- [ ] **Step 3: 補充驗證清單**

新增：

```md
## Validation Checklist

- `cdk synth` 成功
- stack tags 一致
- bucket encryption 開啟
- SG 規則符合最小權限
- Lambda 與 ECS 均有 log group / retention
- RDS 僅位於 private data subnet
- ALB 只暴露必要 listener
- secret 未以 plain text 出現在 template context
```

- [ ] **Step 4: Commit**

```bash
git add docs/sinopac-crawler-prod-equivalent-cdk/plan.md
git commit -m "docs: expand cdk implementation sequence"
```

## Task 5: Plan Self-Review

**Files:**
- Modify: `docs/sinopac-crawler-prod-equivalent-cdk/plan.md`
- Modify: `docs/sinopac-crawler-prod-equivalent-cdk/spec.md`
- Modify: `docs/sinopac-crawler-prod-equivalent-cdk/resource-matrix.md`
- Modify: `docs/sinopac-crawler-prod-equivalent-cdk/parameters.md`
- Test: 使用 `rg` 搜尋 placeholder 與關鍵章節

- [ ] **Step 1: 檢查 spec coverage**

Run:

```bash
rg -n "目標|正式環境整理版架構|CDK 專案切分|參數化策略|命名策略|不納入 IaC 的項目|待現場補件清單" docs/sinopac-crawler-prod-equivalent-cdk/spec.md
```

Expected:

- 規格中的主要區段均存在
- plan 各 task 已覆蓋資源矩陣、參數、stack 邊界、部署順序

- [ ] **Step 2: 搜尋 placeholder 或模糊字眼**

Run:

```bash
pattern='TB''D|TO''DO|implement ''later|fill ''in ''details|appropriate ''error ''handling|similar ''to ''Task'
rg -n "$pattern" docs/sinopac-crawler-prod-equivalent-cdk/plan.md docs/sinopac-crawler-prod-equivalent-cdk/spec.md docs/sinopac-crawler-prod-equivalent-cdk/resource-matrix.md docs/sinopac-crawler-prod-equivalent-cdk/parameters.md
```

Expected:

- 無輸出

- [ ] **Step 3: 檢查命名與 stack 名稱一致性**

Run:

```bash
rg -n "NetworkStack|EdgeStack|DataStack|ComputeAppStack|ComputeCrawlerStack|ObservabilityStack|ConfigStack" docs/sinopac-crawler-prod-equivalent-cdk/plan.md docs/sinopac-crawler-prod-equivalent-cdk/spec.md
```

Expected:

- 所有 stack 名稱拼寫一致

- [ ] **Step 4: Commit**

```bash
git add docs/sinopac-crawler-prod-equivalent-cdk/plan.md docs/sinopac-crawler-prod-equivalent-cdk/spec.md docs/sinopac-crawler-prod-equivalent-cdk/resource-matrix.md docs/sinopac-crawler-prod-equivalent-cdk/parameters.md
git commit -m "docs: finalize prod-equivalent cdk implementation plan"
```
