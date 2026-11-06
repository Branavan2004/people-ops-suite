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

const MAX_EMAIL_LENGTH = 254;

// Same shape the webapp checks before submitting.
final string:RegExp EMAIL_PATTERN = re `[^\s@]+@[^\s@.]+(\.[^\s@.]+)+`;

// E.164: "+", then 2 to 15 digits, not starting with 0.
final string:RegExp PHONE_PATTERN = re `\+[1-9][0-9]{1,14}`;

# Whether the value is a numeric id (digits only); nothing else may reach the upstream URL.
public isolated function isValidNumericId(string id) returns boolean => re `[0-9]+`.isFullMatch(id);

# Whether the value looks like an email address.
public isolated function isValidEmail(string email) returns boolean =>
    email.length() <= MAX_EMAIL_LENGTH && EMAIL_PATTERN.isFullMatch(email);

# Whether the value is a phone number in E.164 format.
public isolated function isValidPhone(string phone) returns boolean => PHONE_PATTERN.isFullMatch(phone);

# A PDF starts with "%PDF", so an upload is not trusted on its declared type alone.
public isolated function isPdf(byte[] content) returns boolean {
    return content.length() >= 4 && content[0] == 0x25 && content[1] == 0x50 && content[2] == 0x44
        && content[3] == 0x46;
}

# The text with every email address, plain or URL-encoded, replaced, so that it is safe to write to a log.
public isolated function withoutEmails(string text) returns string =>
    re `[^\s/?&=]+(%40|@)[^\s/?&=]+`.replaceAll(text, "{email}");

# The text with email addresses and phone numbers replaced, so that an upstream reply or an error quoting a value is
# safe to write to a log.
public isolated function withoutPersonalData(string text) returns string =>
    re `\+?\d[\d\s\-()]{5,}\d`.replaceAll(withoutEmails(text), "{phone}");
