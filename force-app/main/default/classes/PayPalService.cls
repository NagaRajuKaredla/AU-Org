public class PayPalService {
    public static String getAccessToken() {
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Paypal_Sandbox/v1/oauth2/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=client_credentials');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('access_token');
        } else {
            System.debug('Error: ' + res.getBody());
            return null;
        }
    }
}
