/**
 * @description
 * Mock class for simulating a valid XML response from the refund API.
 * Mimics the structure required by GetAllRefundsService_BBD.parseXMLResponse.
 */
public class GetAllRefundMockHttpResponseForBatch implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/xml');

        // Minimal valid XML structure based on your real response
        res.setBody('<?xml version="1.0" encoding="utf-8"?>' +
            '<response>' +
                '<partner_id>09</partner_id>' +
                '<partner_name>Batch Lead</partner_name>' +
                '<refund_requests>' +
                    '<refund_request>' +
                        '<refund_request_id>001</refund_request_id>' +
                        '<refund_request_reason>Clearly bogus contact information.</refund_request_reason>' +
                        '<refund_request_comment>Test Comment</refund_request_comment>' +
                        '<refund_request_admin_remark> Test Admin comment </refund_request_admin_remark>' +
                        '<refund_request_status>Declined</refund_request_status>' +
                        '<lead_id>12345</lead_id>' +
                        '<lead_type>Debt</lead_type>' +
                        '<lead_name>Test Lead</lead_name>' +
                        '<lead_email>example@test.com</lead_email>' +
                        '<lead_address>123 Test Street</lead_address>' +
                        '<request_date>2025-07-10 18:16:30</request_date>' +
                        '<lead_post_date>2025-07-10 18:14:23</lead_post_date>' +
                    '</refund_request>' +
                '</refund_requests>' +
            '</response>'
        );

        return res;
    }
}