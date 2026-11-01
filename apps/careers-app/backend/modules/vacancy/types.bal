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

# ATS connection details.
public type AtsConfig record {|
    string baseUrl;
    string tokenUrl;
    string clientId;
    string clientSecret;
|};

const STATUS_PUBLISHED = "PUBLISHED";

const VISIBILITY_ALL = "All";
const VISIBILITY_EXTERNAL_ONLY = "External Only";
const VISIBILITY_INTERNAL_ONLY = "Internal Only";

const EMPLOYMENT_INTERNSHIP = "Internship";

# The ATS employment type that is shown as EMPLOYMENT_FULL_TIME.
const EMPLOYMENT_PERMANENT = "Permanent";
const EMPLOYMENT_FULL_TIME = "Full Time";

const MODE_REMOTE = "Remote";
const MODE_HYBRID = "Hybrid";

const CANDIDATE_STATUS_CREATED = "CREATED";
const CANDIDATE_STATUS_DELETED = "DELETED";
const CANDIDATE_STATUS_HIRED = "HIRED";

const MAX_NAME_LENGTH = 100;
const MAX_ADDRESS_LENGTH = 300;
const MAX_UNIVERSITY_LENGTH = 255;

const DETAIL_TOO_LONG_MESSAGE = "One of the details is too long.";
const NO_APPLICATIONS_MESSAGE = "No applications found for this account";
const PROFILE_NOT_EDITABLE_MESSAGE = "Your details can be edited after your first application.";

# The most applications of one candidate that are read.
const MAX_HISTORY_ENTRIES = 100;
const APPLIED_FROM_CAREER_SITE = "Career Site";

# The address recorded for an internship.
const ADDRESS_NOT_APPLICABLE = "N/A";

# The name used when an org id has no match.
const UNKNOWN_NAME = "Unknown";

# An ATS reply with a status other than 200.
type UpstreamError distinct error<record {|int status;|}>;

# A vacancy as the ATS returns it.
type AtsVacancy record {
    int id;
    string title;
    int designationId;
    int businessUnitId;
    int departmentId;
    int? officeId = ();
    string employmentType;
    string modeOfWork;
    string[] hiringLocations;
    string visibility;
    json jdHtmlObject = ();
    string status;
    string? publishedOn = ();
};

type AtsDepartment record {
    int id;
    string department;
};

type AtsBusinessUnit record {
    int id;
    AtsDepartment[]? departments = ();
};

type AtsOffice record {
    int id;
    string office;
};

type AtsCompany record {
    string location;
    AtsOffice[]? offices = ();
};

type AtsDesignation record {
    int id;
    string designation;
};

type AtsCareerFunction record {
    AtsDesignation[]? designations = ();
};

type AtsCustomHiringLocation record {
    string location;
    string[] customMap;
};

type AtsAppConfig record {
    string globalHiringTitle;
    AtsCustomHiringLocation[] customHiringLocationMap = [];
};

# The sections of a vacancy's job description.
type JdContent record {
    string mainContent = "";
    string? taskInformation = ();
    string? additionalContent = ();
};

# A candidate as the ATS accepts it.
type AtsCandidate record {|
    *CandidateApplication;
    int vacancyId;
    string status;
    string appliedFrom;
|};

# A vacancy in the job list, in the shape the web app reads.
type VacancyBasicInfo record {|
    int id;
    string title;
    string publish_status;
    string[] country;
    string job_type;
    string team;
    string published_on;
|};

# One vacancy's detail, in the shape the web app reads.
type JobDetail record {|
    int id;
    string title;
    string designation;
    string team;
    string[] country;
    string job_type;
    boolean allow_remote;
    map<string> office_locations;
    string publish_status;
    string? published_on;
    string mainContent;
    string? taskInformation;
    string? additionalContent;
    VacancyBasicInfo[] similar_job_listing;
|};

# Team and hiring location names, keyed by their position in the list.
type OrgStructure record {|
    map<string> location_list;
    map<string> team_list;
|};

# One application in a candidate's history as the ATS returns it.
type AtsHistoryEntry record {
    int id;
    int candidateId = 0;
    int vacancyId;
    string? vacancyTitle = ();
    string status;
    string? firstName = ();
    string? lastName = ();
    string? gender = ();
    string? contactNo = ();
    string? address = ();
    string? university = ();
    string? createdOn = ();
    string? updatedOn = ();
};

type AtsHistoryResponse record {
    AtsHistoryEntry[] candidates;
};

# The signed-in candidate's details, in the shape the web app reads.
type CandidateProfile record {|
    string firstName;
    string lastName;
    string gender;
    string personalEmail;
    string contactNo;
    string? address;
    string? university;
|};

# The details a candidate can change; a null address or university clears it.
public type ProfileChanges record {|
    string firstName?;
    string lastName?;
    string gender?;
    string contactNo?;
    string? address?;
    string? university?;
|};

# The changes in the form the ATS takes.
type AtsCandidateUpdate record {|
    string firstName?;
    string lastName?;
    string gender?;
    string contactNo?;
    string address?;
    string university?;
|};

# An offer letter as the ATS returns it.
type AtsOfferLetter record {
    string subject = "";
    string sentOn = "";
    string? threadId = ();
    string htmlContent = "";
};

# The offer letter a candidate was sent, in the shape the web app reads.
public type OfferLetter record {|
    string subject;
    string sentOn;
    string threadId;
    string html;
|};

# An interview as the ATS returns it. Only the fields below are read; the rest of the reply, which holds internal
# details such as the interviewers and the score cards, is ignored and never passed on.
type AtsInterview record {
    int id;
    string status = "";
    string? startTime = ();
    string? title = ();
    string? interviewStage = ();
    string? interviewModality = ();
    string? meetingUrl = ();
    string? customLocation = ();
    string? roomName = ();
    string? floorNumber = ();
};

# The ATS reply to a list of interviews.
type AtsInterviewResponse record {
    AtsInterview[] interviews = [];
};

# One interview of a candidate's application, in the shape the web app reads.
public type ApplicationInterview record {|
    string id;
    # The stage of the interview, or its title.
    string round;
    # The start of the interview as the ATS gives it.
    string dateTime;
    # "Video" for a virtual interview and "Onsite" for a physical one.
    string mode;
    # The meeting link of a video interview, or the place of an onsite one.
    string location;
    # "Upcoming", "Completed" or "Cancelled".
    string status;
|};

# The most interviews of one application that are read.
const MAX_INTERVIEWS = 50;

# One of the signed-in candidate's applications, in the shape the web app reads.
public type ApplicationSummary record {|
    string id;
    string jobId;
    string jobTitle;
    string department;
    string appliedDate;
    # When the application last changed, which is when it reached its current status.
    string updatedDate;
    string status;
|};

# Candidate details from the application form. `resume` holds the CV's bytes.
public type CandidateApplication record {|
    string firstName;
    string lastName;
    string personalEmail;
    string contactNo;
    string address;
    byte[] resume;
    string taskInfo?;
    string university?;
    string wso2Email?;
|};

type TokenResponse record {
    string access_token;
    int expires_in;
};
