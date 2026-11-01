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
import ballerina/mime;
import ballerina/test;

final http:Client testClient = check new (string `http://localhost:${port}`);

// A client that always declares the length of its body, as a browser does. The public apply route refuses a body that
// does not.
final http:Client sizedClient = check new (string `http://localhost:${port}`,
    http1Settings = {chunking: http:CHUNKING_NEVER});

@test:Config {}
function aDeclaredBodySizeIsComparedWithTheLimit() {
    http:Request req = new;
    req.setHeader(http:CONTENT_LENGTH, "100");
    test:assertTrue(exceeds(req, 50));
    test:assertFalse(exceeds(req, 100));
    http:Request undeclared = new;
    test:assertFalse(exceeds(undeclared, 50));
}

@test:Config {}
function aRequestIsKnownToDeclareItsBodyLengthOrNot() {
    http:Request declared = new;
    declared.setHeader(http:CONTENT_LENGTH, "10");
    test:assertTrue(declaresLength(declared));
    test:assertFalse(declaresLength(new));
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
function routesNotListedAsPublicNeedAToken() returns error? {
    http:Response saved = check testClient->get("/jobs/saved");
    test:assertEquals(saved.statusCode, 401);
    http:Response traversal = check testClient->get("/jobs/..%2Forg-structure");
    test:assertEquals(traversal.statusCode, 401);
    http:Response applyToTraversal = check testClient->post("/jobs/..%2Forg-structure/apply", {});
    test:assertEquals(applyToTraversal.statusCode, 401);
}

@test:Config {}
function publicJobReadsReachTheServiceWithoutAToken() returns error? {
    // No ATS runs in the tests, so a request that passes the interceptor ends in a 504.
    http:Response list = check testClient->get("/jobs");
    test:assertEquals(list.statusCode, 504);
    http:Response detail = check testClient->get("/jobs/258");
    test:assertEquals(detail.statusCode, 504);
}

@test:Config {}
function applyWithoutMultipartFormIsBadRequest() returns error? {
    http:Request req = new;
    req.setTextPayload("firstName=A", "application/x-www-form-urlencoded");
    req.setHeader(http:CONTENT_LENGTH, "11");
    http:Response resp = check sizedClient->post("/jobs/258/apply", req);
    test:assertEquals(resp.statusCode, 400);
}

@test:Config {}
function applyWithAnInvalidFormShowsTheReason() returns error? {
    mime:Entity firstName = new;
    firstName.setContentDisposition(mime:getContentDispositionObject("form-data; name=\"firstName\""));
    firstName.setText("Ada");
    http:Request req = new;
    req.setBodyParts([firstName], "multipart/form-data");
    http:Response resp = check sizedClient->post("/jobs/258/apply", req);
    test:assertEquals(resp.statusCode, 400);
    json body = check resp.getJsonPayload();
    test:assertEquals(check body.message, "First name, last name, phone and address are required.");
}

function responseWithStatus(int statusCode) returns http:Response {
    http:Response resp = new;
    resp.statusCode = statusCode;
    return resp;
}

@test:Config {}
function upstreamJsonIsPassedThrough() {
    http:Response resp = responseWithStatus(200);
    resp.setJsonPayload({"id": 258});
    test:assertEquals(forwardOrError(resp, "failed", "test-request"), {"id": 258});
}

@test:Config {}
function unreachableUpstreamBecomesGatewayTimeout() {
    test:assertTrue(forwardOrError(error("connection refused"), "failed", "test-request") is http:GatewayTimeout);
}

@test:Config {}
function upstreamUnavailableOrTimedOutBecomesGatewayTimeout() {
    test:assertTrue(forwardOrError(responseWithStatus(503), "failed", "test-request") is http:GatewayTimeout);
    test:assertTrue(forwardOrError(responseWithStatus(504), "failed", "test-request") is http:GatewayTimeout);
}

@test:Config {}
function otherUpstreamFailuresBecomeBadGateway() {
    test:assertTrue(forwardOrError(responseWithStatus(500), "failed", "test-request") is http:BadGateway);
    test:assertTrue(forwardOrError(responseWithStatus(401), "failed", "test-request") is http:BadGateway);
}

@test:Config {}
function nonJsonUpstreamBodyBecomesBadGateway() {
    http:Response resp = responseWithStatus(200);
    resp.setTextPayload("not json", "text/plain");
    test:assertTrue(forwardOrError(resp, "failed", "test-request") is http:BadGateway);
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
