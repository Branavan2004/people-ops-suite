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

import ballerina/time;

const SECONDS_PER_DAY = 86400;

# Parses a `yyyy-mm-dd` string into the UTC instant at midnight of that day.
#
# + date - Date in `yyyy-mm-dd` format
# + return - UTC midnight of the date, or an error if the date is invalid
isolated function midnightUtc(string date) returns time:Utc|error {
    if date.length() != 10 {
        return error(string `Invalid date: ${date}`);
    }
    time:Utc utc = check time:utcFromString(date + "T00:00:00Z");
    // Reject dates that were silently rolled over (e.g. 2026-02-30).
    string back = check formatDate(utc);
    if back != date {
        return error(string `Invalid date: ${date}`);
    }
    return utc;
}

# Formats a UTC instant as a `yyyy-mm-dd` string.
#
# + utc - The UTC instant
# + return - Date in `yyyy-mm-dd` format, or an error if formatting fails
isolated function formatDate(time:Utc utc) returns string|error {
    time:Civil civil = time:utcToCivil(utc);
    string month = civil.month < 10 ? string `0${civil.month}` : civil.month.toString();
    string day = civil.day < 10 ? string `0${civil.day}` : civil.day.toString();
    return string `${civil.year}-${month}-${day}`;
}

# Subtracts a number of days from a date.
#
# + date - Date in `yyyy-mm-dd` format
# + days - Number of days to subtract
# + return - The resulting date in `yyyy-mm-dd` format, or an error if the date is invalid
public isolated function subtractDays(string date, int days) returns string|error {
    time:Utc utc = check midnightUtc(date);
    return formatDate(time:utcAddSeconds(utc, <time:Seconds>(-days * SECONDS_PER_DAY)));
}

# Counts the whole days from one date to another.
#
# + fromDate - Start date in `yyyy-mm-dd` format
# + toDate - End date in `yyyy-mm-dd` format
# + return - Days from `fromDate` to `toDate` (negative if `toDate` is earlier), or an error if a date is invalid
public isolated function daysBetween(string fromDate, string toDate) returns int|error {
    time:Utc fromUtc = check midnightUtc(fromDate);
    time:Utc toUtc = check midnightUtc(toDate);
    return <int>(time:utcDiffSeconds(toUtc, fromUtc) / SECONDS_PER_DAY).round();
}

# Checks that a day-count configuration value is at least 1.
#
# + name - Name of the configuration, used in the error message
# + value - The configured number of days
# + return - An error if the value is less than 1, otherwise nil
public isolated function requireAtLeastOne(string name, int value) returns error? {
    if value < 1 {
        return error(string `${name} must be at least 1`);
    }
}
