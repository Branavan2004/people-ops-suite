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
import leave_service.authorization;
import leave_service.database;
import leave_service.employee;
import leave_service.policy;
import leave_service.sick_note;

import ballerina/http;
import ballerina/io;
import ballerina/lang.value;
import ballerina/log;
import ballerina/mime;

# Key that encrypts sick notes: 32 bytes, base64-encoded. Each environment has its own key, kept in the secret store.
configurable string sickNoteEncryptionKey = ?;

# The decoded sick note key. A key that is not base64 of exactly 32 bytes stops the service from starting.
final byte[] & readonly sickNoteKey = check sick_note:decodeKey(sickNoteEncryptionKey).cloneReadOnly();

# Largest sick leave request accepted, in bytes: the base64 of the largest sick note plus 1 MB for the leave. It is
# also the listener's body limit, as every other endpoint takes a small JSON body.
const MAX_SICK_LEAVE_REQUEST_BYTES = sick_note:MAX_SICK_NOTE_BASE64_LENGTH + 1048576;

const ERR_MSG_SUBMIT_LEAVE_FAILED = "Error occurred while submitting a leave";
const ERR_MSG_SICK_NOTE_NOT_FOUND = "No sick note was found for this leave.";
const ERR_MSG_SICK_NOTE_UNREADABLE = "The sick note could not be read.";
const ERR_MSG_SICK_NOTE_FETCH_FAILED = "Error occurred while fetching the sick note";

# Refuse a sick leave request that declares a length over the limit, before any of its body is read. A body that
# declares no length is not refused here: `readSickLeaveRequest` counts its bytes as they are read, which also covers
# HTTP/2, where the listener's `maxEntityBodySize` does not apply.
#
# + req - Sick leave request
# + return - PayloadTooLarge if the declared length is over `MAX_SICK_LEAVE_REQUEST_BYTES`, otherwise nil
function checkSickLeaveRequestSize(http:Request req) returns http:PayloadTooLarge? {
    string|http:HeaderNotFoundError declared = req.getHeader(http:CONTENT_LENGTH);
    int|error length = declared is string ? int:fromString(declared) : declared;
    if length is int && length > MAX_SICK_LEAVE_REQUEST_BYTES {
        return <http:PayloadTooLarge>{
            body: {
                message: sick_note:ERR_MSG_SICK_NOTE_TOO_LARGE
            }
        };
    }
    return ();
}

# Submit sick leave in France with its sick note. The note is checked, encrypted and saved with the leave in one
# transaction; the leave then goes through the same submission as `POST /leaves`. The note is never sent by email or
# added to the calendar event.
#
# + req - JSON request with the leave and the sick note as base64 text
# + email - Email of the applicant
# + jwt - JWT token of the applicant
# + return - Ok when the leave is submitted, BadRequest for an invalid leave or sick note, otherwise
# InternalServerError
function submitSickLeave(http:Request req, string email, string jwt)
    returns http:Ok|http:BadRequest|http:InternalServerError {

    SickLeaveSubmission|error submission = readSickLeaveRequest(req);
    if submission is error {
        log:printWarn("Sick leave request refused", employee = email, reason = submission.message());
        return <http:BadRequest>{
            body: {
                message: submission.message()
            }
        };
    }
    string|error contentType = sick_note:detectContentType(submission.sickNote);
    if contentType is error {
        log:printWarn("Sick note refused", employee = email, reason = contentType.message());
        return <http:BadRequest>{
            body: {
                message: contentType.message()
            }
        };
    }
    string|error location = employee:getEmployeeLocation(email, jwt);
    if location is error {
        log:printError(ERR_MSG_SUBMIT_LEAVE_FAILED, location);
        return <http:InternalServerError>{
            body: {
                message: ERR_MSG_SUBMIT_LEAVE_FAILED
            }
        };
    }
    if !policy:requiresSickNote(submission.leave.leaveType, location) {
        log:printWarn("Sick leave request refused: not sick leave in France", employee = email,
                leaveType = submission.leave.leaveType, location = location);
        return <http:BadRequest>{
            body: {
                message: "This endpoint is only for sick leave in France."
            }
        };
    }
    sick_note:EncryptedSickNote|error encrypted = sick_note:encrypt(submission.sickNote, sickNoteKey);
    if encrypted is error {
        log:printError("Error occurred while encrypting a sick note", encrypted);
        return <http:InternalServerError>{
            body: {
                message: ERR_MSG_SUBMIT_LEAVE_FAILED
            }
        };
    }

    CalculatedLeave|http:Ok|http:BadRequest|http:InternalServerError result = submitLeave(submission.leave, email, jwt,
            false, {
                content: encrypted.content,
                iv: encrypted.iv,
                keyId: encrypted.keyId,
                contentType,
                sizeBytes: submission.sickNote.length(),
                uploadedBy: email
            });
    // Not reached: a calculated leave is returned only in validation mode, which this submission never uses.
    if result is CalculatedLeave {
        return <http:InternalServerError>{
            body: {
                message: ERR_MSG_SUBMIT_LEAVE_FAILED
            }
        };
    }
    return result;
}

# Read a sick leave request: the leave, as sent to `POST /leaves`, and the sick note as base64 text. The note is sent
# as text in JSON, not as a multipart file, because Cloudflare in front of the API gateway challenges request bodies
# that carry raw binary, and a browser request cannot answer that challenge.
#
# The body is read through `sick_note:readUpTo`, so one over `MAX_SICK_LEAVE_REQUEST_BYTES` stops being read once it
# passes the limit, whatever its declared length or HTTP version.
#
# + req - JSON request
# + return - The leave and the decoded sick note file, or an error whose message can be shown to the user
function readSickLeaveRequest(http:Request req) returns SickLeaveSubmission|error {
    stream<byte[], io:Error?>|http:ClientError chunks = req.getByteStream();
    byte[]|error bytes = chunks is http:ClientError ? chunks : sick_note:readUpTo(chunks, MAX_SICK_LEAVE_REQUEST_BYTES);
    if bytes is error {
        return error("The request could not be read.", bytes);
    }
    string|error text = string:fromBytes(bytes);
    json|error body = text is string ? text.fromJsonString() : text;
    if body is error {
        return error("Send the leave and the sick note as JSON.", body);
    }
    SickLeaveRequest|error request = value:fromJsonWithType(body);
    if request is error {
        return error("The request must contain a valid leave and the sick note.", request);
    }
    byte[] sickNote = check sick_note:decodeNote(request.sickNote);
    return {leave: request.leave, sickNote};
}

# Send a sick note to the applicant or a member of `sickNoteRoles`. Access is checked from the note's details before
# its encrypted content is read. The download is recorded before the file is sent, and the file is not sent if the
# record cannot be saved.
#
# + leaveId - Leave ID
# + requesterEmail - Email of the user asking for the file
# + requesterGroups - Groups of the user asking for the file
# + return - The file, NotFound if the leave has no sick note or it was deleted, Forbidden for anyone other than the
# applicant and `sickNoteRoles`, otherwise InternalServerError
function downloadSickNote(int leaveId, string requesterEmail, string[] requesterGroups)
    returns http:Response|http:NotFound|http:Forbidden|http:InternalServerError {

    database:StoredSickNote|error? sickNote = database:getSickNote(leaveId);
    if sickNote is error {
        log:printError(ERR_MSG_SICK_NOTE_FETCH_FAILED, sickNote, leaveId = leaveId);
        return <http:InternalServerError>{
            body: {
                message: ERR_MSG_SICK_NOTE_FETCH_FAILED
            }
        };
    }
    if sickNote is () {
        log:printWarn("Sick note not found", leaveId = leaveId, requestedBy = requesterEmail);
        return <http:NotFound>{
            body: {
                message: ERR_MSG_SICK_NOTE_NOT_FOUND
            }
        };
    }
    if !sick_note:canDownload(requesterEmail, requesterGroups, sickNote.email,
            authorization:authorizedRoles.sickNoteRoles) {
        log:printWarn("Sick note download refused", leaveId = leaveId, requestedBy = requesterEmail);
        return <http:Forbidden>{
            body: {
                message: "You are not authorized to download this sick note."
            }
        };
    }
    if sickNote.deletedAt is string {
        log:printWarn("Sick note already deleted", leaveId = leaveId, requestedBy = requesterEmail);
        return <http:NotFound>{
            body: {
                message: ERR_MSG_SICK_NOTE_NOT_FOUND
            }
        };
    }

    // Read only once the caller may download the note.
    database:SickNoteContent|error? stored = database:getSickNoteContent(sickNote.id);
    if stored is error {
        log:printError(ERR_MSG_SICK_NOTE_FETCH_FAILED, stored, leaveId = leaveId);
        return <http:InternalServerError>{
            body: {
                message: ERR_MSG_SICK_NOTE_FETCH_FAILED
            }
        };
    }
    // The retention job may have cleared the content since the details were read.
    byte[]? content = stored is () ? () : stored.content;
    byte[]? iv = stored is () ? () : stored.iv;
    if content is () || iv is () {
        log:printWarn("Sick note content already cleared", leaveId = leaveId, requestedBy = requesterEmail);
        return <http:NotFound>{
            body: {
                message: ERR_MSG_SICK_NOTE_NOT_FOUND
            }
        };
    }

    // Only the current key exists; a note under any other key id cannot be decrypted.
    byte[]|error file = sickNote.keyId == sick_note:CURRENT_KEY_ID
        ? sick_note:decrypt({content, iv, keyId: sickNote.keyId}, sickNoteKey)
        : error(string `No key is configured for key id ${sickNote.keyId}.`);
    if file is error {
        log:printError(ERR_MSG_SICK_NOTE_UNREADABLE, file, leaveId = leaveId);
        return <http:InternalServerError>{
            body: {
                message: ERR_MSG_SICK_NOTE_UNREADABLE
            }
        };
    }
    error? recorded = database:recordSickNoteDownload(sickNote.id, leaveId, requesterEmail);
    if recorded is error {
        string errMsg = "Error occurred while recording the sick note download";
        log:printError(errMsg, recorded, leaveId = leaveId);
        return <http:InternalServerError>{
            body: {
                message: errMsg
            }
        };
    }
    log:printInfo("Sick note downloaded", leaveId = leaveId, downloadedBy = requesterEmail);

    http:Response response = new;
    response.setBinaryPayload(file, sickNote.contentType);
    response.setHeader(mime:CONTENT_DISPOSITION,
            string `attachment; filename="${sick_note:downloadFileName(leaveId, sickNote.contentType)}"`);
    response.setHeader(http:CACHE_CONTROL, http:NO_STORE);
    response.setHeader("X-Content-Type-Options", "nosniff");
    return response;
}
