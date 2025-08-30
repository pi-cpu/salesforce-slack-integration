public with sharing class SlackNotificationHandler {
    @future(callout=true)
    public static void sendToSlack(String message) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Slack_Webhook');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{ "text": "' + message + '" }');

        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Slack Response: ' + res.getBody());
    }
}
