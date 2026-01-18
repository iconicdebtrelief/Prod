/*
Created By        :  Achieve Dev Team
Summary           :  This controller used to create an Applicant Record.
*/
public class ApplicantController{
    
    @AuraEnabled
    public static String createApplicant(String recordId){
        System.debug('=== Record Id: '+recordId);
        
        List<achieve__Applicant__c> appList = [SELECT Id FROM achieve__Applicant__c WHERE Lead__c =:recordId];
        if(!appList.isEmpty()){
            return 'ERROR: ' + 'Applicant record already created for this Lead. Duplicate is not allowed'; // Return error message
        }
        
        try {
            Lead currLead = [SELECT Id, FirstName, LastName, Email, Phone, ClientDoB__c, City, Street, State, PostalCode, Address, SalesAgentEmail__c, FullAddress__c FROM Lead WHERE Id =:recordId];
            
            achieve__Applicant__c app = new achieve__Applicant__c();
           /* app.achieve__First_Name__c = 'CORE';
            app.achieve__Last_Name__c = 'SIMPLE';
            app.achieve__Email__c = 'hurt-magnet@pfz4dcza.mailosaur.net';
            app.achieve__Day_Mobile_Phone__c = '6666669001';
            app.achieve__Secondary_Phone__c = '6666669001';
            app.achieve__Applicant_DOB__c = Date.newInstance(1951, 01, 01);       
            app.achieve__Mailing_Address_Line1__c = '123 MAIN STREET';
            app.achieve__Physical_Address_Line1__c = '123 MAIN STREET';
            app.achieve__Mailing_City__c = 'TEMPE';
            app.achieve__Physical_City__c = 'TEMPE';
            app.achieve__Mailing_State__c = 'AZ';
            app.achieve__Physical_State__c = 'AZ';
            app.achieve__Mailing_Zip_Code__c = '85288';
            app.achieve__Physical_Zip_Code__c = '85288'; */
            
            app.achieve__First_Name__c = currLead.FirstName;
            app.achieve__Last_Name__c = currLead.LastName;
            app.achieve__Email__c = currLead.Email;
            app.achieve__Day_Mobile_Phone__c = currLead.Phone;
            app.achieve__Secondary_Phone__c = currLead.Phone;
            app.achieve__Applicant_DOB__c = currLead.ClientDoB__c;
            //Mailing Addrress Details
            app.achieve__Mailing_Address_Line1__c = currLead.Street;           
            app.achieve__Mailing_City__c = currLead.City;
            app.achieve__Mailing_State__c = currLead.State;
            app.achieve__Mailing_Zip_Code__c = currLead.PostalCode;
            //Physical Address Details
            app.achieve__Physical_Address_Line1__c = currLead.Street; 
            app.achieve__Physical_City__c = currLead.City;
            app.achieve__Physical_State__c = currLead.State;
            app.achieve__Physical_Zip_Code__c = currLead.PostalCode;          
            app.achieve__Seller_Agent_Email__c = currLead.SalesAgentEmail__c ;
            app.Lead__c = currLead.Id;
            insert app;
            
            return app.Id; // Return success message
        }
        catch (DmlException e) {
            System.debug('=== Exception while inserting applicant: '+e.getStackTraceString());
            return 'ERROR: ' + e.getMessage(); // Return error message
        }
    }
    
}