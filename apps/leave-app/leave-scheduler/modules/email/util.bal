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

import ballerina/lang.regexp;
import ballerina/mime;

# HTML-escape a string to prevent injection/XSS.
# Escapes &, <, >, ", and ' (& first to prevent double-escaping).
#
# + str - String to escape
# + return - HTML-escaped string
isolated function htmlEscape(string str) returns string {
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
# for display in emails. Returns the input unchanged if it is not in the expected form.
#
# + isoDate - Date string in `yyyy-MM-dd` form
# + return - Human-readable date, or the input unchanged if it cannot be parsed
isolated function formatDisplayDate(string isoDate) returns string {
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

# Describe a leave length as the policy does: in weeks when it is a whole number of weeks
# (e.g. "6-week"), otherwise in days (e.g. "30-day").
#
# + durationDays - Number of calendar days the leave spans
# + return - Length label
isolated function formatDuration(int durationDays) returns string =>
    durationDays % 7 == 0 ? string `${durationDays / 7}-week` : string `${durationDays}-day`;

# Bind values to the email template and encode.
#
# + content - Email content
# + keyValPairs - Key value pairs
# + return - Email content
isolated function bindKeyValues(string content, map<string> keyValPairs) returns string|error {
    string bindContent = keyValPairs.entries().reduce(
        isolated function(string accumulation, [string, string] keyVal) returns string {
        regexp:RegExp r = re `<!-- \[${keyVal[0].toUpperAscii()}\] -->`;
        return r.replaceAll(accumulation, htmlEscape(keyVal[1]));
    },
    content);
    return mime:base64Encode(bindContent).ensureType();
}
