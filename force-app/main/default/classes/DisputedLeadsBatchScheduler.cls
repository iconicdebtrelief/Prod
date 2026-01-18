/**
 * @author Ariesbpo
 * @created 07/27/2025
 * @version 1.0
 * @class DisputedLeadsBatchScheduler
 * @description This class implements the Schedulable interface and is used to schedule
 *              the execution of the DisputedLeads_Batch batch class. It can be scheduled
 *              to run at specific times using a CRON expression or through the Salesforce UI.
 */

global class DisputedLeadsBatchScheduler implements Schedulable {
    
     /**
     * @method execute
     * @description This method is called by the system when the scheduled job runs.
     *              It instantiates and executes the DisputedLeads_Batch batch class
     *              with a batch size of 1.
     *              
     * @param sc - An instance of SchedulableContext, which provides the job ID for the scheduled job.
     */
     
    global void execute(SchedulableContext sc) {
        DisputedLeads_Batch batch = new DisputedLeads_Batch();
        Database.executeBatch(batch, 1); 
    }
}