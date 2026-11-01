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

import ballerina/test;
import ballerina/time;

# Five past midnight on 15 October in Sri Lanka, still the afternoon of the 14th in California.
const string SRI_LANKA_JUST_AFTER_MIDNIGHT = "2026-10-14T18:35:00Z";

isolated function joiner(string employeeId, string startDate, string? timeZone) returns JoinerActivation => {
    employeeId,
    firstName: "Test",
    lastName: "Joiner",
    workEmail: "future-joiner@wso2.com",
    startDate,
    workLocation: "Test location",
    timeZone
};

isolated function leaver(string employeeId, string finalDay, string? timeZone) returns LeaverTransition => {
    employeeId,
    firstName: "Test",
    lastName: "Leaver",
    workEmail: "leaver@wso2.com",
    finalDayOfEmployment: finalDay,
    workLocation: "Test location",
    timeZone
};

isolated function scheduledChange(int id, string effectiveDate, string? timeZone) returns ScheduledChange => {
    id,
    employeePkId: id,
    employeeId: string `LK${id}`,
    firstName: "Test",
    lastName: "Change",
    effectiveDate,
    changes: {},
    expected: {},
    createdBy: "admin@wso2.com",
    workLocation: "Test location",
    timeZone
};

@test:Config {}
function dateInFollowsTheZonesOwnCalendar() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    test:assertEquals(dateIn("Asia/Colombo", now), "2026-10-15");
    test:assertEquals(dateIn("America/Los_Angeles", now), "2026-10-14");
    test:assertEquals(dateIn("UTC", now), "2026-10-14");
}

@test:Config {}
function dateInHonoursHalfHourOffsets() returns error? {
    // 23:59 in Sri Lanka: a whole-hour offset of +5 or +6 would put it on the wrong side of midnight.
    test:assertEquals(dateIn("Asia/Colombo", check time:utcFromString("2026-10-14T18:29:00Z")), "2026-10-14");
    test:assertEquals(dateIn("Asia/Colombo", check time:utcFromString("2026-10-14T18:30:00Z")), "2026-10-15");
}

@test:Config {}
function dateInHonoursDaylightSaving() returns error? {
    // 04:30 UTC is 00:30 on 1 July in New York under daylight saving (UTC-4), but still
    // 23:30 on 14 January in winter (UTC-5).
    test:assertEquals(dateIn("America/New_York", check time:utcFromString("2026-07-01T04:30:00Z")), "2026-07-01");
    test:assertEquals(dateIn("America/New_York", check time:utcFromString("2026-01-15T04:30:00Z")), "2026-01-14");
}

@test:Config {}
function dateInRejectsAnUnknownZone() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    test:assertEquals(dateIn("Asia/Colmbo", now), ());
    test:assertEquals(dateIn("", now), ());
}

@test:Config {}
function aMissingOrUnusableZoneFallsBackToSriLanka() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    test:assertEquals(employeeToday("LK1", (), now), "2026-10-15");
    test:assertEquals(employeeToday("LK1", "Asia/Colmbo", now), "2026-10-15");
    test:assertEquals(employeeToday("US1", "America/Los_Angeles", now), "2026-10-14");
}

@test:Config {}
function aJoinerIsActivatedOnceTheirStartDateBeginsWhereTheyWork() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    JoinerActivation[] due = dueJoiners([
        joiner("LK-TODAY", "2026-10-15", "Asia/Colombo"),
        joiner("US-TOMORROW", "2026-10-15", "America/Los_Angeles"),
        joiner("US-TODAY", "2026-10-14", "America/Los_Angeles"),
        joiner("LK-NEXT-WEEK", "2026-10-22", "Asia/Colombo")
    ], now);
    test:assertEquals(from JoinerActivation j in due select j.employeeId, ["LK-TODAY", "US-TODAY"]);
}

@test:Config {}
function aLeaverLeavesOnceTheirFinalDayIsOverWhereTheyWork() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    LeaverTransition[] due = dueLeavers([
        // Their final day ended five minutes ago.
        leaver("LK-ENDED", "2026-10-14", "Asia/Colombo"),
        // Today is their final day: they are still employed until it ends.
        leaver("LK-LAST-DAY", "2026-10-15", "Asia/Colombo"),
        // Still the afternoon of their final day in California.
        leaver("US-LAST-DAY", "2026-10-14", "America/Los_Angeles"),
        leaver("US-ENDED", "2026-10-13", "America/Los_Angeles")
    ], now);
    test:assertEquals(from LeaverTransition l in due select l.employeeId, ["LK-ENDED", "US-ENDED"]);
}

@test:Config {}
function aScheduledChangeAppliesOnceItsDateBeginsWhereTheEmployeeWorks() returns error? {
    time:Utc now = check time:utcFromString(SRI_LANKA_JUST_AFTER_MIDNIGHT);
    ScheduledChange[] due = dueScheduledChanges([
        scheduledChange(1, "2026-10-14", "America/Los_Angeles"),
        scheduledChange(2, "2026-10-15", "America/Los_Angeles"),
        scheduledChange(3, "2026-10-15", "Asia/Colombo"),
        scheduledChange(4, "2026-10-16", "Asia/Colombo")
    ], now);
    // Order is kept, so two changes to one employee still land in the order they were meant to.
    test:assertEquals(from ScheduledChange c in due select c.id, [1, 3]);
}

@test:Config {}
function joinerCandidatesReachADayPastUtc() {
    // Zones ahead of UTC reach a start date before UTC does, so the candidates must too.
    string text = string:'join("?", ...getDueNewJoinersQuery().strings);
    test:assertTrue(text.includes("e.start_date <= UTC_DATE() + INTERVAL 1 DAY"));
    test:assertTrue(text.includes("time_zone"), "candidates should carry the work location's timezone");
}

@test:Config {}
function scheduledChangeCandidatesReachADayPastUtc() {
    string text = string:'join("?", ...getDueScheduledChangesQuery().strings);
    test:assertTrue(text.includes("sc.effective_date <= UTC_DATE() + INTERVAL 1 DAY"));
    test:assertTrue(text.includes("time_zone"), "candidates should carry the work location's timezone");
}

@test:Config {}
function leaverCandidatesCarryTheirTimezone() {
    string text = string:'join("?", ...getExpiredLeaversQuery().strings);
    test:assertTrue(text.includes("time_zone"), "candidates should carry the work location's timezone");
}

# The timezones people_app_table_update_v1.4.0.sql gives the live work locations.
final readonly & string[] LIVE_TIME_ZONES = [
    "Asia/Colombo", "Asia/Kolkata", "Asia/Dhaka", "Asia/Bangkok", "Asia/Singapore", "Asia/Hong_Kong",
    "Asia/Dubai", "Asia/Riyadh", "Australia/Sydney", "Pacific/Auckland", "Europe/London", "Europe/Lisbon",
    "Europe/Madrid", "Europe/Paris", "Europe/Amsterdam", "Europe/Berlin", "Europe/Rome", "Europe/Stockholm",
    "Europe/Athens", "Europe/Kyiv", "Africa/Casablanca", "Africa/Johannesburg", "Africa/Nairobi",
    "America/Sao_Paulo", "America/Argentina/Buenos_Aires", "America/Bogota", "America/Mexico_City",
    "America/Toronto", "America/New_York"
];

# Minutes past each hour, in UTC, that an hourly run starts at.
const int HOURLY_RUN_MINUTE = 35;

# The first hourly run, from two days before the date, at which a sweep would move them.
#
# + date - Start date of the joiner, or final day of the leaver
# + timeZone - Their work location's timezone
# + leaving - True for a leaver, false for a joiner
# + return - The run that moves them, or nil when none in four days does
isolated function firstHourlyRunThatMoves(string date, string timeZone, boolean leaving) returns time:Utc?|error {
    time:Civil dayBefore = check time:civilFromString(string `${date}T00:00:00Z`);
    time:Utc first = time:utcAddSeconds(check time:utcFromCivil(dayBefore),
            -2 * 86400d + <decimal>(HOURLY_RUN_MINUTE * 60));
    foreach int hour in 0 ..< 96 {
        time:Utc run = time:utcAddSeconds(first, <decimal>(hour * 3600));
        boolean moves = leaving
            ? dueLeavers([leaver("L", date, timeZone)], run).length() == 1
            : dueJoiners([joiner("J", date, timeZone)], run).length() == 1;
        if moves {
            return run;
        }
    }
    return ();
}

# Minutes from local midnight at which a run lands, with the local date it lands on.
#
# + run - The run
# + timeZone - Timezone to read it in
# + return - Local date and minutes since local midnight
isolated function localDateAndMinute(time:Utc run, string timeZone) returns [string, int]|error {
    time:Zone? zone = time:getZone(timeZone);
    if zone is () {
        return error(string `Unknown timezone ${timeZone}`);
    }
    time:Civil civil = zone.utcToCivil(run);
    return [<string>dateIn(timeZone, run), civil.hour * 60 + civil.minute];
}

@test:Config {}
function hourlyRunsMoveEveryLiveLocationWithinAnHourOfLocalMidnight() returns error? {
    // An ordinary day, the day UK clocks go back, and the day US clocks go back.
    foreach string date in ["2026-10-16", "2026-10-25", "2026-11-01"] {
        time:Civil next = check time:civilFromString(string `${date}T00:00:00Z`);
        string dayAfter = time:utcToString(time:utcAddSeconds(check time:utcFromCivil(next), 86400)).substring(0, 10);
        foreach string zone in LIVE_TIME_ZONES {
            // A joiner moves in the first hour of their start date.
            time:Utc activated = check (check firstHourlyRunThatMoves(date, zone, false)).ensureType();
            [string, int] [activatedOn, activatedMinute] = check localDateAndMinute(activated, zone);
            test:assertEquals(activatedOn, date, string `${zone}: activated on the wrong local day for ${date}`);
            test:assertTrue(activatedMinute < 60,
                    string `${zone}: activated ${activatedMinute} minutes after local midnight`);

            // A leaver moves in the first hour after their final day ends.
            time:Utc left = check (check firstHourlyRunThatMoves(date, zone, true)).ensureType();
            [string, int] [leftOn, leftMinute] = check localDateAndMinute(left, zone);
            test:assertEquals(leftOn, dayAfter, string `${zone}: left on the wrong local day for final day ${date}`);
            test:assertTrue(leftMinute < 60, string `${zone}: left ${leftMinute} minutes after local midnight`);
        }
    }
}
