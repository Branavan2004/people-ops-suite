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
import ballerina/mime;
import ballerina/test;
import ballerina/time;

const byte[] PDF_BYTES = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34];

// The first bytes of a PNG image of the given size: the signature, then the header chunk with the width and height.
function pngBytes(int width, int height) returns byte[] => [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, <byte>(width / 256), <byte>(width % 256), 0x00, 0x00, <byte>(height / 256), <byte>(height % 256)
];

// The first bytes of a JPEG image of the given size: a "start of frame" segment holds the height, then the width.
function jpegBytes(int width, int height) returns byte[] => [
    0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x11, 0x08, <byte>(height / 256), <byte>(height % 256), <byte>(width / 256),
    <byte>(width % 256), 0x03, 0x01, 0x22, 0x00
];

function contact(string name, string mobile) returns map<json> => {
    "name": name,
    "relationship": "Parent",
    "address": "42 Lake Road, Negombo",
    "mobileNumber": mobile,
    "landNumber": ""
};

function validDetails() returns map<json> => {
    "title": "Mr",
    "firstName": "Isuranga",
    "fullName": "Isuranga Peter Warnasooriya",
    "preferredName": "Isuranga",
    "surname": "Warnasooriya",
    "initials": "I. P.",
    "nameWithInitials": "I.P. Warnasooriya",
    "gender": "Male",
    "dateOfBirth": "1999-03-12",
    "idNumber": "199912345678",
    "civilStatus": "Single",
    "tshirtSize": "M",
    "homeAddress": "42 Lake Road, Negombo",
    "temporaryAddress": "",
    "mobileNumber": "+94 77 123 4567",
    "landNumber": "",
    "personalEmail": "isuranga@example.com",
    "businessInterest": "No",
    "dependants": [
        {"relationship": "Parent", "name": "Nimal Warnasooriya", "dateOfBirth": "1965-05-01", "idNumber": "196512345678"}
    ],
    "emergencyContacts": [contact("Nimal Warnasooriya", "+94 71 987 6543"), contact("Kamala Warnasooriya", "+94 72 111 2222")],
    "bank": {"bank": "Commercial Bank", "branch": "Negombo", "accountNumber": "0012345678"},
    "highestQualification": "BSc in Computer Science",
    "university": "University of Moratuwa",
    "githubUserId": ""
};

function withDetail(string name, json value) returns string {
    map<json> details = validDetails();
    details[name] = value;
    return details.toJsonString();
}

function documentsRequest(map<byte[]> files, boolean declared = true, string? detailsText = validDetails().toJsonString())
        returns http:Request {
    mime:Entity[] parts = [];
    if detailsText is string {
        mime:Entity details = new;
        details.setContentDisposition(mime:getContentDispositionObject("form-data; name=\"details\""));
        details.setText(detailsText);
        parts.push(details);
    }
    if declared {
        mime:Entity declaration = new;
        declaration.setContentDisposition(mime:getContentDispositionObject("form-data; name=\"declaration\""));
        declaration.setText("true");
        parts.push(declaration);
    }
    foreach [string, byte[]] [key, content] in files.entries() {
        mime:Entity file = new;
        file.setContentDisposition(mime:getContentDispositionObject(string `form-data; name="${key}"; filename="${key}"`));
        file.setByteArray(content, "application/octet-stream");
        parts.push(file);
    }
    http:Request req = new;
    req.setBodyParts(parts, "multipart/form-data");
    return req;
}

function requiredFiles() returns map<byte[]> {
    map<byte[]> files = {};
    foreach DocumentSpec spec in REQUIRED_DOCUMENTS {
        if spec.required {
            files[spec.key] = spec.types.indexOf("pdf") is int ? PDF_BYTES : pngBytes(175, 175);
        }
    }
    return files;
}

@test:Config {}
function aCompleteSubmissionIsAccepted() {
    Submission|string result = parseDocuments(documentsRequest(requiredFiles()));
    if result is string {
        test:assertFail("A complete submission was refused: " + result);
    }
    test:assertEquals(result.documents.length(), requiredFiles().length());
    test:assertEquals(result.documents[0].extension, "pdf");
    test:assertEquals(result.documents[0].contentType, "application/pdf");
    test:assertEquals(result.details.fullName, "Isuranga Peter Warnasooriya");
    test:assertEquals(result.details.mobileNumber, "+94771234567");
    test:assertEquals(result.details.emergencyContacts[0].mobileNumber, "+94719876543");
    test:assertEquals(result.details.bank.accountNumber, "0012345678");
}

@test:Config {}
function theOptionalPoliceReportIsAcceptedWhenSent() {
    map<byte[]> files = requiredFiles();
    files["policeReport"] = PDF_BYTES;
    Submission|string result = parseDocuments(documentsRequest(files));
    test:assertTrue(result is Submission && result.documents.length() == requiredFiles().length() + 1);
    test:assertTrue(parseDocuments(documentsRequest(requiredFiles())) is Submission);
}

@test:Config {}
function aSubmissionWithoutTheDeclarationIsRefused() {
    Submission|string result = parseDocuments(documentsRequest(requiredFiles(), false));
    test:assertTrue(result is string && result.includes("declaration"));
}

@test:Config {}
function aMissingRequiredDocumentIsRefused() {
    map<byte[]> files = requiredFiles();
    _ = files.remove("identityDocument");
    Submission|string result = parseDocuments(documentsRequest(files));
    test:assertTrue(result is string && result.includes("is required"));
}

@test:Config {}
function aRequiredDocumentAlreadySentNeedNotBeSentAgain() {
    map<byte[]> files = requiredFiles();
    _ = files.remove("identityDocument");
    test:assertTrue(parseDocuments(documentsRequest(files)) is string);
    test:assertTrue(parseDocuments(documentsRequest(files), ["identityDocument"]) is Submission);
}

@test:Config {}
function aFileWithAnUnknownNameIsRefused() {
    map<byte[]> files = requiredFiles();
    files["../other"] = PDF_BYTES;
    test:assertTrue(parseDocuments(documentsRequest(files)) is string);
}

@test:Config {}
function aFileOfTheWrongTypeIsRefused() {
    map<byte[]> files = requiredFiles();
    files["identityDocument"] = "<script>alert(1)</script>".toBytes();
    Submission|string result = parseDocuments(documentsRequest(files));
    test:assertTrue(result is string && result.includes("PDF file"));
}

@test:Config {}
function aPictureIsRefusedForAPdfSlot() {
    map<byte[]> files = requiredFiles();
    files["identityDocument"] = pngBytes(175, 175);
    Submission|string result = parseDocuments(documentsRequest(files));
    test:assertTrue(result is string && result.includes("PDF file"));
}

@test:Config {}
function aPdfIsRefusedForAPictureSlot() {
    map<byte[]> files = requiredFiles();
    files["profilePicture"] = PDF_BYTES;
    Submission|string result = parseDocuments(documentsRequest(files));
    test:assertTrue(result is string && result.includes("JPG or PNG image"));
}

@test:Config {}
function anEmptyFileIsRefused() {
    map<byte[]> files = requiredFiles();
    files["identityDocument"] = [];
    Submission|string result = parseDocuments(documentsRequest(files));
    test:assertTrue(result is string && result.includes("is empty"));
}

@test:Config {}
function aFileOverTheLimitIsRefused() {
    byte[] large = [];
    foreach int index in 0 ... MAX_FILE_BYTES {
        large.push(index < PDF_BYTES.length() ? PDF_BYTES[index] : 0x20);
    }
    map<byte[]> files = requiredFiles();
    files["identityDocument"] = large;
    Submission|string result = parseDocuments(documentsRequest(files));
    test:assertTrue(result is string && result.includes("or smaller"));
}

@test:Config {}
function aProfilePictureMustBeSquareAndBigEnough() {
    map<byte[]> files = requiredFiles();
    files["profilePicture"] = jpegBytes(300, 300);
    test:assertTrue(parseDocuments(documentsRequest(files)) is Submission);

    files["profilePicture"] = pngBytes(100, 100);
    Submission|string small = parseDocuments(documentsRequest(files));
    test:assertTrue(small is string && small.includes("175 x 175"));

    files["profilePicture"] = pngBytes(300, 200);
    test:assertTrue(parseDocuments(documentsRequest(files)) is string);
}

@test:Config {}
function theDetailsAreRequiredAndMustBeReadable() {
    Submission|string missing = parseDocuments(documentsRequest(requiredFiles(), true, ()));
    test:assertTrue(missing is string && missing.includes("personal details"));
    test:assertTrue(parseDocuments(documentsRequest(requiredFiles(), true, "not json")) is string);
    test:assertTrue(parseDocuments(documentsRequest(requiredFiles(), true, "{\"title\": \"Mr\"}")) is string);
}

@test:Config {}
function aMissingPersonalDetailIsRefused() {
    Submission|string result = parseDocuments(documentsRequest(requiredFiles(), true, withDetail("fullName", "")));
    test:assertTrue(result is string && result.includes("full name"));
    test:assertTrue(parseDocuments(documentsRequest(requiredFiles(), true, withDetail("firstName", ""))) is string);
}

@test:Config {}
function aPersonalDetailThatIsNotValidIsRefused() {
    string[] invalid = [
        withDetail("title", "Sir"),
        withDetail("gender", "unknown"),
        withDetail("idNumber", "123"),
        withDetail("idNumber", "AB!@#$%^&*"),
        withDetail("dateOfBirth", "2999-01-01"),
        withDetail("dateOfBirth", "2020-02-30"),
        withDetail("dateOfBirth", "12/03/1999"),
        withDetail("civilStatus", "Complicated"),
        withDetail("businessInterest", "Maybe"),
        withDetail("businessInterest", ""),
        withDetail("tshirtSize", "Tiny"),
        withDetail("mobileNumber", "0771234567"),
        withDetail("landNumber", "abc"),
        withDetail("personalEmail", "not-an-email"),
        withDetail("githubUserId", "bad id!"),
        withDetail("bank", {"bank": "Commercial Bank", "branch": "Negombo", "accountNumber": "12ab"}),
        withDetail("bank", {"bank": "", "branch": "Negombo", "accountNumber": "0012345678"}),
        withDetail("emergencyContacts", [contact("Nimal Warnasooriya", "+94 71 987 6543")]),
        withDetail("emergencyContacts", [contact("Nimal", "+94 71 987 6543"), contact("Kamala", "12345")]),
        withDetail("dependants", [{"relationship": "Cousin", "name": "A", "dateOfBirth": "1990-01-01", "idNumber": ""}])
    ];
    foreach string details in invalid {
        test:assertTrue(parseDocuments(documentsRequest(requiredFiles(), true, details)) is string, details);
    }
}

@test:Config {}
function theOptionalDetailsMayBeLeftOut() {
    map<json> details = validDetails();
    details["dependants"] = [];
    details["temporaryAddress"] = "";
    details["landNumber"] = "";
    details["githubUserId"] = "";
    test:assertTrue(parseDocuments(documentsRequest(requiredFiles(), true, details.toJsonString())) is Submission);
}

@test:Config {}
function atMostTwoDependantsAreAccepted() {
    map<json> parent = {"relationship": "Parent", "name": "Nimal Warnasooriya", "dateOfBirth": "1965-05-01", "idNumber": "196512345678"};
    map<json> other = {"relationship": "Parent", "name": "Kamala Warnasooriya", "dateOfBirth": "1967-03-02", "idNumber": "196712345678"};
    test:assertEquals(MAX_DEPENDANTS, 2);
    test:assertTrue(parseDocuments(documentsRequest(requiredFiles(), true, withDetail("dependants", [parent, other]))) is Submission);
    string tooMany = withDetail("dependants", [parent, other, parent]);
    test:assertEquals(parseDocuments(documentsRequest(requiredFiles(), true, tooMany)), "At most 2 dependants can be added.");
}

@test:Config {}
function aChildMayHaveNoIdNumberAndAGithubIdIsAccepted() {
    string text = withDetail("dependants",
        [{"relationship": "Child", "name": "Sithum Warnasooriya", "dateOfBirth": "2022-01-15", "idNumber": ""}]);
    test:assertTrue(parseDocuments(documentsRequest(requiredFiles(), true, text)) is Submission);
    test:assertTrue(parseDocuments(documentsRequest(requiredFiles(), true, withDetail("githubUserId", "isuranga-w"))) is Submission);
}

@test:Config {}
function anIdNumberOfAnyCountryIsAcceptedInCapitals() {
    Submission|string result = parseDocuments(documentsRequest(requiredFiles(), true, withDetail("idNumber", "991234567v")));
    test:assertTrue(result is Submission && result.details.idNumber == "991234567V");
}

@test:Config {}
function theDateOfBirthMustBeARealPastDate() {
    test:assertTrue(isValidDateOfBirth("1999-03-12"));
    test:assertFalse(isValidDateOfBirth("2999-01-01"));
    test:assertFalse(isValidDateOfBirth("1999-13-01"));
    test:assertFalse(isValidDateOfBirth("1899-01-01"));
    test:assertTrue(isValidPastDate("1925-01-01", 1900));
}

@test:Config {}
function theSizeOfAnImageIsReadFromItsHeader() {
    test:assertEquals(imageSizeOf(pngBytes(175, 200), "png"), [175, 200]);
    test:assertEquals(imageSizeOf(jpegBytes(640, 480), "jpg"), [640, 480]);
    test:assertEquals(imageSizeOf([0x89, 0x50, 0x4E, 0x47], "png"), ());
}

@test:Config {}
function typeIsReadFromTheFirstBytes() {
    test:assertEquals(fileTypeOf([0x25, 0x50, 0x44, 0x46, 0x2D]), "pdf");
    test:assertEquals(fileTypeOf([0xFF, 0xD8, 0xFF, 0xE0]), "jpg");
    test:assertEquals(fileTypeOf([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]), "png");
}

@test:Config {}
function otherContentIsNotAccepted() {
    test:assertEquals(fileTypeOf([0x4D, 0x5A, 0x90, 0x00]), ());
    test:assertEquals(fileTypeOf("<script>".toBytes()), ());
    test:assertEquals(fileTypeOf([]), ());
    test:assertEquals(fileTypeOf([0x89, 0x50, 0x4E, 0x47]), ());
    // A zip file, which Word and Excel files are, is not accepted.
    test:assertEquals(fileTypeOf([0x50, 0x4B, 0x03, 0x04, 0x00]), ());
}

@test:Config {}
function contentTypeFollowsTheDetectedType() {
    test:assertEquals(contentTypeOf("pdf"), "application/pdf");
    test:assertEquals(contentTypeOf("png"), "image/png");
    test:assertEquals(contentTypeOf("jpg"), "image/jpeg");
}

@test:Config {}
function onlyRequestedDocumentsAreKnown() {
    test:assertTrue(specOf("identityDocument") is DocumentSpec);
    test:assertEquals(specOf("detailsSheet"), ());
    test:assertEquals(specOf("../etc/passwd"), ());
    test:assertEquals(specOf(""), ());
}

@test:Config {}
function nothingCanBeChangedWhileNoDaysAreAllowed() {
    Manifest manifest = manifestMadeAt(time:utcToString(time:utcNow()));
    test:assertFalse(canEdit(manifest));
    test:assertEquals(editableUntil(manifest), ());
}

// A submission made at the given time, with nothing else of interest.
function manifestMadeAt(string submittedAt) returns Manifest => {
    applicationId: "1",
    candidateName: "Ada Lovelace",
    folder: "applications/Ada Lovelace - 1",
    details: <PersonalDetails>{
        title: "", firstName: "", surname: "", fullName: "", preferredName: "", initials: "", nameWithInitials: "",
        gender: "", dateOfBirth: "", idNumber: "", civilStatus: "", tshirtSize: "", homeAddress: "",
        temporaryAddress: "", mobileNumber: "", landNumber: "", personalEmail: "", businessInterest: "",
        dependants: [], emergencyContacts: [], bank: {bank: "", branch: "", accountNumber: ""},
        highestQualification: "", university: "", githubUserId: ""
    },
    files: {},
    declared: true,
    submittedAt,
    updatedAt: submittedAt
};

@test:Config {}
function eachSubmissionHasItsOwnTimeToBeChanged() {
    time:Utc now = time:utcNow();
    // Made two days ago with a week allowed: five days remain. Made ten days ago: the week has run out.
    Manifest recent = manifestMadeAt(time:utcToString(time:utcAddSeconds(now, -2 * 86400d)));
    Manifest old = manifestMadeAt(time:utcToString(time:utcAddSeconds(now, -10 * 86400d)));

    time:Utc? recentUntil = editableUntilAfter(recent, 7);
    time:Utc? oldUntil = editableUntilAfter(old, 7);
    test:assertTrue(recentUntil is time:Utc && time:utcDiffSeconds(recentUntil, now) > 4 * 86400d);
    test:assertTrue(oldUntil is time:Utc && time:utcDiffSeconds(oldUntil, now) < 0d);
    // The two submissions differ even though the setting is the same for everyone.
    test:assertNotEquals(recentUntil, oldUntil);
}

@test:Config {}
function sasTokenIsUsedWithoutALeadingQuestionMark() {
    test:assertEquals(sasQuery(), "sv=test&sig=test");
}

@test:Config {}
function aSubmissionIsFiledUnderTheCandidatesNameAndTheApplicationId() {
    string folder = folderOf("Ada Lovelace", "123");
    test:assertEquals(folder, "applications/Ada Lovelace - 123");
    test:assertEquals(fileName(folder, "Ada Lovelace", "identityDocument", "pdf"),
        "applications/Ada Lovelace - 123/Ada Lovelace - Identity document.pdf");
    test:assertEquals(fileName(folder, "Ada Lovelace", "profilePicture", "png"),
        "applications/Ada Lovelace - 123/Ada Lovelace - Profile picture.png");
    test:assertEquals(fileName(folder, "Ada Lovelace", "funPicture", "jpg"),
        "applications/Ada Lovelace - 123/Ada Lovelace - Fun picture of you.jpg");
}

@test:Config {}
function aNameThatAPathRejectsIsMadeSafe() {
    test:assertEquals(safeName("Ada/Love:lace?", "Candidate"), "Ada Love lace");
    test:assertEquals(safeName("  ../Ada   Lovelace.. ", "Candidate"), "Ada Lovelace");
    test:assertEquals(safeName("///", "Candidate"), "Candidate");
    test:assertEquals(safeName("", "Candidate"), "Candidate");
    // Without its slashes, ".." in the middle of a name is only text and cannot climb out of the folder.
    string folder = folderOf("Ada/../Lovelace", "7");
    test:assertEquals(folder, "applications/Ada .. Lovelace - 7");
    test:assertEquals(re `/`.split(folder).length(), 2);
}

@test:Config {}
function aBlobPathEncodesTheNameButKeepsItsFolders() returns error? {
    string path = check blobPath("applications/Ada Lovelace - 123/Ada Lovelace - Identity document.pdf");
    test:assertTrue(path.startsWith("/test-container/applications/Ada%20Lovelace%20-%20123/"), path);
    test:assertTrue(path.endsWith("Identity%20document.pdf?sv=test&sig=test"), path);
    string accented = check blobPath("applications/José Núñez - 5/a.pdf");
    test:assertFalse(accented.includes("é"));
    test:assertTrue(accented.includes("Jos%C3%A9%20N%C3%BA%C3%B1ez"), accented);
}
