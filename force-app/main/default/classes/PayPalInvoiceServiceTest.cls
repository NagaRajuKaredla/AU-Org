@isTest
public class PayPalInvoiceServiceTest {

    @isTest
    static void testCreateDraftInvoice() {
        // Setup test data
        Account account = new Account(Name = 'Test Account');
        insert account;
        
        Contact contact = new Contact(
            FirstName = 'John', 
            LastName = 'Doe', 
            Email = 'john.doe@example.com', 
            Phone = '1234567890', 
            MailingCountryCode = 'US', 
            MailingPostalCode = '90001'
        );
        insert contact;

        Product2 product = new Product2(Name = 'Test Product', IsActive = true);
        insert product;

        PricebookEntry pricebookEntry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            UnitPrice = 500,
            IsActive = true
        );
        insert pricebookEntry;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = account.Id,
            CloseDate = System.today().addDays(10),
            StageName = 'Closed Won',
            Amount = 1000,
            CurrencyIsoCode = 'USD',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert opp;

        OpportunityContactRole contactRole = new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = contact.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );
        insert contactRole;

        OpportunityLineItem lineItem = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pricebookEntry.Id,
            product2Id = product.id,
            Quantity = 1,
            UnitPrice = 500
        );
        insert lineItem;

        Test.startTest();

        // Mock PayPal response
        Test.setMock(HttpCalloutMock.class, new PayPalMockResponseGenerator());

        String invoiceId = PayPalInvoiceService.createDraftInvoice(opp.Id);
        PayPalInvoiceService.sendInvoice(invoiceId);
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Invoice_Id__c, Invoice_Link__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(invoiceId, updatedOpp.Invoice_Id__c, 'Invoice ID should match the one returned from PayPal');
        System.assertEquals('https://example.com/invoice/12345', updatedOpp.Invoice_Link__c, 'Invoice link should match the one returned from PayPal');
    }

    @isTest
    class PayPalMockResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setBody('{"id": "INV123456","href": "https://example.com/invoice/12345"}');
            return res;
        }
    }
}
