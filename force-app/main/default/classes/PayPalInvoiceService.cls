public class PayPalInvoiceService {

    // Method to create draft invoice
    public static String createDraftInvoice(Id oppId) {
        if (String.isBlank(oppId)) {
            return null;
        }
        try {
            Opportunity opp = getOpportunity(oppId);
            if (opp == null || opp.OpportunityContactRoles.isEmpty() || opp.OpportunityLineItems.isEmpty()) {
                return null;
            }

            string accessToken = PayPalAuthService.getAccessToken();
            if(string.isEmpty(accessToken)){
                return null;
            }

            OpportunityContactRole contactRole = opp.OpportunityContactRoles[0];
            OpportunityLineItem[] lineItems = opp.OpportunityLineItems;

            Map<String, Object> request = buildRequestPayload(opp, contactRole, lineItems);
            String payload = JSON.serialize(request);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Paypal_Sandbox/v2/invoicing/invoices');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Prefer', 'return=representation');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody(payload);

            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('res: ' + res);

            if (res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('responseMap: ' + responseMap);
                String invoiceId = (String)responseMap.get('id');
                System.debug('invoice Id: ' + invoiceId);

                Database.update(new Opportunity(Id = opp.Id, Invoice_Id__c = invoiceId), false);

                return invoiceId;
            } else {
                System.debug('Error: ' + res.getStatus());
                System.debug('Response: ' + res.getBody());
                return null;
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            return null;
        }
    }

    // Method to send an invoice
    public static void sendInvoice(String invoiceId, Id oppId) {
        if (String.isBlank(invoiceId)) {
            return;
        }

        try {
            String accessToken = PayPalAuthService.getAccessToken();
            if (String.isEmpty(accessToken)) {
                return;
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Paypal_Sandbox/v2/invoicing/invoices/' + invoiceId + '/send');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Prefer', 'return=representation');
            req.setBody(JSON.serialize(new map<string, object>{'send_to_recipient' => true}));

            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Send Invoice Response: ' + res);

            if (res.getStatusCode() == 200) {
                // Successful response
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('Send Invoice Response Map: ' + responseMap);
                Database.update(new Opportunity(Id = oppId, Invoice_Iink__c = (String)responseMap.get('href')), false);
                
            } else {
                // Log error response
                System.debug('Error: ' + res.getStatus());
                System.debug('Response: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
    }

    private static Opportunity getOpportunity(Id oppId) {
        List<Opportunity> oppData = [SELECT Id, Name, Amount, CurrencyIsoCode,
                                        (SELECT Id, Product2.Name, ProductCode, Quantity, UnitPrice, Discount FROM OpportunityLineItems),
                                        (SELECT Id, Contact.FirstName, Contact.LastName, Contact.Email, Contact.Phone, Contact.CountryISDCode__c,
                                                Contact.MailingStreet, Contact.MailingCity, Contact.MailingState, Contact.MailingStateCode, 
                                                Contact.MailingCountryCode, Contact.MailingPostalCode FROM OpportunityContactRoles WHERE IsPrimary = TRUE)
                                    FROM Opportunity WHERE Id = :oppId];
        return oppData.isEmpty() ? null : oppData[0];
    }

    private static Map<String, Object> buildRequestPayload(Opportunity opp, OpportunityContactRole contactRole, OpportunityLineItem[] lineItems) {
        Map<String, Object> request = new Map<String, Object>();
        
        request.put('detail', buildDetails(opp));
        request.put('invoicer', buildInvoicer());
        request.put('primary_recipients', buildPrimaryRecipients(contactRole));
        request.put('items', buildItems(opp, lineItems));
       // request.put('configuration', buildConfiguration());
        request.put('amount', buildAmount(opp));

        return request;
    }

    private static Map<String, Object> buildDetails(Opportunity opp) {
        String dueDate = System.now().format('YYYY-MM-dd');
        
        Map<String, Object> details = new Map<String, Object>();
        details.put('currency_code', opp.CurrencyIsoCode);
       // details.put('invoice_number', '#123');  // Skip this param to generate dynamic invoice number from paypals
        details.put('reference', opp.Name);
        details.put('invoice_date', dueDate);
        details.put('note', 'Thank you for your business.');
        details.put('term', 'No refunds after 30 days.');
        details.put('memo', 'This is a long contract');
        details.put('payment_term', new Map<String, Object>{'term_type' => 'NO_DUE_DATE', 'due_date' => dueDate});

        return details;
    }

    private static Map<String, Object> buildInvoicer() {
        Map<String, Object> invoicer = new Map<String, Object>();
        //I have provided static invoicer details but in real time it should be a business client details.
        invoicer.put('name', new Map<String, Object>{'given_name' => 'David', 'surname' => 'Larusso'});
        invoicer.put('address', new Map<String, Object>{
            'address_line_1' => '1234 First Street',
            'address_line_2' => '337673 Hillside Court',
            'admin_area_2' => 'Anytown',
            'admin_area_1' => 'CA',
            'postal_code' => '98765',
            'country_code' => 'US'
        });
        invoicer.put('email_address', 'merchant@example.com');
        invoicer.put('phones', new List<Object>{new Map<String, Object>{
            'country_code' => '001',
            'national_number' => '4085551234',
            'phone_type' => 'MOBILE'
        }});
        invoicer.put('website', 'www.test.com');
        invoicer.put('tax_id', 'ABcNkWSfb5ICTt73nD3QON1fnnpgNKBy- Jb5SeuGj185MNNw6g');
        invoicer.put('logo_url', 'https://example.com/logo.PNG');
        invoicer.put('additional_notes', '2-4');

        return invoicer;
    }

    private static List<Object> buildPrimaryRecipients(OpportunityContactRole contactRole) {
        Map<String, Object> recipientInfo = new Map<String, Object>{
            'name' => new Map<String, Object>{'given_name' => contactRole.Contact.FirstName, 'surname' => contactRole.Contact.LastName},
            'address' => new Map<String, Object>{
                'address_line_1' => contactRole.Contact.MailingStreet,
                'admin_area_2' => contactRole.Contact.MailingCity,
                'admin_area_1' => contactRole.Contact.MailingStateCode,
                'postal_code' => contactRole.Contact.MailingPostalCode,
                'country_code' => contactRole.Contact.MailingCountryCode
            },
            'email_address' => contactRole.Contact.Email,
            'phones' => new List<Object>{new Map<String, Object>{
                'country_code' => contactRole.Contact.CountryISDCode__c,
                'national_number' => contactRole.Contact.Phone,
                'phone_type' => 'HOME'
            }},
            'additional_info_value' => 'add-info'
        };

        return new List<Object>{
            new Map<String, Object>{
                'billing_info' => recipientInfo,
                'shipping_info' => recipientInfo
            }
        };
    }

    private static List<Object> buildItems(Opportunity opp, OpportunityLineItem[] lineItems) {
        List<Object> itemList = new List<Object>();
        
        for (OpportunityLineItem item : lineItems) {
            itemList.add(new Map<String, Object>{
                'name' => item.Product2.Name,
                'description' => item.ProductCode,
                'quantity' => String.valueOf(item.Quantity),
                'unit_of_measure' => 'QUANTITY',
                'unit_amount' => new Map<String, Object>{ 'currency_code' => opp.CurrencyIsoCode, 'value' => String.valueOf(item.UnitPrice) },
                'tax' => new Map<String, Object>{ 'name' => 'Sales Tax', 'percent' => '5' },
                'discount' => new Map<String, Object>{ 'percent' => String.valueOf(item.discount) }
            });
        }

        // Example of an additional item with a fixed amount discount
        /*itemList.add(new Map<String, Object>{
            'name' => 'Yoga t-shirt',
            'quantity' => '1',
            'unit_of_measure' => QUANTITY,
            'unit_amount' => new Map<String, Object>{ 'currency_code' => 'USD', 'value' => '10.00' },
            'tax' => new Map<String, Object>{ 'name' => 'Sales Tax', 'percent' => String.valueOf(SALES_TAX_PERCENT), 'tax_note' => 'Reduced tax rate' },
            'discount' => new Map<String, Object>{ 'amount' => new Map<String, Object>{ 'currency_code' => 'USD', 'value' => '5.00' } }
        });*/

        return itemList;
    }

    //Example of Configurations for partial payments
    private static Map<String, Object> buildConfiguration() {
        return new Map<String, Object>{
            'partial_payment' => new Map<String, Object>{
                'allow_partial_payment' => true,
                'minimum_amount_due' => new Map<String, Object>{ 'currency_code' => 'USD', 'value' => '20.00' }
            },
            'allow_tip' => true,
            'tax_calculated_after_discount' => true,
            'tax_inclusive' => false,
            'template_id' => 'TEMP-19V05281TU309413B'
        };
    }

    private static Map<String, Object> buildAmount(Opportunity opp) {
        return new Map<String, Object>{
            'breakdown' => new Map<String, Object>{
                'custom' => new Map<String, Object>{
                    'label' => 'Packing Charges',
                    'amount' => new Map<String, Object>{ 'currency_code' => 'USD', 'value' => '10.00' }
                },
                'shipping' => new Map<String, Object>{
                    'amount' => new Map<String, Object>{ 'currency_code' => 'USD', 'value' => '10.00' },
                    'tax' => new Map<String, Object>{ 'name' => 'Sales Tax', 'percent' => '7.25' }
                },
                'discount' => new Map<String, Object>{
                    'invoice_discount' => new Map<String, Object>{ 'percent' => '5' }
                }
            }
        };
    }
}
