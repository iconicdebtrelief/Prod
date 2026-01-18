/**
 * Author : AriesBpo
 * @description
 * This service class handles the integration with the Boberdoo API to fetch all refund requests for Leads.
 * It parses the XML response, updates the corresponding Lead records with refund status/comments,
 * and logs each integration attempt.
 */
public class GetAllRefundsService_BBD {

    /**
     * @description
     * Inner class to represent a structured refund response from the Boberdoo API.
     */
    public class RefundResponse {
        public String bbdId;              // Unique Lead identifier from Boberdoo
        public String bbdStatus;          // Refund status (Approved, Declined, etc.)
        public String bbdComment;         // Refund comment
        public String reason;             // Refund reason
        public String bbdAdminRemark;     // Admin notes from Boberdoo
        public Datetime bbdModDateTime;   // Date/time of refund modification
    }

    /**
     * @description
     * Makes a GET callout to Boberdoo's "getAllRefunds" API endpoint to fetch refund details
     * within the specified date range. Parses the XML response, logs the result, and updates Leads.
     *
     * @param partnerId  The partner ID for the API call.
     * @param type       The refund type (e.g., 'lead', 'ping').
     * @param startDate  Start date for fetching refunds (format: yyyy-MM-dd).
     * @param endDate    End date for fetching refunds.
     * @param leadId     The specific Lead ID used for logging in case of single-lead callout failure.
     */
    public static void fetchAndProcessRefunds(String partnerId, String type, String startDate, String endDate, Id leadId) {
        String endpoint = Label.BoberdooCalloutEndpoint;
        String key = Label.BoberdooDisputeCallOutKey;

        List<IntegrationLog__c> integrationLogList = new List<IntegrationLog__c>();
        List<Lead> updateLeadList = new List<Lead>();

        // Construct the full GET URL
        String fullUrl = endpoint +
            '?Key=' + EncodingUtil.urlEncode(key, 'UTF-8') +
            '&API_Action=getAllRefunds' +
            '&Format=XML' +
            '&Partner_ID=' + EncodingUtil.urlEncode(partnerId, 'UTF-8') +
            '&TYPE=' + EncodingUtil.urlEncode(type, 'UTF-8') +
            '&Date_Start=' + EncodingUtil.urlEncode(startDate, 'UTF-8') +
            '&Date_End=' + EncodingUtil.urlEncode(endDate, 'UTF-8');

        // Prepare the callout request
        HttpRequest requestXml = new HttpRequest();
        requestXml.setEndpoint(fullUrl);
        requestXml.setMethod('GET');

        Http http = new Http();
        HttpResponse responseXml = http.send(requestXml);
        System.debug(' ### Status code ### ' + responseXml.getStatusCode());

        if (responseXml.getStatusCode() == 200) {
            System.debug(' ### Call out Success ### ');
            Dom.Document doc = new Dom.Document();
            doc.load(responseXml.getBody());
            Dom.XMLNode root = doc.getRootElement();

            // Handle errors returned in XML
            Dom.XMLNode errorsNode = root.getChildElement('errors', null);
            if (errorsNode != null) {
                for (Dom.XMLNode node : errorsNode.getChildElements()) {
                    if (node.getName() == 'error') {
                        String errorMsg = node.getText();
                        integrationLogList.add(logCallout(fullUrl, responseXml.getBody(), 'Error', leadId));
                        updateLeadList.add(updateLeadIntegrationStatus(leadId, 'Error', errorMsg));
                    }
                }
            } else {
                // Parse valid response and update Leads
                Map<String, RefundResponse> refundResponseMap = parseXMLResponse(responseXml.getBody());
                Map<String, String> leadBBDMap = updateLeads(refundResponseMap.values());

                for (String bbdId : refundResponseMap.keySet()) {
                    if (leadBBDMap.containsKey(bbdId)) {
                        String responseString = JSON.serializePretty(refundResponseMap.get(bbdId));
                        integrationLogList.add(logCallout(fullUrl, responseString, 'Success', leadBBDMap.get(bbdId)));
                        // Optional: Uncomment if you want to also update success message to Lead
                        // updateLeadList.add(updateLeadIntegrationStatus(...));
                    }
                }
            }
        } else {
            // Handle failed HTTP callout
            System.debug('Callout failed: ' + responseXml.getStatus());
            integrationLogList.add(logCallout(fullUrl, responseXml.getBody(), 'Error', leadId));
            updateLeadList.add(updateLeadIntegrationStatus(leadId, 'Error', responseXml.getBody()));
        }

        // Persist logs and lead updates
        if (!integrationLogList.isEmpty()) insert integrationLogList;
        if (!updateLeadList.isEmpty()) update updateLeadList;
    }

    /**
     * @description
     * Parses the XML response body and converts it into a map of RefundResponse objects.
     *
     * @param xmlStr  The raw XML string response from the API.
     * @return        Map of BBD Id → RefundResponse.
     */
    public static Map<String, RefundResponse> parseXMLResponse(String xmlStr) {
        Map<String, RefundResponse> refundResponseMap = new Map<String, RefundResponse>();
        Dom.Document doc = new Dom.Document();
        doc.load(xmlStr);
        Dom.XMLNode root = doc.getRootElement();

        for (Dom.XMLNode reqNode : root.getChildElement('refund_requests', null).getChildElements()) {
            RefundResponse ref = new RefundResponse();
            ref.bbdId = reqNode.getChildElement('lead_id', null).getText();
            ref.bbdStatus = reqNode.getChildElement('refund_request_status', null).getText();
            ref.bbdComment = reqNode.getChildElement('refund_request_comment', null).getText();
            ref.reason = reqNode.getChildElement('refund_request_admin_remark', null).getText();
            ref.bbdAdminRemark = reqNode.getChildElement('refund_request_admin_remark', null).getText();
            ref.bbdModDateTime = Datetime.valueOf(reqNode.getChildElement('request_date', null).getText());

            if (ref.bbdId != null) {
                refundResponseMap.put(ref.bbdId, ref);
            }
        }
        return refundResponseMap;
    }

    /**
     * @description
     * Updates the Lead records based on the refund status in the Boberdoo response.
     * Only updates Leads where current BBDStatus__c = 'Pending' and response status is Approved/Declined.
     *
     * @param refundResponseList  List of parsed refund responses from the API.
     * @return                    Map of BBD Id → Lead Id for logging purposes.
     */
    public static Map<String, String> updateLeads(List<RefundResponse> refundResponseList) {
        Map<String, Lead> leadMap = new Map<String, Lead>();
        Map<String, String> leadBBDMap = new Map<String, String>();
        Set<String> bbdIdSet = new Set<String>();

        for (RefundResponse refundResponse : refundResponseList) {
            bbdIdSet.add(refundResponse.bbdId);
        }

        // Query existing Leads with matching BBD Ids and status = Pending
        for (Lead curLead : [SELECT Id, BBDId__c, BBDStatus__c, BBDAdminNotes__c FROM Lead WHERE BBDId__c IN :bbdIdSet AND BBDStatus__c = 'Pending']) {
            leadMap.put(curLead.BBDId__c, curLead);
        }

        List<Lead> updateLeadList = new List<Lead>();
        for (RefundResponse response : refundResponseList) {
            if (leadMap.containsKey(response.bbdId) && (response.bbdStatus == 'Approved' || response.bbdStatus == 'Declined')) {
                Lead existingLead = new Lead(Id = leadMap.get(response.bbdId).Id);
                existingLead.BBDStatus__c = response.bbdStatus;
                existingLead.BBDAdminNotes__c = response.bbdAdminRemark;
                existingLead.BBDModDateTime__c = response.bbdModDateTime;
                existingLead.IntegrationStatus__c = 'Success';
                existingLead.IntegrationMessage__c = 'BBD status and comments updated successfully';
                leadBBDMap.put(response.bbdId, existingLead.Id);
                updateLeadList.add(existingLead);
            }
        }

        if (!updateLeadList.isEmpty()) {
            update updateLeadList;
        }

        return leadBBDMap;
    }

    /**
     * @description
     * Helper method to update integration status and message for a Lead.
     *
     * @param leadId   Lead Id to update.
     * @param status   Integration status (e.g., 'Success', 'Error').
     * @param message  Status message or error details.
     * @return         A Lead record with populated integration fields (not yet committed).
     */
    public static Lead updateLeadIntegrationStatus(Id leadId, String status, String message) {
        Lead curLead = new Lead(Id = leadId);
        curLead.IntegrationStatus__c = status;
        curLead.IntegrationMessage__c = message;
        return curLead;
    }

    /**
     * @description
     * Logs each API callout in IntegrationLog__c custom object for auditing and debugging.
     *
     * @param requestXml   Full request URL used for GET call.
     * @param responseXml  Response body from Boberdoo.
     * @param status       Status of the callout ('Success' or 'Error').
     * @param leadId       Optional Lead Id associated with the request.
     * @return             A new IntegrationLog__c record (not yet inserted).
     */
    public static IntegrationLog__c logCallout(String requestXml, String responseXml, String status, String leadId) {
        IntegrationLog__c log = new IntegrationLog__c();
        log.Action__c = 'Get All Refunds';
        log.RequestBody__c = requestXml;
        log.ResponseBody__c = responseXml;
        log.Status__c = status;
        log.Lead__c = leadId;
        log.IntegrationMethod__c = 'GET';
        log.Endpoint__c = Label.BoberdooCalloutEndpoint;
        log.ContentType__c = 'application/xml';
        return log;
    }
}