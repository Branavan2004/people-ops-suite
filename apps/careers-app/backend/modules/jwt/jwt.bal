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

import ballerina/cache;
import ballerina/http;
import ballerina/jwt;
import ballerina/log;

configurable AuthConfig authConfig = ?;

# Validates the token's signature, issuer, audience and expiry, and returns the caller's identity.
public isolated function validateToken(string token) returns AsgardeoJwt|error {
    // Reject a malformed token before attempting signature validation.
    [jwt:Header, jwt:Payload] _ = check jwt:decode(token);

    jwt:ValidatorConfig config = {
        issuer: authConfig.issuer,
        audience: authConfig.audience,
        signatureConfig: {
            jwksConfig: {
                url: authConfig.jwksUrl
            }
        }
    };
    jwt:Payload payload = check jwt:validate(token, config);
    if payload?.exp is () {
        return error("Invalid token: missing exp");
    }
    return identityOf(payload);
}

isolated function identityOf(jwt:Payload payload) returns AsgardeoJwt|error {
    string? sub = payload?.sub;
    if sub is () || sub == "" {
        return error("Invalid token: missing sub");
    }
    return {sub};
}

isolated function isUserInfoOf(json userInfo, string sub) returns boolean =>
    userInfo is map<json> && userInfo["sub"] == sub;

isolated function textOf(json value) returns string => value is string ? value.trim() : "";

isolated function detailsOf(json userInfo) returns CallerDetails {
    if userInfo !is map<json> {
        return {};
    }
    return {
        email: textOf(userInfo["email"]).toLowerAscii(),
        firstName: textOf(userInfo["given_name"]),
        lastName: textOf(userInfo["family_name"]),
        gender: textOf(userInfo["gender"]),
        contactNo: textOf(userInfo["phone_number"])
    };
}

final http:Client userInfoClient = check new (authConfig.userInfoUrl, {timeout: 15});

// Callers' details by subject.
final cache:Cache detailsCache = new ({capacity: 1000, defaultMaxAge: 300, cleanupInterval: 600});

# The caller's details from the identity provider, with the email in lower case.
public isolated function callerDetails(AsgardeoJwt user, string accessToken) returns CallerDetails|error {
    any|cache:Error cached = detailsCache.get(user.sub);
    if cached is CallerDetails {
        return cached;
    }
    http:Response resp = check userInfoClient->get("", {"Authorization": "Bearer " + accessToken});
    if resp.statusCode == http:STATUS_UNAUTHORIZED || resp.statusCode == http:STATUS_FORBIDDEN {
        return error UserInfoRefused("The identity provider refused the access token");
    }
    if resp.statusCode != http:STATUS_OK {
        return error(string `The identity provider replied with status ${resp.statusCode}`);
    }
    json|error userInfo = resp.getJsonPayload();
    if userInfo is error {
        return error("The user-info reply could not be read");
    }
    if !isUserInfoOf(userInfo, user.sub) {
        return error("The user-info reply does not belong to the caller");
    }
    CallerDetails details = detailsOf(userInfo);
    cache:Error? stored = detailsCache.put(user.sub, details.cloneReadOnly());
    if stored is cache:Error {
        log:printWarn("Could not keep the caller's details in the cache", stored);
    }
    return details;
}

# The access token of the validated caller.
public isolated function getAccessToken(http:RequestContext ctx) returns string|error {
    return ctx.getWithType(CTX_TOKEN);
}

# The validated caller, read back from the request context.
public isolated function getUser(http:RequestContext ctx) returns AsgardeoJwt|error {
    return ctx.getWithType(CTX_USER);
}