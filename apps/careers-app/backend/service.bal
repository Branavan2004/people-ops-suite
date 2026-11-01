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

import wso2/careers_app.apply;
import wso2/careers_app.documents;
import wso2/careers_app.jwt;
import wso2/careers_app.types;
import wso2/careers_app.vacancy;

import ballerina/http;
import ballerina/log;

configurable string[] allowedOrigins = ?;
configurable int port = ?;

# Longest piece of an upstream reply written to the log.
const MAX_LOGGED_REPLY_LENGTH = 200;

# Whether the request declares a body larger than the limit. The listener's own limit still applies to a request
# that does not declare its length.
isolated function exceeds(http:Request req, int maxBytes) returns boolean {
    string|http:HeaderNotFoundError declared = req.getHeader(http:CONTENT_LENGTH);
    if declared is string {
        int|error length = int:fromString(declared);
        return length is int && length > maxBytes;
    }
    return false;
}

# Whether the request declares the length of its body. The listener then reads only the declared bytes, which a body
# sent in chunks does not allow.
isolated function declaresLength(http:Request req) returns boolean => req.hasHeader(http:CONTENT_LENGTH);

# Passes an upstream JSON response, or maps its failure to a gateway error.
isolated function forwardOrError(http:Response|error resp, string failureMessage, string requestId)
        returns json|http:BadGateway|http:GatewayTimeout {
    if resp is error {
        log:printError(failureMessage, errorMessage = types:withoutPersonalData(resp.message()), requestId = requestId);
        return <http:GatewayTimeout>{body: {message: "Upstream service unreachable"}};
    }
    if resp.statusCode == 503 || resp.statusCode == 504 {
        log:printError(string `${failureMessage}: status ${resp.statusCode}`, requestId = requestId);
        return <http:GatewayTimeout>{body: {message: "Upstream service unreachable"}};
    }
    if resp.statusCode != 200 {
        log:printError(string `${failureMessage}: status ${resp.statusCode}`, requestId = requestId);
        return <http:BadGateway>{body: {message: failureMessage}};
    }
    json|error respBody = resp.getJsonPayload();
    if respBody is error {
        log:printError(failureMessage + " (non-JSON body)", errorMessage = types:withoutPersonalData(respBody.message()),
            requestId = requestId);
        return <http:BadGateway>{body: {message: failureMessage}};
    }
    return respBody;
}

@http:ServiceConfig {
    cors: {
        allowOrigins: allowedOrigins,
        allowMethods: [http:GET, http:POST, http:PUT, http:OPTIONS, http:PATCH],
        allowHeaders: [http:CONTENT_TYPE, http:AUTH_HEADER, types:REQUEST_ID_HEADER],
        allowCredentials: false,
        maxAge: 84900
    }
}
service http:InterceptableService / on new http:Listener(port, requestLimits = {maxEntityBodySize: documents:MAX_REQUEST_BYTES}) {

    function init() {
        log:printInfo("Careers App backend started...");
        _ = start vacancy:warmUp();
    }

    public function createInterceptors() returns http:Interceptor[] =>
        [new types:RequestIdInterceptor(), new jwt:JwtInterceptor(), new jwt:NoStoreInterceptor()];

    # The published job list. Public: no sign-in needed.
    resource function get jobs(http:RequestContext ctx) returns json|http:BadGateway|http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        json|http:Response|error result = vacancy:cachedJobs(requestId);
        if result is json {
            return result;
        }
        return forwardOrError(result, "Failed to fetch jobs from upstream service", requestId);
    }

    # The team and location org structure. Public: no sign-in needed.
    resource function get jobs/org\-structure(http:RequestContext ctx)
            returns json|http:BadGateway|http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        json|http:Response|error result = vacancy:cachedOrgStructure(requestId);
        if result is json {
            return result;
        }
        return forwardOrError(result, "Failed to fetch org structure from upstream service", requestId);
    }

    # One published job's detail, 404 if it doesn't exist. Public: no sign-in needed.
    resource function get jobs/[string jobId](http:RequestContext ctx)
            returns json|http:BadRequest|http:NotFound|http:BadGateway|http:GatewayTimeout {
        if !types:isValidJobId(jobId) {
            return <http:BadRequest>{body: {message: "Invalid job id"}};
        }
        string requestId = types:requestIdOf(ctx);
        json|http:Response|error result = vacancy:cachedJob(jobId, requestId);
        if result is json {
            return result;
        }
        if result is error {
            log:printError("Failed to fetch job from upstream service", result, requestId = requestId);
            return <http:GatewayTimeout>{body: {message: "Upstream service unreachable"}};
        }
        // A vacancy that is not published is answered with 400, which is also "not found" here.
        if result.statusCode == 404 || result.statusCode == 400 {
            return <http:NotFound>{body: {message: "Job not found"}};
        }
        return forwardOrError(result, "Failed to fetch job from upstream service", requestId);
    }

    # Validates the application form and CV, then creates the candidate in the ATS.
    # Public: no sign-in needed.
    resource function post jobs/[string jobId]/apply(http:Request req, http:RequestContext ctx)
            returns http:Created|http:BadRequest|http:LengthRequired|http:NotFound|http:Conflict|http:BadGateway
                |http:GatewayTimeout {
        if !types:isValidJobId(jobId) {
            return <http:BadRequest>{body: {message: "Invalid job id"}};
        }
        string requestId = types:requestIdOf(ctx);
        // The listener's size limit is the larger one the documents need, so this public route bounds its own body.
        if !declaresLength(req) {
            return <http:LengthRequired>{body: {message: "The request must declare the length of its body."}};
        }
        if exceeds(req, apply:MAX_REQUEST_BYTES) {
            return <http:BadRequest>{body: {message: "The application is too large."}};
        }
        apply:ApplicationForm|string form = apply:parseApplicationForm(req);
        if form is string {
            return <http:BadRequest>{body: {message: form}};
        }

        vacancy:CandidateApplication candidate = {
            firstName: form.firstName,
            lastName: form.lastName,
            personalEmail: form.email.toLowerAscii(),
            contactNo: form.phone,
            address: form.address,
            resume: form.cv
        };
        string? university = form?.university;
        if university is string {
            candidate.university = university;
        }
        http:Response|error resp = vacancy:applyForJob(jobId, candidate, requestId);
        if resp is error {
            log:printError("Failed to reach the ATS for an application",
                errorMessage = types:withoutPersonalData(resp.message()), requestId = requestId);
            return <http:GatewayTimeout>{body: {message: "Upstream service unreachable"}};
        }
        if resp.statusCode == http:STATUS_UNPROCESSABLE_ENTITY {
            string|error reason = resp.getTextPayload();
            return <http:BadRequest>{body: {message: reason is string ? reason : "The application was not accepted."}};
        }
        if resp.statusCode < 200 || resp.statusCode >= 300 {
            // Log the upstream status and a short piece of its reply, never the applicant's details.
            string|error reply = resp.getTextPayload();
            string redacted = reply is string ? types:withoutPersonalData(reply) : "";
            string replySnippet = redacted.length() > MAX_LOGGED_REPLY_LENGTH
                ? redacted.substring(0, MAX_LOGGED_REPLY_LENGTH) : redacted;
            log:printError(string `The ATS did not accept an application for vacancy ${jobId}: status ${resp.statusCode}`,
                reply = replySnippet, requestId = requestId);
            return apply:applyFailure(resp.statusCode);
        }
        log:printInfo(string `Application submitted for vacancy ${jobId}`, requestId = requestId);
        return <http:Created>{body: {message: "Application submitted"}};
    }

    # The signed-in candidate's details, taken from their most recent application.
    resource function get candidates/me(http:RequestContext ctx)
            returns json|http:Unauthorized|http:Forbidden|http:BadRequest|http:NotFound|http:BadGateway
                |http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        jwt:CallerDetails|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout caller =
            callerOf(ctx, requestId);
        if caller !is jwt:CallerDetails {
            return caller;
        }
        http:Response|error resp = vacancy:getProfile(caller.email, requestId);
        if resp is http:Response && resp.statusCode == http:STATUS_NOT_FOUND {
            return profileFrom(caller);
        }
        return profileReply(resp, "Failed to fetch the candidate profile", requestId);
    }

    # Saves changes to the signed-in candidate's details and returns their profile.
    resource function patch candidates/me(http:RequestContext ctx, vacancy:ProfileChanges changes)
            returns json|http:Unauthorized|http:BadRequest|http:Forbidden|http:NotFound|http:BadGateway
                |http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        jwt:CallerDetails|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout caller =
            callerOf(ctx, requestId);
        if caller !is jwt:CallerDetails {
            return caller;
        }
        return profileReply(vacancy:updateProfile(caller.email, changes, requestId), "Failed to save the candidate profile",
            requestId);
    }

    # The signed-in candidate's applications, newest first.
    resource function get applications(http:RequestContext ctx)
            returns vacancy:ApplicationSummary[]|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        jwt:CallerDetails|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout caller =
            callerOf(ctx, requestId);
        if caller !is jwt:CallerDetails {
            return caller;
        }
        vacancy:ApplicationSummary[]|error applications = vacancy:listApplications(caller.email, requestId);
        if applications is error {
            return candidateFailure(applications, "Failed to fetch the candidate's applications", requestId);
        }
        return applications;
    }

    # The offer letter sent for one of the signed-in candidate's own applications, 404 when there is none.
    resource function get applications/[string applicationId]/offer\-letter(http:RequestContext ctx)
            returns json|http:Unauthorized|http:Forbidden|http:BadRequest|http:NotFound|http:BadGateway
                |http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        if !types:isValidJobId(applicationId) {
            return <http:NotFound>{body: {message: "Application not found"}};
        }
        jwt:CallerDetails|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout caller =
            callerOf(ctx, requestId);
        if caller !is jwt:CallerDetails {
            return caller;
        }
        return profileReply(vacancy:getOfferLetter(caller.email, applicationId, requestId),
            "Failed to fetch the offer letter", requestId);
    }

    # The interviews of one of the signed-in candidate's own applications, in the order they take place.
    resource function get applications/[string applicationId]/interviews(http:RequestContext ctx)
            returns json|http:Unauthorized|http:Forbidden|http:BadRequest|http:NotFound|http:BadGateway
                |http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        if !types:isValidJobId(applicationId) {
            return <http:NotFound>{body: {message: "Application not found"}};
        }
        jwt:CallerDetails|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout caller =
            callerOf(ctx, requestId);
        if caller !is jwt:CallerDetails {
            return caller;
        }
        return profileReply(vacancy:getInterviews(caller.email, applicationId, requestId),
            "Failed to fetch the interviews", requestId);
    }

    # Whether the signed-in candidate has submitted the documents for one of their own accepted offers, whether they
    # can still change them and until when, and, when they have submitted, what they saved.
    resource function get applications/[string applicationId]/documents(http:RequestContext ctx)
            returns json|http:Unauthorized|http:Forbidden|http:NotFound|http:BadGateway|http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        if !types:isValidJobId(applicationId) {
            return <http:NotFound>{body: {message: "Application not found"}};
        }
        jwt:CallerDetails|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout caller =
            callerOf(ctx, requestId);
        if caller !is jwt:CallerDetails {
            return caller;
        }
        // The submission is read while the ATS is asked about the application, and is used only once the application
        // is known to be an accepted offer of the caller's own.
        future<documents:SubmissionStatus|error> read = start documents:submissionStatus(applicationId);
        boolean|error accepted = vacancy:isOfferAccepted(caller.email, applicationId, requestId);
        if accepted is error {
            return candidateFailure(accepted, "Failed to check the application", requestId);
        }
        if !accepted {
            return <http:NotFound>{body: {message: "Application not found"}};
        }
        documents:SubmissionStatus|error status = wait read;
        if status is error {
            return candidateFailure(status, "Failed to check the submission", requestId);
        }
        return status.toJson();
    }

    # The documents asked for after an offer is accepted, and the limits each file must meet.
    resource function get documents/requirements() returns json => {
        documents: documents:REQUIRED_DOCUMENTS.toJson(),
        maxFiles: documents:MAX_FILES,
        maxFileBytes: documents:MAX_FILE_BYTES,
        maxTotalBytes: documents:MAX_TOTAL_BYTES,
        tshirtSizes: documents:TSHIRT_SIZES,
        titles: documents:TITLES,
        genders: documents:GENDERS,
        civilStatuses: documents:CIVIL_STATUSES,
        dependantRelationships: documents:DEPENDANT_RELATIONSHIPS,
        maxDependants: documents:MAX_DEPENDANTS,
        maxEmergencyContacts: documents:MAX_EMERGENCY_CONTACTS
    };

    # Stores the signed-in candidate's onboarding documents for one of their own applications whose offer is accepted.
    resource function post applications/[string applicationId]/documents(http:Request req, http:RequestContext ctx)
            returns http:Created|http:BadRequest|http:Unauthorized|http:Forbidden|http:NotFound|http:Conflict
                |http:BadGateway|http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        if !types:isValidJobId(applicationId) {
            return <http:NotFound>{body: {message: "Application not found"}};
        }
        jwt:AsgardeoJwt|error user = jwt:getUser(ctx);
        if user is error {
            return <http:Forbidden>{body: {message: "The caller could not be identified"}};
        }
        jwt:CallerDetails|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout caller =
            callerOf(ctx, requestId);
        if caller !is jwt:CallerDetails {
            return caller;
        }

        // The application is looked up through the caller's own email, so an id from the client is never trusted.
        string?|error candidateName = vacancy:acceptedApplicantName(caller.email, applicationId, requestId);
        if candidateName is error {
            return candidateFailure(candidateName, "Failed to check the application", requestId);
        }
        if candidateName is () {
            log:printWarn("Documents refused: not an accepted offer of the caller", outcome = "refused",
                applicationId = applicationId, subject = user.sub, requestId = requestId);
            return <http:NotFound>{body: {message: "Application not found"}};
        }

        if exceeds(req, documents:MAX_REQUEST_BYTES) {
            return <http:BadRequest>{body: {message: "The documents are too large."}};
        }
        documents:Submission|string parsed = documents:parseDocuments(req);
        if parsed is string {
            log:printWarn("Documents refused: the files were not valid", outcome = "invalid",
                applicationId = applicationId, subject = user.sub, requestId = requestId);
            return <http:BadRequest>{body: {message: parsed}};
        }

        documents:SubmitOutcome|error stored = documents:storeDocuments(applicationId, parsed, candidateName, requestId);
        if stored is error {
            return candidateFailure(stored, "Failed to store the documents", requestId);
        }
        if stored == documents:IN_PROGRESS {
            log:printWarn("Documents refused: another submission is in progress", outcome = "in-progress",
                applicationId = applicationId, subject = user.sub, requestId = requestId);
            return <http:Conflict>{
                body: {message: "Your documents are already being submitted. Please wait a moment and check the application."}
            };
        }
        if stored == documents:ALREADY_SUBMITTED {
            log:printWarn("Documents refused: already submitted", outcome = "duplicate",
                applicationId = applicationId, subject = user.sub, requestId = requestId);
            return <http:Conflict>{body: {message: "Your documents were already submitted for this application."}};
        }
        log:printInfo("Onboarding documents stored", outcome = "stored", applicationId = applicationId,
            subject = user.sub, files = parsed.documents.length(), requestId = requestId);
        return <http:Created>{body: {message: "Documents submitted"}};
    }

    # Changes what the signed-in candidate submitted, until the deadline: the details are replaced, and so are the
    # files they send. A file they do not send stays as it was.
    resource function put applications/[string applicationId]/documents(http:Request req, http:RequestContext ctx)
            returns http:Ok|http:BadRequest|http:Unauthorized|http:Forbidden|http:NotFound|http:Conflict
                |http:BadGateway|http:GatewayTimeout {
        string requestId = types:requestIdOf(ctx);
        if !types:isValidJobId(applicationId) {
            return <http:NotFound>{body: {message: "Application not found"}};
        }
        jwt:AsgardeoJwt|error user = jwt:getUser(ctx);
        if user is error {
            return <http:Forbidden>{body: {message: "The caller could not be identified"}};
        }
        jwt:CallerDetails|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout caller =
            callerOf(ctx, requestId);
        if caller !is jwt:CallerDetails {
            return caller;
        }

        // The application is looked up through the caller's own email, so an id from the client is never trusted.
        string?|error candidateName = vacancy:acceptedApplicantName(caller.email, applicationId, requestId);
        if candidateName is error {
            return candidateFailure(candidateName, "Failed to check the application", requestId);
        }
        if candidateName is () {
            log:printWarn("Changes refused: not an accepted offer of the caller", outcome = "refused",
                applicationId = applicationId, subject = user.sub, requestId = requestId);
            return <http:NotFound>{body: {message: "Application not found"}};
        }
        [documents:Manifest, string]?|error loaded = documents:loadManifest(applicationId);
        if loaded is error {
            return candidateFailure(loaded, "Failed to read the submission", requestId);
        }
        if loaded is () {
            return <http:NotFound>{body: {message: "There is nothing to change yet. Submit your documents first."}};
        }
        // The time to change a submission is only ever checked here, on the backend, so the page cannot extend it.
        if !documents:canEdit(loaded[0]) {
            log:printWarn("Changes refused: the time to change them has ended", outcome = "closed",
                applicationId = applicationId, subject = user.sub, requestId = requestId);
            return <http:Forbidden>{body: {message: "The time to change your documents has ended."}};
        }

        if exceeds(req, documents:MAX_REQUEST_BYTES) {
            return <http:BadRequest>{body: {message: "The documents are too large."}};
        }
        documents:Submission|string parsed = documents:parseDocuments(req, loaded[0].files.keys());
        if parsed is string {
            log:printWarn("Changes refused: the files were not valid", outcome = "invalid",
                applicationId = applicationId, subject = user.sub, requestId = requestId);
            return <http:BadRequest>{body: {message: parsed}};
        }

        boolean|error saved = documents:saveChanges(applicationId, loaded[0], loaded[1], parsed, requestId);
        if saved is error {
            return candidateFailure(saved, "Failed to save the changes", requestId);
        }
        if !saved {
            log:printWarn("Changes refused: the submission changed in the meantime", outcome = "changed",
                applicationId = applicationId, subject = user.sub, requestId = requestId);
            return <http:Conflict>{body: {message: "Your submission was changed elsewhere. Reload the page and try again."}};
        }
        log:printInfo("Onboarding documents changed", outcome = "updated", applicationId = applicationId,
            subject = user.sub, files = parsed.documents.length(), requestId = requestId);
        return <http:Ok>{body: {message: "Changes saved"}};
    }
}

isolated function profileReply(http:Response|error resp, string failureMessage, string requestId)
        returns json|http:BadRequest|http:NotFound|http:BadGateway|http:GatewayTimeout {
    if resp is error {
        return candidateFailure(resp, failureMessage, requestId);
    }
    if resp.statusCode == http:STATUS_OK {
        json|error profile = resp.getJsonPayload();
        return profile is json ? profile : candidateFailure(profile, failureMessage, requestId);
    }
    string|error reason = resp.getTextPayload();
    string message = reason is string ? reason : failureMessage;
    if resp.statusCode == http:STATUS_BAD_REQUEST {
        return <http:BadRequest>{body: {message}};
    }
    if resp.statusCode == http:STATUS_NOT_FOUND {
        return <http:NotFound>{body: {message}};
    }
    log:printError("The ATS refused a profile request", status = resp.statusCode, requestId = requestId);
    return <http:BadGateway>{body: {message: failureMessage}};
}

# The caller's details from the identity provider, or a refusal when the account has no email.
isolated function callerOf(http:RequestContext ctx, string requestId)
        returns jwt:CallerDetails|http:Unauthorized|http:Forbidden|http:BadGateway|http:GatewayTimeout {
    jwt:AsgardeoJwt|error user = jwt:getUser(ctx);
    string|error token = jwt:getAccessToken(ctx);
    if user is error || token is error {
        return <http:Forbidden>{body: {message: "The caller could not be identified"}};
    }
    jwt:CallerDetails|error details = jwt:callerDetails(user, token);
    if details is jwt:UserInfoRefused {
        return <http:Unauthorized>{body: {message: "Unauthorized"}};
    }
    if details is error {
        return candidateFailure(details, "Failed to read the caller's details", requestId);
    }
    if details.email == "" {
        return <http:Forbidden>{body: {message: "The account has no email address"}};
    }
    return details;
}

isolated function genderOf(string gender) returns string {
    match gender.toLowerAscii() {
        "male" => {
            return "Male";
        }
        "female" => {
            return "Female";
        }
    }
    return "";
}

# The profile of a caller who has not applied yet, from what the identity provider knows.
isolated function profileFrom(jwt:CallerDetails caller) returns json => {
    firstName: caller.firstName,
    lastName: caller.lastName,
    gender: genderOf(caller.gender),
    personalEmail: caller.email,
    contactNo: caller.contactNo,
    address: (),
    university: (),
    editable: false
};

isolated function candidateFailure(error err, string failureMessage, string requestId)
        returns http:BadGateway|http:GatewayTimeout {
    log:printError(failureMessage, errorMessage = types:withoutPersonalData(err.message()), requestId = requestId);
    if err is http:ClientError {
        return <http:GatewayTimeout>{body: {message: "Upstream service unreachable"}};
    }
    return <http:BadGateway>{body: {message: failureMessage}};
}
