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