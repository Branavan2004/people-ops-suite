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

# Where the onboarding documents are stored.
public type StorageConfig record {|
    # The blob service address.
    string baseUrl;
    # The private container the documents are written to.
    string container;
    # A SAS token for that container, with create, write and read permission.
    string sasToken;
|};

# One document the candidate is asked for.
public type DocumentSpec record {|
    # The name of the form field the file is sent in.
    string key;
    # What the candidate sees.
    string label;
    boolean required;
    # The step of the form the document belongs to: "documents" or "photos".
    string group;
    # The file types this document accepts: pdf, jpg or png.
    string[] types;
    # A line of guidance shown under the name.
    string hint = "";
    # When above zero, the picture must be square and at least this many pixels on each side.
    int minSquareSide = 0;
|};

# A document the candidate sent, after its type has been checked against its first bytes.
public type UploadedDocument record {|
    string key;
    # The extension of the detected type: pdf, jpg or png.
    string extension;
    string contentType;
    byte[] content;
|};

# A person the new joiner supports, who may be covered by the company's insurance policy.
public type Dependant record {|
    # Spouse, Child or Parent.
    string relationship;
    string name;
    # The date of birth as yyyy-mm-dd.
    string dateOfBirth;
    # The number of the national identity card or passport; a child may have none.
    string idNumber = "";
|};

# A person to call in an emergency.
public type EmergencyContact record {|
    string name;
    string relationship;
    string address;
    # The mobile number in international format.
    string mobileNumber;
    # The land line in international format, when there is one.
    string landNumber = "";
|};

# The account the salary is paid into.
public type BankDetails record {|
    string bank;
    string branch;
    # Digits only.
    string accountNumber;
|};

# The personal details a new joiner fills in: the sheet HR keeps for every new employee.
public type PersonalDetails record {|
    string title;
    # The first name and the last name, as the ATS keeps them.
    string firstName;
    string surname;
    # The full name as on the identity document, which the candidate types.
    string fullName;
    string preferredName;
    string initials;
    string nameWithInitials;
    string gender;
    # The date of birth as yyyy-mm-dd.
    string dateOfBirth;
    # The number of the identity document: a national identity card or a passport.
    string idNumber;
    string civilStatus;
    string tshirtSize;
    string homeAddress;
    string temporaryAddress = "";
    # The mobile number in international format.
    string mobileNumber;
    # The land line in international format, when there is one.
    string landNumber = "";
    string personalEmail;
    # Yes or No: whether the joiner has an interest in any commercial or business pursuit.
    string businessInterest;
    Dependant[] dependants = [];
    EmergencyContact[] emergencyContacts;
    BankDetails bank;
    string highestQualification;
    string university;
    string githubUserId = "";
|};

# What a candidate sent: the documents and the personal details.
public type Submission record {|
    UploadedDocument[] documents;
    PersonalDetails details;
|};

# The record of a submission, kept in storage: the current state, which an edit replaces.
public type Manifest record {|
    string applicationId;
    string candidateName;
    # The folder the files and this record are in: the candidate's full name and the application id.
    string folder;
    PersonalDetails details;
    # The stored file of each document, by document key.
    map<string> files;
    boolean declared;
    string submittedAt;
    string updatedAt;
|};

# Where an application's submission is kept, so it can be found by the application id alone.
type SubmissionIndex record {|
    string folder;
    # The name the files of the submission are given, which a retry keeps whatever the candidate's name is by then.
    string candidateName = "";
    # The request that is making the first submission, which is the only one that may write its files.
    string claimedBy = "";
    # When that request claimed it. Empty once the claim is released, as after a failure.
    string claimedAt = "";
|};

# What the candidate's page is told about their submission.
public type SubmissionStatus record {|
    boolean submitted;
    boolean canEdit;
    # The deadline as configured, or an empty text when none is set.
    string editableUntil;
    # The saved details, when there is a submission.
    PersonalDetails? details = ();
    # The keys of the documents already sent.
    string[] files = [];
|};

# What came of storing a first submission.
public enum SubmitOutcome {
    STORED,
    ALREADY_SUBMITTED,
    # Another request is making the first submission of the application.
    IN_PROGRESS
}

# How many days after it was made a submission can be changed, counted from that submission and not from a date for
# everyone. Nothing can be changed while it is zero.
public configurable int editableDays = 0;

# The T-shirt sizes a candidate can choose from.
public final readonly & string[] TSHIRT_SIZES = ["XS", "S", "M", "L", "XL", "XXL", "XXXL"];

public final readonly & string[] TITLES = ["Mr", "Mrs", "Ms", "Miss", "Dr"];

public final readonly & string[] GENDERS = ["Male", "Female", "Prefer not to say"];

public final readonly & string[] CIVIL_STATUSES = ["Single", "Married", "Divorced", "Widowed"];

public final readonly & string[] DEPENDANT_RELATIONSHIPS = ["Spouse", "Child", "Parent"];

public final readonly & string[] YES_NO = ["Yes", "No"];

# The most dependants and emergency contacts accepted.
public const MAX_DEPENDANTS = 2;
public const MAX_EMERGENCY_CONTACTS = 5;

# The name of the form field that carries the personal details, as one JSON text.
public const DETAILS_FIELD = "details";

# The longest the JSON text of the personal details may be, in characters.
public const MAX_DETAILS_LENGTH = 30000;

# The most files accepted in one submission.
public const MAX_FILES = 10;

# The largest single file accepted, in bytes.
public const MAX_FILE_BYTES = 5 * 1024 * 1024;

# The largest total size of one submission, in bytes.
public const MAX_TOTAL_BYTES = 20 * 1024 * 1024;

# The largest request body accepted: the files plus the form framing.
public const MAX_REQUEST_BYTES = MAX_TOTAL_BYTES + 1024 * 1024;

# The documents asked for. The key is the only name the client may use for a file.
public final readonly & DocumentSpec[] REQUIRED_DOCUMENTS = [
    {
        key: "identityDocument",
        label: "Identity document",
        required: true,
        group: "documents",
        types: ["pdf"],
        hint: "A copy of your national identity card or passport."
    },
    {
        key: "birthCertificate",
        label: "Birth certificate",
        required: true,
        group: "documents",
        types: ["pdf"],
        hint: "A copy of your birth certificate."
    },
    {
        key: "policeReport",
        label: "Police Clearance Certificate",
        required: false,
        group: "documents",
        types: ["pdf"],
        hint: "From the Police Station in your area. One obtained within the past 6 months is fine."
    },
    {
        key: "profilePicture",
        label: "Profile picture (for your ID card and Google account)",
        required: true,
        group: "photos",
        types: ["jpg", "png"],
        hint: "A recent front-facing picture with a white background, square and at least 175 x 175 pixels.",
        minSquareSide: 175
    },
    {
        key: "funPicture",
        label: "Fun picture of you (for the Team Page)",
        required: true,
        group: "photos",
        types: ["jpg", "png"],
        hint: "A fun photo for our Team Page. See https://wso2.com/team/all for how it should look."
    }
];

# The name of the form field that carries the candidate's declaration.
public const DECLARATION_FIELD = "declaration";

configurable readonly & StorageConfig storageConfig = ?;
