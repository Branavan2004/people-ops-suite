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

import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/url;

// The longest a write waits for the storage service to reply.
const decimal STORAGE_TIMEOUT_SECONDS = 60;

const STORAGE_API_VERSION = "2023-11-03";

// Azure does not accept a chunked body, so the client speaks HTTP/1.1 and is told never to chunk.
final http:Client storageClient = check new (storageConfig.baseUrl, {
    httpVersion: http:HTTP_1_1,
    timeout: STORAGE_TIMEOUT_SECONDS,
    http1Settings: {chunking: http:CHUNKING_NEVER}
});

isolated function sasQuery() returns string {
    string token = storageConfig.sasToken;
    return token.startsWith("?") ? token.substring(1) : token;
}

// The request path of a blob, with each part of its name encoded.
isolated function blobPath(string name) returns string|error {
    string[] parts = [];
    foreach string part in re `/`.split(name) {
        parts.push(check url:encode(part, "UTF-8"));
    }
    return string `/${storageConfig.container}/${string:'join("/", ...parts)}?${sasQuery()}`;
}

// The file in a submission's folder that records it and its current state.
isolated function manifestName(string folder) returns string => string `${folder}/submitted.json`;

// The small file that says which folder holds an application's submission, so it can be found by the application id
// alone.
isolated function indexName(string applicationId) returns string => string `index/${applicationId}.json`;

// The longest a candidate's name is kept in a folder or file name.
const MAX_STORED_NAME_LENGTH = 80;

// The text as a name a path and a file system accept: characters they reject become spaces, and what is left is
// trimmed. Names that end up empty are replaced by the fallback.
isolated function safeName(string text, string fallback) returns string {
    string cleaned = re `[\\/:*?"<>|\p{Cc}]+`.replaceAll(text, " ");
    cleaned = re `\s+`.replaceAll(cleaned, " ").trim();
    cleaned = re `^[.\s]+|[.\s]+$`.replaceAll(cleaned, "");
    if cleaned.length() > MAX_STORED_NAME_LENGTH {
        cleaned = cleaned.substring(0, MAX_STORED_NAME_LENGTH).trim();
    }
    return cleaned == "" ? fallback : cleaned;
}

// The folder of a submission: the candidate's full name and the application id.
isolated function folderOf(string candidateName, string applicationId) returns string =>
    string `applications/${safeName(candidateName, "Candidate")} - ${applicationId}`;

// What a document is called in a file name: its label without the explanation in brackets.
isolated function shortLabelOf(string key) returns string {
    foreach DocumentSpec spec in REQUIRED_DOCUMENTS {
        if spec.key == key {
            return safeName(re `\s*\(.*\)`.replaceAll(spec.label, ""), key);
        }
    }
    return safeName(key, "Document");
}

// A document's file, "<full name> - <document>": one fixed name per document, so an edit replaces the earlier file.
isolated function fileName(string folder, string candidateName, string key, string extension) returns string =>
    string `${folder}/${safeName(candidateName, "Candidate")} - ${shortLabelOf(key)}.${extension}`;

isolated function storageError(http:Response resp) returns error {
    string|http:HeaderNotFoundError reason = resp.getHeader("x-ms-error-code");
    // The reply's text says which header or value was refused. It holds no secret, and only its start is kept.
    string|error body = resp.getTextPayload();
    string detail = body is string ? (body.length() > 400 ? body.substring(0, 400) : body) : "";
    return error(string `The storage service replied with status ${resp.statusCode} (${reason is string ? reason : "no reason given"}) ${detail}`);
}

// Writes a blob. With `createOnly` it must not exist yet, and with `etag` it must be unchanged since it was read.
// False when that condition is not met. A write without a condition that is refused (a lease, a retention policy) is
// an error, since the blob was not written.
isolated function putBlob(string name, byte[] content, string contentType, map<string> metadata,
        boolean createOnly = false, string? etag = ()) returns boolean|error {
    http:Request req = new;
    req.setBinaryPayload(content, contentType);
    req.setHeader("x-ms-blob-type", "BlockBlob");
    req.setHeader("x-ms-version", STORAGE_API_VERSION);
    if createOnly {
        req.setHeader("If-None-Match", "*");
    }
    if etag is string {
        req.setHeader("If-Match", etag);
    }
    // The length is stated up front, so the body is never sent in chunks.
    req.setHeader("Content-Length", content.length().toString());
    foreach [string, string] [key, value] in metadata.entries() {
        req.setHeader("x-ms-meta-" + key, value);
    }
    http:Response resp = check storageClient->put(check blobPath(name), req);
    if resp.statusCode == http:STATUS_CREATED {
        return true;
    }
    if (resp.statusCode == http:STATUS_CONFLICT || resp.statusCode == http:STATUS_PRECONDITION_FAILED)
            && (createOnly || etag is string) {
        return false;
    }
    return storageError(resp);
}

# The moment a submission can no longer be changed: when it was made plus the days allowed. Nothing when no days are
# allowed or the time it was made cannot be read.
public isolated function editableUntil(Manifest manifest) returns time:Utc? => editableUntilAfter(manifest, editableDays);

isolated function editableUntilAfter(Manifest manifest, int days) returns time:Utc? {
    if days <= 0 {
        return ();
    }
    time:Utc|error made = time:utcFromString(manifest.submittedAt);
    return made is time:Utc ? time:utcAddSeconds(made, <decimal>days * 86400d) : ();
}

# Whether a submission can still be changed: only while its own time to change it has not run out.
public isolated function canEdit(Manifest manifest) returns boolean {
    time:Utc? until = editableUntil(manifest);
    return until is time:Utc && time:utcDiffSeconds(until, time:utcNow()) > 0d;
}

# Reads the record of an application's submission and the tag Azure gives its current version, or nothing when
# there is no submission. Needs a token that may read.
public isolated function loadManifest(string applicationId) returns [Manifest, string]?|error {
    string? folder = check folderOfSubmission(applicationId);
    return folder is () ? () : manifestIn(folder);
}

// The record in a submission's folder and its tag, or nothing when the folder has none.
isolated function manifestIn(string folder) returns [Manifest, string]?|error {
    http:Response resp = check storageClient->get(check blobPath(manifestName(folder)),
        {"x-ms-version": STORAGE_API_VERSION});
    if resp.statusCode == http:STATUS_NOT_FOUND {
        return ();
    }
    if resp.statusCode != http:STATUS_OK {
        return storageError(resp);
    }
    json body = check resp.getJsonPayload();
    Manifest manifest = check body.fromJsonWithType();
    string etag = check resp.getHeader("ETag");
    return [manifest, etag];
}

// The folder that holds an application's submission, from the index, or nothing when it has none.
isolated function folderOfSubmission(string applicationId) returns string?|error {
    [SubmissionIndex, string]? index = check indexOf(applicationId);
    return index is () ? () : index[0].folder;
}

// The index of an application and its tag, or nothing when there is none.
isolated function indexOf(string applicationId) returns [SubmissionIndex, string]?|error {
    http:Response resp = check storageClient->get(check blobPath(indexName(applicationId)),
        {"x-ms-version": STORAGE_API_VERSION});
    if resp.statusCode == http:STATUS_NOT_FOUND {
        return ();
    }
    if resp.statusCode != http:STATUS_OK {
        return storageError(resp);
    }
    json body = check resp.getJsonPayload();
    SubmissionIndex index = check body.fromJsonWithType();
    return [index, check resp.getHeader("ETag")];
}

// How long a first submission may run before another request may take its place, in seconds. It is longer than the
// time the web app waits for a reply.
const decimal STALE_CLAIM_SECONDS = 300;

// An index that claims the folder for a request, as of now.
isolated function claimFor(string folder, string candidateName, string requestId) returns SubmissionIndex =>
    {folder, candidateName, claimedBy: requestId, claimedAt: time:utcToString(time:utcNow())};

// Whether the first submission an index records was released or has run too long to be still going.
isolated function isAbandoned(SubmissionIndex index) returns boolean {
    if index.claimedAt == "" {
        return true;
    }
    time:Utc|error claimed = time:utcFromString(index.claimedAt);
    return claimed is error || time:utcDiffSeconds(time:utcNow(), claimed) > STALE_CLAIM_SECONDS;
}

# What the candidate's page needs to know: whether they submitted, whether they can still change it and until
# when, and, for the candidate whose submission it is, the details they saved and which documents they sent.
public isolated function submissionStatus(string applicationId) returns SubmissionStatus|error {
    [Manifest, string]? loaded = check loadManifest(applicationId);
    if loaded is () {
        return {submitted: false, canEdit: false, editableUntil: ""};
    }
    Manifest manifest = loaded[0];
    time:Utc? until = editableUntil(manifest);
    return {
        submitted: true,
        canEdit: canEdit(manifest),
        editableUntil: until is time:Utc ? time:utcToString(until) : "",
        details: manifest.details,
        files: manifest.files.keys()
    };
}

# Stores a first submission: the index, the documents, then the record of it. Nothing is written when the application
# already has a submission, or when another request is making it: the index records which request claimed the
# folder, and only that request writes into it. A claim that was released after a failure, or has run too long, is
# taken over and its folder continued, whatever the candidate's name is now.
public isolated function storeDocuments(string applicationId, Submission submission, string candidateName,
        string requestId) returns SubmitOutcome|error {
    map<string> & readonly metadata = {applicationid: applicationId, requestid: requestId}.cloneReadOnly();
    [SubmissionIndex, string]? earlier = check indexOf(applicationId);
    // A retry gives the files the name the first attempt gave them, so no second set of names is left in the folder.
    string submissionName = earlier is () || earlier[0].candidateName == "" ? candidateName : earlier[0].candidateName;
    string folder = earlier is () ? folderOf(submissionName, applicationId) : earlier[0].folder;
    if earlier is () {
        boolean claimed = check putBlob(indexName(applicationId),
            claimFor(folder, submissionName, requestId).toJsonString().toBytes(), "application/json", metadata,
            createOnly = true);
        if !claimed {
            return IN_PROGRESS;
        }
    } else {
        if check manifestIn(folder) !is () {
            return ALREADY_SUBMITTED;
        }
        // An index without a record is a submission still running, or one that was abandoned.
        if !isAbandoned(earlier[0]) {
            return IN_PROGRESS;
        }
        boolean tookOver = check putBlob(indexName(applicationId),
            claimFor(folder, submissionName, requestId).toJsonString().toBytes(), "application/json", metadata,
            etag = earlier[1]);
        if !tookOver {
            return IN_PROGRESS;
        }
    }
    SubmitOutcome|error stored = writeSubmission(applicationId, submission, submissionName, folder, requestId,
        metadata);
    if stored is error {
        releaseClaim(applicationId, folder, requestId, metadata);
    }
    return stored;
}

// Gives up the claim on an application's folder after a failure, so a retry does not have to wait for it to run out.
// Nothing is done when the claim is no longer this request's.
isolated function releaseClaim(string applicationId, string folder, string requestId, map<string> metadata) {
    [SubmissionIndex, string]|error|() index = indexOf(applicationId);
    if index is [SubmissionIndex, string] && index[0].claimedBy == requestId {
        SubmissionIndex released = {folder, candidateName: index[0].candidateName};
        boolean|error written = putBlob(indexName(applicationId), released.toJsonString().toBytes(),
            "application/json", metadata, etag = index[1]);
        if written is error {
            log:printWarn("Could not release the claim on a submission", errorMessage = written.message(),
                requestId = requestId);
        }
    }
}

// Writes the files, then the record, of a submission whose folder this request has claimed.
isolated function writeSubmission(string applicationId, Submission submission, string candidateName, string folder,
        string requestId, map<string> & readonly metadata) returns SubmitOutcome|error {
    map<string> files = {};
    // The files are sent together; the record waits for all of them.
    future<boolean|error>[] writes = [];
    foreach UploadedDocument document in submission.documents {
        string name = fileName(folder, candidateName, document.key, document.extension);
        files[document.key] = name;
        future<boolean|error> write = start putBlob(name, document.content.cloneReadOnly(), document.contentType,
            metadata);
        writes.push(write);
    }
    error? failure = ();
    foreach future<boolean|error> write in writes {
        boolean|error written = wait write;
        if written is error && failure is () {
            failure = written;
        }
    }
    if failure is error {
        return failure;
    }
    // The claim may have been taken over while the files were being sent; the record then belongs to the other request.
    [SubmissionIndex, string]? claim = check indexOf(applicationId);
    if claim is () || claim[0].claimedBy != requestId {
        return IN_PROGRESS;
    }
    string now = time:utcToString(time:utcNow());
    Manifest manifest = {
        applicationId,
        candidateName,
        folder,
        details: submission.details,
        files,
        declared: true,
        submittedAt: now,
        updatedAt: now
    };
    boolean written = check putBlob(manifestName(folder), manifest.toJsonString().toBytes(),
        "application/json", metadata, createOnly = true);
    return written ? STORED : ALREADY_SUBMITTED;
}

# Applies a candidate's changes to a submission: the files they sent replace the earlier ones, and the details are
# replaced. Nothing is written when the record has changed since it was read. Otherwise the files are replaced and the
# record is saved, and if that is refused or anything fails, the earlier files are put back, so the candidate has
# either the new submission or the old one. False when the record had changed.
public isolated function saveChanges(string applicationId, Manifest current, string etag, Submission update,
        string requestId) returns boolean|error {
    map<string> metadata = {applicationid: applicationId, requestid: requestId};
    // The folder and the file names keep the name the submission was made under.
    string folder = current.folder;
    [Manifest, string]? latest = check manifestIn(folder);
    if latest is () || latest[1] != etag {
        return false;
    }

    map<string> files = current.files.clone();
    // The files replaced under their own name, with what they held, to put back; the files written under a new name
    // (the type changed); and the earlier files of those, to remove once the record points at the new ones.
    [string, byte[], string][] overwritten = [];
    string[] added = [];
    string[] superseded = [];
    boolean|error saved = false;
    do {
        foreach UploadedDocument document in update.documents {
            string name = fileName(folder, current.candidateName, document.key, document.extension);
            string? previous = files[document.key];
            if previous is string && previous == name {
                [byte[], string]? earlier = check readBlob(name);
                if earlier is [byte[], string] {
                    overwritten.push([name, earlier[0], earlier[1]]);
                }
            } else {
                added.push(name);
                if previous is string {
                    superseded.push(previous);
                }
            }
            _ = check putBlob(name, document.content, document.contentType, metadata);
            files[document.key] = name;
        }
        Manifest next = {
            applicationId: current.applicationId,
            // The name the submission was made under, which its files carry, whatever the candidate's name is now.
            candidateName: current.candidateName,
            folder,
            details: update.details,
            files,
            declared: true,
            submittedAt: current.submittedAt,
            updatedAt: time:utcToString(time:utcNow())
        };
        saved = check putBlob(manifestName(folder), next.toJsonString().toBytes(), "application/json", metadata,
            etag = etag);
    } on fail error failure {
        saved = failure;
    }

    if saved is true {
        // A file of another type has another name. It cannot be deleted with this token, so the earlier one is
        // emptied, and only once the record no longer points at it.
        emptyBlobs(superseded, metadata, requestId);
    } else {
        foreach [string, byte[], string] [name, content, contentType] in overwritten {
            boolean|error restored = putBlob(name, content, contentType, metadata);
            if restored is error {
                log:printWarn("Could not put back an earlier file", errorMessage = restored.message(),
                    requestId = requestId);
            }
        }
        emptyBlobs(added, metadata, requestId);
    }
    return saved;
}

// What a blob holds and its content type, or nothing when there is no such blob.
isolated function readBlob(string name) returns [byte[], string]?|error {
    http:Response resp = check storageClient->get(check blobPath(name), {"x-ms-version": STORAGE_API_VERSION});
    if resp.statusCode == http:STATUS_NOT_FOUND {
        return ();
    }
    if resp.statusCode != http:STATUS_OK {
        return storageError(resp);
    }
    byte[] content = check resp.getBinaryPayload();
    string|http:HeaderNotFoundError contentType = resp.getHeader("Content-Type");
    return [content, contentType is string ? contentType : "application/octet-stream"];
}

// Empties blobs that no record points at, since this token cannot delete them. A blob that cannot be emptied is
// logged and left.
isolated function emptyBlobs(string[] names, map<string> metadata, string requestId) {
    foreach string name in names {
        boolean|error emptied = putBlob(name, [], "application/octet-stream", metadata);
        if emptied is error {
            log:printWarn("Could not empty an unused file", errorMessage = emptied.message(), requestId = requestId);
        }
    }
}
