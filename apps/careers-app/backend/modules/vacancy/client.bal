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

// Client for applications, which wait longer than reads.
final http:Client atsApplyHttpClient = check new (atsConfig.baseUrl, {
    timeout: 90
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

# POST to the ATS with automatic token refresh on 401.
isolated function postWithToken(string path, AtsCandidate payload, string requestId)
        returns http:Response|error {
    // A read-only copy, which the retry can send again.
    final readonly & AtsCandidate body = payload.cloneReadOnly();
    return withToken(isolated function(string token) returns http:Response|error {
        return atsApplyHttpClient->post(path, body, authHeaders(token, requestId));
    });
}

# PATCH to the ATS with automatic token refresh on 401.
isolated function patchWithToken(string path, AtsCandidateUpdate payload, string requestId)
        returns http:Response|error {
    final readonly & AtsCandidateUpdate body = payload.cloneReadOnly();
    return withToken(isolated function(string token) returns http:Response|error {
        return atsHttpClient->patch(path, body, authHeaders(token, requestId));
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

// The query for the vacancies listed on the public site, optionally of one designation and employment type.
isolated function vacancyQuery(int? designationId, string? employmentType) returns string|error {
    string query = "status=PUBLISHED";
    foreach string visibility in [VISIBILITY_ALL, VISIBILITY_EXTERNAL_ONLY] {
        query += "&visibility=" + check url:encode(visibility, "UTF-8");
    }
    if designationId is int {
        query += "&designationId=" + designationId.toString();
    }
    if employmentType is string {
        query += "&employmentType=" + check url:encode(employmentType, "UTF-8");
    }
    return query;
}

// The published vacancies listed on the public site, optionally of one designation and employment type.
isolated function publishedVacancies(string requestId, int? designationId = (), string? employmentType = ())
        returns AtsVacancy[]|error {
    string query = check vacancyQuery(designationId, employmentType);
    json body = check atsJson("/vacancies?" + query, requestId);
    return vacanciesOf(body, requestId);
}

// The vacancies in the ATS list reply; one that cannot be read is skipped, so it cannot hide the others.
isolated function vacanciesOf(json body, string requestId) returns AtsVacancy[]|error {
    json items = body is map<json> ? body["vacancies"] : ();
    if items !is json[] {
        return error("The ATS vacancy list could not be read");
    }
    // The ATS returns at most its default page (1000) when no limit is sent, and reports the full count beside it.
    json total = body is map<json> ? body["totalCount"] : ();
    if total is int && total > items.length() {
        log:printWarn("The ATS vacancy list is cut short; some published vacancies are not listed",
            listed = items.length(), total = total, requestId = requestId);
    }
    AtsVacancy[] vacancies = [];
    foreach json item in items {
        AtsVacancy|error vacancy = item.fromJsonWithType();
        if vacancy is error {
            json id = item is map<json> ? item["id"] : ();
            log:printWarn("Skipped a vacancy that could not be read", vacancyId = id is int ? id : 0,
                requestId = requestId);
            continue;
        }
        vacancies.push(vacancy);
    }
    return vacancies;
}

isolated function fetchVacancy(string jobId, string requestId) returns AtsVacancy|error {
    json body = check atsJson("/vacancies/" + jobId, requestId);
    return body.fromJsonWithType();
}

isolated function orgDetails(string requestId) returns AtsBusinessUnit[]|error {
    json body = check atsJson("/org-details", requestId);
    return body.fromJsonWithType();
}

isolated function companies(string requestId) returns AtsCompany[]|error {
    json body = check atsJson("/companies", requestId);
    return body.fromJsonWithType();
}

isolated function careerFunctions(string requestId) returns AtsCareerFunction[]|error {
    json body = check atsJson("/career-functions", requestId);
    return body.fromJsonWithType();
}

isolated function appConfig(string requestId) returns AtsAppConfig|error {
    json body = check atsJson("/app-config", requestId);
    return body.fromJsonWithType();
}

isolated function loadJobList(string requestId) returns VacancyBasicInfo[]|error {
    // The two reads run together.
    future<AtsVacancy[]|error> vacanciesRead = start publishedVacancies(requestId);
    future<AtsBusinessUnit[]|error> unitsRead = start orgDetails(requestId);
    AtsVacancy[]|error vacancies = wait vacanciesRead;
    AtsBusinessUnit[]|error units = wait unitsRead;
    if vacancies is error {
        return vacancies;
    }
    if units is error {
        return units;
    }
    return from AtsVacancy vacancy in vacancies
        select basicInfoOf(vacancy, units);
}

isolated function loadOrgStructure(string requestId) returns OrgStructure|error {
    future<AtsCompany[]|error> companiesRead = start companies(requestId);
    future<AtsBusinessUnit[]|error> unitsRead = start orgDetails(requestId);
    future<AtsAppConfig|error> configRead = start appConfig(requestId);
    AtsCompany[]|error allCompanies = wait companiesRead;
    AtsBusinessUnit[]|error units = wait unitsRead;
    AtsAppConfig|error config = wait configRead;
    if allCompanies is error {
        return allCompanies;
    }
    if units is error {
        return units;
    }
    if config is error {
        log:printError("Could not read the ATS app config", config, requestId = requestId);
    }
    return orgStructureOf(allCompanies, units, config is AtsAppConfig ? config : ());
}

// Whether the vacancy is published and visible to candidates.
isolated function isOpenToApply(AtsVacancy vacancy) returns boolean =>
    vacancy.status == STATUS_PUBLISHED && vacancy.visibility != VISIBILITY_INTERNAL_ONLY;

isolated function loadJobDetail(string jobId, string requestId) returns JobDetail|error {
    AtsVacancy vacancy = check fetchVacancy(jobId, requestId);
    if !isOpenToApply(vacancy) {
        return error UpstreamError("The vacancy is not published", status = http:STATUS_BAD_REQUEST);
    }
    do {
        // The reads below run together once the vacancy is known.
        future<AtsCompany[]|error> companiesRead = start companies(requestId);
        future<AtsBusinessUnit[]|error> unitsRead = start orgDetails(requestId);
        future<AtsCareerFunction[]|error> functionsRead = start careerFunctions(requestId);
        future<AtsVacancy[]> similarRead = start similarVacancies(vacancy.designationId, vacancy.employmentType,
            requestId);
        AtsCompany[] allCompanies = check wait companiesRead;
        AtsBusinessUnit[] units = check wait unitsRead;
        AtsCareerFunction[] functions = check wait functionsRead;
        AtsVacancy[]|error similarResult = wait similarRead;
        AtsVacancy[] similar = similarResult is AtsVacancy[] ? similarResult : [];
        return detailOf(vacancy, allCompanies, units, functions, similar);
    } on fail error err {
        return asLookupFailure(err);
    }
}

// A refused lookup that only supports the job page is a bad gateway, not a statement about the job itself.
isolated function asLookupFailure(error err) returns error =>
    err is UpstreamError ? error UpstreamError("A lookup for the job failed", status = http:STATUS_BAD_GATEWAY) : err;

// The other vacancies like this one; none when the lookup fails.
isolated function similarVacancies(int designationId, string employmentType, string requestId) returns AtsVacancy[] {
    AtsVacancy[]|error similar = publishedVacancies(requestId, designationId, employmentType);
    if similar is error {
        log:printWarn("Could not read the similar vacancies", similar, requestId = requestId);
        return [];
    }
    return similar;
}

isolated function candidateFor(string jobId, CandidateApplication candidate, string requestId)
        returns AtsCandidate|error {
    int|error vacancyId = int:fromString(jobId);
    if vacancyId is error {
        return error UpstreamError("Invalid vacancy id", status = http:STATUS_BAD_REQUEST);
    }
    // Only the vacancy is read.
    AtsVacancy vacancy = check fetchVacancy(jobId, requestId);
    if !isOpenToApply(vacancy) {
        return error UpstreamError("The vacancy is not available", status = http:STATUS_NOT_FOUND);
    }
    AtsCandidate|string atsCandidate = atsCandidateOf(candidate, vacancy.employmentType, vacancyId);
    if atsCandidate is string {
        return error UpstreamError(atsCandidate, status = http:STATUS_UNPROCESSABLE_ENTITY);
    }
    return atsCandidate;
}

# The published vacancies, in the shape the web app reads.
public isolated function listJobs(string requestId) returns http:Response|error {
    VacancyBasicInfo[]|error jobs = loadJobList(requestId);
    return jobs is error ? failedReply(jobs, requestId) : okReply(jobs.toJson());
}

# The teams and hiring locations.
public isolated function getOrgStructure(string requestId) returns http:Response|error {
    OrgStructure|error org = loadOrgStructure(requestId);
    return org is error ? failedReply(org, requestId) : okReply(org.toJson());
}

# One published vacancy, with its similar listings.
public isolated function getJob(string jobId, string requestId) returns http:Response|error {
    JobDetail|error detail = loadJobDetail(jobId, requestId);
    return detail is error ? failedReply(detail, requestId) : okReply(detail.toJson());
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

# The candidate's full name, first and last name as saved in their profile, when the application is one of their own
# and its offer is accepted; nothing otherwise. One read of the history answers both.
public isolated function acceptedApplicantName(string email, string applicationId, string requestId)
        returns string?|error {
    int|error id = int:fromString(applicationId);
    if id is error {
        return ();
    }
    AtsHistoryEntry[] history = check candidateHistory(email, requestId);
    foreach AtsHistoryEntry entry in history {
        if entry.id == id {
            CandidateProfile? profile = profileOf(history, email);
            if entry.status != CANDIDATE_STATUS_HIRED || profile is () {
                return ();
            }
            return string:'join(" ", profile.firstName, profile.lastName).trim();
        }
    }
    return ();
}

isolated function profileReplyOf(CandidateProfile|error profile, string requestId) returns http:Response|error =>
    profile is error ? failedReply(profile, requestId) : okReply(profile.toJson());

# The candidate's details from their most recent application; a 404 reply when they have not applied.
public isolated function getProfile(string email, string requestId) returns http:Response|error =>
    profileReplyOf(profileFor(email, requestId), requestId);

# The candidate's applications, newest first.
public isolated function listApplications(string email, string requestId) returns ApplicationSummary[]|error {
    AtsHistoryEntry[] history = check candidateHistory(email, requestId);
    return applicationsOf(history, departmentsOf(cachedJobsIfPresent()));
}

// The interviews of one of the caller's own applications, found through their email.
isolated function interviewsFor(string email, string applicationId, string requestId)
        returns ApplicationInterview[]|error {
    int|error id = int:fromString(applicationId);
    if id is error {
        return error UpstreamError("Application not found", status = http:STATUS_NOT_FOUND);
    }
    AtsHistoryEntry[] history = check candidateHistory(email, requestId);
    foreach AtsHistoryEntry entry in history {
        if entry.id == id && entry.status != CANDIDATE_STATUS_DELETED {
            json body = check atsJson(string `/interviews?status=SCHEDULED&status=COMPLETED&status=WITHDRAWN&candidateVacancyId=${entry.id}&limit=${MAX_INTERVIEWS}`,
                requestId);
            AtsInterviewResponse reply = check body.fromJsonWithType();
            return interviewsOf(reply.interviews);
        }
    }
    return error UpstreamError("Application not found", status = http:STATUS_NOT_FOUND);
}

# The interviews of one of the caller's own applications; a 404 reply when it is not theirs.
public isolated function getInterviews(string email, string applicationId, string requestId)
        returns http:Response|error {
    ApplicationInterview[]|error interviews = interviewsFor(email, applicationId, requestId);
    return interviews is error ? failedReply(interviews, requestId) : okReply(interviews.toJson());
}

// The offer letter of one of the caller's own applications, found through their email.
isolated function offerLetterFor(string email, string applicationId, string requestId) returns OfferLetter|error {
    int|error id = int:fromString(applicationId);
    if id is error {
        return error UpstreamError("Application not found", status = http:STATUS_NOT_FOUND);
    }
    AtsHistoryEntry[] history = check candidateHistory(email, requestId);
    foreach AtsHistoryEntry entry in history {
        if entry.id == id && entry.status != CANDIDATE_STATUS_DELETED {
            json body = check atsJson(string `/candidates/${entry.candidateId}/vacancies/${entry.id}/offer-letter`,
                requestId);
            AtsOfferLetter letter = check body.fromJsonWithType();
            if letter.htmlContent == "" {
                return error UpstreamError("No offer letter was found", status = http:STATUS_NOT_FOUND);
            }
            return {
                subject: letter.subject,
                sentOn: letter.sentOn,
                threadId: letter.threadId ?: "",
                html: letter.htmlContent
            };
        }
    }
    return error UpstreamError("Application not found", status = http:STATUS_NOT_FOUND);
}

# The offer letter sent for one of the caller's own applications; a 404 reply when it is not theirs or has none.
public isolated function getOfferLetter(string email, string applicationId, string requestId)
        returns http:Response|error {
    OfferLetter|error letter = offerLetterFor(email, applicationId, requestId);
    return letter is error ? failedReply(letter, requestId) : okReply(letter.toJson());
}

# Whether the application is one of the caller's own, found through their email, and the ATS shows its offer as
# accepted. An application that is not the caller's gives false, the same as one that is not accepted.
public isolated function isOfferAccepted(string email, string applicationId, string requestId) returns boolean|error {
    int|error id = int:fromString(applicationId);
    if id is error {
        return false;
    }
    AtsHistoryEntry[] history = check candidateHistory(email, requestId);
    foreach AtsHistoryEntry entry in history {
        if entry.id == id {
            return entry.status == CANDIDATE_STATUS_HIRED;
        }
    }
    return false;
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

# Creates the candidate in the ATS and returns its reply unchanged.
public isolated function applyForJob(string jobId, CandidateApplication candidate, string requestId)
        returns http:Response|error {
    AtsCandidate|error atsCandidate = candidateFor(jobId, candidate, requestId);
    if atsCandidate is error {
        return failedReply(atsCandidate, requestId);
    }
    http:Response resp = check postWithToken("/candidates", atsCandidate, requestId);
    return atsReply(resp);
}

// The ATS's reply, with a 422 turned into a 400, since only this service's own refusals use 422.
isolated function atsReply(http:Response resp) returns http:Response {
    if resp.statusCode == http:STATUS_UNPROCESSABLE_ENTITY {
        resp.statusCode = http:STATUS_BAD_REQUEST;
    }
    return resp;
}
