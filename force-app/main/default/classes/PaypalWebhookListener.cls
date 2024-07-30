@RestResource(urlMapping='/paypalListener/*')
global without sharing class PaypalWebhookListener {

    @HttpPost
    global static void postHandler() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Parse the request body to extract the JSON payload
            String requestBody = req.requestBody.toString();
            Map<String, Object> jsonPayload = (Map<String, Object>) JSON.deserializeUntyped(requestBody);

            // Debug the payload for verification
            System.debug(jsonPayload);

            // Check if the resource type is 'invoices'
            if ((String)jsonPayload.get('resource_type') == 'invoices') {
                // Extract invoice details
                Map<String, Object> invoice = (Map<String, Object>)((Map<String, Object>)jsonPayload.get('resource')).get('invoice');
                System.debug(invoice);

                // Retrieve invoice ID and status
                String invoiceId = (String)invoice.get('id');
                String invoiceStatus = (String)invoice.get('status');

                // Query Opportunity using the invoice ID
                List<Opportunity> opportunities = [SELECT Id FROM Opportunity WHERE Invoice_Id__c = :invoiceId LIMIT 1];
                
                if (!opportunities.isEmpty()) {
                    Opportunity opp = opportunities[0];
                    opp.Invoice_Status__c = invoiceStatus;

                    // Update Opportunity
                    Database.SaveResult result = Database.update(opp, false);
                    if (result.isSuccess()) {
                        res.statusCode = 200;
                        res.responseBody = Blob.valueOf('Opportunity updated successfully.');
                    } else {
                        res.statusCode = 500;
                        res.responseBody = Blob.valueOf('Failed to update Opportunity: ' + result.getErrors()[0].getMessage());
                    }
                } else {
                    res.statusCode = 404;
                    res.responseBody = Blob.valueOf('Invoice not found for ID: ' + invoiceId);
                }
            } else {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Invalid resource type');
            }
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error processing request: ' + e.getMessage());
        }
    }
}
