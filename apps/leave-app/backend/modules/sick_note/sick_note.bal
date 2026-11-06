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

import ballerina/crypto;
import ballerina/io;
import ballerina/lang.array;
import ballerina/mime;
import ballerina/random;

# Largest sick note accepted, in bytes (5 MB).
public const MAX_SICK_NOTE_BYTES = 5242880;

# Message for a sick note over `MAX_SICK_NOTE_BYTES`.
public const ERR_MSG_SICK_NOTE_TOO_LARGE = "The sick note must be at most 5 MB.";

# Longest base64 text accepted for a sick note: the base64 length of a 5 MB file.
public const MAX_SICK_NOTE_BASE64_LENGTH = (MAX_SICK_NOTE_BYTES + 2) / 3 * 4;

# Content types accepted for a sick note.
public final readonly & string[] SICK_NOTE_CONTENT_TYPES = [mime:APPLICATION_PDF, mime:IMAGE_JPEG, mime:IMAGE_PNG];

# Id of the encryption key used for new sick notes.
public const CURRENT_KEY_ID = 1;

const KEY_LENGTH = 32;
const IV_LENGTH = 12;
const GCM_TAG_BITS = 128;

final readonly & byte[] PDF_PREFIX = [0x25, 0x50, 0x44, 0x46, 0x2D];
final readonly & byte[] PNG_PREFIX = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
final readonly & byte[] JPEG_PREFIX = [0xFF, 0xD8, 0xFF];

# A sick note as it is stored: AES-256-GCM ciphertext (with its tag), the IV and the key id.
public type EncryptedSickNote record {|
    # Ciphertext followed by the 128-bit authentication tag
    byte[] content;
    # 12-byte initialization vector, unique per note
    byte[] iv;
    # Id of the key that encrypted the note
    int keyId;
|};

# Check the size of a sick note and detect its content type from its first bytes.
# The file name and the type the browser reports are not trusted.
#
# + content - The uploaded file content
# + return - One of `SICK_NOTE_CONTENT_TYPES`, or an error when the file is empty, too big or not a PDF, JPG or PNG
public isolated function detectContentType(byte[] content) returns string|error {
    if content.length() == 0 {
        return error("The sick note is empty.");
    }
    if content.length() > MAX_SICK_NOTE_BYTES {
        return error(ERR_MSG_SICK_NOTE_TOO_LARGE);
    }
    if startsWith(content, PDF_PREFIX) {
        return mime:APPLICATION_PDF;
    }
    if startsWith(content, PNG_PREFIX) {
        return mime:IMAGE_PNG;
    }
    if startsWith(content, JPEG_PREFIX) {
        return mime:IMAGE_JPEG;
    }
    return error("Send the sick note as a PDF, JPG or PNG file.");
}

# Decode a sick note sent as base64 text. Text longer than a 5 MB file's base64 is refused before it is decoded. The
# decoded size is checked too, as a file just over 5 MB can have base64 of the same length.
#
# + base64Note - The file as base64 text
# + return - The file content, or an error whose message can be shown to the user
public isolated function decodeNote(string base64Note) returns byte[]|error {
    if base64Note.length() > MAX_SICK_NOTE_BASE64_LENGTH {
        return error(ERR_MSG_SICK_NOTE_TOO_LARGE);
    }
    byte[]|error content = array:fromBase64(base64Note);
    if content is error {
        return error("The sick note could not be read from the request.");
    }
    if content.length() > MAX_SICK_NOTE_BYTES {
        return error(ERR_MSG_SICK_NOTE_TOO_LARGE);
    }
    return content;
}

# Read a request body, stopping as soon as it passes the limit, so an oversized body is never held whole. A declared
# length can be missing, and the listener's `maxEntityBodySize` does not apply to HTTP/2.
#
# + chunks - The body as it arrives
# + maxBytes - Largest body allowed, in bytes
# + return - The body, or an error once it passes `maxBytes` or if it could not be read
public isolated function readUpTo(stream<byte[], io:Error?> chunks, int maxBytes) returns byte[]|error {
    byte[] body = [];
    while true {
        record {|byte[] value;|}|io:Error? next = chunks.next();
        if next !is record {|byte[] value;|} {
            return next ?: body;
        }
        if body.length() + next.value.length() > maxBytes {
            return error(string `The body is over ${maxBytes} bytes.`);
        }
        body.push(...next.value);
    }
}

# Decode the base64 encryption key.
#
# + base64Key - Base64 text of the 32-byte key
# + return - The 32 key bytes, or an error when the text is not base64 of exactly 32 bytes
public isolated function decodeKey(string base64Key) returns byte[]|error {
    byte[]|error key = array:fromBase64(base64Key);
    if key is error || key.length() != KEY_LENGTH {
        return error("sickNoteEncryptionKey must be 32 bytes, base64-encoded.");
    }
    return key;
}

# Encrypt a sick note with AES-256-GCM and a fresh random 12-byte IV.
#
# + content - The plain file content
# + key - The 32-byte key from `decodeKey`
# + return - The encrypted note to store, or an error, including when the key is not 32 bytes
public isolated function encrypt(byte[] content, byte[] key) returns EncryptedSickNote|error {
    check checkKeyLength(key);
    byte[] iv = check randomIv();
    byte[] encrypted = check crypto:encryptAesGcm(content, key, iv, crypto:NONE, GCM_TAG_BITS);
    return {content: encrypted, iv, keyId: CURRENT_KEY_ID};
}

# Decrypt a stored sick note. Fails if the content was altered or the key is wrong.
#
# + note - The stored note
# + key - The 32-byte key for the note's key id
# + return - The plain file content, or an error, including when the key is not 32 bytes
public isolated function decrypt(EncryptedSickNote note, byte[] key) returns byte[]|error {
    check checkKeyLength(key);
    return crypto:decryptAesGcm(note.content, key, note.iv, crypto:NONE, GCM_TAG_BITS);
}

# Decide whether a user may download a sick note: the applicant, or a member of a configured People Ops role.
#
# + requesterEmail - Email of the user asking for the file
# + requesterGroups - Groups of the user asking for the file
# + applicantEmail - Email of the employee the leave belongs to
# + sickNoteRoles - Groups allowed to download any sick note
# + return - `true` when the download is allowed; never for a blank requester email
public isolated function canDownload(string requesterEmail, string[] requesterGroups, string applicantEmail,
        string[] sickNoteRoles) returns boolean {
    if requesterEmail.trim() == "" {
        return false;
    }
    if requesterEmail.toLowerAscii() == applicantEmail.toLowerAscii() {
        return true;
    }
    foreach string group in requesterGroups {
        if sickNoteRoles.indexOf(group) !is () {
            return true;
        }
    }
    return false;
}

# Build the download file name, which never reveals the name the employee uploaded.
#
# + leaveId - Id of the leave
# + contentType - One of `SICK_NOTE_CONTENT_TYPES`
# + return - `sick-note-<id>` followed by `.pdf`, `.jpg` or `.png`
public isolated function downloadFileName(int leaveId, string contentType) returns string {
    string extension = contentType == mime:APPLICATION_PDF ? "pdf" : contentType == mime:IMAGE_PNG ? "png" : "jpg";
    return string `sick-note-${leaveId}.${extension}`;
}

# Check that a key is 32 bytes. crypto also accepts 16- and 24-byte keys, which would quietly mean AES-128 or
# AES-192.
#
# + key - The key to check
# + return - An error if the key is not 32 bytes
isolated function checkKeyLength(byte[] key) returns error? {
    if key.length() != KEY_LENGTH {
        return error(string `The sick note key must be ${KEY_LENGTH} bytes for AES-256.`);
    }
}

# Check whether the content begins with the given bytes.
#
# + content - File content
# + prefix - Expected leading bytes
# + return - `true` if `content` starts with `prefix`
isolated function startsWith(byte[] content, byte[] prefix) returns boolean {
    if content.length() < prefix.length() {
        return false;
    }
    foreach int i in 0 ..< prefix.length() {
        if content[i] != prefix[i] {
            return false;
        }
    }
    return true;
}

# Generate a random 12-byte IV. random:createIntInRange is a time-seeded LCG that the library documents as not
# secure, so it is not used here. random:createDecimal draws from java.security.SecureRandom.
#
# + return - The IV, or an error
isolated function randomIv() returns byte[]|error {
    byte[] iv = [];
    foreach int _ in 0 ..< IV_LENGTH {
        int value = <int>(random:createDecimal() * 256.0);
        iv.push(<byte>(value > 255 ? 255 : value));
    }
    return iv;
}
