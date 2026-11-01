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

@test:Config {}
function latestDateIsTheLastDayInTheBatch() {
    test:assertEquals(latestDate(["2026-10-16", "2026-10-17", "2026-10-15"]), "2026-10-17");
    test:assertEquals(latestDate(["2026-10-16"]), "2026-10-16");
    test:assertEquals(latestDate([]), ());
}

@test:Config {}
function locationLabelNamesTheTimezoneByItsCity() {
    test:assertEquals(locationLabel("Australia", "Australia/Sydney"), "Australia · Sydney time");
    test:assertEquals(locationLabel("US", "America/New_York"), "US · New York time");
    test:assertEquals(locationLabel("Argentina", "America/Argentina/Buenos_Aires"), "Argentina · Buenos Aires time");
}

@test:Config {}
function locationLabelSaysWhenTheDefaultTimezoneWasUsed() {
    // Shown to HR so a location that matches nothing gets fixed, rather than only logged.
    test:assertEquals(locationLabel("United Kingdom", ()),
            "United Kingdom · Colombo time (no timezone on record)");
    test:assertEquals(locationLabel("UK", "Europe/Lnodon"),
            "UK · Colombo time (timezone not recognised)");
}

@test:Config {}
function sharedLocationIsNamedOnlyWhenEveryoneHasIt() {
    test:assertEquals(sharedLocation(["Australia", "Australia"]), "Australia");
    test:assertEquals(sharedLocation(["Sri Lanka", "India"]), ());
    test:assertEquals(sharedLocation([]), ());
}

@test:Config {}
function candidatesCarryTheirWorkLocation() {
    foreach string text in [
            string:'join("?", ...getExpiredLeaversQuery().strings),
            string:'join("?", ...getDueNewJoinersQuery().strings),
            string:'join("?", ...getDueScheduledChangesQuery().strings)
        ] {
        test:assertTrue(text.includes("e.work_location"), "the summary email names each employee's location");
    }
}
