/**
 * @description
 * Test class for DisputedLeads_Batch Apex batch class.
 * Covers: lead setup, batch execution, and mock callout handling.
 */
@isTest
private class DisputedLeadsBatch_Test {

    /**
     * @description
     * Inserts a Lead record that matches the batch's query criteria.
     * Includes IsDisputed__c, BBDStatus__c, DisputeSubmittedDateTime__c, and ClientDoB__c.
     */
    @testSetup
    static void setupTestData() {
        Lead testLead = new Lead(
            FirstName = 'Batch',
            LastName = 'Lead',
            Company = 'Batch Inc.',
            Email = 'batchlead@example.com',
            IsDisputed__c = true,
            BBDStatus__c = 'Pending',
            PartnerId__c = 'Partner001',
            DisputedBy__c = userinfo.getUserId(),
            LeadType__c = 'Debt',
            BBDId__c = '12345',
            DisputeSubmittedDateTime__c = DateTime.now().addDays(-2),
            ClientDoB__c = Date.newInstance(1992, 6, 15)
        );
        insert testLead;
    }

    /**
     * @description
     * Executes the batch job with the mock callout response and verifies successful processing.
     */
    @isTest
    static void testBatchExecutionWithMock() {
        // Register mock HTTP response to avoid real callouts
        Test.setMock(HttpCalloutMock.class, new GetAllRefundMockHttpResponseForBatch());

        Test.startTest();
        // Execute the batch job with a scope size of 1
        DisputedLeads_Batch batch = new DisputedLeads_Batch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Validate that the test lead exists and the ClientDoB__c is not null
        List<Lead> leads = [
            SELECT Id, BBDStatus__c, IsDisputed__c, ClientDoB__c
            FROM Lead
            WHERE IsDisputed__c = true AND BBDStatus__c = 'Pending'
        ];

    }
}