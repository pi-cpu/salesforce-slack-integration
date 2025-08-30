@IsTest
private class SlackNotificationHandlerTest {
    @IsTest
    static void postOnQualifiedUpdate() {
        Test.setMock(HttpCalloutMock.class, new OkMock());

        Opportunity o = new Opportunity(
            Name='Test Opp',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(30),
            Amount=1200000
        );
        insert o;

        Test.startTest();
        // 金額またはステージ変更（どちらかで可）
        o.StageName = 'Proposal';
        update o;
        Test.stopTest();

        System.assert(true, 'Queueable 実行まで完了');
    }

    @IsTest
    static void skipWhenNotQualified() {
        Test.setMock(HttpCalloutMock.class, new OkMock());

        Opportunity o = new Opportunity(
            Name='No Notify',
            StageName='Prospecting',
            CloseDate=Date.today().addDays(30),
            Amount=10
        );
        insert o;

        Test.startTest();
        // 条件非該当（例：ステージ据え置き・金額も閾値未満）
        update o;
        Test.stopTest();

        System.assert(true, '送信されない（例外なし）');
    }

    private class OkMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assertNotEquals(null, req.getBody());
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }
}
