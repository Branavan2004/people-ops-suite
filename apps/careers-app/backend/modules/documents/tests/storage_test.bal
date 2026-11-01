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
import ballerina/lang.array;
import ballerina/test;
import ballerina/time;

// The blobs of the stand-in storage service, each with the tag the service gives it.
isolated class BlobStore {
    private map<byte[]> blobs = {};
    private map<string> tags = {};
    private int writes = 0;
    // A write whose blob name contains this text is refused with a server error.
    private string failingName = "";
    // A write whose blob name contains this text is refused as if its tag were out of date.
    private string refusedName = "";

    isolated function reset() {
        lock {
            self.blobs = {};
            self.tags = {};
            self.writes = 0;
            self.failingName = "";
            self.refusedName = "";
        }
    }

    isolated function refuseWritesTo(string name) {
        lock {
            self.refusedName = name;
        }
    }

    isolated function failWritesTo(string name) {
        lock {
            self.failingName = name;
        }
    }

    // The status of a write and the tag of the stored blob. `createOnly` and `expectedTag` are the write conditions.
    isolated function write(string name, byte[] content, boolean createOnly, string? expectedTag)
            returns [int, string] {
        lock {
            if self.failingName != "" && name.includes(self.failingName) {
                return [http:STATUS_INTERNAL_SERVER_ERROR, ""];
            }
            if self.refusedName != "" && name.includes(self.refusedName) {
                return [http:STATUS_PRECONDITION_FAILED, ""];
            }
            if createOnly && self.blobs.hasKey(name) {
                return [http:STATUS_CONFLICT, ""];
            }
            if expectedTag is string && self.tags[name] != expectedTag {
                return [http:STATUS_PRECONDITION_FAILED, ""];
            }
            self.writes += 1;
            self.blobs[name] = content.clone();
            string tag = string `"${self.writes}"`;
            self.tags[name] = tag;
            return [http:STATUS_CREATED, tag];
        }
    }

    isolated function read(string name) returns [byte[], string]? {
        lock {
            byte[]? content = self.blobs[name];
            if content is () {
                return ();
            }
            return [content.clone(), self.tags.get(name)];
        }
    }

    isolated function names() returns string[] {
        lock {
            return array:sort(self.blobs.keys()).clone();
        }
    }

    isolated function writeCount() returns int {
        lock {
            return self.writes;
        }
    }
}

final BlobStore store = new;

listener http:Listener storageService = new (10000);

// An in-memory stand-in for the blob service, honouring the write conditions the code relies on.
service /test\-container on storageService {
    isolated resource function put [string... path](http:Request req) returns http:Response|error {
        string|error createOnly = req.getHeader("If-None-Match");
        string|error expectedTag = req.getHeader("If-Match");
        [int, string] result = store.write(string:'join("/", ...path), check req.getBinaryPayload(),
            createOnly is string && createOnly == "*", expectedTag is string ? expectedTag : ());
        // No ETag is sent back: a listener answers 304 to a conditional request when the reply carries one.
        http:Response resp = new;
        resp.statusCode = result[0];
        return resp;
    }

    isolated resource function get [string... path]() returns http:Response {
        string name = string:'join("/", ...path);
        [byte[], string]? found = store.read(name);
        http:Response resp = new;
        if found is () {
            resp.statusCode = http:STATUS_NOT_FOUND;
            return resp;
        }
        resp.statusCode = http:STATUS_OK;
        resp.setBinaryPayload(found[0], name.endsWith(".json") ? "application/json" : "application/pdf");
        resp.setHeader("ETag", found[1]);
        return resp;
    }
}

@test:BeforeEach
function emptyTheStorage() {
    store.reset();
}

// What a stored blob holds; empty when it holds nothing or does not exist.
function contentOf(string name) returns byte[] {
    [byte[], string]? found = store.read(name);
    if found is () {
        return [];
    }
    return found[0];
}

function aSubmission() returns Submission {
    Submission|string parsed = parseDocuments(documentsRequest(requiredFiles()));
    if parsed is string {
        panic error("The test submission was refused: " + parsed);
    }
    return parsed;
}

const FOLDER = "applications/Ada Lovelace - 123";

@test:Config {}
function aFirstSubmissionIsStoredInOneFolderNamedAfterTheCandidate() returns error? {
    Submission submission = aSubmission();
    SubmitOutcome outcome = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    test:assertEquals(outcome, STORED);

    string[] names = store.names();
    test:assertEquals(names.length(), submission.documents.length() + 2);
    test:assertTrue(names.indexOf("index/123.json") is int);
    test:assertTrue(names.indexOf(FOLDER + "/submitted.json") is int);
    test:assertTrue(names.indexOf(FOLDER + "/Ada Lovelace - Identity document.pdf") is int);
    foreach string name in names {
        test:assertTrue(name == "index/123.json" || name.startsWith(FOLDER + "/"), name);
    }
}

@test:Config {}
function aSecondSubmissionForTheSameApplicationIsRefusedAndWritesNothing() returns error? {
    Submission submission = aSubmission();
    _ = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    int before = store.writeCount();

    SubmitOutcome outcome = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    test:assertEquals(outcome, ALREADY_SUBMITTED);
    test:assertEquals(store.writeCount(), before);
}

@test:Config {}
function aSubmissionIsFoundByTheApplicationIdAndListsItsFiles() returns error? {
    Submission submission = aSubmission();
    _ = check storeDocuments("123", submission, "Ada Lovelace", "test-request");

    SubmissionStatus status = check submissionStatus("123");
    test:assertTrue(status.submitted);
    test:assertFalse(status.canEdit);
    test:assertEquals(status.files.length(), submission.documents.length());
    test:assertEquals(status.details?.fullName, submission.details.fullName);

    [Manifest, string]? loaded = check loadManifest("123");
    if loaded is () {
        test:assertFail("The record was not found through the index");
    }
    test:assertEquals(loaded[0].folder, FOLDER);
    test:assertEquals(loaded[0].candidateName, "Ada Lovelace");
}

@test:Config {}
function anApplicationWithoutASubmissionIsNotSubmitted() returns error? {
    SubmissionStatus status = check submissionStatus("999");
    test:assertFalse(status.submitted);
    test:assertEquals(status.files, []);
    test:assertEquals(check loadManifest("999"), ());
}

@test:Config {}
function aChangeReplacesAFileOnlyWhileTheRecordIsUnchanged() returns error? {
    Submission submission = aSubmission();
    _ = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    [Manifest, string]? loaded = check loadManifest("123");
    if loaded is () {
        test:assertFail("The record was not found");
    }
    Submission update = {
        documents: [{key: "identityDocument", extension: "pdf", contentType: "application/pdf", content: [1, 2, 3]}],
        details: submission.details
    };

    int filesBefore = store.names().length();
    boolean saved = check saveChanges("123", loaded[0], loaded[1], update, "test-request");
    test:assertTrue(saved);

    // The file is replaced under its own name, and the folder holds nothing extra.
    test:assertEquals(contentOf(FOLDER + "/Ada Lovelace - Identity document.pdf"), <byte[]>[1, 2, 3]);
    test:assertEquals(store.names().length(), filesBefore);

    // The record changed with that save, so the tag read earlier no longer matches.
    boolean savedAgain = check saveChanges("123", loaded[0], loaded[1], update, "test-request");
    test:assertFalse(savedAgain);
}

@test:Config {}
function aChangeOnARecordThatMovedOnWritesNothing() returns error? {
    Submission submission = aSubmission();
    _ = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    [Manifest, string]? loaded = check loadManifest("123");
    if loaded is () {
        test:assertFail("The record was not found");
    }
    string identity = FOLDER + "/Ada Lovelace - Identity document.pdf";
    Submission byA = {
        documents: [{key: "identityDocument", extension: "pdf", contentType: "application/pdf", content: [1, 1, 1]}],
        details: submission.details
    };
    Submission byB = {
        documents: [{key: "identityDocument", extension: "pdf", contentType: "application/pdf", content: [2, 2, 2]}],
        details: submission.details
    };

    // Both read the record with the same tag. A saves first, so B is refused before it writes anything.
    test:assertTrue(check saveChanges("123", loaded[0], loaded[1], byA, "test-request"));
    int writesAfterA = store.writeCount();
    test:assertFalse(check saveChanges("123", loaded[0], loaded[1], byB, "test-request"));
    test:assertEquals(store.writeCount(), writesAfterA);
    test:assertEquals(contentOf(identity), <byte[]>[1, 1, 1]);
}

@test:Config {}
function aChangeRefusedAfterTheFilesWereReplacedPutsThemBack() returns error? {
    Submission submission = aSubmission();
    _ = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    [Manifest, string]? loaded = check loadManifest("123");
    if loaded is () {
        test:assertFail("The record was not found");
    }
    string identity = FOLDER + "/Ada Lovelace - Identity document.pdf";
    byte[] identityBefore = contentOf(identity);
    Submission update = {
        documents: [{key: "identityDocument", extension: "pdf", contentType: "application/pdf", content: [1, 2, 3]}],
        details: submission.details
    };

    // The record still matches when the change starts, but its own write is refused after the file was replaced.
    store.refuseWritesTo("submitted.json");
    boolean saved = check saveChanges("123", loaded[0], loaded[1], update, "test-request");
    test:assertFalse(saved);
    test:assertEquals(contentOf(identity), identityBefore);
}

@test:Config {}
function aChangeThatFailsPartwayPutsTheEarlierFilesBack() returns error? {
    Submission submission = aSubmission();
    _ = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    [Manifest, string]? loaded = check loadManifest("123");
    if loaded is () {
        test:assertFail("The record was not found");
    }
    string identity = FOLDER + "/Ada Lovelace - Identity document.pdf";
    string birth = FOLDER + "/Ada Lovelace - Birth certificate.pdf";
    byte[] identityBefore = contentOf(identity);
    byte[] birthBefore = contentOf(birth);
    int filesBefore = store.names().length();
    Submission update = {
        documents: [
            {key: "identityDocument", extension: "pdf", contentType: "application/pdf", content: [1, 2, 3]},
            {key: "birthCertificate", extension: "pdf", contentType: "application/pdf", content: [4, 5, 6]}
        ],
        details: submission.details
    };

    // The second file cannot be written, so the change fails after the first one was replaced.
    store.failWritesTo("Birth certificate");
    boolean|error result = saveChanges("123", loaded[0], loaded[1], update, "test-request");
    store.failWritesTo("");
    test:assertTrue(result is error);

    test:assertEquals(contentOf(identity), identityBefore);
    test:assertEquals(contentOf(birth), birthBefore);
    test:assertEquals(store.names().length(), filesBefore);
    [Manifest, string]? after = check loadManifest("123");
    test:assertEquals(after is () ? () : after[0].files, loaded[0].files);
}

@test:Config {}
function aFileOfAnotherTypeIsEmptiedOnlyOnceTheRecordIsSaved() returns error? {
    Submission submission = aSubmission();
    _ = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    [Manifest, string]? loaded = check loadManifest("123");
    if loaded is () {
        test:assertFail("The record was not found");
    }
    string oldPicture = FOLDER + "/Ada Lovelace - Profile picture.png";
    string newPicture = FOLDER + "/Ada Lovelace - Profile picture.jpg";
    byte[] oldBefore = contentOf(oldPicture);
    Submission update = {
        documents: [{key: "profilePicture", extension: "jpg", contentType: "image/jpeg", content: [1, 2, 3]}],
        details: submission.details
    };

    // The record write is refused, so the earlier picture stays and the new file holds nothing.
    store.refuseWritesTo("submitted.json");
    test:assertFalse(check saveChanges("123", loaded[0], loaded[1], update, "test-request"));
    store.refuseWritesTo("");
    test:assertEquals(contentOf(oldPicture), oldBefore);
    test:assertEquals(contentOf(newPicture), <byte[]>[]);

    // Saved, so the record points at the new picture and the earlier one is emptied.
    test:assertTrue(check saveChanges("123", loaded[0], loaded[1], update, "test-request"));
    test:assertEquals(contentOf(newPicture), <byte[]>[1, 2, 3]);
    test:assertEquals(contentOf(oldPicture), <byte[]>[]);
}

// An index as one request leaves it when it claims the folder.
function claimJson(string claimedBy, string claimedAt) returns string =>
    {folder: FOLDER, claimedBy, claimedAt}.toJsonString();

@test:Config {}
function aSubmissionThatIsStillRunningIsNotWrittenOverBySecondRequest() returns error? {
    // The first request has claimed the folder and has not written its record yet.
    _ = store.write("index/123.json", claimJson("first-request", time:utcToString(time:utcNow())).toBytes(), false, ());
    int writesBefore = store.writeCount();

    SubmitOutcome outcome = check storeDocuments("123", aSubmission(), "Ada Lovelace", "second-request");
    test:assertEquals(outcome, IN_PROGRESS);
    test:assertEquals(store.writeCount(), writesBefore);
}

@test:Config {}
function aClaimThatRanOutIsTakenOver() returns error? {
    _ = store.write("index/123.json", claimJson("first-request", "2020-01-01T00:00:00Z").toBytes(), false, ());

    SubmitOutcome outcome = check storeDocuments("123", aSubmission(), "Ada Lovelace", "second-request");
    test:assertEquals(outcome, STORED);
    SubmissionStatus status = check submissionStatus("123");
    test:assertTrue(status.submitted);
}

@test:Config {}
function aFailedFirstAttemptReleasesItsClaimSoTheRetryCanGoAhead() returns error? {
    store.failWritesTo("Birth certificate");
    SubmitOutcome|error failed = storeDocuments("123", aSubmission(), "Ada Lovelace", "first-request");
    store.failWritesTo("");
    test:assertTrue(failed is error);

    // The retry is a different request, and does not wait for the claim of the failed one to run out.
    SubmitOutcome outcome = check storeDocuments("123", aSubmission(), "Ada Lovelace", "second-request");
    test:assertEquals(outcome, STORED);
}

@test:Config {}
function aFileWriteRefusedByTheStorageIsAnErrorNotAStoredFile() {
    // A lease or a retention policy refuses the write of a file with a conflict, which is not a stored file.
    store.refuseWritesTo("Identity document");
    SubmitOutcome|error outcome = storeDocuments("123", aSubmission(), "Ada Lovelace", "test-request");
    store.refuseWritesTo("");
    test:assertTrue(outcome is error);
    test:assertEquals(store.names().indexOf(FOLDER + "/submitted.json"), ());
}

@test:Config {}
function aChangeWhoseFileWriteIsRefusedFailsAndKeepsTheEarlierSubmission() returns error? {
    Submission submission = aSubmission();
    _ = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    [Manifest, string]? loaded = check loadManifest("123");
    if loaded is () {
        test:assertFail("The record was not found");
    }
    string identity = FOLDER + "/Ada Lovelace - Identity document.pdf";
    byte[] identityBefore = contentOf(identity);
    Submission update = {
        documents: [{key: "identityDocument", extension: "pdf", contentType: "application/pdf", content: [1, 2, 3]}],
        details: submission.details
    };

    store.refuseWritesTo("Identity document");
    boolean|error result = saveChanges("123", loaded[0], loaded[1], update, "test-request");
    store.refuseWritesTo("");
    test:assertTrue(result is error);
    test:assertEquals(contentOf(identity), identityBefore);
    [Manifest, string]? after = check loadManifest("123");
    test:assertEquals(after is () ? () : after[1], loaded[1]);
}

@test:Config {}
function aFileThatCannotBeWrittenLeavesNoRecord() {
    store.failWritesTo("Birth certificate");
    SubmitOutcome|error outcome = storeDocuments("123", aSubmission(), "Ada Lovelace", "test-request");
    test:assertTrue(outcome is error);

    test:assertEquals(store.names().indexOf(FOLDER + "/submitted.json"), ());
    SubmissionStatus|error status = submissionStatus("123");
    test:assertTrue(status is SubmissionStatus && !status.submitted);
}

@test:Config {}
function aRetryAfterAFailedAttemptKeepsTheNamesOfTheFirstAttemptWhateverTheNameIsNow() returns error? {
    store.failWritesTo("Birth certificate");
    SubmitOutcome|error failed = storeDocuments("123", aSubmission(), "Ada Lovelace", "first-request");
    test:assertTrue(failed is error);

    // The candidate's name has changed by the retry, but the files carry the name of the first attempt.
    store.failWritesTo("");
    SubmitOutcome outcome = check storeDocuments("123", aSubmission(), "Ada King", "second-request");
    test:assertEquals(outcome, STORED);

    string[] names = store.names();
    test:assertEquals(names.filter(name => name.endsWith("/submitted.json")), [FOLDER + "/submitted.json"]);
    foreach string name in names {
        test:assertTrue(name == "index/123.json" || name.startsWith(FOLDER + "/Ada Lovelace - ")
            || name == FOLDER + "/submitted.json", name);
        test:assertFalse(name.includes("Ada King"), name);
    }
    [Manifest, string]? loaded = check loadManifest("123");
    test:assertEquals(loaded is () ? () : loaded[0].candidateName, "Ada Lovelace");
}

@test:Config {}
function aChangeAfterTheCandidatesNameChangedKeepsTheNamesOfTheSubmission() returns error? {
    Submission submission = aSubmission();
    _ = check storeDocuments("123", submission, "Ada Lovelace", "test-request");
    int filesBefore = store.names().length();

    // Two changes in a row, as when the ATS name has changed in between: neither renames anything.
    foreach int round in 1 ... 2 {
        [Manifest, string]? loaded = check loadManifest("123");
        if loaded is () {
            test:assertFail("The record was not found");
        }
        Submission update = {
            documents: [{key: "identityDocument", extension: "pdf", contentType: "application/pdf", content: [<byte>round, 9]}],
            details: submission.details
        };
        test:assertTrue(check saveChanges("123", loaded[0], loaded[1], update, "test-request"));
    }

    [Manifest, string]? after = check loadManifest("123");
    test:assertEquals(after is () ? () : after[0].candidateName, "Ada Lovelace");
    test:assertEquals(contentOf(FOLDER + "/Ada Lovelace - Identity document.pdf"), <byte[]>[2, 9]);
    test:assertEquals(store.names().length(), filesBefore);
    foreach string name in store.names() {
        test:assertFalse(name.includes("Ada King"), name);
    }
}
