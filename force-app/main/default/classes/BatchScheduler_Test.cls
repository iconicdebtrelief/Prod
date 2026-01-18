@isTest
public class BatchScheduler_Test {

    @isTest
    static void batchSchedulerExecution() {
        // Schedule the job to run 1 minute from now (test context executes it immediately)
        Datetime scheduledTime = Datetime.now().addMinutes(1);
        Integer minute = scheduledTime.minute();
        Integer hour = scheduledTime.hour();
        Integer day = scheduledTime.day();
        Integer month = scheduledTime.month();
        Integer year = scheduledTime.year();

        // Build cron expression dynamically for the scheduled time
        String cronExp = '0 ' + minute + ' ' + hour + ' ' + day + ' ' + month + ' ? ' + year;

        // Schedule the job
        String jobId = System.schedule('Test NoResponse Batch Scheduler', cronExp, new NoResponseStatusUpdateBatchScheduler());
        
        String job2Id = System.schedule('Disputed Lead Batch Scheduler', cronExp, new DisputedLeadsBatchScheduler());


        // Assert that the job was scheduled successfully
        System.assertNotEquals(null, jobId);
         System.assertNotEquals(null, job2Id);
    }
}