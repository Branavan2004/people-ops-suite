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

const CANDIDATE_STATUS_DELETED = "DELETED";
const CANDIDATE_STATUS_HIRED = "HIRED";

const OFFER_STATUS_OFFER_SENT = "OFFER_SENT";
const OFFER_STATUS_ACCEPTED = "ACCEPTED";
const OFFER_STATUS_DECLINED = "DECLINED";
const OFFER_STATUS_EXPIRED = "EXPIRED";

const MAX_DECLINE_REASON_LENGTH = 255;
const MAX_DECLINE_FEEDBACK_LENGTH = 1000;

const MAX_NAME_LENGTH = 100;
const MAX_ADDRESS_LENGTH = 300;
const MAX_UNIVERSITY_LENGTH = 255;

const DETAIL_TOO_LONG_MESSAGE = "One of the details is too long.";
const NO_APPLICATIONS_MESSAGE = "No applications found for this account";
const PROFILE_NOT_EDITABLE_MESSAGE = "Your details can be edited after your first application.";

# The most applications of one candidate that are read.
const MAX_HISTORY_ENTRIES = 100;

# The address recorded for an internship.
const ADDRESS_NOT_APPLICABLE = "N/A";

# An ATS reply with a status other than 200.
type UpstreamError distinct error<record {|int status;|}>;

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
    # Status of the latest offer of the application, if it has one.
    string? offerStatus = ();
    # Expiry date of that offer as the offer letter states it, yyyy-MM-dd.
    string? offerExpiryDate = ();
    # Subject of the email the offer was sent with.
    string? offerEmailSubject = ();
    # When that offer was sent, and last changed by an answer or its expiry.
    string? offerUpdatedAt = ();
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
    string appliedDate;
    # When the application last changed, which is when it reached its current status. Once an offer has been sent it is
    # when the offer was sent or last changed, so it dates the Offer, Offer Accepted, Offer Declined and Offer Expired
    # statuses.
    string updatedDate;
    string status;
    # The date the offer must be answered by, anywhere on Earth (yyyy-MM-dd). Set while the offer is open or after it
    # expired.
    string offerExpiresOn?;
    # The subject of the offer email, so the candidate can find it. Set only while the offer is open.
    string offerEmailSubject?;
|};

# A candidate's answer to an offer.
public type OfferDecision record {|
    # ACCEPTED or DECLINED
    string decision;
    # The reason for declining, required for a decline
    string declineReason?;
    # Optional feedback for a decline
    string declineReasonAdditional?;
|};

type TokenResponse record {
    string access_token;
    int expires_in;
};
