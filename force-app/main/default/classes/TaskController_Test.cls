/*
* @Author : Ariesbpo
* @Description : Cover TaskController class to fetch Task records related to a given parent record
*/
@isTest
private class TaskController_Test {

    @isTest
    static void testGetTasksForRecord() {
        // Create a test Lead (can also be Contact or any WhoId/WhatId-supported object)
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            ClientDoB__c = Date.newinstance(1900,01,01),
            Status = 'New'
        );
        insert testLead;

        // Create related Task records
        Task task1 = new Task(
            Subject = 'Follow Up',
            Status = 'Not Started',
            ActivityDate = Date.today().addDays(-1),
            WhoId = testLead.Id,
            description = 'Test cpmment 1'
        );
        
        Task task2 = new Task(
            Subject = 'Call Client',
            Status = 'Completed',
            ActivityDate = Date.today(),
            WhoId = testLead.Id,
            description = 'Test comment 2'
        );

        insert new List<Task>{ task1, task2 };

        // Call the method and verify results
        Test.startTest();
        List<Task> result = TaskController.getTasksForRecord(testLead.Id);
        Test.stopTest();

        // Validate the result
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.size(), 'There should be 2 tasks returned');
        
        // Verify order (ActivityDate DESC)
        System.assertEquals(task1.Id, result[0].Id, 'Most recent task should come first');
        System.assertEquals(task2.Id, result[1].Id, 'Older task should come second');
    }
}