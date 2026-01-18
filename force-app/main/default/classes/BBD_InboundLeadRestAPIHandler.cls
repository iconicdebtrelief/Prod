/**
 * Author : AriesBpo
 * @description
 * REST API endpoint to create a new Lead from an external system (e.g., Boberdoo).
 * 
 * Features:
 * - API key validation
 * - Dynamic field mapping using Custom Metadata (LeadFieldMapping__mdt)
 * - Required field validation
 * - Type-safe parsing (Date, Decimal, Boolean, etc.)
 * - Duplicate lead detection (based on Source__c and Phone)
 * - Error handling with clear responses
 * 
 * Endpoint: /services/apexrest/leadSFApi/
 */
@RestResource(urlMapping='/leadSFApi/')
global without sharing class BBD_InboundLeadRestAPIHandler {
    /**
     * @description
     * Handles HTTP POST request to create a new Lead from API input.
     * @return JSON string with success, duplicate, or error message.
     */
    @HttpPost
    global static String createLead() {
        RestRequest req = RestContext.request;
        Map<String, String> queryParams = req.params;
        Lead newLead = new Lead();
        List<String> missingFieldList = new List<String>();
        String outputJson = '';
        String action = '';
        
        System.debug(' ## queryParams ## ' + queryParams);
        System.debug(' ## req  ## ' + req);
        
        try {
            
            // Query the custom metadata for field mapping
            List<LeadFieldMapping__mdt> mappingList = [
                SELECT Id, LeadFieldAPIName__c, JSONFieldName__c, DataType__c, IsRequired__c, DefaultValue__c 
                FROM LeadFieldMapping__mdt 
                WHERE isActive__c = true
            ];
            
            Map<String, String> stateCodeMap = new Map<String, String>();
            for (StateCodeMapping__mdt metadata : [SELECT StateName__c, StateCode__c FROM StateCodeMapping__mdt]) {
                String normalizedKey = normalize(metadata.StateName__c);
                stateCodeMap.put(normalizedKey, metadata.StateCode__c);
            }

            
            for (LeadFieldMapping__mdt mapItem : mappingList) {
                String paramValue = queryParams.get(mapItem.JSONFieldName__c);                
                
                system.debug('## mapItem.JSONFieldName__c ##' + mapItem.JSONFieldName__c + '----' + paramValue);
                //Assign Default value for the mandatory fields
                if((paramValue == NULL || paramValue == '') && mapItem.DefaultValue__c != NULL){
                    paramValue = mapItem.DefaultValue__c;
                }
                
                // Check for required field
                if (mapItem.IsRequired__c && (paramValue == null || paramValue.trim() == '')) {
                    system.debug('## Inside If block -- mapItem.JSONFieldName__c ##' + mapItem.JSONFieldName__c + '----' + paramValue);
                    missingFieldList.add(mapItem.JSONFieldName__c);
                    continue;
                }
                
                system.debug('### missingFieldList ## ' + missingFieldList);

                if (paramValue != null && paramValue != '') {
                    Object typedValue;

                    try {
                        switch on mapItem.DataType__c.toLowerCase() {
                            when 'string' {
                                typedValue = paramValue;
                            }
                            when 'decimal' {
                                typedValue = Decimal.valueOf(paramValue);
                            }
                            when 'date' {
                                typedValue = Date.valueOf(paramValue);
                            }
                            when 'boolean' {
                                typedValue = Boolean.valueOf(paramValue);
                            }
                            when 'integer' {
                                typedValue = Integer.valueOf(paramValue);
                            }
                        }

                        if (typedValue != null) {
                            if(mapItem.LeadFieldAPIName__c == 'State' && string.valueOf(typedValue).length() > 2){
                                 String normalizedKey = normalize(string.valueof(typedValue));
                                 newLead.put(mapItem.LeadFieldAPIName__c, stateCodeMap.get(normalizedKey));
                            }else{
                                 newLead.put(mapItem.LeadFieldAPIName__c, typedValue);
                            }
                            if(mapItem.LeadFieldAPIName__c == 'Origin__c' && newLead.get('Origin__c') == 'BBD'){
                                action = 'Inbound BBD';                                
                            }
                            else if(mapItem.LeadFieldAPIName__c == 'Origin__c' && newLead.get('Origin__c') == 'GHL'){
                                action = 'Inbound GHL';
                            }
                        }

                    } catch (Exception ex) {
                        System.debug('Exception occured ' + ex.getMessage());
                        outputJson = JSON.serialize(new Map<String, Object>{
                            'Error' => 'Data parsing error for ' + mapItem.JSONFieldName__c,
                            'Details' => ex.getMessage()
                        });
                        logCallout(string.valueof(queryParams), outputJson , 'Error', Null , action);
                        return outputJson;
                    }
                }
                
            }
            
                String token = queryParams.get('Key');
                String expectedKey = Label.RestApiKey;
                system.debug('token --> ' + token);
                system.debug('expectedKey --> ' + expectedKey);
                if( token.trim().toLowerCase() != expectedKey.trim().toLowerCase()){
                    
                    outputJson = JSON.serialize(new Map<String, Object>{
                        'Error' => 'Invalid Key used in the URL',
                        'Key' => token
                    });
                    logCallout(string.valueof(req), outputJson , 'Error', Null , action);
                    return outputJson;
               }

            // Return if any required fields are missing
            if (!missingFieldList.isEmpty()) {
                RestContext.response.statusCode = 400;
                outputJson = JSON.serialize(new Map<String, Object>{
                    'Error' => 'Missing required fields',
                    'MissingFields' => missingFieldList
                });
                logCallout(string.valueof(req), outputJson , 'Error', Null , action);
                return outputJson;
            }

            Set<String> duplicateLeadSet = validateDuplicateLead(newLead);
            if (!duplicateLeadSet.isEmpty()) {
                outputJson = JSON.serialize(new Map<String, Object>{
                    'Message' => 'Duplicate Lead(s) found',
                    'LeadId' => duplicateLeadSet
                });
                logCallout(string.valueof(req), outputJson , 'Error', Null, action);
                return outputJson;
            }

            // Insert lead
            insert newLead;            
            
            outputJson = JSON.serialize(new Map<String, Object>{
                'Message' => 'Lead created successfully',
                'LeadId' => newLead.Id
            });
            logCallout(string.valueof(req), outputJson , 'Success', string.valueOf(newLead.Id), action);
            return outputJson ;
            

        } catch (Exception ex) {
            RestContext.response.statusCode = 500;
            outputJson = JSON.serialize(new Map<String, Object>{
                'Error' => 'Exception occurred',
                'Details' => ex.getMessage()
            });
            logCallout(string.valueof(req), outputJson , 'Error', Null , action);
            return outputJson ;
        }
    }
    
    /**
     * @description
     * Checks for existing duplicate leads using Source__c and Phone fields.
     * If duplicates are found, logs the match and returns the Lead Id(s).
     *
     * @param newLead The lead being created.
     * @return Set of duplicate lead IDs.
     */
    public static Set<String> validateDuplicateLead(Lead newLead) {
        Set<String> duplicateLeadSet = new Set<String>();
        List<Log__c> logList = new List<Log__c>();
        
        //Email =: newLead.Email
        
        for (Lead dbLead : [
            SELECT Id, Name, Email, Phone, LeadSource, BBDId__c
            FROM Lead 
            WHERE (((Source__c =: newLead.Source__c AND Phone =: newLead.Phone) OR BBDId__c =: newLead.BBDId__c) AND PreventDuplicate__c = true AND BBDId__c != NULL)
        ]) {
            duplicateLeadSet.add(dbLead.Id);

            Log__c newLog = new Log__c();
            newLog.ExistingLead__c = dbLead.Id;
            newLog.Payload__c = JSON.serializePretty(newLead);
            newLog.DuplicateMatchingFields__c =  'LeadSource: ' + newLead.Source__c + ', Phone: ' + newLead.Phone + ', BBD Id: ' + newLead.BBDId__c;
            logList.add(newLog);
        }

        if (!logList.isEmpty()) {
            insert logList;
        }

        return duplicateLeadSet;
    }
    
    /**
     * @description
     * Logs each API callout in IntegrationLog__c custom object for auditing and debugging.
     * @param requestXml   Request from BBD POST call.
     * @param responseXml  Response body from Boberdoo/GHL.
     * @param status       Status of the callout ('Success' or 'Error').
     * @param leadId       Optional Lead Id associated with the request.
     * @return             A new IntegrationLog__c record (not yet inserted).
     */
    public static IntegrationLog__c logCallout(String requestXml, String responseXml, String status, String leadId, String action) {
        IntegrationLog__c log = new IntegrationLog__c();
        log.Action__c = action;
        log.RequestBody__c = requestXml;
        log.ResponseBody__c = responseXml;
        log.Status__c = status;
        log.Lead__c = leadId;
        log.IntegrationMethod__c = 'POST';
        log.Endpoint__c = Label.BoberdooCalloutEndpoint;
        log.ContentType__c = 'application/xml';
        insert log;
        return log;
    }
    
    
    private static String normalize(String input) {
        if (input == null) return null;
        return input.replaceAll('[^A-Za-z]', '').toUpperCase();
    }
}