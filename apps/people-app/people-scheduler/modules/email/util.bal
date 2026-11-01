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

import people_scheduler.database;

import ballerina/lang.regexp;
import ballerina/mime;

# HTML-escape a string to prevent injection/XSS.
# Escapes &, <, >, ", and ' (& first to prevent double-escaping).
#
# + str - String to escape
# + return - HTML-escaped string
public isolated function htmlEscape(string str) returns string {
    string escaped = str;
    escaped = re `&`.replaceAll(escaped, "&amp;");
    escaped = re `<`.replaceAll(escaped, "&lt;");
    escaped = re `>`.replaceAll(escaped, "&gt;");
    escaped = re `"`.replaceAll(escaped, "&quot;");
    escaped = re `'`.replaceAll(escaped, "&#39;");
    return escaped;
}

# Month names indexed by month number (1-12).
final readonly & string[] MONTH_NAMES = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
];

# Format an ISO `yyyy-MM-dd` date as `MMMM dd, yyyy` (e.g. "2026-08-07" -> "August 07, 2026")
# for display in emails. Returns the input unchanged if it is not in the expected form, so a
# malformed value degrades to the raw date rather than failing the notification.
#
# + isoDate - Date string in `yyyy-MM-dd` form
# + return - Human-readable date, or the input unchanged if it cannot be parsed
public isolated function formatDisplayDate(string isoDate) returns string {
    string[] parts = re `-`.split(isoDate);
    if parts.length() != 3 {
        return isoDate;
    }
    int|error year = int:fromString(parts[0]);
    int|error month = int:fromString(parts[1]);
    if year is error || month is error || month < 1 || month > 12 {
        return isoDate;
    }
    return string `${MONTH_NAMES[month - 1]} ${parts[2]}, ${year}`;
}

# Placeholders whose values are HTML built by this module, with their own values already
# escaped. They are bound as-is; every other value is escaped on binding.
final readonly & string[] PREBUILT_HTML_KEYS = ["EMPLOYEE_LIST", "PENDING_EMAIL_NOTE"];

# Bind values to the email template and encode.
#
# + content - Email content
# + keyValPairs - Key value pairs
# + return - Email content
public isolated function bindKeyValues(string content, map<string> keyValPairs) returns string|error {
    string bindContent = keyValPairs.entries().reduce(
        isolated function(string accumulation, [string, string] keyVal) returns string {
        regexp:RegExp r = re `<!-- \[${keyVal[0].toUpperAscii()}\] -->`;
        string valueToReplace = PREBUILT_HTML_KEYS.indexOf(keyVal[0]) is int ? keyVal[1] : htmlEscape(keyVal[1]);
        return r.replaceAll(accumulation, valueToReplace);
    },
    content);
    return mime:base64Encode(bindContent).ensureType();
}

# The date a summary email is for, and the subject's heading for it.
#
# The date is the latest one the employees in the email moved on (their start date,
# effective date or final day) rather than the date of the run, which for a location ahead
# of Sri Lanka falls on the day before. The heading adds the location when everyone in the
# email shares one; otherwise each row names its own.
#
# + dates - The date each employee in the email moved on, in YYYY-MM-DD form
# + locations - Each employee's work location
# + return - The date, and the subject's heading for it
isolated function summaryDateAndHeading(string[] dates, string[] locations) returns [string, string] {
    string date = database:latestDate(dates) ?: "";
    string? location = database:sharedLocation(locations);
    return [date, location is string ? string `${date}, ${location}` : date];
}
