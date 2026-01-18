import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createApplicant from '@salesforce/apex/ApplicantController.createApplicant';
import { getRecord } from 'lightning/uiRecordApi';
import NAME_FIELD from "@salesforce/schema/Lead.Name"
import { RefreshEvent } from 'lightning/refresh';
import { NavigationMixin } from 'lightning/navigation';
import { EnclosingTabId, openSubtab } from 'lightning/platformWorkspaceApi';
const FIELDS = [NAME_FIELD]

export default class CreateApplicantRec extends NavigationMixin(LightningElement) {
    @api recordId; // This automatically gets the record ID
    @wire(EnclosingTabId) enclosingTabId;

    @wire(getRecord, {
        recordId: "$recordId",
        fields: FIELDS
    }) loadFields({ error, data }) {
    }

    @api invoke(){
        console.log('=== invoke method called');
         this.createData();
    }

    createData() {
        createApplicant({ recordId: this.recordId })
            .then(result => {
                if (result !== null && result !== undefined) {
                    if (!result.includes("ERROR")) {
                        this.showToast('Success!', 'Applicant record is successfully created.', 'success');
                        this.openAnotherSubTab(result);  // Navigate to new record
                    }
                    else {
                        this.showToast('Error!', result, 'error');
                    }
                    this.dispatchEvent(new RefreshEvent());
                }
            })
            .catch(error => {
                this.error = error;
                this.showToast('Error!', error, 'error');
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

    openAnotherSubTab(appRecId) {
        if (!this.enclosingTabId) {
            return;
        }
        openSubtab(this.enclosingTabId, {
            pageReference: {
                type: 'standard__recordPage',
                attributes: {
                    recordId: appRecId,
                    objectApiName: 'achieve__Applicant__c',
                    actionName: 'view'
                }
            }
        });
    }
}