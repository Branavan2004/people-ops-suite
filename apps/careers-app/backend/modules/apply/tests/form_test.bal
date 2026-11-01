// Copyright (c) 2026 WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/mime;
import ballerina/test;

const byte[] PDF_BYTES = [0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x34];

function validFields() returns map<string> => {
    "firstName": "Ada",
    "lastName": "Lovelace",
    "email": "ada@example.com",
    "phone": "+94771234567",
    "address": "1 Example Road, Colombo"
};

function formRequest(map<string> fields, byte[]? cv) returns http:Request {
    mime:Entity[] parts = [];
    foreach [string, string] [name, value] in fields.entries() {
        mime:Entity textPart = new;
        textPart.setContentDisposition(mime:getContentDispositionObject(string `form-data; name="${name}"`));
        textPart.setText(value);
        parts.push(textPart);
    }
    if cv is byte[] {
        mime:Entity file = new;
        file.setContentDisposition(mime:getContentDispositionObject("form-data; name=\"cv\"; filename=\"cv.pdf\""));
        file.setByteArray(cv, "application/pdf");
        parts.push(file);
    }
    http:Request req = new;
    req.setBodyParts(parts, "multipart/form-data");
    return req;
}

function withField(string name, string value) returns map<string> {
    map<string> fields = validFields();
    fields[name] = value;
    return fields;
}

@test:Config {}
function aValidFormIsAccepted() {
    ApplicationForm|string result = parseApplicationForm(formRequest(validFields(), PDF_BYTES));
    if result is string {
        test:assertFail("A valid form was rejected: " + result);
    }
    test:assertEquals(result.firstName, "Ada");
    test:assertEquals(result.email, "ada@example.com");
    test:assertEquals(result.phone, "+94771234567");
    test:assertEquals(result.cv, PDF_BYTES);
}

@test:Config {}
function theUniversityIsOptionalAndTrimmed() {
    ApplicationForm|string filled = parseApplicationForm(formRequest(withField("university", " State University "),
        PDF_BYTES));
    if filled is string {
        test:assertFail(filled);
    }
    test:assertEquals(filled?.university, "State University");

    ApplicationForm|string blank = parseApplicationForm(formRequest(withField("university", "  "), PDF_BYTES));
    if blank is string {
        test:assertFail(blank);
    }
    test:assertEquals(blank?.university, ());
}

@test:Config {}
function aTooLongUniversityIsRejected() {
    string tooLong = "".padEnd(256, "a");
    test:assertEquals(parseApplicationForm(formRequest(withField("university", tooLong), PDF_BYTES)),
        "One of the details is too long.");
}

@test:Config {}
function aRequestThatIsNotMultipartIsRejected() {
    http:Request req = new;
    req.setJsonPayload({"firstName": "Ada"});
    test:assertEquals(parseApplicationForm(req), "The application must be sent as a multipart form.");
}

@test:Config {}
function missingRequiredFieldsAreRejected() {
    string expected = "First name, last name, phone and address are required.";
    foreach string name in ["firstName", "lastName", "phone", "address"] {
        test:assertEquals(parseApplicationForm(formRequest(withField(name, "  "), PDF_BYTES)), expected,
            string `Missing ${name}`);
    }
}

@test:Config {}
function tooLongDetailsAreRejected() {
    string tooLong = string:'join("", ...from int _ in 1 ... 301 select "x");
    string expected = "One of the details is too long.";
    test:assertEquals(parseApplicationForm(formRequest(withField("address", tooLong), PDF_BYTES)), expected);
    test:assertEquals(parseApplicationForm(formRequest(withField("firstName", tooLong), PDF_BYTES)), expected);
}

@test:Config {}
function invalidEmailsAreRejected() {
    string expected = "Enter a valid email address.";
    foreach string email in ["", "abc", "a@b", "@example.com", "a b@example.com", "a@@example.com", "a@.example.com"] {
        test:assertEquals(parseApplicationForm(formRequest(withField("email", email), PDF_BYTES)), expected,
            string `Email "${email}"`);
    }
}

@test:Config {}
function phoneNumbersMustBeInInternationalFormat() {
    string expected = "Enter the phone number in international format, for example +94771234567.";
    foreach string phone in ["0771234567", "94771234567", "+0771234567", "+94 77 123 4567", "+9477abc", "+1"] {
        test:assertEquals(parseApplicationForm(formRequest(withField("phone", phone), PDF_BYTES)), expected,
            string `Phone "${phone}"`);
    }
}

@test:Config {}
function theCvIsRequiredAndMustBeASmallPdf() {
    test:assertEquals(parseApplicationForm(formRequest(validFields(), ())), "A CV is required.");
    test:assertEquals(parseApplicationForm(formRequest(validFields(), [0x50, 0x4b, 0x03, 0x04])),
        "The CV must be a PDF file.");
    byte[] tooBig = [0x25, 0x50, 0x44, 0x46];
    foreach int _ in 0 ..< MAX_CV_BYTES {
        tooBig.push(0);
    }
    test:assertEquals(parseApplicationForm(formRequest(validFields(), tooBig)), "The CV must be 5MB or smaller.");
}

@test:Config {}
function emailPhoneAndPdfHelpers() {
    test:assertTrue(isValidEmail("name@example.com"));
    test:assertTrue(isValidPhone("+94771234567"));
    test:assertFalse(isValidPhone("+0771234567"));
    test:assertTrue(isPdf([0x25, 0x50, 0x44, 0x46, 0x2d]));
    test:assertFalse(isPdf([0x25, 0x50]));
}
