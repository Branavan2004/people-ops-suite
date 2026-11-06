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
function datesCrossYearBoundary() {
    test:assertEquals(subtractDays("2027-01-02", 5), "2026-12-28");
    test:assertEquals(daysBetween("2026-12-30", "2027-01-02"), 3);
    test:assertEquals(subtractDays("2026-03-01", 1), "2026-02-28");
    test:assertEquals(daysBetween("2026-10-26", "2026-10-26"), 0);
}

@test:Config {}
function daysMustBeAtLeastOne() {
    test:assertTrue(requireAtLeastOne("approvalReminderIntervalInDays", 1) is ());
    error? zero = requireAtLeastOne("approvalReminderIntervalInDays", 0);
    test:assertEquals((<error>zero).message(), "approvalReminderIntervalInDays must be at least 1");
}

@test:Config {}
function invalidDatesReturnErrors() {
    test:assertTrue(subtractDays("not-a-date", 1) is error);
    test:assertTrue(daysBetween("2026-10-26", "2026-13-45") is error);
}
