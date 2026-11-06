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
function numericIdsAreAccepted() {
    test:assertTrue(isValidNumericId("258"));
    test:assertTrue(isValidNumericId("7"));
}

@test:Config {}
function pathTraversalAndOddIdsAreRejected() {
    string[] rejected = ["", "..", "../org-structure", "..%2Forg-structure", "1/2", "1 2", "1?x=y", "%2e%2e", "saved",
        "org-structure", "12a", "-1"];
    foreach string id in rejected {
        test:assertFalse(isValidNumericId(id), string `Id "${id}" should be rejected`);
    }
}

@test:Config {}
function invalidEmailsAreRejected() {
    test:assertTrue(isValidEmail("name@example.com"));
    foreach string email in ["", "abc", "a@b", "@example.com", "a b@example.com", "a@@example.com", "a@.example.com"] {
        test:assertFalse(isValidEmail(email), string `Email "${email}"`);
    }
}

@test:Config {}
function phoneNumbersMustBeInInternationalFormat() {
    test:assertTrue(isValidPhone("+94771234567"));
    foreach string phone in ["0771234567", "94771234567", "+0771234567", "+94 77 123 4567", "+9477abc", "+1"] {
        test:assertFalse(isValidPhone(phone), string `Phone "${phone}"`);
    }
}

@test:Config {}
function aPdfIsRecognisedByItsFirstBytes() {
    test:assertTrue(isPdf([0x25, 0x50, 0x44, 0x46, 0x2d]));
    test:assertFalse(isPdf([0x25, 0x50]));
    test:assertFalse(isPdf([0x50, 0x4b, 0x03, 0x04]));
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
