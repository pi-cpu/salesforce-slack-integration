public with sharing class SlackNotificationHandler implements Queueable, Database.AllowsCallouts {
    private final List<Opportunity> opps;

    public SlackNotificationHandler(List<Opportunity> opps) {
        // 深いコピーで防御（関連含む）
        this.opps = (opps == null) ? new List<Opportunity>() : opps.deepClone(true, true, true);
    }

    /** トリガからの入口（1トランザクション=1ジョブ） */
    public static void enqueueOpps(List<Opportunity> opps) {
        if (opps == null || opps.isEmpty()) return;
        System.enqueueJob(new SlackNotificationHandler(opps));
    }

    /** 既存の単発API互換（必要なら残す） */
    public static void sendToSlack(String message) {
        if (String.isBlank(message)) return;
        Opportunity dummy = new Opportunity(Name=message);
        System.enqueueJob(new SlackNotificationHandler(new List<Opportunity>{ dummy }));
    }

    public void execute(QueueableContext qc) {
        // CMDTから設定をロード（なければ安全なデフォルト）
        SlackConfigProvider.Conf conf = SlackConfigProvider.load();

        if (!conf.enabled) return;

        // Block Kit の blocks を構築（設定に合致した商談のみ）
        List<Object> blocks = new List<Object>();

        // 見出し（任意）
        blocks.add(new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => 'Opportunity Updates'
            }
        });

        for (Opportunity o : opps) {
            // 条件：ステージ OR 金額（設定未指定の条件はスキップ扱い）
            Boolean stageOk  = conf.targetStages.isEmpty() ? false
                               : (o.StageName != null && conf.targetStages.contains(o.StageName));
            Boolean amountOk = (conf.minAmount == null) ? false
                               : (o.Amount != null && o.Amount >= conf.minAmount);

            if (!(stageOk || amountOk)) continue;

            String acct  = (o.Account != null) ? o.Account.Name : '（取引先なし）';
            String owner = (o.Owner   != null) ? o.Owner.Name   : '（担当不明）';
            String amt   = (o.Amount  != null) ? String.valueOf(o.Amount.setScale(0)) : '—';
            String stage = (o.StageName != null) ? o.StageName : '—';

            // 1商談=1セクション
            blocks.add(new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*' + o.Name + '*\n' +
                              '顧客: ' + acct + ' | フェーズ: ' + stage + ' | 金額: ' + amt + ' | 担当: ' + owner
                }
            });

            // 仕切り線（任意）
            blocks.add(new Map<String, Object>{ 'type' => 'divider' });
        }

        // 送るものが無ければ終了
        if (blocks.size() <= 2) return; // header + dividerのみ等は送らない

        Map<String, Object> payload = new Map<String, Object>{
            'text'   => 'Opportunity Updates',
            'blocks' => blocks
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Slack_Webhook');                 // Named Credential でURL/認証を外出し
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json; charset=utf-8');
        req.setTimeout(5000);
        req.setBody(JSON.serialize(payload));                     // JSONは必ずserialize

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            Integer code = res.getStatusCode();
            if (code < 200 || code >= 300) {
                logError('Slack post failed', code + ' ' + res.getBody());
            }
        } catch (Exception e) {
            logError('Slack post exception', e.getMessage());
        }
    }

    @TestVisible private static void logError(String title, String detail) {
        System.debug(LoggingLevel.ERROR, title + ' :: ' + detail);
        // 将来: Integration_Log__c に保存 or Platform Event へ
    }
}
