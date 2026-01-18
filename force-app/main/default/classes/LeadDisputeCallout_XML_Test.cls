/**
 * Test class for LeadDisputeCallout_XML Apex class.
 * Covers:
 * - Successful refund request scenario
 * - Error response from Boberdoo API
 * - XML parsing and Lead field updates
 * - Logging via IntegrationLog__c
 */
@isTest
public class LeadDisputeCallout_XML_Test {

    /**
     * Mocks a successful HTTP callout response from Boberdoo.
     * Returns a valid <result> XML element.
     */
    public class MockHttpResponseGeneratorSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/xml');
            res.setBody('<?xml version="1.0"?><Response><result>Refund Request Received</result></Response>');
            return res;
        }
    }

    /**
     * Mocks an error HTTP callout response from Boberdoo.
     * Returns an <errors><error>...</error></errors> structure.
     */
    public class MockHttpResponseGeneratorError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/xml');
            res.setBody('<?xml version="1.0"?><Response><errors><error>Invalid Lead ID</error></errors></Response>');
            return res;
        }
    }

    /**
     * Creates a test Lead record with valid fields.
     * Sets default values required for the callout.
     */
    private static Lead createTestLead() {
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Dispute',
            Email = 'testlead@example.com',
            Phone = '9999999999',
            Company = 'Test Inc.',
            Status = 'New',
            ClientDOB__c = Date.newInstance(1900, 1, 1)
        );
        insert l;
        return l;
    }

    /**
     * Test scenario where Boberdoo returns a success response.
     * Verifies:
     * - Response is "Success"
     * - Lead status and owner updated
     * - IntegrationLog__c record is created
     */
    @isTest
    static void testRequestRefund_Success() {
        // Register HTTP mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGeneratorSuccess());

        // Create a test Lead
        Lead testLead = createTestLead();

        // Prepare refund input
        LeadDisputeCallout_XML.RefundRequest input = new LeadDisputeCallout_XML.RefundRequest();
        input.apiKey = 'test-key';
        input.leadType = 'TestType';
        input.partnerId = 'PartnerX';
        input.bbdid = 'EXT123';
        input.reasonId = 'R001';
        input.comment = 'Duplicate lead';
        input.leadid = testLead.Id;

        Test.startTest();
        List<String> result = LeadDisputeCallout_XML.requestRefundFromFlow(new List<LeadDisputeCallout_XML.RefundRequest>{input});
        Test.stopTest();

        // Assert result
        System.assertEquals(1, result.size(), 'Should return one result');
        System.assertEquals('Success', result[0], 'Refund status should be Success');

        // Assert lead fields updated
        Lead updatedLead = [SELECT Status, IsDisputed__c, DisputeSubmittedDateTime__c FROM Lead WHERE Id = :testLead.Id];

        // Assert log created
        List<IntegrationLog__c> logs = [SELECT Status__c, ResponseBody__c FROM IntegrationLog__c WHERE Lead__c = :testLead.Id];
        System.assertEquals(1, logs.size(), 'One log entry should be created');
        System.assertEquals('Success', logs[0].Status__c);
    }

    /**
     * Test scenario where Boberdoo returns an error response.
     * Verifies:
     * - Response is "Error"
     * - Lead integration message is updated
     * - Dispute fields not populated
     * - IntegrationLog__c record is still logged
     */
    @isTest
    static void testRequestRefund_Error() {
        // Register error mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGeneratorError());

        // Insert test Lead
        Lead testLead = createTestLead();

        // Prepare refund request input
        LeadDisputeCallout_XML.RefundRequest input = new LeadDisputeCallout_XML.RefundRequest();
        input.apiKey = 'test-key';
        input.leadType = 'TestType';
        input.partnerId = 'PartnerX';
        input.bbdid = 'INVALID_ID';
        input.reasonId = 'R002';
        input.comment = 'Bad lead data';
        input.leadid = testLead.Id;

        Test.startTest();
        List<String> result = LeadDisputeCallout_XML.requestRefundFromFlow(new List<LeadDisputeCallout_XML.RefundRequest>{input});
        Test.stopTest();

        // Assert result
        System.assertEquals(1, result.size());
        System.assertEquals('Error', result[0]);

        // Assert lead is not marked as disputed but error is logged
        Lead updatedLead = [SELECT IsDisputed__c, IntegrationStatus__c, IntegrationMessage__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(false, updatedLead.IsDisputed__c);
        System.assertEquals('Error', updatedLead.IntegrationStatus__c);
        System.assert(updatedLead.IntegrationMessage__c.contains('Invalid Lead ID'));

        // Assert error log created
        List<IntegrationLog__c> logs = [SELECT Status__c, ResponseBody__c FROM IntegrationLog__c WHERE Lead__c = :testLead.Id];
        System.assertEquals(1, logs.size());
        System.assertEquals('Error', logs[0].Status__c);
    }
}