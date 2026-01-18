/**
 * @class LeadNoResponseStatusUpdaterBatch
 * @description Batch class to update BBDStatus__c to 'No Response (7 Days)' 
 *              for Leads where NoDisputeResponse__c = true.
 *              Typically used to follow up on leads with no response after dispute.
 * 
 * @author 
 * @date 
 */
global class BBD_NoResponseStatusUpdate_Batch implements Database.Batchable<SObject> {

    /**
     * @method start
     * @description Defines the query to retrieve Leads where NoDisputeResponse__c is true.
     *              These leads are assumed to have received no response for 7+ days.
     * @param bc Batchable context
     * @return Database.QueryLocator that provides the scope of records to process
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, BBDStatus__c
            FROM Lead
            WHERE NoDisputeResponse__c = TRUE
        ]);
    }

    /**
     * @method execute
     * @description Processes each batch of Leads and updates the BBDStatus__c field
     *              to 'No Response (7 Days)' to mark lack of response.
     * @param bc Batchable context
     * @param scope List of Lead records in current batch
     */
    global void execute(Database.BatchableContext bc, List<Lead> scope) {
        
        for (Lead l : scope) {
            l.BBDStatus__c = 'No Response (7 Days)';
        }
        update scope;
    }

    /**
     * @method finish
     * @description Optional method for post-processing logic, such as sending notifications
     *              or logging completion. Can be customized as needed.
     * @param bc Batchable context
     */
    global void finish(Database.BatchableContext bc) {
        // Example: Logging or email notification logic can be placed here
        System.debug('Lead BBD Status Update Batch completed.');
    }
}