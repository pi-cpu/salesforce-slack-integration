trigger OpportunityTrigger on Opportunity (after insert, after update) {
    // 変更検知（フェーズ or 金額）
    List<Id> changedIds = new List<Id>();
    for (Opportunity n : Trigger.new) {
        Opportunity o = Trigger.isUpdate ? Trigger.oldMap.get(n.Id) : null;

        Boolean stageChanged = Trigger.isInsert
            ? (n.StageName != null)
            : (n.StageName != o.StageName);

        Boolean amountChanged = Trigger.isInsert
            ? (n.Amount != null)
            : ((n.Amount == null && o.Amount != null)
               || (n.Amount != null && o.Amount == null)
               || (n.Amount != null && o.Amount != null && n.Amount != o.Amount));

        if (stageChanged || amountChanged) {
            changedIds.add(n.Id);
        }
    }
    if (changedIds.isEmpty()) return;

    // N+1回避：関連を含め一括SOQL
    List<Opportunity> opps = [
        SELECT Id, Name, StageName, Amount,
               AccountId, Account.Name,
               OwnerId, Owner.Name
        FROM Opportunity
        WHERE Id IN :changedIds
    ];

    // 判定や送信はハンドラ側（CMDTを読むので）
    SlackNotificationHandler.enqueueOpps(opps);
}
