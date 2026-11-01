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

import ballerina/jwt;
import ballerina/test;

// Header {"alg":"none"} with a payload that looks valid (right issuer and audience, far-future expiry) and no signature.
const string UNSIGNED_TOKEN = "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0."
    + "eyJzdWIiOiJzb21lb25lIiwiZXhwIjo5OTk5OTk5OTk5LCJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLnRlc3QiLCJhdWQiOiJ0ZXN0LWF1ZGllbmNlIn0.";

@test:Config {}
function emptyTokenIsRejected() {
    test:assertTrue(validateToken("") is error);
}

@test:Config {}
function malformedTokenIsRejected() {
    test:assertTrue(validateToken("not-a-jwt") is error);
}

@test:Config {}
function unsignedTokenIsRejected() {
    test:assertTrue(validateToken(UNSIGNED_TOKEN) is error);
}

@test:Config {}
function identityIsTheSubject() {
    jwt:Payload payload = {sub: "user-1"};
    test:assertEquals(identityOf(payload), {sub: "user-1"});
}

@test:Config {}
function identityNeedsASubject() {
    test:assertTrue(identityOf({iss: "issuer"}) is error);
    test:assertTrue(identityOf({sub: ""}) is error);
}

@test:Config {}
function detailsComeFromTheUserInfo() {
    CallerDetails details = detailsOf({
        "sub": "u",
        "email": " Ada@Example.test ",
        "given_name": " Ada ",
        "family_name": "Lovelace",
        "gender": "female",
        "phone_number": "+94771234567"
    });
    test:assertEquals(details.email, "ada@example.test");
    test:assertEquals(details.firstName, "Ada");
    test:assertEquals(details.lastName, "Lovelace");
    test:assertEquals(details.gender, "female");
    test:assertEquals(details.contactNo, "+94771234567");
}

@test:Config {}
function userInfoMustBelongToTheCaller() {
    test:assertTrue(isUserInfoOf({"sub": "user-1", "email": "ada@example.test"}, "user-1"));
    test:assertFalse(isUserInfoOf({"sub": "user-2", "email": "ada@example.test"}, "user-1"));
    test:assertFalse(isUserInfoOf({"email": "ada@example.test"}, "user-1"));
    test:assertFalse(isUserInfoOf({"sub": 1}, "1"));
    test:assertFalse(isUserInfoOf("not an object", "user-1"));
}

@test:Config {}
function aRefusedAccessTokenIsToldApartFromOtherFailures() {
    error refused = error UserInfoRefused("refused");
    error other = error("unreadable reply");
    test:assertTrue(refused is UserInfoRefused);
    test:assertFalse(other is UserInfoRefused);
}

@test:Config {}
function missingUserInfoValuesAreEmptyText() {
    CallerDetails unknown = {};
    test:assertEquals(detailsOf({"sub": "u", "email": "  "}), unknown);
    test:assertEquals(detailsOf({"sub": "u", "given_name": 5}), unknown);
    test:assertEquals(detailsOf("not an object"), unknown);
}

