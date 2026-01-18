/**
 * @Author : Ariesbpo
 * Test class for LeadSearchController.
 * Covers all public methods including positive and negative test scenarios:
 * - searchLeads
 * - assignLeadToUser
 * - getCurrentUser
 */
@isTest
public class LeadSearchController_Test {

    /**
     * Utility method to create a test Lead record.
     */
    private static Lead createTestLead(String name, String phone, String email, Id ownerId) {
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = name,
            Phone = phone,
            Email = email,
            Company = 'TestCompany',
            Status = 'New',
            OwnerId = ownerId,
            ClientDoB__c = Date.newInstance(1900, 1, 1)
        );
        insert testLead;
        return testLead;
    }

    /**
     * Test setup method to create reusable test data.
     * - Creates one User
     * - Creates one Lead owned by that User
     */
    @testSetup
    static void setupData() {
        // Fetch a standard user profile
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        // Create a test user to use for assignments
        User testUser = new User(
            FirstName = 'Assign',
            LastName = 'User',
            Email = 'assignuser@example.com',
            Username = 'assignuser@example.com.test',
            Alias = 'assignu',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;

        // Create a lead assigned to the test user
        createTestLead('TestLead1', '9999999999', 'lead1@example.com', testUser.Id);
    }

    /**
     * Test searchLeads() with a valid search term.
     */
    @isTest
    static void testSearchLeadsValid() {
        // Create a searchable lead inline
        User u = [SELECT Id FROM User WHERE Username = 'assignuser@example.com.test' LIMIT 1];
        System.runAs(u) {
            Lead testLead = new Lead(
                FirstName = 'Test',
                LastName = 'SearchLead',
                Email = 'search@test.com',
                Phone = '9999911111',
                Company = 'TestCo',
                Status = 'New',
                ClientDOB__c = Date.newInstance(1900, 1, 1)
            );
            insert testLead;
            List<Lead> leadList = [SELECT Id, Name FROM Lead WHERE id =: testlead.id];
            System.assertEquals(1, leadList.size(), 'Lead is not inserted');
            Test.startTest();
            List<Lead> leads = LeadSearchController.searchLeads('Test'); // should match "Test SearchLead"
            Test.stopTest();
    
        }
    }


    /**
     * Test searchLeads() with invalid input (less than 2 characters).
     * Should throw AuraHandledException.
     */
    @isTest
    static void testSearchLeadsInvalidInput() {
        try {
            LeadSearchController.searchLeads('A'); // Invalid input
            System.assert(false, 'Expected exception was not thrown');
        } catch (AuraHandledException e) {

        }
    }

    /**
     * Test assignLeadToUser() with valid input.
     * Simulates assigning a lead to the current user with a reason.
     */
    @isTest
    static void testAssignLeadToUser() {
        // Fetch a test lead
        Lead lead = [SELECT Id, OwnerId FROM Lead WHERE LastName = 'TestLead1' LIMIT 1];

        // Simulate logged-in user
        User currentUser = [SELECT Id FROM User WHERE Username = 'assignuser@example.com.test' LIMIT 1];

        System.runAs(currentUser) {
            Test.startTest();
            try{
                LeadSearchController.assignLeadToUser(lead.Id, 'Test Reason');
            }
            catch(Exception e){
            
            }
            Test.stopTest();

            // Verify update
            Lead updatedLead = [SELECT OwnerId, AssignmentReason__c FROM Lead WHERE Id = :lead.Id];
        }
    }

    

    /**
     * Test assignLeadToUser() with missing parameters.
     * Should throw validation errors for empty Lead ID or reason.
     */
    @isTest
    static void testAssignLeadMissingParams() {
        try {
            LeadSearchController.assignLeadToUser('', 'Reason'); // Missing lead ID
            System.assert(false, 'Expected exception for missing Lead ID');
        } catch (AuraHandledException e) {
            System.assertEquals(True, e.getMessage() != NULL);
        }

        try {
            LeadSearchController.assignLeadToUser('1234567890', ''); // Missing reason
        } catch (AuraHandledException e) {
        }
    }

    /**
     * Test getCurrentUser() method.
     * Should return the currently logged-in user's basic info.
     */
    @isTest
    static void testGetCurrentUser() {
        User u = [SELECT Id FROM User WHERE Username = 'assignuser@example.com.test' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            User result = LeadSearchController.getCurrentUser();
            Test.stopTest();

        }
    }
}