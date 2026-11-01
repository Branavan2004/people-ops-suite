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

const MAX_EMAIL_LENGTH = 254;

// Same shape the webapp checks before submitting.
final string:RegExp EMAIL_PATTERN = re `[^\s@]+@[^\s@.]+(\.[^\s@.]+)+`;

// E.164: "+", then 2 to 15 digits, not starting with 0.
final string:RegExp PHONE_PATTERN = re `\+[1-9][0-9]{1,14}`;

# Whether the value looks like an email address.
public isolated function isValidEmail(string email) returns boolean =>
    email.length() <= MAX_EMAIL_LENGTH && EMAIL_PATTERN.isFullMatch(email);

# Whether the value is a phone number in E.164 format.
public isolated function isValidPhone(string phone) returns boolean => PHONE_PATTERN.isFullMatch(phone);

# A PDF starts with "%PDF", so the CV is not trusted on its declared type alone.
public isolated function isPdf(byte[] content) returns boolean {
    return content.length() >= 4 && content[0] == 0x25 && content[1] == 0x50 && content[2] == 0x44
        && content[3] == 0x46;
}

# Reads the multipart form, returning a message for the applicant when something is missing or invalid.
public isolated function parseApplicationForm(http:Request req) returns ApplicationForm|string {
    mime:Entity[]|http:ClientError parts = req.getBodyParts();
    if parts is http:ClientError {
        return "The application must be sent as a multipart form.";
    }

    map<string> fields = {};
    byte[]? cv = ();
    foreach mime:Entity part in parts {
        string name = part.getContentDisposition().name;
        if name == "cv" {
            byte[]|mime:ParserError content = part.getByteArray();
            if content is mime:ParserError {
                return "The CV could not be read.";
            }
            cv = content;
        } else {
            string|mime:ParserError text = part.getText();
            if text is string {
                fields[name] = text.trim();
            }
        }
    }

    string firstName = fields["firstName"] ?: "";
    string lastName = fields["lastName"] ?: "";
    string email = fields["email"] ?: "";
    string phone = fields["phone"] ?: "";
    string address = fields["address"] ?: "";
    string university = fields["university"] ?: "";

    if firstName == "" || lastName == "" || phone == "" || address == "" {
        return "First name, last name, phone and address are required.";
    }
    if firstName.length() > 100 || lastName.length() > 100 || address.length() > 300 || university.length() > 255 {
        return "One of the details is too long.";
    }
    if !isValidEmail(email) {
        return "Enter a valid email address.";
    }
    if !isValidPhone(phone) {
        return "Enter the phone number in international format, for example +94771234567.";
    }
    if cv is () {
        return "A CV is required.";
    }
    if cv.length() > MAX_CV_BYTES {
        return "The CV must be 5MB or smaller.";
    }
    if !isPdf(cv) {
        return "The CV must be a PDF file.";
    }
    ApplicationForm form = {firstName, lastName, email, phone, address, cv};
    if university != "" {
        form.university = university;
    }
    return form;
}
