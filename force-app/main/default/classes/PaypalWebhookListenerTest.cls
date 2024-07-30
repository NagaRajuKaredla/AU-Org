/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class PaypalWebhookListenerTest {

    @isTest
    static void testPostListener() {
        // Create test Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Invoice_Id__c = 'INV12345'
        );
        insert testOpp;

        // Define test JSON payload
        String jsonPayload = '{"resource_type": "invoices", "resource": {"invoice": {"id": "INV12345", "status": "PAID"}}}';

        // Mock HTTP request and response
        Test.starttest();
        
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/paypalListener/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonPayload);
        
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method
        PaypalWebhookListener.postHandler();
        
        Test.stoptest();
        
        // Validate the response
        System.assertEquals(200, res.statusCode);
        System.assertEquals('Opportunity updated successfully.', res.responseBody.toString());

        // Retrieve the updated Opportunity and verify status
        Opportunity updatedOpp = [SELECT Invoice_Status__c FROM Opportunity WHERE Id = :testOpp.Id];
        System.assertEquals('PAID', updatedOpp.Invoice_Status__c);
    }

    
}
