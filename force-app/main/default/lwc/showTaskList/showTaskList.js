import { LightningElement, api, track, wire } from 'lwc';
import getTasksForRecord from '@salesforce/apex/TaskController.getTasksForRecord';
import { refreshApex } from '@salesforce/apex';

export default class ShowTaskList extends LightningElement {
    @api recordId;
    @track tasks;
    @track error;
    isLoading = true;
    wiredTaskResult;

    @wire(getTasksForRecord, { parentId: '$recordId' })
    wiredTasks(result) {
        this.wiredTaskResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            // Add URL property for each task
            this.tasks = data.map(task => ({
                ...task,
                url: '/' + task.Id
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.tasks = undefined;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredTaskResult).finally(() => {
            this.isLoading = false;
        });
    }
}