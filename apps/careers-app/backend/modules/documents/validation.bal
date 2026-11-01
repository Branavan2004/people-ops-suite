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

import ballerina/http;
import ballerina/lang.value;
import ballerina/mime;
import ballerina/time;

// The number of a national identity card or a passport, whichever country issued it: four to thirty letters, digits,
// spaces, slashes or hyphens, starting with a letter or a digit.
final string:RegExp ID_NUMBER_PATTERN = re `[A-Z0-9][A-Z0-9 /-]{3,29}`;

final string:RegExp DATE_PATTERN = re `[0-9]{4}-[0-9]{2}-[0-9]{2}`;

// A bank account number is kept as text.
final string:RegExp ACCOUNT_NUMBER_PATTERN = re `[0-9]{5,20}`;

final string:RegExp GITHUB_PATTERN = re `[A-Za-z0-9-]{1,39}`;

const MAX_FULL_NAME_LENGTH = 150;
const MAX_NAME_LENGTH = 100;
const MAX_ADDRESS_LENGTH = 300;
const MAX_QUALIFICATION_LENGTH = 200;
const MAX_UNIVERSITY_LENGTH = 255;

# The type of file the first bytes show: "pdf", "jpg" or "png". Nil for anything else.
public isolated function fileTypeOf(byte[] content) returns string? {
    if apply:isPdf(content) {
        return "pdf";
    }
    if content.length() >= 3 && content[0] == 0xFF && content[1] == 0xD8 && content[2] == 0xFF {
        return "jpg";
    }
    if content.length() >= 8 && content[0] == 0x89 && content[1] == 0x50 && content[2] == 0x4E
        && content[3] == 0x47 && content[4] == 0x0D && content[5] == 0x0A && content[6] == 0x1A
        && content[7] == 0x0A {
        return "png";
    }
    return ();
}

// The number a run of bytes spells, most significant byte first.
isolated function bigEndian(byte[] content, int offset, int count) returns int {
    int number = 0;
    foreach int index in offset ..< offset + count {
        number = number * 256 + content[index];
    }
    return number;
}

// The width and height of a PNG or JPEG image, read from its header. Nil when the header cannot be read.
isolated function imageSizeOf(byte[] content, string extension) returns [int, int]? {
    if extension == "png" {
        return content.length() < 24 ? () : [bigEndian(content, 16, 4), bigEndian(content, 20, 4)];
    }
    // A JPEG is a run of segments; the first "start of frame" segment holds the height, then the width.
    int position = 2;
    while position + 9 < content.length() {
        if content[position] != 0xFF {
            return ();
        }
        int marker = content[position + 1];
        if marker == 0xFF {
            position += 1;
        } else if marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9) {
            position += 2;
        } else if marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC {
            return [bigEndian(content, position + 7, 2), bigEndian(content, position + 5, 2)];
        } else {
            position += 2 + bigEndian(content, position + 2, 2);
        }
    }
    return ();
}

isolated function contentTypeOf(string extension) returns string {
    match extension {
        "pdf" => {
            return "application/pdf";
        }
        "png" => {
            return "image/png";
        }
    }
    return "image/jpeg";
}

isolated function typeMessage(DocumentSpec spec) returns string {
    if spec.types.indexOf("pdf") is int {
        return string `The ${spec.label} must be a PDF file.`;
    }
    return string `The ${spec.label} must be a JPG or PNG image.`;
}

isolated function specOf(string key) returns DocumentSpec? {
    foreach DocumentSpec spec in REQUIRED_DOCUMENTS {
        if spec.key == key {
            return spec;
        }
    }
    return ();
}

// A phone number without the spaces and hyphens people type in it.
isolated function compactPhone(string phone) returns string => re `[\s-]`.replaceAll(phone, "");

// The phone number in international format without spaces, or nil when it is not a valid number.
isolated function normalisedPhone(string phone) returns string? {
    string compact = compactPhone(phone.trim());
    return apply:isValidPhone(compact) ? compact : ();
}

isolated function isOneOf(string value, string[] options) returns boolean => options.indexOf(value) is int;

// Whether the text is a real date, written yyyy-mm-dd, that is not in the future and not before the given year.
isolated function isValidPastDate(string date, int earliestYear) returns boolean {
    if !DATE_PATTERN.isFullMatch(date) {
        return false;
    }
    int|error year = int:fromString(date.substring(0, 4));
    int|error month = int:fromString(date.substring(5, 7));
    int|error day = int:fromString(date.substring(8, 10));
    if year is error || month is error || day is error {
        return false;
    }
    if year < earliestYear {
        return false;
    }
    time:Date candidate = {year, month, day};
    if time:dateValidate(candidate) is error {
        return false;
    }
    time:Civil today = time:utcToCivil(time:utcNow());
    return year * 10000 + month * 100 + day <= today.year * 10000 + today.month * 100 + today.day;
}

isolated function isValidDateOfBirth(string date) returns boolean => isValidPastDate(date, 1940);

# Checks the personal details and returns them tidied (spaces trimmed, identity numbers in capitals, phone numbers
# without spaces), or a message for the candidate about the first detail that is missing or not valid.
isolated function validateDetails(PersonalDetails details) returns PersonalDetails|string {
    string title = details.title.trim();
    string firstName = details.firstName.trim();
    string fullName = details.fullName.trim();
    string preferredName = details.preferredName.trim();
    string surname = details.surname.trim();
    string initials = details.initials.trim();
    string nameWithInitials = details.nameWithInitials.trim();
    string gender = details.gender.trim();
    string dateOfBirth = details.dateOfBirth.trim();
    string idNumber = details.idNumber.trim().toUpperAscii();
    string civilStatus = details.civilStatus.trim();
    string tshirtSize = details.tshirtSize.trim();
    string homeAddress = details.homeAddress.trim();
    string temporaryAddress = details.temporaryAddress.trim();
    string landNumber = details.landNumber.trim();
    string personalEmail = details.personalEmail.trim();
    string businessInterest = details.businessInterest.trim();
    string highestQualification = details.highestQualification.trim();
    string university = details.university.trim();
    string githubUserId = details.githubUserId.trim();

    if !isOneOf(title, TITLES) {
        return "Choose your title.";
    }
    if firstName == "" || fullName == "" || preferredName == "" || surname == "" || initials == ""
        || nameWithInitials == "" {
        return "Fill in your first name, last name, full name, preferred name, initials and name with initials.";
    }
    if fullName.length() > MAX_FULL_NAME_LENGTH || nameWithInitials.length() > MAX_FULL_NAME_LENGTH
        || firstName.length() > MAX_NAME_LENGTH || preferredName.length() > MAX_NAME_LENGTH
        || surname.length() > MAX_NAME_LENGTH || initials.length() > 30 {
        return "One of the names is too long.";
    }
    if !isOneOf(gender, GENDERS) {
        return "Choose your gender.";
    }
    if !isValidDateOfBirth(dateOfBirth) {
        return "Enter a valid date of birth.";
    }
    if !ID_NUMBER_PATTERN.isFullMatch(idNumber) {
        return "Enter a valid identity document number.";
    }
    if !isOneOf(civilStatus, CIVIL_STATUSES) {
        return "Choose your civil status.";
    }
    if !isOneOf(tshirtSize, TSHIRT_SIZES) {
        return "Choose your T-shirt size.";
    }
    if homeAddress == "" {
        return "Enter your residential address.";
    }
    if homeAddress.length() > MAX_ADDRESS_LENGTH || temporaryAddress.length() > MAX_ADDRESS_LENGTH {
        return "An address is too long.";
    }
    string? mobileNumber = normalisedPhone(details.mobileNumber);
    if mobileNumber is () {
        return "Enter your mobile number with its country code.";
    }
    string normalisedLand = "";
    if landNumber != "" {
        string? land = normalisedPhone(landNumber);
        if land is () {
            return "Enter your land number with its country code, or leave it blank.";
        }
        normalisedLand = land;
    }
    if !apply:isValidEmail(personalEmail) {
        return "Enter a valid personal email address.";
    }
    if !isOneOf(businessInterest, YES_NO) {
        return "Say whether you have an interest in any commercial or business pursuit.";
    }

    if details.dependants.length() > MAX_DEPENDANTS {
        return string `At most ${MAX_DEPENDANTS} dependants can be added.`;
    }
    Dependant[] dependants = [];
    foreach int index in 0 ..< details.dependants.length() {
        Dependant dependant = details.dependants[index];
        string relationship = dependant.relationship.trim();
        string name = dependant.name.trim();
        string born = dependant.dateOfBirth.trim();
        string dependantId = dependant.idNumber.trim().toUpperAscii();
        if !isOneOf(relationship, DEPENDANT_RELATIONSHIPS) || name == "" || name.length() > MAX_FULL_NAME_LENGTH
            || !isValidPastDate(born, 1900) || (dependantId != "" && !ID_NUMBER_PATTERN.isFullMatch(dependantId)) {
            return string `Check the details of dependant ${index + 1}.`;
        }
        dependants.push({relationship, name, dateOfBirth: born, idNumber: dependantId});
    }

    if details.emergencyContacts.length() < 2 {
        return "Give at least two emergency contacts.";
    }
    if details.emergencyContacts.length() > MAX_EMERGENCY_CONTACTS {
        return string `At most ${MAX_EMERGENCY_CONTACTS} emergency contacts can be added.`;
    }
    EmergencyContact[] emergencyContacts = [];
    foreach int index in 0 ..< details.emergencyContacts.length() {
        EmergencyContact contact = details.emergencyContacts[index];
        string name = contact.name.trim();
        string relationship = contact.relationship.trim();
        string address = contact.address.trim();
        string? contactMobile = normalisedPhone(contact.mobileNumber);
        string contactLandText = contact.landNumber.trim();
        string? contactLand = contactLandText == "" ? "" : normalisedPhone(contactLandText);
        if contactMobile is () || contactLand is () {
            return string `Check the phone numbers of emergency contact ${index + 1}.`;
        }
        if name == "" || relationship == "" || address == "" || name.length() > MAX_FULL_NAME_LENGTH
            || relationship.length() > MAX_NAME_LENGTH || address.length() > MAX_ADDRESS_LENGTH {
            return string `Check the details of emergency contact ${index + 1}.`;
        }
        emergencyContacts.push({name, relationship, address, mobileNumber: contactMobile, landNumber: contactLand});
    }

    string bank = details.bank.bank.trim();
    string branch = details.bank.branch.trim();
    string accountNumber = details.bank.accountNumber.trim();
    if bank == "" || branch == "" || bank.length() > MAX_NAME_LENGTH || branch.length() > MAX_NAME_LENGTH {
        return "Enter the bank and the branch your salary should be paid to.";
    }
    if !ACCOUNT_NUMBER_PATTERN.isFullMatch(accountNumber) {
        return "Enter the account number as digits only, including any zeros at the start.";
    }

    if highestQualification == "" || highestQualification.length() > MAX_QUALIFICATION_LENGTH {
        return "Enter your highest qualification.";
    }
    if university == "" || university.length() > MAX_UNIVERSITY_LENGTH {
        return "Enter your university.";
    }
    if githubUserId != "" && !GITHUB_PATTERN.isFullMatch(githubUserId) {
        return "Enter a valid GitHub user ID, or leave it blank.";
    }

    return {
        title,
        firstName,
        surname,
        fullName,
        preferredName,
        initials,
        nameWithInitials,
        gender,
        dateOfBirth,
        idNumber,
        civilStatus,
        tshirtSize,
        homeAddress,
        temporaryAddress,
        mobileNumber,
        landNumber: normalisedLand,
        personalEmail,
        businessInterest,
        dependants,
        emergencyContacts,
        bank: {bank, branch, accountNumber},
        highestQualification,
        university,
        githubUserId
    };
}

# Reads the multipart form, returning a message for the candidate when a file is missing, unknown, too large or of
# a type that is not accepted, or when a personal detail is missing or not valid, or the declaration is missing. A
# required document that was already sent need not be sent again. Every file is checked before any of them is stored.
public isolated function parseDocuments(http:Request req, string[] alreadySent = []) returns Submission|string {
    mime:Entity[]|http:ClientError parts = req.getBodyParts();
    if parts is http:ClientError {
        return "The documents must be sent as a multipart form.";
    }
    // The files, the personal details and the declaration.
    if parts.length() > MAX_FILES + 2 {
        return "Too many parts were sent.";
    }

    UploadedDocument[] documents = [];
    map<boolean> received = {};
    string detailsText = "";
    int total = 0;
    int fileCount = 0;
    boolean declared = false;
    foreach mime:Entity part in parts {
        string fieldName = part.getContentDisposition().name;
        if fieldName == DECLARATION_FIELD {
            string|mime:ParserError text = part.getText();
            declared = text is string && text.trim() == "true";
            continue;
        }
        if fieldName == DETAILS_FIELD {
            string|mime:ParserError text = part.getText();
            if text is mime:ParserError || text.length() > MAX_DETAILS_LENGTH {
                return "The personal details could not be read.";
            }
            detailsText = text;
            continue;
        }
        DocumentSpec? spec = specOf(fieldName);
        if spec is () {
            return "One of the files is not one of the requested documents.";
        }
        if received.hasKey(spec.key) {
            return string `The ${spec.label} was sent more than once.`;
        }
        received[spec.key] = true;
        fileCount += 1;
        if fileCount > MAX_FILES {
            return string `At most ${MAX_FILES} files can be sent.`;
        }

        byte[]|mime:ParserError content = part.getByteArray();
        if content is mime:ParserError {
            return string `The ${spec.label} could not be read.`;
        }
        if content.length() == 0 {
            return string `The ${spec.label} is empty.`;
        }
        if content.length() > MAX_FILE_BYTES {
            return string `The ${spec.label} must be ${MAX_FILE_BYTES / (1024 * 1024)}MB or smaller.`;
        }
        total += content.length();
        if total > MAX_TOTAL_BYTES {
            return string `The files must be ${MAX_TOTAL_BYTES / (1024 * 1024)}MB or smaller in total.`;
        }
        string? extension = fileTypeOf(content);
        if extension is () {
            return typeMessage(spec);
        }
        if spec.types.indexOf(extension) is () {
            return typeMessage(spec);
        }
        if spec.minSquareSide > 0 {
            [int, int]? size = imageSizeOf(content, extension);
            if size is () || size[0] != size[1] || size[0] < spec.minSquareSide {
                return string `The ${spec.label} must be a square picture, at least ${spec.minSquareSide} x ${spec.minSquareSide} pixels.`;
            }
        }
        documents.push({key: spec.key, extension, contentType: contentTypeOf(extension), content});
    }

    foreach DocumentSpec spec in REQUIRED_DOCUMENTS {
        if spec.required && !received.hasKey(spec.key) && alreadySent.indexOf(spec.key) is () {
            return string `The ${spec.label} is required.`;
        }
    }
    if detailsText == "" {
        return "Fill in your personal details.";
    }
    json|error parsed = value:fromJsonString(detailsText);
    if parsed is error {
        return "The personal details could not be read.";
    }
    PersonalDetails|error read = parsed.fromJsonWithType();
    if read is error {
        return "The personal details are incomplete or not in the expected form.";
    }
    PersonalDetails|string details = validateDetails(read);
    if details is string {
        return details;
    }
    if !declared {
        return "Please confirm the declaration.";
    }
    return {documents, details};
}
