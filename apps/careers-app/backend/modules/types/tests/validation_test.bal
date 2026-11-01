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
function numericJobIdsAreAccepted() {
    test:assertTrue(isValidJobId("258"));
    test:assertTrue(isValidJobId("7"));
}

@test:Config {}
function pathTraversalAndOddJobIdsAreRejected() {
    string[] rejected = ["", "..", "../org-structure", "..%2Forg-structure", "1/2", "1 2", "1?x=y", "%2e%2e", "saved",
        "org-structure", "12a", "-1"];
    foreach string jobId in rejected {
        test:assertFalse(isValidJobId(jobId), string `Job id "${jobId}" should be rejected`);
    }
}

@test:Config {}
function emailAddressesAreRemovedFromLoggedText() {
    test:assertEquals(withoutEmails("failed for ada@example.test and more"), "failed for {email} and more");
    test:assertEquals(withoutEmails("connection refused"), "connection refused");
}

@test:Config {}
function emailAddressesAndPhoneNumbersAreRemovedFromAnUpstreamReply() {
    string logged = withoutPersonalData("Candidate ada@example.test already exists, call +94 77 123 4567");
    test:assertEquals(logged, "Candidate {email} already exists, call {phone}");
    test:assertEquals(withoutPersonalData("found '+94771234567' in the history"), "found '{phone}' in the history");
    test:assertEquals(withoutPersonalData("The ATS replied with status 502"), "The ATS replied with status 502");
}

@test:Config {}
function aCandidatesEmailIsNotPartOfALoggedPath() {
    string logged = withoutEmails("/candidates/ada%40example.test/histories?limit=100");
    test:assertEquals(logged, "/candidates/{email}/histories?limit=100");
    test:assertFalse(logged.includes("ada"));
    test:assertFalse(logged.includes("example"));
}

@test:Config {}
function pathsWithoutAnEmailAreLoggedAsTheyAre() {
    test:assertEquals(withoutEmails("/vacancies/224"), "/vacancies/224");
    test:assertEquals(withoutEmails("/vacancies?status=PUBLISHED"), "/vacancies?status=PUBLISHED");
    test:assertEquals(withoutEmails("/org-details"), "/org-details");
}
