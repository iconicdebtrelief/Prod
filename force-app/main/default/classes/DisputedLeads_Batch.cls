/**
 * @Author : Ariesbpo
 * @description
 * Batch class to process disputed leads with 'Pending' BBD status.
 * For each disputed lead, it makes a callout to fetch and process refund data 
 * using an external service class `GetAllRefundsService_BBD`.
 *
 * Implements:
 * - Database.Batchable<SObject> to enable batch processing
 * - Database.AllowsCallouts to allow HTTP callouts in execute method
*/
public class DisputedLeads_Batch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    /**
     * @description
     * Start method of the batch job. Constructs and returns a QueryLocator
     * that retrieves all leads where:
     * - IsDisputed__c = TRUE
     * - BBDStatus__c = 'Pending'
     * - DisputeSubmittedDateTime__c is not null
     *
     * @param bc Batchable context object
     * @return QueryLocator for eligible Lead records
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Email, OwnerId, IsDisputed__c, PartnerId__c, BBDStatus__c,
                   LeadType__c, DisputeSubmittedDateTime__c, CreatedDate
            FROM Lead
            WHERE IsDisputed__c = TRUE
              AND BBDStatus__c = 'Pending'
              AND DisputeSubmittedDateTime__c != NULL
        ]);
    }

    /**
     * @description
     * Execute method for processing each batch of leads. For each lead:
     * - Extracts the dispute submission date and current date
     * - Calls external service to fetch and process refunds using lead data
     *
     * @param bc Batchable context object
     * @param scope List of Lead records to process in this batch
     */
    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        for (Lead lead : scope) {
            // Convert DisputeSubmittedDateTime to date string
            String disputestartDate = String.valueOf(lead.DisputeSubmittedDateTime__c.date());

            // Use today's date as end date
            String endDate = String.valueOf(System.today());

            // Make callout to external service to process refund info
            GetAllRefundsService_BBD.fetchAndProcessRefunds(
                lead.PartnerId__c,
                lead.LeadType__c,
                disputestartDate,
                endDate,
                lead.Id
            );
        }
    }

    /**
     * @description
     * Finish method runs once after all batches are processed.
     * Currently logs batch completion for tracking.
     *
     * @param bc Batchable context object
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('Disputed Leads Batch Completed.');
    }
}