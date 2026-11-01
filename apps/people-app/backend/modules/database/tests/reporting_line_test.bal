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
isolated function testWalkRemembersWhereEachRouteStarted() {
    // Each row carries the lead's additional report its route started from, or NULL when the route
    // started from a direct report. That is what lets the reporting line name who links someone in.
    string text = sqlText(subordinateTreeCte(LEAD_EMAIL));
    test:assertTrue(text.includes("subordinate_tree (pk_id, w_email, visited, traversable, root_additional)"),
            "the walk should carry where each route started");
    test:assertEquals(occurrences(text, "CAST(NULL AS SIGNED)"), 1,
            "a route from a direct report starts from no additional report");
    test:assertEquals(occurrences(text, "st.root_additional"), 2,
            "every recursive step should keep where its route started");
}

@test:Config {}
isolated function testReportingLineWalksTheSameChain() {
    test:assertTrue(sqlText(reportingLineQuery(LEAD_EMAIL, "LK100001")).startsWith(sqlText(subordinateTreeCte(LEAD_EMAIL))),
            "the reporting line should be read from the same walk as My Team and record access");
}

@test:Config {}
isolated function testReportingLineNamesOnlyAStartEveryRouteShares() {
    // Someone reached both through a direct report and through an additional report is in the team
    // in the ordinary way, so no additional report is named.
    test:assertTrue(sqlText(reportingLineQuery(LEAD_EMAIL, "LK100001")).includes("MAX(root_additional IS NULL)"),
            "the start should be named only when no route starts from a direct report");
}

# A reporting line row as the query returns it, linked through one additional report.
#
# + relation - How the employee relates to the lead
# + return - The row
isolated function lineRow(ReportingRelation relation) returns ReportingLineRow => {
    relation,
    throughEmployeeId: "LK100002",
    throughFirstName: "Test",
    throughLastName: "Person"
};

@test:Config {}
isolated function testIndirectReportNamesTheAdditionalReportTheyCameThrough() {
    test:assertEquals(reportingLineFromRow(lineRow(INDIRECT)), {
        relation: INDIRECT,
        through: {employeeId: "LK100002", firstName: "Test", lastName: "Person"}
    });
}

@test:Config {}
isolated function testDirectAndAdditionalReportsNameNoOne() {
    // An additional report's own route starts at them, so the row names them. The relation already
    // says it all.
    test:assertEquals(reportingLineFromRow(lineRow(DIRECT)), {relation: DIRECT, through: ()});
    test:assertEquals(reportingLineFromRow(lineRow(ADDITIONAL)), {relation: ADDITIONAL, through: ()});
}

@test:Config {}
isolated function testIndirectReportReachedDirectlyNamesNoOne() {
    test:assertEquals(reportingLineFromRow({relation: INDIRECT}), {relation: INDIRECT, through: ()});
}

@test:Config {}
isolated function testWholeChainNamesTheAdditionalReportEachMemberCameThrough() {
    string text = sqlText(getEmployeesQuery(leadSearchPayload(false), LEAD_EMAIL));
    test:assertTrue(text.includes("via.employee_id AS throughEmployeeId"),
            "each row should name the additional report it came through");
    test:assertTrue(text.includes("MAX(root_additional IS NULL)"),
            "a start should be named only when every route to the member shares it");
    test:assertTrue(text.includes("route.root_additional <> e.id"),
            "an additional report should not be named as coming through themselves");
}

@test:Config {}
isolated function testListsThatDoNotWalkTheChainNameNoOne() {
    // Direct Reports Only and searches by anyone but a lead never walk the chain, so there is no
    // route to read.
    foreach string text in [
        sqlText(getEmployeesQuery(leadSearchPayload(true), LEAD_EMAIL)),
        sqlText(getEmployeesQuery(leadSearchPayload(false)))
    ] {
        test:assertTrue(text.includes("NULL AS throughEmployeeId"), "rows should name no one");
        test:assertFalse(text.includes("subordinate_tree"), "the list should not walk the chain");
    }
}

@test:Config {}
isolated function testWholeChainReadsTheWalkOnce() {
    // MySQL 8.0.27 shifts the columns of a recursive CTE that one query reads twice ("Incorrect
    // integer value ... for column 'pk_id'"). The route lookup therefore also restricts the list to
    // the chain, in place of a separate IN filter.
    string text = sqlText(getEmployeesQuery(leadSearchPayload(false), LEAD_EMAIL));
    test:assertEquals(occurrences(text, "FROM subordinate_tree"), 1, "the whole-chain list should read the walk once");

    // That one read is what keeps the list to the lead's chain, so it must be an inner join.
    int? read = text.indexOf("FROM subordinate_tree");
    string before = read is int ? text.substring(0, read) : "";
    int? joinAt = before.lastIndexOf("JOIN (");
    test:assertTrue(joinAt is int && joinAt >= 6 && before.substring(joinAt - 6, joinAt) == "INNER ",
            "the walk should be read through an inner join, so rows outside the chain are dropped");
}
