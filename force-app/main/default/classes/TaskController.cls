/**
 * @Author Ariesbpo
 * @class TaskController
 * @description Controller class to fetch Task records related to a given parent record.
 *              This class is designed to be used in Lightning components or Aura components.
 *              It returns Tasks associated with either the WhoId (e.g., Contact or Lead)
 *              or WhatId of the specified parent record.
 *
 */
public with sharing class TaskController {
    @AuraEnabled(cacheable=true)
    /**
     * @method getTasksForRecord
     * @description Retrieves a list of Task records associated with the given parent record ID.
     *              It considers both WhatId and WhoId fields to fetch related tasks.
     *              The result is sorted by ActivityDate in descending order.
     */
    public static List<Task> getTasksForRecord(Id parentId) {
        return [
            SELECT Id, Subject, Status, ActivityDate, Description, WhoId, WhatId
            FROM Task
            WHERE WhatId = :parentId OR WhoId = :parentId
            ORDER BY CreatedDate DESC
        ];
    }
    
    
    @AuraEnabled
    public static Id logCall(Id parentId, String subject, String comments) {
        Task t = new Task(
            WhatId = parentId,
            Subject = subject,
            Status = 'Completed',
            ActivityDate = Date.today(),
            Description = comments
        );
        insert t;
        return t.Id;
    }
}