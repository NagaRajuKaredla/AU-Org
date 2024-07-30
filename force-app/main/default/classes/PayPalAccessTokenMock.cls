@IsTest
global class PayPalAccessTokenMock implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"access_token":"A21AAK...xyz"}');
        res.setStatusCode(200);
        return res;
    }
}
