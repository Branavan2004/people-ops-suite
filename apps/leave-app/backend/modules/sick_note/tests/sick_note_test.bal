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

import ballerina/test;

@test:Config {}
function readUpToReturnsABodyUpToTheLimit() returns error? {
    byte[][] parts = [[1, 2], [3, 4]];
    test:assertEquals(check readUpTo(parts.toStream(), 4), <byte[]>[1, 2, 3, 4]);
}

@test:Config {}
function readUpToRefusesABodyOverTheLimit() {
    byte[][] parts = [[1, 2], [3, 4], [5]];
    test:assertTrue(readUpTo(parts.toStream(), 4) is error);
}

@test:Config {}
function contentDecidesTheType() {
    test:assertEquals(detectContentType([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]), "application/pdf");
    test:assertEquals(detectContentType([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]), "image/png");
    test:assertEquals(detectContentType([0xFF, 0xD8, 0xFF, 0xE0]), "image/jpeg");
    string|error exe = detectContentType([0x4D, 0x5A, 0x90, 0x00]); // "MZ", a Windows executable named note.pdf
    test:assertEquals((<error>exe).message(), "Send the sick note as a PDF, JPG or PNG file.");
}

@test:Config {}
function emptyAndOversizedFilesAreRefused() {
    test:assertEquals((<error>detectContentType([])).message(), "The sick note is empty.");
    byte[] tooBig = [0x25, 0x50, 0x44, 0x46, 0x2D];
    tooBig.setLength(MAX_SICK_NOTE_BYTES + 1);
    test:assertEquals((<error>detectContentType(tooBig)).message(), "The sick note must be at most 5 MB.");
    byte[] exactlyMax = [0x25, 0x50, 0x44, 0x46, 0x2D];
    exactlyMax.setLength(MAX_SICK_NOTE_BYTES);
    test:assertEquals(detectContentType(exactlyMax), "application/pdf");
}

@test:Config {}
function base64NotesDecodeToTheFile() returns error? {
    byte[] note = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x00, 0xFF, 0x80];
    test:assertEquals(check decodeNote(note.toBase64()), note);
    byte[] empty = check decodeNote("");
    test:assertEquals(empty.length(), 0);
}

@test:Config {}
function unreadableBase64NotesAreRefused() {
    string unreadable = "The sick note could not be read from the request.";
    test:assertEquals((<error>decodeNote("not base64!")).message(), unreadable);
    // The data URL prefix a browser's FileReader adds is not part of the file.
    test:assertEquals((<error>decodeNote("data:application/pdf;base64,JVBERi0=")).message(), unreadable);
}

@test:Config {}
function base64OfAFileOver5MbIsRefused() returns error? {
    byte[] exactlyMax = [0x25, 0x50, 0x44, 0x46, 0x2D];
    exactlyMax.setLength(MAX_SICK_NOTE_BYTES);
    string atLimit = exactlyMax.toBase64();
    test:assertEquals(atLimit.length(), MAX_SICK_NOTE_BASE64_LENGTH);
    test:assertEquals((check decodeNote(atLimit)).length(), MAX_SICK_NOTE_BYTES);
    string tooLarge = "The sick note must be at most 5 MB.";
    // One byte over 5 MB has base64 of the same length, so only the decoded size catches it.
    byte[] oneOver = exactlyMax.clone();
    oneOver.setLength(MAX_SICK_NOTE_BYTES + 1);
    test:assertEquals(oneOver.toBase64().length(), MAX_SICK_NOTE_BASE64_LENGTH);
    test:assertEquals((<error>decodeNote(oneOver.toBase64())).message(), tooLarge);
    // Longer text is refused before it is decoded.
    byte[] wellOver = exactlyMax.clone();
    wellOver.setLength(MAX_SICK_NOTE_BYTES + 3);
    test:assertEquals((<error>decodeNote(wellOver.toBase64())).message(), tooLarge);
}

@test:Config {}
function keyMustBe32Bytes() {
    byte[] key = [];
    key.setLength(32);
    test:assertEquals(decodeKey(key.toBase64()), key);
    byte[] short = [];
    short.setLength(16);
    test:assertTrue(decodeKey(short.toBase64()) is error);
    test:assertTrue(decodeKey("not base64!") is error);
}

@test:Config {}
function encryptionRoundTripsAndUsesAFreshIv() returns error? {
    byte[] key = testKey();
    byte[] note = "%PDF-1.7 sick note".toBytes();
    EncryptedSickNote first = check encrypt(note, key);
    EncryptedSickNote second = check encrypt(note, key);
    test:assertEquals(first.iv.length(), 12);
    test:assertEquals(first.keyId, CURRENT_KEY_ID);
    test:assertNotEquals(first.iv, second.iv);
    test:assertNotEquals(first.content, note);
    test:assertEquals(check decrypt(first, key), note);
}

@test:Config {}
function tamperedOrWrongKeyNotesDoNotDecrypt() returns error? {
    byte[] key = testKey();
    EncryptedSickNote stored = check encrypt("%PDF-1.7".toBytes(), key);
    byte[] tampered = stored.content.clone();
    tampered[0] = <byte>(tampered[0] ^ 0x01);
    test:assertTrue(decrypt({content: tampered, iv: stored.iv, keyId: stored.keyId}, key) is error);
    byte[] otherKey = testKey();
    otherKey[0] = <byte>(otherKey[0] ^ 0x01);
    test:assertTrue(decrypt(stored, otherKey) is error);
}

@test:Config {}
function onlyA32ByteKeyEncryptsOrDecrypts() returns error? {
    // crypto would accept this 16-byte key as AES-128.
    byte[] aes128Key = testKey().slice(0, 16);
    string keyError = "The sick note key must be 32 bytes for AES-256.";
    test:assertEquals((<error>encrypt("%PDF-1.7".toBytes(), aes128Key)).message(), keyError);
    EncryptedSickNote stored = check encrypt("%PDF-1.7".toBytes(), testKey());
    test:assertEquals((<error>decrypt(stored, aes128Key)).message(), keyError);
}

@test:Config {}
function onlyTheApplicantAndSickNoteRolesMayDownload() {
    string[] roles = ["people-ops"];
    test:assertTrue(canDownload("jane@wso2.com", ["wso2-everyone"], "jane@wso2.com", roles));
    test:assertTrue(canDownload("hr@wso2.com", ["people-ops"], "jane@wso2.com", roles));
    test:assertFalse(canDownload("lead@wso2.com", ["wso2-everyone"], "jane@wso2.com", roles));
    test:assertFalse(canDownload("hr@wso2.com", ["people-ops"], "jane@wso2.com", []));
}

@test:Config {}
function canDownloadIgnoresEmailCase() {
    test:assertTrue(canDownload("jane.doe@wso2.com", [], "Jane.Doe@wso2.com", []));
}

@test:Config {}
function aBlankRequesterMayNotDownload() {
    test:assertFalse(canDownload("", [], "", []));
    test:assertFalse(canDownload("  ", [], "  ", []));
}

@test:Config {}
function downloadNamesHideTheOriginalName() {
    test:assertEquals(downloadFileName(42, "application/pdf"), "sick-note-42.pdf");
    test:assertEquals(downloadFileName(7, "image/jpeg"), "sick-note-7.jpg");
    test:assertEquals(downloadFileName(9, "image/png"), "sick-note-9.png");
}

// 32 bytes with values 0-31.
function testKey() returns byte[] {
    byte[] key = [];
    foreach int i in 0 ..< 32 {
        key.push(<byte>i);
    }
    return key;
}
