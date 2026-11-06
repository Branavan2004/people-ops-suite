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

import wso2/careers_app.jwt;

import ballerina/http;
import ballerina/test;

final http:Client testClient = check new ("http://localhost:9090");

@test:Config {}
function aDeclaredBodySizeIsComparedWithTheLimit() {
    http:Request req = new;
    req.setHeader(http:CONTENT_LENGTH, "100");
    test:assertTrue(exceeds(req, 50));
    test:assertFalse(exceeds(req, 100));
    http:Request undeclared = new;
    test:assertFalse(exceeds(undeclared, 50));
}

// "/profile" stands in for any restricted route.
@test:Config {}
function restrictedRouteWithoutTokenIsUnauthorized() returns error? {
    http:Response resp = check testClient->get("/profile");
    test:assertEquals(resp.statusCode, 401);
}

@test:Config {}
function restrictedRouteWithGarbageTokenIsUnauthorized() returns error? {
    http:Response resp = check testClient->get("/profile", {"Authorization": "Bearer not-a-jwt"});
    test:assertEquals(resp.statusCode, 401);
}

@test:Config {}
function theRemovedJobRoutesNeedAToken() returns error? {
    http:Response list = check testClient->get("/jobs");
    test:assertEquals(list.statusCode, 401);
    http:Response detail = check testClient->get("/jobs/258");
    test:assertEquals(detail.statusCode, 401);
    http:Response apply = check testClient->post("/jobs/258/apply", {});
    test:assertEquals(apply.statusCode, 401);
}

@test:Config {}
function candidateRoutesWithoutATokenAreUnauthorized() returns error? {
    http:Response profile = check testClient->get("/candidates/me");
    test:assertEquals(profile.statusCode, 401);
    http:Response applications = check testClient->get("/applications");
    test:assertEquals(applications.statusCode, 401);
    http:Response save = check testClient->patch("/candidates/me", {"firstName": "Ada"});
    test:assertEquals(save.statusCode, 401);
}

@test:Config {}
function candidateRoutesWithAGarbageTokenAreUnauthorized() returns error? {
    map<string> headers = {"Authorization": "Bearer not-a-jwt"};
    http:Response profile = check testClient->get("/candidates/me", headers);
    test:assertEquals(profile.statusCode, 401);
    http:Response applications = check testClient->get("/applications", headers);
    test:assertEquals(applications.statusCode, 401);
    http:Response save = check testClient->patch("/candidates/me", {"firstName": "Ada"}, headers);
    test:assertEquals(save.statusCode, 401);
}

@test:Config {}
function candidateRoutesWithAMalformedAuthorizationHeaderAreUnauthorized() returns error? {
    http:Response basic = check testClient->get("/candidates/me", {"Authorization": "Basic abc"});
    test:assertEquals(basic.statusCode, 401);
    http:Response bare = check testClient->get("/applications", {"Authorization": "not-a-bearer-header"});
    test:assertEquals(bare.statusCode, 401);
}

@test:Config {}
function aCallerWhoHasNotAppliedGetsTheirProfileFromTheIdentityProvider() {
    jwt:CallerDetails caller = {
        email: "ada@example.test",
        firstName: "Ada",
        lastName: "Lovelace",
        gender: "female",
        contactNo: "+94771234567"
    };
    test:assertEquals(profileFrom(caller), {
        firstName: "Ada",
        lastName: "Lovelace",
        gender: "Female",
        personalEmail: "ada@example.test",
        contactNo: "+94771234567",
        address: (),
        university: (),
        editable: false
    });
}

@test:Config {}
function genderFromTheIdentityProviderIsMappedToTheAtsValues() {
    test:assertEquals(genderOf("MALE"), "Male");
    test:assertEquals(genderOf("female"), "Female");
    test:assertEquals(genderOf("other"), "");
    test:assertEquals(genderOf(""), "");
}

@test:Config {}
function unreachableCandidateLookupBecomesGatewayTimeout() {
    http:BadGateway|http:GatewayTimeout failure = candidateFailure(error http:GenericClientError("connection refused"),
        "failed", "test-request");
    test:assertTrue(failure is http:GatewayTimeout);
}

@test:Config {}
function otherCandidateLookupFailuresBecomeBadGateway() {
    http:BadGateway|http:GatewayTimeout failure = candidateFailure(error("unreadable reply"), "failed",
        "test-request");
    test:assertTrue(failure is http:BadGateway);
}
