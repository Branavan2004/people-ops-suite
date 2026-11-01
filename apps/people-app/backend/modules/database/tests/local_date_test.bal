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

import ballerina/sql;
import ballerina/test;
import ballerina/time;

# Five past midnight on 15 October in Sri Lanka, still the afternoon of the 14th in California.
const string SRI_LANKA_JUST_AFTER_MIDNIGHT = "2026-10-14T18:35:00Z";

const int SRI_LANKA_COMPANY = 6;
const int US_COMPANY = 1;

isolated function sampleLocationTimeZones() returns map<string> => toLocationTimeZoneMap([
    {companyId: SRI_LANKA_COMPANY, allowedLocation: "Sri Lanka", timeZone: "Asia/Colombo"},
    {companyId: US_COMPANY, allowedLocation: "US", timeZone: "America/Los_Angeles"},
    {companyId: US_COMPANY, allowedLocation: "Sri Lanka", timeZone: "America/New_York"}
]);

@test:Config {}
function dateInFollowsTheZonesOwnCalendar() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    test:assertEquals(dateIn("Asia/Colombo", now), "2026-10-15");
    test:assertEquals(dateIn("America/Los_Angeles", now), "2026-10-14");
}

@test:Config {}
function dateInHonoursHalfHourOffsets() returns error? {
    test:assertEquals(dateIn("Asia/Colombo", check time:utcFromString("2026-10-14T18:29:00Z")), "2026-10-14");
    test:assertEquals(dateIn("Asia/Colombo", check time:utcFromString("2026-10-14T18:30:00Z")), "2026-10-15");
}

@test:Config {}
function dateInHonoursDaylightSaving() returns error? {
    test:assertEquals(dateIn("America/New_York", check time:utcFromString("2026-07-01T04:30:00Z")), "2026-07-01");
    test:assertEquals(dateIn("America/New_York", check time:utcFromString("2026-01-15T04:30:00Z")), "2026-01-14");
}

@test:Config {}
function dateInRejectsAnUnknownZone() returns error? {
    test:assertEquals(dateIn("Asia/Colmbo", check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT)), ());
}

@test:Config {}
function localDateFollowsTheWorkLocationsTimezone() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    map<string> zones = sampleLocationTimeZones();
    test:assertEquals(localDateAt(zones, SRI_LANKA_COMPANY, "Sri Lanka", now), "2026-10-15");
    test:assertEquals(localDateAt(zones, US_COMPANY, "US", now), "2026-10-14");
}

@test:Config {}
function localDateMatchesTheLocationRegardlessOfCaseAndSpacing() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    test:assertEquals(localDateAt(sampleLocationTimeZones(), US_COMPANY, "  us ", now), "2026-10-14");
}

@test:Config {}
function localDateUsesTheEmployeesOwnCompanysLocation() returns error? {
    // The same location name under another company carries that company's timezone, not this one's.
    time:Utc now = check time:utcFromString("2026-10-15T02:00:00Z");
    map<string> zones = sampleLocationTimeZones();
    test:assertEquals(localDateAt(zones, SRI_LANKA_COMPANY, "Sri Lanka", now), "2026-10-15");
    test:assertEquals(localDateAt(zones, US_COMPANY, "Sri Lanka", now), "2026-10-14");
}

@test:Config {}
function anUnknownWorkLocationFallsBackToSriLanka() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    test:assertEquals(localDateAt(sampleLocationTimeZones(), US_COMPANY, "United Kingdom", now), "2026-10-15");
    test:assertEquals(localDateAt({}, US_COMPANY, "US", now), "2026-10-15");
}

@test:Config {}
function anUnusableTimezoneFallsBackToSriLanka() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    map<string> zones = toLocationTimeZoneMap([
        {companyId: US_COMPANY, allowedLocation: "US", timeZone: "America/Las_Angeles"}
    ]);
    test:assertEquals(localDateAt(zones, US_COMPANY, "US", now), "2026-10-15");
}

@test:Config {}
function locationTimezonesIncludeInactiveLocations() {
    // An employee keeps a location after it stops being offered to new joiners, and still
    // needs its timezone.
    test:assertFalse(sqlText(getLocationTimeZonesQuery()).includes("is_active"));
}

@test:Config {}
function excludingFutureJoinersExcludesTheNewJoinerStatus() {
    // Whether someone has started is the status the scheduler keeps per work location, not
    // a start date compared with the database server's own date.
    sql:ParameterizedQuery query = getEmployeesQuery(
            {filters: {excludeFutureStartDate: true}, pagination: {}, sort: {}});
    string text = sqlText(query);
    test:assertTrue(text.includes("e.employee_status <> ?"), "future joiners should be excluded by status");
    test:assertFalse(text.includes("CURDATE"), "the server's own date should not decide who has started");
    int newJoinerBindings = 0;
    foreach var value in query.insertions {
        if value is string && value == EMPLOYEE_NEW_JOINER {
            newJoinerBindings += 1;
        }
    }
    test:assertEquals(newJoinerBindings, 1, "the New joiner status should be bound once");
}
