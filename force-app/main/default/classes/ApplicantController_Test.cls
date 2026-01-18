@isTest
private class ApplicantController_Test {

    /**
     * @description
     * Test successful creation of an Applicant when no existing Applicant is linked to the Lead.
     */
    @isTest
    static void testCreateApplicant_Success() {
        Lead testLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com',
            Phone = '1234567890',
            ClientDoB__c = Date.newInstance(1990, 1, 1),
            Street = '123 Main St',
            City = 'Sample City',
            State = 'CA',
            PostalCode = '90001',
            Company = 'Test Co',
            Status = 'Open - Not Contacted'
        );
        insert testLead;

        //Call the controller method to create an Applicant
        Test.startTest();
        String result = ApplicantController.createApplicant(testLead.Id);
        Test.stopTest();

        //Assert the Applicant was created and returned a valid Id
        System.assert(!result.startsWith('ERROR'), 'Expected success but got error: ' + result);

        //Query the inserted Applicant to validate linkage
        achieve__Applicant__c insertedApp = [SELECT Id, Lead__c FROM achieve__Applicant__c WHERE Lead__c = :testLead.Id LIMIT 1];
        System.assertEquals(testLead.Id, insertedApp.Lead__c, 'Lead Id mismatch in created applicant');
    }

    /**
     * @description
     * Test that duplicate Applicant creation is prevented when one already exists for the Lead.
     */
    @isTest
    static void testCreateApplicant_Duplicate() {
        //Create a Lead
        Lead lead = new Lead(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane@example.com',
            Phone = '9876543210',
            ClientDoB__c = Date.newInstance(1992, 2, 2),
            Street = '456 Another St',
            City = 'Another City',
            State = 'NY',
            PostalCode = '10001',
            Company = 'Test Co',
            Status = 'Working - Contacted'
        );
        insert lead;

        //Insert an Applicant linked to this Lead (simulate existing record)
        /*achieve__Applicant__c existingApp = new achieve__Applicant__c(
            achieve__First_Name__c = 'Jane',
            achieve__Last_Name__c = 'Smith',
            achieve__Email__c = 'jane@example.com',
            Lead__c = lead.Id
        );
        insert existingApp;*/

        //Call the controller method again to test duplicate logic
        Test.startTest();
        String result1 = ApplicantController.createApplicant(lead.Id);
        String result2 = ApplicantController.createApplicant(lead.Id);
        Test.stopTest();

        //Validate that a duplicate error message is returned
        System.assert(result2.startsWith('ERROR'), 'Expected duplicate error');
        System.assert(result2.contains('Duplicate is not allowed'), 'Expected specific duplicate error message');
    }

    /**
     * @description
     * Test how the method handles a Lead Id that doesn't exist (simulated error case).
     */
    @isTest
    static void testCreateApplicant_LeadNotFound() {
        // Simulate a non-existent Lead Id
        String fakeLeadId = '00Q000000000000AAA'; // Well-formed but non-existent Id

        // Call the controller method with invalid Id
        Test.startTest();
        String result;
        try{
            result = ApplicantController.createApplicant(fakeLeadId);
        }
        catch(Exception e){
        }
        Test.stopTest();

    }
}