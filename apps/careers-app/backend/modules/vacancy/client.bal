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

import wso2/careers_app.types;

import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/url;

configurable AtsConfig atsConfig = ?;

// Identifies this service in the upstream's logs.
const USER_AGENT = "careers-app-backend/0.1.0";

// The longest a read, or a token request, waits for the upstream to reply.
const decimal UPSTREAM_TIMEOUT_SECONDS = 15;

final http:Client atsHttpClient = check new (atsConfig.baseUrl, {
    timeout: UPSTREAM_TIMEOUT_SECONDS
});

final http:Client tokenHttpClient = check new (atsConfig.tokenUrl, {
    auth: {
        username: atsConfig.clientId,
        password: atsConfig.clientSecret
    },
    timeout: UPSTREAM_TIMEOUT_SECONDS
});

isolated function currentEpoch() returns int {
    [int, decimal] [seconds, _] = time:utcNow();
    return seconds;
}


isolated class TokenCache {
    private string cachedToken = "";
    private int expiryEpoch = 0;

    isolated function get() returns string? {
        lock {
            if self.cachedToken != "" && currentEpoch() < self.expiryEpoch {
                return self.cachedToken;
            }
        }
        return ();
    }

    isolated function put(string token, int expiresInSeconds) {
        lock {
            self.cachedToken = token;
            self.expiryEpoch = currentEpoch() + (expiresInSeconds - 60);
        }
    }

    # Forgets the rejected token
    isolated function clear(string rejectedToken) {
        lock {
            if self.cachedToken == rejectedToken {
                self.cachedToken = "";
                self.expiryEpoch = 0;
            }
        }
    }
}

final TokenCache tokenCache = new;

isolated function getAtsToken() returns string|error {
    string? cached = tokenCache.get();
    if cached is string {
        return cached;
    }

    http:Request req = new;
    req.setTextPayload("grant_type=client_credentials");
    req.setHeader("Content-Type", "application/x-www-form-urlencoded");

    TokenResponse tokenResponse = check tokenHttpClient->post("", req);
    tokenCache.put(tokenResponse.access_token, tokenResponse.expires_in);
    return tokenResponse.access_token;
}

isolated function authHeaders(string token, string requestId) returns map<string> => {
    "Authorization": "Bearer " + token,
    "User-Agent": USER_AGENT,
    [types:REQUEST_ID_HEADER]: requestId
};

# Sends a request with the ATS token, and once more with a fresh token if the ATS rejects the first with a 401.
isolated function withToken(isolated function (string token) returns http:Response|error send)
        returns http:Response|error {
    string token = check getAtsToken();
    http:Response resp = check send(token);
    if resp.statusCode != http:STATUS_UNAUTHORIZED {
        return resp;
    }
    tokenCache.clear(token);
    string freshToken = check getAtsToken();
    return send(freshToken);
}

# GET from the ATS with automatic token refresh on 401.
isolated function getWithToken(string path, string requestId) returns http:Response|error =>
    withToken(isolated function(string token) returns http:Response|error {
        return atsHttpClient->get(path, authHeaders(token, requestId));
    });

# PATCH to the ATS with automatic token refresh on 401.
isolated function patchWithToken(string path, AtsCandidateUpdate payload, string requestId)
        returns http:Response|error {
    final readonly & AtsCandidateUpdate body = payload.cloneReadOnly();
    return withToken(isolated function(string token) returns http:Response|error {
        return atsHttpClient->patch(path, body, authHeaders(token, requestId));
    });
}

# POST to the ATS with automatic token refresh on 401.
isolated function postWithToken(string path, json payload, string requestId) returns http:Response|error {
    final readonly & json body = payload.cloneReadOnly();
    return withToken(isolated function(string token) returns http:Response|error {
        return atsHttpClient->post(path, body, authHeaders(token, requestId));
    });
}

// The JSON of a 200 reply; any other status becomes an UpstreamError.
isolated function atsJson(string path, string requestId) returns json|error {
    http:Response resp = check getWithToken(path, requestId);
    if resp.statusCode != http:STATUS_OK {
        log:printWarn("The ATS did not return 200", path = types:withoutEmails(path), status = resp.statusCode,
            requestId = requestId);
        return error UpstreamError(string `The ATS replied with status ${resp.statusCode}`, status = resp.statusCode);
    }
    json|error body = resp.getJsonPayload();
    return body is json ? body : error("The ATS reply could not be read");
}

// The reply for a failed load.
isolated function failedReply(error err, string requestId) returns http:Response|error {
    if err is http:ClientError {
        return err;
    }
    http:Response resp = new;
    if err is UpstreamError {
        resp.statusCode = err.detail().status;
    } else {
        log:printError("Could not build a vacancy reply from the ATS data",
            errorMessage = types:withoutPersonalData(err.message()), requestId = requestId);
        resp.statusCode = http:STATUS_BAD_GATEWAY;
    }
    resp.setTextPayload(err.message());
    return resp;
}

// A 200 reply carrying the JSON.
isolated function okReply(json body) returns http:Response {
    http:Response resp = new;
    resp.statusCode = http:STATUS_OK;
    resp.setJsonPayload(body);
    return resp;
}

isolated function candidateHistory(string email, string requestId) returns AtsHistoryEntry[]|error {
    string path = "/candidates/" + check url:encode(email, "UTF-8") + "/histories?limit=" + MAX_HISTORY_ENTRIES.toString();
    json|error body = atsJson(path, requestId);
    if body is UpstreamError && body.detail().status == http:STATUS_NOT_FOUND {
        return [];
    }
    if body is error {
        return body;
    }
    AtsHistoryResponse history = check body.fromJsonWithType();
    return history.candidates;
}

isolated function profileFor(string email, string requestId) returns CandidateProfile|error {
    AtsHistoryEntry[] history = check candidateHistory(email, requestId);
    CandidateProfile? profile = profileOf(history, email);
    if profile is () {
        return error UpstreamError(NO_APPLICATIONS_MESSAGE, status = http:STATUS_NOT_FOUND);
    }
    return profile;
}

// The caller's own application with that id, found in their history; nothing when it is not theirs.
isolated function ownApplication(AtsHistoryEntry[] history, int id) returns AtsHistoryEntry? {
    foreach AtsHistoryEntry entry in history {
        if entry.id == id {
            return entry;
        }
    }
    return ();
}

# The candidate's full name, first and last name as saved in their profile, when the application is one of their own
# and its offer is accepted; nothing otherwise. One read of the history answers both.
public isolated function acceptedApplicantName(string email, string applicationId, string requestId)
        returns string?|error {
    int|error id = int:fromString(applicationId);
    if id is error {
        return ();
    }
    AtsHistoryEntry[] history = check candidateHistory(email, requestId);
    AtsHistoryEntry? entry = ownApplication(history, id);
    CandidateProfile? profile = profileOf(history, email);
    if entry is () || entry.offerStatus != OFFER_STATUS_ACCEPTED || profile is () {
        return ();
    }
    return string:'join(" ", profile.firstName, profile.lastName).trim();
}

isolated function profileReplyOf(CandidateProfile|error profile, string requestId) returns http:Response|error =>
    profile is error ? failedReply(profile, requestId) : okReply(profile.toJson());

# The candidate's details from their most recent application; a 404 reply when they have not applied.
public isolated function getProfile(string email, string requestId) returns http:Response|error =>
    profileReplyOf(profileFor(email, requestId), requestId);

# The candidate's applications, newest first.
public isolated function listApplications(string email, string requestId) returns ApplicationSummary[]|error {
    AtsHistoryEntry[] history = check candidateHistory(email, requestId);
    return applicationsOf(history);
}

// The interviews of one of the caller's own applications, found through their email.
isolated function interviewsFor(string email, string applicationId, string requestId)
        returns ApplicationInterview[]|error {
    int|error id = int:fromString(applicationId);
    if id is error {
        return error UpstreamError("Application not found", status = http:STATUS_NOT_FOUND);
    }
    AtsHistoryEntry? entry = ownApplication(check candidateHistory(email, requestId), id);
    if entry is () || entry.status == CANDIDATE_STATUS_DELETED {
        return error UpstreamError("Application not found", status = http:STATUS_NOT_FOUND);
    }
    json body = check atsJson(string `/interviews?status=SCHEDULED&status=COMPLETED&status=WITHDRAWN&candidateVacancyId=${entry.id}&limit=${MAX_INTERVIEWS}`,
        requestId);
    AtsInterviewResponse reply = check body.fromJsonWithType();
    return interviewsOf(reply.interviews);
}

# The interviews of one of the caller's own applications; a 404 reply when it is not theirs.
public isolated function getInterviews(string email, string applicationId, string requestId)
        returns http:Response|error {
    ApplicationInterview[]|error interviews = interviewsFor(email, applicationId, requestId);
    return interviews is error ? failedReply(interviews, requestId) : okReply(interviews.toJson());
}

# Whether the application is one of the caller's own, found through their email, and the ATS shows its offer as
# accepted. An application that is not the caller's gives false, the same as one that is not accepted.
public isolated function isOfferAccepted(string email, string applicationId, string requestId) returns boolean|error {
    int|error id = int:fromString(applicationId);
    if id is error {
        return false;
    }
    AtsHistoryEntry? entry = ownApplication(check candidateHistory(email, requestId), id);
    return entry is AtsHistoryEntry && entry.offerStatus == OFFER_STATUS_ACCEPTED;
}

# Checks the answer and passes it to the ATS with the caller's email, which the ATS compares with the application's own
# and refuses with a 404 when they differ. The ATS reply is returned as it is, so its refusals can be told to the
# candidate.
public isolated function answerOffer(string email, string applicationId, OfferDecision answer,
        string[] requestedDocuments, string requestId) returns http:Response|error {
    string? problem = offerDecisionProblem(answer);
    if problem is string {
        return failedReply(error UpstreamError(problem, status = http:STATUS_BAD_REQUEST), requestId);
    }
    int|error id = int:fromString(applicationId);
    if id is error {
        return failedReply(error UpstreamError("Application not found", status = http:STATUS_NOT_FOUND), requestId);
    }
    // The ATS compares the email with the application's own, and answers 404 when they differ, so the application does
    // not need to be found here first.
    boolean declined = answer.decision == OFFER_STATUS_DECLINED;
    json body = {
        candidateEmail: email,
        decision: answer.decision,
        declineReason: declined ? (answer.declineReason ?: "").trim() : (),
        declineReasonAdditional: declined ? (answer.declineReasonAdditional ?: "").trim() : (),
        requestedDocuments
    };
    return postWithToken(string `/candidates/${id}/offer/decision`, body, requestId);
}

isolated function saveProfile(string email, ProfileChanges changes, string requestId) returns CandidateProfile|error {
    AtsCandidateUpdate|string update = atsUpdateOf(changes);
    if update is string {
        return error UpstreamError(update, status = http:STATUS_BAD_REQUEST);
    }
    AtsHistoryEntry[] history = check candidateHistory(email, requestId);
    AtsHistoryEntry? latest = latestEntry(history);
    if latest is () || latest.candidateId < 1 {
        return error UpstreamError(PROFILE_NOT_EDITABLE_MESSAGE, status = http:STATUS_NOT_FOUND);
    }
    if update.length() > 0 {
        string path = string `/candidates/${latest.candidateId}/vacancies/${latest.id}`;
        http:Response resp = check patchWithToken(path, update, requestId);
        if resp.statusCode == http:STATUS_BAD_REQUEST {
            return error UpstreamError("The details were not accepted. Please check them and try again.",
                status = http:STATUS_BAD_REQUEST);
        }
        if resp.statusCode < http:STATUS_OK || resp.statusCode >= http:STATUS_MULTIPLE_CHOICES {
            return error UpstreamError(string `The ATS replied with status ${resp.statusCode}`, status = resp.statusCode);
        }
    }
    return profileFor(email, requestId);
}

# Saves the changes to the candidate's details, found through their own email, and returns their profile.
public isolated function updateProfile(string email, ProfileChanges changes, string requestId)
        returns http:Response|error => profileReplyOf(saveProfile(email, changes, requestId), requestId);
