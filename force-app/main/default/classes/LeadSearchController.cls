/**
 * @Author : Ariesbpo
 * @Version : 1.0
 * LeadSearchController provides server-side logic for searching and assigning leads,
 * and for retrieving current user details. Designed for use with Lightning Components.
 */
public without sharing class LeadSearchController {
    
    /**
     * Searches for leads based on the given search term using SOSL.
     * Supports searching across all Lead fields (Name, Email, Phone, etc.).
     *
     * @param searchTerm The term to search for (must be at least 2 characters).
     * @return List of Lead records that match the search term.
     * @throws AuraHandledException if input is invalid or an error occurs during the search.
     */
    @AuraEnabled
    public static List<Lead> searchLeads(String searchTerm) {
        try {
            // Validate input - require at least 2 characters
            if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
                throw new AuraHandledException('Search term must be at least 2 characters long.');
            }
            
            // Sanitize input by escaping single quotes
            String cleanSearchTerm = String.escapeSingleQuotes(searchTerm.trim());
            system.debug('## cleanSearchTerm  ##' + cleanSearchTerm );
            
            String normalizedPhone;
            Boolean hasDigits = Pattern.matches('.*\\d.*', searchTerm); // contains at least one digit
            Boolean hasLetters = Pattern.matches('.*[a-zA-Z].*', searchTerm);// contains at least one letter
            
            if (hasDigits && !hasLetters) {
                // Numeric only (phone number case)
                normalizedPhone = searchTerm.replaceAll('[^0-9]', '');
            } else {
                // Text or alphanumeric (name/code search)
                normalizedPhone = searchTerm;
            }
            
            
            system.debug('## normalizedPhone ##' + normalizedPhone );
            
            // Construct SOSL query across all Lead fields
            String soslQuery = 'FIND \'' + normalizedPhone + '*\' IN ALL FIELDS RETURNING ' +
                               'Lead(Id, Name, Phone, Email, Status, OwnerId, Owner.Name, Owner.Type, LeadPhase__c ' +
                               'ORDER BY Name ASC LIMIT 50)';
            
            // Execute SOSL query
            List<List<SObject>> searchResults = Search.query(soslQuery);
            
            // Extract leads from results
            List<Lead> leads = new List<Lead>();
            if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
                leads = (List<Lead>) searchResults[0];
            }
            
            return leads;
            
        } catch (Exception e) {
            System.debug('Error in searchLeads: ' + e.getMessage());
            throw new AuraHandledException('Error searching leads: ' + e.getMessage());
        }
    }
    
    /**
     * Assigns a lead to the current user with a specified assignment reason.
     *
     * @param leadId The ID of the Lead to assign.
     * @param assignmentReason The reason for the assignment (stored in custom field).
     * @throws AuraHandledException if input is invalid, lead doesn't exist, 
     *         already assigned, or update fails.
     */
    @AuraEnabled
    public static void assignLeadToUser(String leadId, String assignmentReason) {
        try {
            // Validate required parameters
            if (String.isBlank(leadId)) {
                throw new AuraHandledException('Lead ID cannot be empty.');
            }
            if (String.isBlank(assignmentReason)) {
                throw new AuraHandledException('Assignment reason cannot be empty.');
            }
            
            // Get current user ID
            Id currentUserId = UserInfo.getUserId();
            
            // Retrieve the Lead record
            Lead leadToUpdate = [
                SELECT Id, Name, OwnerId, Owner.Name, Status, AssignmentReason__c, LeadPhase__c  
                FROM Lead 
                WHERE Id = :leadId 
                LIMIT 1
            ];

            // Assign the lead to current user and update reason
            leadToUpdate.OwnerId = currentUserId;
            leadToUpdate.AssignmentReason__c = assignmentReason;
            
            // Perform update
            update leadToUpdate;
            
        } catch (DmlException e) {
            System.debug('DML Error in assignLeadToUser: ' + e.getMessage());
            throw new AuraHandledException('Error updating lead: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            System.debug('Error in assignLeadToUser: ' + e.getMessage());
            throw new AuraHandledException('Error assigning lead: ' + e.getMessage());
        }
    }
    
    /**
     * Retrieves details of the currently logged-in user.
     *
     * @return A User record with Id, Name, and Email.
     */
    @AuraEnabled(cacheable=True)
    public static User getCurrentUser() {
        return [
            SELECT Id, Name, Email 
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ];
    }
}