public with sharing class SlackConfigProvider {
    /** 設定用の軽量DTO */
    public class Conf {
        public Boolean enabled = true;
        public Decimal minAmount;           // nullなら金額判定を無効化
        public Set<String> targetStages = new Set<String>(); // 空ならステージ判定を無効化
    }

    /**
     * Custom Metadata (Slack_Config__mdt) を読み込む。
     * DeveloperName='Default' を想定。存在しない場合は安全デフォルト。
     */
    public static Conf load() {
        Conf c = new Conf();

        // デフォルト（CMDT未設定でも動く）
        c.enabled = true;
        c.minAmount = 1000000; // 100万円
        c.targetStages.addAll(new List<String>{ 'Prospecting', 'Proposal', 'Closed Won' });

        // CMDTがあれば上書き
        try {
            Slack_Config__mdt m = Slack_Config__mdt.getInstance('Default');
            if (m != null) {
                c.enabled = (m.Enabled__c == null) ? c.enabled : m.Enabled__c;
                if (m.MinAmount__c != null) c.minAmount = m.MinAmount__c;

                c.targetStages.clear();
                if (m.TargetStages__c != null && m.TargetStages__c.trim().length() > 0) {
                    for (String s : m.TargetStages__c.split('\\s*,\\s*')) {
                        if (!String.isBlank(s)) c.targetStages.add(s.trim());
                    }
                }
            }
        } catch (Exception e) {
            // 読み込み失敗時はデフォルトで継続
            System.debug(LoggingLevel.WARN, 'CMDT load failed: ' + e.getMessage());
        }
        return c;
    }
}
