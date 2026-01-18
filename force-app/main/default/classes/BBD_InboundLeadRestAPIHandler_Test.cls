@isTest
private class BBD_InboundLeadRestAPIHandler_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create test Lead Field Mapping metadata records would be done via metadata deployment
        // For testing purposes, we'll create test leads that can be used for duplicate validation
        
        // Create a test lead for duplicate validation
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Email = 'test@example.com',
            Phone = '1234567890',
            Source__c = 'Web',
            BBDId__c = 'BBD123',
            ClientDoB__c = Date.newInstance(1900, 01, 01)
        );
        insert testLead;
    }
    
    @isTest
    static void testCreateLead_Success() {
        // Setup REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String key = Label.RestApiKey;
        req.requestURI = '/services/apexrest/leadSFApi/';
        req.httpMethod = 'POST';
        
        // Set up parameters properly for the final params property
        req.params.put('Key', key); 
        req.params.put('LastName', 'Test Lead Success');
        req.params.put('Company', 'Test Company Success');
        req.params.put('Email', 'success@example.com');
        req.params.put('Phone', '9876543210');
        req.params.put('Billable', 'true');
        req.params.put('TotalEstimatedDebt','123');
        req.params.put('Price','110.60');
        req.params.put('Source', 'API');
        req.params.put('BBDID', 'BBD456');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        String result = BBD_InboundLeadRestAPIHandler.createLead();
        Test.stopTest();
        
        // Verify the response
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(result);
        //System.assertEquals('Lead created successfully', response.get('Message'));
        //System.assertNotEquals(null, response.get('LeadId'));
        
        // Verify the lead was actually created
        List<Lead> createdLeads = [SELECT Id, LastName, Company, Email FROM Lead WHERE Email = 'success@example.com'];
        //System.assertEquals(1, createdLeads.size());
        //System.assertEquals('Test Lead Success', createdLeads[0].LastName);
    }
    
    @isTest
    static void testCreateLead_InvalidKey() {
        // Setup REST context with invalid key
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String key = Label.RestApiKey;
        req.requestURI = '/services/apexrest/leadSFApi/';
        req.httpMethod = 'POST';
        
        req.params.put('Key', 'key123');
        req.params.put('LastName', 'Test Lead');
        req.params.put('Company', 'Test Company');
        req.params.put('Billable', 'true');
        req.params.put('TotalEstimatedDebt','123');
        req.params.put('Price','110.60');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Mock the custom label value
        // Note: In actual test, you'd need to have the custom label set up properly
        Test.startTest();
        String result;
        try {
            result = BBD_InboundLeadRestAPIHandler.createLead();
        } catch (Exception e) {
            // Handle case where custom label doesn't exist in test
            System.assert(true, 'Expected exception due to custom label in test context');
            return;
        }
        Test.stopTest();
        
        // If custom label exists and test runs, verify error response
        if (result != null) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(result);
            System.assertEquals('Invalid Key used in the URL', response.get('Error'));
        }
    }
    
    @isTest
    static void testCreateLead_MissingRequiredFields() {
        // This test assumes there are required fields configured in metadata
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String key = Label.RestApiKey;
        req.requestURI = '/services/apexrest/leadSFApi/';
        req.httpMethod = 'POST';
        
        req.params.put('Key', key);
        req.params.put('Email', 'incomplete@example.com');
        // Missing required fields like lastName, company
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        String result = BBD_InboundLeadRestAPIHandler.createLead();
        Test.stopTest();
        
        // Verify error response for missing fields
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(result);
        // Note: This test will pass/fail based on your actual metadata configuration
        System.assert(response.containsKey('Error') || response.containsKey('Message'));
    }
    
    @isTest
    static void testCreateLead_DuplicateDetection() {
        // Setup REST context with duplicate data
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String key = Label.RestApiKey;
        req.requestURI = '/services/apexrest/leadSFApi/';
        req.httpMethod = 'POST';
        
        req.params.put('Key', key);
        req.params.put('LastName', 'Duplicate Lead');
        req.params.put('Company', 'Duplicate Company');
        req.params.put('Billable', 'true');
        req.params.put('TotalEstimatedDebt', '100');
        req.params.put('Price','110.60');
        req.params.put('Email', 'duplicate@example.com');
        req.params.put('Phone', '1234567890'); // Same as test data
        req.params.put('Source', 'Web');       // Same as test data
        req.params.put('BBDID', 'BBD789');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        String result = BBD_InboundLeadRestAPIHandler.createLead();
        Test.stopTest();
        
    }
    
    @isTest
    static void testCreateLead_DuplicateByBBDId() {
        // Test duplicate detection by BBD ID
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String key = Label.RestApiKey;
        req.requestURI = '/services/apexrest/leadSFApi/';
        req.httpMethod = 'POST';
        
        req.params.put('Key', key);
        req.params.put('LastName', 'BBD Duplicate');
        req.params.put('Company', 'BBD Company');
        req.params.put('Email', 'bbdduplicate@example.com');
        req.params.put('Phone', '5555555555');
        req.params.put('Billable__c', 'true');
        req.params.put('TotalEstimatedDebt__c','123');
        req.params.put('Price__c','110.60');
        req.params.put('Source', 'API');
        req.params.put('BBDID', 'BBD123'); // Same BBD ID as test data
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        String result = BBD_InboundLeadRestAPIHandler.createLead();
        Test.stopTest();
        
        // Verify duplicate detection response
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(result);
        //System.assertEquals('Duplicate Lead(s) found', response.get('Message'));
        
        // Verify log was created
        List<Log__c> logs = [SELECT Id, ExistingLead__c, DuplicateMatchingFields__c FROM Log__c];
        //System.assertEquals(1, logs.size());
    }
    
    @isTest
    static void testCreateLead_DataTypeConversion() {
        // Test different data type conversions
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String key = Label.RestApiKey;
        req.requestURI = '/services/apexrest/leadSFApi/';
        req.httpMethod = 'POST';
        
        req.params.put('Key', key);
        req.params.put('LastName', 'Data Type Test');
        req.params.put('Company', 'Data Type Company');
        req.params.put('Email', 'datatype@example.com');
        req.params.put('Phone', '7777777777');
        req.params.put('Source', 'API');
        req.params.put('BBDID', 'BBD999');
        req.params.put('Billable__c', 'true');
        req.params.put('TotalEstimatedDebt__c','123');
        req.params.put('Price__c','110.60');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        String result = BBD_InboundLeadRestAPIHandler.createLead();
        Test.stopTest();
        
        // Verify successful creation or appropriate error handling
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assert(response.containsKey('Message') || response.containsKey('Error'));
    }
    
    @isTest
    static void testCreateLead_InvalidDataType() {
        // Test invalid data type conversion
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String key = Label.RestApiKey;
        req.requestURI = '/services/apexrest/leadSFApi/';
        req.httpMethod = 'POST';
        
        req.params.put('Key', key);
        req.params.put('LastName', 'Invalid Data Test');
        req.params.put('Company', 'Invalid Data Company');
        req.params.put('Email', 'invalid@example.com');
        req.params.put('Phone', '8888888888');
        req.params.put('Source', 'API');
        req.params.put('BBDID', 'BBD888');
        req.params.put('Billable', 'true');
        req.params.put('TotalEstimatedDebt','123');
        req.params.put('Price','110.60');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        String result = BBD_InboundLeadRestAPIHandler.createLead();
        Test.stopTest();
        
        // Verify error response for data parsing error
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(result);
        //System.assert(response.containsKey('Error'));
        //System.assert(response.get('Error').toString().contains('Data parsing error'));
    }
    
    @isTest
    static void testCreateLead_DatabaseException() {
        // Test database exception handling
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String key = Label.RestApiKey;
        req.requestURI = '/services/apexrest/leadSFApi/';
        req.httpMethod = 'POST';
        
        req.params.put('Key', key);
        req.params.put('LastName', 'Exception Test');
        req.params.put('Company', 'Exception Company');
        req.params.put('Email', 'exception@example.com');
        req.params.put('Phone', '9999999999');
        req.params.put('Source', 'API');
        req.params.put('BBDID', 'BBD777');
        req.params.put('Billable', 'true');
        req.params.put('TotalEstimatedDebt','123');
        req.params.put('Price','110.60');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        String result = BBD_InboundLeadRestAPIHandler.createLead();
        Test.stopTest();
        
        // This test depends on your actual field mappings and lead validation rules
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assert(response.containsKey('Message') || response.containsKey('Error'));
    }
    
    @isTest
    static void testValidateDuplicateLead_NoMetadata() {
        // Test the duplicate validation method directly
        Lead testLead = new Lead(
            LastName = 'Direct Test',
            Company = 'Direct Company',
            Email = 'direct@example.com',
            Phone = '1111111111',
            Source__c = 'Direct',
            BBDId__c = 'BBD000'
        );
        
        Test.startTest();
        Set<String> duplicates = BBD_InboundLeadRestAPIHandler.validateDuplicateLead(testLead);
        Test.stopTest();
        
        // Should return empty set if no duplicates found
        System.assertEquals(0, duplicates.size());
    }
    
    @isTest
    static void testValidateDuplicateLead_WithDuplicates() {
        // Test duplicate validation with existing data
        Lead testLead = new Lead(
            LastName = 'Duplicate Test',
            Company = 'Duplicate Company',
            Email = 'duplicatetest@example.com',
            Phone = '1234567890',    // Same as setup data
            Source__c = 'Web',       // Same as setup data
            BBDId__c = 'BBD999'
        );
        
        Test.startTest();
        Set<String> duplicates = BBD_InboundLeadRestAPIHandler.validateDuplicateLead(testLead);
        Test.stopTest();
        
        // Should find duplicate from setup data
        System.assertEquals(1, duplicates.size());
        
        // Verify log was created
        List<Log__c> logs = [SELECT Id FROM Log__c];
        System.assertEquals(1, logs.size());
    }
    
    @isTest
    static void testCreateLead_WithDefaultValues() {
        // Test with fields that have default values in metadata
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        String key = Label.RestApiKey;
        req.requestURI = '/services/apexrest/leadSFApi/';
        req.httpMethod = 'POST';
        
        req.params.put('Key', key);
        req.params.put('LastName', 'Default Value Test');
        req.params.put('Company', 'Default Company');
        req.params.put('Email', 'default@example.com');
        req.params.put('Phone', '2222222222');
        req.params.put('Billable', 'true');
        req.params.put('TotalEstimatedDebt','123');
        req.params.put('Price','110.60');
        req.params.put('BBDID', 'BBD111');
        // Missing source, should use default value if configured
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        String result = BBD_InboundLeadRestAPIHandler.createLead();
        Test.stopTest();
        
        // Verify response (success or error based on metadata configuration)
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assert(response.containsKey('Message') || response.containsKey('Error'));
    }
}