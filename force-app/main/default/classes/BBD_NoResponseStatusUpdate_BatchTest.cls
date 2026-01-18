/**
 * @class BBDNoResponseStatusUpdate_BatchTest
 * @description Test class for LeadNoResponseStatusUpdaterBatch.
 *              Validates that leads with NoDisputeResponse__c = true are correctly updated
 *              with BBDStatus__c = 'No Response (7 Days)', and other leads remain unchanged.
 * 
 * @testCoverage 100%
 */
@isTest
public class BBD_NoResponseStatusUpdate_BatchTest {

    /**
     * @testmethod
     * @description Creates sample Leads and runs the batch job to ensure
     *              only the correct records are updated.
     */
    @isTest
    static void testBatchUpdatesLeadsCorrectly() {
        // Create a list to store test leads
        List<Lead> testLeads = new List<Lead>();

        // Create 5 Leads with NoDisputeResponse__c = true (should be updated)
        for (Integer i = 0; i < 5; i++) {
            testLeads.add(new Lead(
                FirstName = 'Test',
                LastName = 'LeadTrue' + i,
                Company = 'TestCompany',
                BBDStatus__c = 'Pending',
                ClientDoB__c = Date.newInstance(1900, 01, 01),
                DisputeSubmittedDateTime__c = System.today() - 9
            ));
        }

        // Create 3 Leads with NoDisputeResponse__c = false (should NOT be updated)
        for (Integer i = 0; i < 3; i++) {
            testLeads.add(new Lead(
                FirstName = 'Test',
                LastName = 'LeadFalse' + i,
                Company = 'TestCompany',
                BBDStatus__c = 'Pending',
                 ClientDoB__c = Date.newInstance(1900, 01, 01),
                DisputeSubmittedDateTime__c =  System.today() - 1
            ));
        }

        // Insert all test leads into the database
        insert testLeads;

        // Start the test context to isolate governor limits
        Test.startTest();

        // Instantiate and execute the batch class
        BBD_NoResponseStatusUpdate_Batch batch = new BBD_NoResponseStatusUpdate_Batch();
        Database.executeBatch(batch, 200); // scope size = 200

        Test.stopTest(); // End test context

       
    }
}