/**
 * @Author : Ariesbpo
 * LeadDisputeCallout_XML
 * Handles XML-based refund request callouts to the Boberdoo system.
 * Invoked via Flow using the `@InvocableMethod`, processes refund request details,
 * performs an HTTP callout with an XML body, updates the corresponding Lead record,
 * and logs the integration result.
 */
public with sharing class LeadDisputeCallout_XML {
    
    /**
     * RefundRequest
     * Data structure used by Flow to pass parameters for the refund request.
     */
    public class RefundRequest {
        @InvocableVariable(required=true)
        public String apiKey;         // API key for authentication with Boberdoo

        @InvocableVariable(required=true)
        public String leadType;       // Lead type received from Boberdoo

        @InvocableVariable(required=true)
        public String partnerId;      // Partner ID (Ex: 921)

        @InvocableVariable(required=true)
        public String bbdid;          // Boberdoo Lead ID (external)

        @InvocableVariable(required=true)
        public String reasonId;       // Reason code for refund

        @InvocableVariable
        public String comment;        // Dispute Reason on Lead

        @InvocableVariable(required=true)
        public String leadid;         // Salesforce Lead Id (to update)
    }

    /**
     * requestRefundFromFlow
     *
     * Invoked from Flow to request a refund for each input request.
     * Each request is processed individually and results in "Success" or "Error".
     *
     * @param requestList List of refund request inputs from Flow
     * @return List of status strings: "Success" or "Error" per input
     */
    @InvocableMethod(label='Request Refund For Lead' description='Send refund request to Boberdoo via XML')
    public static List<String> requestRefundFromFlow(List<RefundRequest> requestList) {
        List<String> outputResultList  = new List<String>();

        for (RefundRequest request : requestList) {
            String outputResult = sendRefundRequest(request); 
            outputResultList.add(outputResult);
        }

        return outputResultList;
    }

    /**
     * sendRefundRequest
     *
     * Sends the refund request to Boberdoo via XML over HTTP POST.
     * Parses the XML response, updates the related Lead record, and logs the integration.
     *
     * @param input RefundRequest input data
     * @return String status ("Success" or "Error")
     */
    private static String sendRefundRequest(RefundRequest input) {
        // Construct XML body
        String xmlBody = '<?xml version="1.0"?>' +
            '<Request>' +
                '<Key>' + input.apiKey + '</Key>' +
                '<API_Action>requestRefundForLead</API_Action>' +
                '<Lead_Type>' + input.leadType + '</Lead_Type>' +
                '<Partner_ID>' + input.partnerId + '</Partner_ID>' +
                '<Lead_ID>' + input.bbdid + '</Lead_ID>' +
                '<Reason_ID>' + input.reasonId + '</Reason_ID>' +
                '<Comment>' + input.comment + '</Comment>' +
            '</Request>';

        // Prepare HTTP Request
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://leads.iconicresults.com/apiXML.php');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/xml');
        req.setBody(xmlBody);

        Http http = new Http();
        HttpResponse res;
        String responseXml = '';
        String status = 'Failed';

        try {
            // Send HTTP request and parse response
            res = http.send(req);
            responseXml = res.getBody();

            Dom.Document doc = new Dom.Document();
            doc.load(responseXml);
            Dom.XmlNode root = doc.getRootElement();
            String message = '';

            // Check for <errors>
            Dom.XmlNode errorsNode = root.getChildElement('errors', null);
            if (errorsNode != null) {
                List<Dom.XmlNode> errorNodes = errorsNode.getChildElements();
                List<String> errorMessages = new List<String>();

                for (Dom.XmlNode errorNode : errorNodes) {
                    if (errorNode.getName() == 'error') {
                        errorMessages.add(errorNode.getText());
                    }
                }

                if (!errorMessages.isEmpty()) {
                    message = String.join(errorMessages, ' | ');
                    updateLead(input.leadid, 'Error', message, input.comment);
                    status = 'Error';
                }

            } else {
                // If no <errors>, look for <result>
                Dom.XmlNode resultNode = root.getChildElement('result', null);
                if (resultNode != null) {
                    message = resultNode.getText();
                    updateLead(input.leadid, 'Success', message, input.comment);
                    status = 'Success';
                }
            }

        } catch (Exception e) {
            responseXml = e.getMessage();
            status = 'Error';
        } finally {
            // Always log the callout
            logCallout(xmlBody, responseXml, status, input);
        }

        return status;
    }

    /**
     * updateLead
     *
     * Updates the Lead record with the result of the refund request.
     * On success, updates dispute status fields and reassigns lead to dispute queue.
     *
     * @param curLeadId Lead Id to update
     * @param integrationStatus 'Success' or 'Error'
     * @param integrationMessage Message from Boberdoo response
     * @param disputeReason Reason comment for dispute
     */
    private static void updateLead(Id curLeadId, String integrationStatus, String integrationMessage, String disputeReason) {
        Lead curLead = new Lead(Id = curLeadId);
        curLead.IntegrationStatus__c = integrationStatus;
        curLead.IntegrationMessage__c = integrationMessage;

        if (integrationStatus == 'Success') {
            // Assign to dispute queue and update dispute fields
            Id disputeQueueId = [
                SELECT Id 
                FROM Group 
                WHERE DeveloperName = 'Dispute_Lead_Queue' 
                LIMIT 1
            ].Id;

            curLead.DisputeReason__c = disputeReason;
            curLead.DisputeSubmittedDateTime__c = System.now();
            curLead.DisputedBy__c = UserInfo.getUserId();
            curLead.IsDisputed__c = true;
            curLead.LeadPhase__c = 'Dispute Transfer';
            curLead.Status = 'Dispute Lead';
            curLead.BBDStatus__c = 'Pending';
            curLead.OwnerId = disputeQueueId;
        }

        try {
            update curLead;
        } catch (Exception ex) {
            System.debug('## Exception occurred during lead update ## ' + ex.getMessage());
        }
    }

    /**
     * logCallout
     *
     * Logs the callout details into the custom IntegrationLog__c object.
     *
     * @param requestXml  The XML request sent
     * @param responseXml The XML response received
     * @param status      Result of the callout ('Success' / 'Error' / 'Failed')
     * @param input       Original input data (RefundRequest)
     */
    private static void logCallout(String requestXml, String responseXml, String status, RefundRequest input) {
        IntegrationLog__c log = new IntegrationLog__c();
        log.Action__c = 'Request Refund For Lead';
        log.RequestBody__c = requestXml;
        log.ResponseBody__c = responseXml;
        log.Status__c = status;
        log.Lead__c = input.leadid;
        log.IntegrationMethod__c = 'POST';
        log.Endpoint__c = Label.BoberdooCalloutEndpoint;
        log.ContentType__c = 'application/xml';

        insert log;
    }
}