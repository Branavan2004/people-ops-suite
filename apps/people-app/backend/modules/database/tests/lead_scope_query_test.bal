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

const LEAD_EMAIL = "lead@example.invalid";

# A lead's My Team search, either the whole reporting chain or direct reports only.
#
# + directReports - Whether to restrict to direct reports
# + return - Search payload as the My Team screen sends it
isolated function leadSearchPayload(boolean directReports) returns EmployeeSearchPayload => {
    filters: {directReports, employeeStatuses: [EMPLOYEE_ACTIVE, EMPLOYEE_MARKED_LEAVER]},
    pagination: {},
    sort: {},
    leadOnly: true
};

# Whether every read of `employee_additional_managers` is limited to active rows.
#
# Removing an additional manager only sets `is_active = 0`, so a read without that condition
# still counts the removed link. The condition must sit in the same clause as the table, before
# the clause's closing parenthesis.
#
# + sqlString - SQL text to inspect
# + return - True when every mention of the table is followed by `is_active = 1` in its clause
isolated function readsOnlyActiveAdditionalManagers(string sqlString) returns boolean {
    string tableName = "employee_additional_managers";
    int? at = sqlString.indexOf(tableName);
    while at is int {
        string rest = sqlString.substring(at + tableName.length());
        int? clauseEnd = rest.indexOf(")");
        string clause = clauseEnd is int ? rest.substring(0, clauseEnd) : rest;
        if !clause.includes("is_active = 1") {
            return false;
        }
        at = sqlString.indexOf(tableName, at + tableName.length());
    }
    return true;
}

@test:Config {}
isolated function testWholeChainIgnoresRemovedAdditionalManagers() {
    test:assertTrue(readsOnlyActiveAdditionalManagers(sqlText(getEmployeesQuery(leadSearchPayload(false),
                    LEAD_EMAIL))), "a removed additional manager must not pull anyone into the chain");
}

@test:Config {}
isolated function testDirectReportsIgnoreRemovedAdditionalManagers() {
    test:assertTrue(readsOnlyActiveAdditionalManagers(sqlText(getEmployeesQuery(leadSearchPayload(true),
                    LEAD_EMAIL))), "a removed additional manager must not count as a direct report");
}

@test:Config {}
isolated function testRecordAccessIgnoresRemovedAdditionalManagers() {
    test:assertTrue(readsOnlyActiveAdditionalManagers(sqlText(isSubordinateOfLeadQuery(LEAD_EMAIL, "LK100001"))),
            "a removed additional manager must not grant access to the employee's record");
}

@test:Config {}
isolated function testLeadStatusIgnoresRemovedAdditionalManagers() {
    test:assertTrue(readsOnlyActiveAdditionalManagers(sqlText(isLeadQuery(LEAD_EMAIL))),
            "a removed additional manager must not keep someone a lead");
}

@test:Config {}
isolated function testChainAndRecordAccessShareOneWalk() {
    string walk = sqlText(subordinateTreeCte(LEAD_EMAIL));
    test:assertTrue(sqlText(getEmployeesQuery(leadSearchPayload(false), LEAD_EMAIL)).startsWith(walk),
            "the My Team list should walk the chain with the shared query");
    test:assertTrue(sqlText(isSubordinateOfLeadQuery(LEAD_EMAIL, "LK100001")).startsWith(walk),
            "record access should walk the same chain as the My Team list");
}

@test:Config {}
isolated function testChainWalkStopsAtAnEarlierEmploymentOfARehire() {
    // A rehire keeps their work email, so their earlier, Left row still names the manager they
    // had the first time. Walking on from that row would hand their current reports to that
    // manager. Every recursive step must check the row it continues from.
    sql:ParameterizedQuery walk = subordinateTreeCte(LEAD_EMAIL);
    string text = sqlText(walk);
    int recursiveSteps = occurrences(text, "JOIN subordinate_tree st");
    test:assertEquals(recursiveSteps, 2, "the walk follows both the manager and the additional-manager link");
    test:assertEquals(occurrences(text, "st.traversable = 1"), recursiveSteps,
            "every recursive step should continue only from a traversable row");
    test:assertTrue(walk.insertions.some(value => value == EMPLOYEE_LEFT),
            "traversability should be decided by the Left status");
}

# How many times a substring occurs in a string.
#
# + text - Text to search
# + part - Substring to count
# + return - Number of non-overlapping occurrences
isolated function occurrences(string text, string part) returns int {
    int count = 0;
    int? at = text.indexOf(part);
    while at is int {
        count += 1;
        at = text.indexOf(part, at + part.length());
    }
    return count;
}

@test:Config {}
isolated function testCurrentEmploymentsExcludeMissingWorkEmails() {
    // Traversability is a NOT IN over current work emails. A single NULL in that list makes
    // NOT IN unknown for every row, so no leaver could ever be walked through. Work email is
    // optional for a new joiner, so the list must leave NULLs out.
    string text = sqlText(subordinateTreeCte(LEAD_EMAIL));
    test:assertTrue(text.includes("NOT IN (SELECT email FROM current_email)"),
            "current work emails should be collected once, not looked up per row");
    test:assertTrue(text.includes("work_email IS NOT NULL"),
            "a missing work email must not reach the NOT IN list");
}
