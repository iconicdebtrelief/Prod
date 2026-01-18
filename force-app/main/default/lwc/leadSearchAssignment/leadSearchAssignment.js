import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchLeads from '@salesforce/apex/LeadSearchController.searchLeads';
import assignLeadToUser from '@salesforce/apex/LeadSearchController.assignLeadToUser';
import getCurrentUser from '@salesforce/apex/LeadSearchController.getCurrentUser';
import Id from '@salesforce/user/Id';

import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import ASSIGNMENT_REASON_FIELD from '@salesforce/schema/Lead.AssignmentReason__c';
import LEAD_OBJECT from '@salesforce/schema/Lead';

export default class LeadSearchAssignment extends LightningElement {
    @track searchTerm = '';
    @track leads = [];
    @track allLeads = [];
    @track isLoading = false;
    @track currentPage = 1;
    @track pageSize = 10;
    @track totalRecords = 0;
    @track totalPages = 0;
    @track showPagination = false;
    @track assignmentReasonOptions = [];
    @track userName;
    

    userId = Id;

    pageSizeOptions = [
        { label: '5', value: 5 },
        { label: '10', value: 10 },
        { label: '20', value: 20 },
        { label: '50', value: 50 }
    ];

    @wire(getCurrentUser)
    wiredUser({ error, data }) {
        if (data) {
            this.userName = data.Name;
        } else if (error) {
            console.error('Error fetching user', error);
        }
    }

    @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: ASSIGNMENT_REASON_FIELD
    })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.assignmentReasonOptions = [
                { label: 'Select Assignment Reason', value: '' },
                ...data.values
            ];
        } else if (error) {
            console.error('Picklist error', error);
            this.assignmentReasonOptions = [{ label: 'Select Assignment Reason', value: '' }];
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleSearch() {
        if (!this.searchTerm || this.searchTerm.trim().length < 2) {
            this.showToast('Error', 'Please enter at least 2 characters to search', 'error');
            return;
        }

        this.isLoading = true;
        searchLeads({ searchTerm: this.searchTerm.trim() })
            .then(result => {
                this.allLeads = result.map(lead => {
                    const isCurrentUserOwner = lead.OwnerId === this.userId;
                    const isQueueOwner = lead.Owner?.Type === 'Queue';
                    const isAllowedQueue = isQueueOwner && lead.Owner?.Name === 'Lead Default Assignment Queue'; 
                    return {
                        ...lead,
                        maskedPhone: lead.Phone,
                        maskedEmail: lead.Email,
                        selectedAssignmentReason: '',
                        showAssignButton: false,
                        showOpenButton: isCurrentUserOwner,
                        disableReasonPicklist: (isCurrentUserOwner || !isAllowedQueue),
                        OwnerName: lead.Owner?.Name || '',
                        OwnerId: lead.OwnerId
                    };
                });
                this.totalRecords = this.allLeads.length;
                this.totalPages = Math.ceil(this.totalRecords / this.pageSize);
                this.currentPage = 1;
                this.showPagination = this.totalRecords > this.pageSize;
                this.updateDisplayedLeads();
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Error searching leads: ' + error.body.message, 'error');
                this.isLoading = false;
            });
    }

    handleAssignmentReasonChange(event) {
        const leadId = event.target.dataset.leadId;
        const selectedValue = event.target.value;

        this.allLeads = this.allLeads.map(lead => {
            if (lead.Id === leadId) {
                const isCurrentUserOwner = lead.OwnerId === this.userId;
                const isQueueOwner = lead.Owner?.Type === 'Queue';
                const isAllowedQueue = isQueueOwner && lead.Owner?.Name === 'Lead Default Assignment Queue'; 

                return {
                    ...lead,
                    selectedAssignmentReason: selectedValue,
                    showAssignButton: selectedValue !== '' && !isCurrentUserOwner,
                    showOpenButton: isCurrentUserOwner,
                    disableReasonPicklist: (isCurrentUserOwner || !isAllowedQueue)
                };
            }
            return lead;
        });

        this.updateDisplayedLeads();
    }

    handleAssignLead(event) {
        const leadId = event.target.dataset.leadId;
        const lead = this.allLeads.find(l => l.Id === leadId);

        if (!lead || !lead.selectedAssignmentReason) {
            this.showToast('Error', 'Please select an assignment reason', 'error');
            return;
        }

        this.isLoading = true;
        assignLeadToUser({
            leadId: leadId,
            assignmentReason: lead.selectedAssignmentReason
        })
            .then(() => {
                this.showToast('Success', 'Lead assigned successfully', 'success');
                this.allLeads = this.allLeads.map(l => {
                    if (l.Id === leadId) {
                        return {
                            ...l,
                            showAssignButton: false,
                            showOpenButton: true,
                            disableReasonPicklist: true,
                            OwnerId: this.userId,
                            OwnerName: this.userName
                        };
                    }
                    return l;
                });
                this.updateDisplayedLeads();
                this.isLoading = false;
            })
            .catch(error => {
                const msg = error?.body?.message || 'Unknown error';
                this.showToast('Error', msg, 'error');
                this.isLoading = false;
            });
    }

    handleOpenLead(event) {
        const leadId = event.target.dataset.leadId;
        if (leadId) {
            window.open('/' + leadId, '_blank');
        }
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value);
        this.totalPages = Math.ceil(this.totalRecords / this.pageSize);
        this.currentPage = 1;
        this.showPagination = this.totalRecords > this.pageSize;
        this.updateDisplayedLeads();
    }

    handleFirstPage() {
        this.currentPage = 1;
        this.updateDisplayedLeads();
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateDisplayedLeads();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateDisplayedLeads();
        }
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        this.updateDisplayedLeads();
    }

    updateDisplayedLeads() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        this.leads = this.allLeads.slice(startIndex, endIndex);
    }

    get paginationInfo() {
        const startRecord = this.totalRecords === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
        const endRecord = Math.min(this.currentPage * this.pageSize, this.totalRecords);
        return `Showing ${startRecord} - ${endRecord} of ${this.totalRecords} records`;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    maskPhone(phone) {
        if (!phone) return '';
        if (phone.length <= 4) return phone;
        return phone.substring(0, 3) + '****' + phone.substring(phone.length - 4);
    }

    maskEmail(email) {
        if (!email) return '';
        const [username, domain] = email.split('@');
        if (!username || !domain) return email;
        if (username.length <= 2) {
            return username + '***@' + domain;
        }
        return username.substring(0, 2) + '***@' + domain;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    handleClear() {
        this.searchTerm = '';
        this.leads = [];
        this.allLeads = [];
        this.currentPage = 1;
        this.totalRecords = 0;
        this.totalPages = 0;
        this.showPagination = false;
    }
}