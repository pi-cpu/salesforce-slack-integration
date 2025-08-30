# Salesforce + Slack Notification Integration

## プロジェクト概要
Salesforce の商談進捗をトリガーにして **Slack へ通知を送信する API 連携** を構築。  
標準機能との差別化を示し、**拡張性とコスト削減**をアピールできるポートフォリオ用プロジェクト。

---

## 背景と目的
- 多くの企業は Salesforce と Slack を併用し、営業進捗をリアルタイム共有したいと考えている。  
- 標準連携（AppExchange アプリ）は存在するが、**通知条件やメッセージ内容の柔軟な制御が難しい**。  
- 本実装では **Webhook + Apex Callout** を用いて、条件や通知内容を自由に設計可能にした。

---

## 要件定義
1. **トリガー条件**
   - 商談オブジェクトのフェーズが特定の値（例：50% / 10% / 0%）に変更されたとき  
   - 金額が一定以上になったとき  

2. **通知内容**
   - 商談名  
   - 顧客名（Account）  
   - 担当者（Owner）  
   - 進捗状況（Stage, Probability）  
   - 備考（Remarks）  

3. **通知方法**
   - Slack Webhook URL を利用  
   - JSON 形式でカスタムメッセージを送信  

---

## 標準機能との比較
| 項目 | 標準連携 (Salesforce for Slack) | 自作API連携 |
|------|---------------------------------|-------------|
| 初期コスト | 高い（ライセンス費用が発生する場合あり） | 低い（Webhook利用のみ） |
| カスタマイズ性 | 限定的 | 高い（条件・メッセージ自由） |
| 拡張性 | Slackのみ | Teams/Discordなどへ拡張可能 |

---

## アーキテクチャ

```mermaid
flowchart LR
    A[Salesforce Opportunity Update] --> B[Apex Trigger]
    B --> C[SlackNotificationHandler (Future Callout)]
    C --> D[Slack Webhook]
    D --> E[Slack Channel]
```
---

## クイックスタート

1. **SlackでWebhookを発行**
   - ワークスペース設定から「Incoming Webhook」を有効化し、通知先チャンネルを指定してURLを控える。  

2. **環境変数を設定**
   - リポジトリ直下に `.env` を作成し、以下の内容を記述：
     ```dotenv
     SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxxx/yyyy/zzzz
     ```

3. **SalesforceにApexコードをデプロイ**
   - `SlackNotificationHandler.cls` とトリガファイルをアップロード。  

4. **動作確認**
   - 商談ステージを変更してSlackに通知が届くことを確認。  

---

## 環境変数とセキュリティ

- 本番用のWebhook URLは `.env` に記述し、`.gitignore` によりリポジトリには含めない。  
- 代わりに `.env.example` を配布用として用意。  
- Push Protection / Secret Scanning を有効化し、誤コミットを防止。  

---

## 拡張案

- **他ツールへの展開**  
  - Teams / Discord / Google Chat など、Webhook対応サービスへ拡張可能。  

- **通知内容のテンプレート化**  
  - JSON構造をメタデータ化し、管理者がGUIで編集できるように。  

- **キューイング処理**  
  - Platform Eventsやキューを利用して、大量通知時の負荷を軽減。  

- **権限設定**  
  - 特定のプロファイル/ロールのみ通知を許可する制御。  

---

## スクリーンショット（例）

<!-- 後で追加予定 -->

## 設計 (Architecture & Design)

### 目的（非機能要件）
- **バルク安全**：複数レコード更新でも Governor Limit に掛からない
- **責務分離**：Trigger は検知・抽出のみ、処理は Handler（Queueable）へ委譲
- **運用容易**：閾値/対象ステージは **Custom Metadata**（CMDT）でノーコード設定
- **セキュア**：Webhook URL は **Named Credential** に外出し（コードに秘匿情報を持たない）
- **見やすい通知**：Slack **Block Kit** で可読性の高いメッセージ

---

### モジュール構成
- **`OpportunityTrigger.trigger`**
  - after insert / after update で変更検知（フェーズ or 金額）
  - 関連（Account, Owner）を **一括SOQL** で取得
  - 通知メッセージの素材を作り、**1回だけ Queueable** を enqueue

- **`SlackNotificationHandler.cls`**
  - `Queueable, AllowsCallouts` で **非同期 Callout**
  - **Named Credential**（`callout:Slack_Webhook`）へ POST
  - JSON は `JSON.serialize` で安全生成
  - Slack **Block Kit** の `blocks` を構築し、**複数商談を1リクエスト**で送信
  - 失敗時は `System.debug(ERROR)`（将来はログ用オブジェクト/Platform Eventへ）

- **`SlackConfigProvider.cls`**
  - **CMDT (`Slack_Config__mdt`)** から設定を読込
    - `Enabled__c`（ON/OFF）
    - `MinAmount__c`（通知する金額の下限）
    - `TargetStages__c`（カンマ区切りの対象ステージ）
  - CMDT が未設定でも動く **安全デフォルト** を保持

---

### 処理フロー
```mermaid
sequenceDiagram
  participant SF as Salesforce
  participant Trg as OpportunityTrigger
  participant Q as SlackNotificationHandler(Queueable)
  participant Slack as Slack Webhook

  SF->>Trg: after insert/update (Opportunity)
  Trg->>Trg: フェーズ/金額の変更検知、対象IDを収集
  Trg->>Trg: 1回のSOQLで関連(Account/Owner)を取得
  Trg->>Q: enqueueOpps(opps)（1トランザクション＝1ジョブ）
  activate Q
  Q->>Q: CMDT 読込（閾値/対象ステージ/有効フラグ）
  Q->>Q: Block Kit blocks を組み立て
  Q->>Slack: POST (Named Credential: callout:Slack_Webhook)
  Slack-->>Q: 200 / エラー
  Q->>Q: エラーなら監査ログ出力
  deactivate Q
