trigger OpportunityTrigger on Opportunity (after update) {
    for (Opportunity opp : Trigger.new) {
        Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
        
        // フェーズや金額の変化を検知
        if (opp.StageName != oldOpp.StageName || opp.Amount != oldOpp.Amount) {
            String message = '商談更新: ' + opp.Name +
                             ', 顧客=' + opp.Account.Name +
                             ', フェーズ=' + opp.StageName +
                             ', 金額=' + opp.Amount +
                             ', 担当=' + opp.Owner.Name;
            SlackNotificationHandler.sendToSlack(message);
        }
    }
}
