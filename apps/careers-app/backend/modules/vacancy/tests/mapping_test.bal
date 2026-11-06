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
import ballerina/test;

@test:Config {}
function aRefusedRequestKeepsTheAtsStatus() {
    http:Response|error reply = failedReply(error UpstreamError("refused", status = 409), "test-request");
    test:assertTrue(reply is http:Response && reply.statusCode == 409);
}

@test:Config {}
function anUnreadableReplyBecomesBadGateway() {
    http:Response|error reply = failedReply(error("unreadable"), "test-request");
    test:assertTrue(reply is http:Response && reply.statusCode == 502);
}

function historyEntry(int id, string status = "CREATED", int vacancyId = 7) returns AtsHistoryEntry => {
    id,
    vacancyId,
    vacancyTitle: "Engineer",
    status,
    firstName: "Ada",
    lastName: "Lovelace",
    gender: "Female",
    contactNo: "+94771234567",
    address: "1 Main Street",
    createdOn: "2026-01-01T00:00:00Z"
};

@test:Config {}
function atsStatusesAreShownAsTheWebAppNamesThem() {
    test:assertEquals(applicationStatusOf("CREATED"), "Applied");
    test:assertEquals(applicationStatusOf("SHORTLISTED"), "Screening");
    test:assertEquals(applicationStatusOf("INTERVIEW_IN_PROGRESS"), "Interview");
    test:assertEquals(applicationStatusOf("INTERVIEW_COMPLETED"), "Interview");
    test:assertEquals(applicationStatusOf("HIRED"), "Selected");
    test:assertEquals(applicationStatusOf("REJECTED"), "Rejected");
    test:assertEquals(applicationStatusOf("NOT_SHORTLISTED"), "Rejected");
    test:assertEquals(applicationStatusOf("VACANCY_CLOSED"), "Applied");
    test:assertEquals(applicationStatusOf("SOMETHING_NEW"), "Applied");
}

@test:Config {}
function applicationsAreNewestFirstWithoutDeletedOnes() {
    AtsHistoryEntry[] history = [historyEntry(1), historyEntry(3, "DELETED"), historyEntry(2, "HIRED", 8)];
    ApplicationSummary[] applications = applicationsOf(history);
    test:assertEquals(applications.length(), 2);
    test:assertEquals(applications[0].id, "2");
    test:assertEquals(applications[0].status, "Selected");
    test:assertEquals(applications[1].id, "1");
    test:assertEquals(applications[1].jobId, "7");
    test:assertEquals(applications[1].jobTitle, "Engineer");
    test:assertEquals(applications[1].appliedDate, "2026-01-01T00:00:00Z");
    // An application that was never changed was last updated when it was made.
    test:assertEquals(applications[1].updatedDate, "2026-01-01T00:00:00Z");
}

@test:Config {}
function anApplicationShowsWhenItLastChanged() {
    AtsHistoryEntry shortlisted = historyEntry(5, "SHORTLISTED");
    shortlisted.updatedOn = "2026-01-04T09:30:00Z";
    ApplicationSummary[] applications = applicationsOf([shortlisted]);
    test:assertEquals(applications[0].status, "Screening");
    test:assertEquals(applications[0].appliedDate, "2026-01-01T00:00:00Z");
    test:assertEquals(applications[0].updatedDate, "2026-01-04T09:30:00Z");
}

@test:Config {}
function profileComesFromTheMostRecentApplication() {
    AtsHistoryEntry older = historyEntry(1);
    older.firstName = "Old";
    AtsHistoryEntry latest = historyEntry(2);
    latest.address = "N/A";
    latest.university = "State University";
    CandidateProfile? profile = profileOf([older, latest], "ada@example.test");
    if profile is () {
        test:assertFail("A profile was expected");
    }
    test:assertEquals(profile.firstName, "Ada");
    test:assertEquals(profile.personalEmail, "ada@example.test");
    test:assertEquals(profile.address, ());
    test:assertEquals(profile.university, "State University");
}

@test:Config {}
function nullsInTheHistoryDoNotBreakTheConversion() {
    json history = {
        "candidates": [
            {
                "id": 1,
                "vacancyId": 7,
                "status": "CREATED",
                "vacancyTitle": null,
                "firstName": "Ada",
                "lastName": null,
                "gender": null,
                "contactNo": null,
                "address": null,
                "university": null,
                "createdOn": null
            }
        ]
    };
    AtsHistoryResponse|error converted = history.fromJsonWithType();
    if converted is error {
        test:assertFail(converted.message());
    }
    CandidateProfile? profile = profileOf(converted.candidates, "ada@example.test");
    if profile is () {
        test:assertFail("A profile was expected");
    }
    test:assertEquals(profile.firstName, "Ada");
    test:assertEquals(profile.gender, "");
    ApplicationSummary[] applications = applicationsOf(converted.candidates);
    test:assertEquals(applications[0].jobTitle, "");
    test:assertEquals(applications[0].appliedDate, "");
}

@test:Config {}
function noProfileWithoutAnApplication() {
    test:assertEquals(profileOf([], "ada@example.test"), ());
    test:assertEquals(profileOf([historyEntry(1, "DELETED")], "ada@example.test"), ());
}

@test:Config {}
function changesAreTrimmedAndClearedValuesAreSentAsEmptyText() {
    ProfileChanges changes = {firstName: " Ada ", contactNo: " +94771234567 ", address: (), university: "State University"};
    AtsCandidateUpdate|string update = atsUpdateOf(changes);
    if update is string {
        test:assertFail(update);
    }
    test:assertEquals(update.firstName, "Ada");
    test:assertEquals(update.contactNo, "+94771234567");
    test:assertEquals(update.address, "");
    test:assertEquals(update.university, "State University");
    test:assertFalse(update.hasKey("lastName"));
    test:assertFalse(update.hasKey("gender"));
}

@test:Config {}
function noChangesMakeAnEmptyUpdate() {
    AtsCandidateUpdate|string update = atsUpdateOf({});
    test:assertTrue(update is AtsCandidateUpdate && update.length() == 0);
}

@test:Config {}
function changesThatCannotBeSavedAreRefused() {
    test:assertEquals(atsUpdateOf({firstName: "  "}), "Enter your first name.");
    test:assertEquals(atsUpdateOf({lastName: ""}), "Enter your last name.");
    test:assertEquals(atsUpdateOf({gender: "Other"}), "Choose Male, Female or Prefer not to say as the gender.");
    test:assertTrue(atsUpdateOf({gender: "Female"}) is AtsCandidateUpdate);
    test:assertTrue(atsUpdateOf({gender: "Prefer not to say"}) is AtsCandidateUpdate);
}

@test:Config {}
function aContactNumberMustBeInInternationalFormat() {
    string reason = "Enter the phone number in international format, for example +94771234567.";
    test:assertEquals(atsUpdateOf({contactNo: ""}), reason);
    test:assertEquals(atsUpdateOf({contactNo: "call me"}), reason);
    test:assertEquals(atsUpdateOf({contactNo: "0771234567"}), reason);
    test:assertTrue(atsUpdateOf({contactNo: "+94771234567"}) is AtsCandidateUpdate);
}

@test:Config {}
function tooLongProfileDetailsAreRefused() {
    string tooLong = "".padEnd(301, "a");
    test:assertEquals(atsUpdateOf({firstName: "".padEnd(101, "a")}), "One of the details is too long.");
    test:assertEquals(atsUpdateOf({lastName: "".padEnd(101, "a")}), "One of the details is too long.");
    test:assertEquals(atsUpdateOf({address: tooLong}), "One of the details is too long.");
    test:assertEquals(atsUpdateOf({university: "".padEnd(256, "a")}), "One of the details is too long.");
    test:assertTrue(atsUpdateOf({firstName: "".padEnd(100, "a"), address: "".padEnd(300, "a")}) is AtsCandidateUpdate);
}

@test:Config {}
function aVirtualInterviewShowsItsMeetingLink() {
    ApplicationInterview shown = interviewOf({
        id: 7,
        status: "SCHEDULED",
        startTime: "2026-11-05T11:00:00",
        interviewStage: "Technical interview",
        interviewModality: "Virtual",
        meetingUrl: " https://meet.example.test/abc "
    });
    test:assertEquals(shown, <ApplicationInterview>{
        id: "7",
        round: "Technical interview",
        dateTime: "2026-11-05T11:00:00",
        mode: "Video",
        location: "https://meet.example.test/abc",
        status: "Upcoming"
    });
}

@test:Config {}
function aPhysicalInterviewShowsItsPlace() {
    AtsInterview custom = {id: 8, status: "COMPLETED", interviewModality: "Physical", customLocation: "Head office, lobby"};
    test:assertEquals(interviewOf(custom).location, "Head office, lobby");
    test:assertEquals(interviewOf(custom).mode, "Onsite");
    test:assertEquals(interviewOf(custom).status, "Completed");

    AtsInterview room = {id: 9, status: "SCHEDULED", interviewModality: "Physical", roomName: "Orion", floorNumber: "3"};
    test:assertEquals(interviewOf(room).location, "Orion, floor 3");
}

@test:Config {}
function aWithdrawnInterviewIsCancelledAndTheRoundFallsBackToTheTitle() {
    ApplicationInterview shown = interviewOf({id: 10, status: "WITHDRAWN", title: "Final round", interviewModality: "Virtual"});
    test:assertEquals(shown.status, "Cancelled");
    test:assertEquals(shown.round, "Final round");
    test:assertEquals(shown.location, "");
    test:assertEquals(interviewOf({id: 11, status: "SCHEDULED"}).round, "Interview");
}

@test:Config {}
function nothingInternalIsPassedOnWithAnInterview() returns error? {
    json reply = {
        "interviews": [
            {
                "id": 12,
                "status": "SCHEDULED",
                "startTime": "2026-11-06T09:00:00",
                "interviewModality": "Virtual",
                "meetingUrl": "https://meet.example.test/x",
                "interviewerEmail": "interviewer@example.test",
                "scoreCards": [{"score": 4}],
                "description": "Internal notes"
            }
        ]
    };
    AtsInterviewResponse parsed = check reply.fromJsonWithType();
    json shown = interviewsOf(parsed.interviews).toJson();
    string text = shown.toJsonString();
    test:assertFalse(text.includes("interviewer"));
    test:assertFalse(text.includes("score"));
    test:assertFalse(text.includes("Internal notes"));
    test:assertTrue(text.includes("https://meet.example.test/x"));
}

@test:Config {}
function interviewsAreListedInTheOrderTheyTakePlace() {
    ApplicationInterview[] shown = interviewsOf([
        {id: 2, status: "SCHEDULED", startTime: "2026-11-09T10:00:00"},
        {id: 1, status: "COMPLETED", startTime: "2026-11-02T10:00:00"}
    ]);
    test:assertEquals(shown.map(interview => interview.id), ["1", "2"]);
}

@test:Config {}
function anOfferStatusReplacesTheApplicationStatus() {
    test:assertEquals(applicationStatusOf("HIRED", "OFFER_SENT"), "Offer");
    test:assertEquals(applicationStatusOf("HIRED", "ACCEPTED"), "Offer Accepted");
    test:assertEquals(applicationStatusOf("HIRED", "DECLINED"), "Offer Declined");
    test:assertEquals(applicationStatusOf("HIRED", "EXPIRED"), "Offer Expired");
    test:assertEquals(applicationStatusOf("REJECTED", ()), "Rejected");
}

function offeredEntry(string offerStatus) returns AtsHistoryEntry {
    AtsHistoryEntry entry = historyEntry(1, "HIRED");
    entry.offerStatus = offerStatus;
    entry.offerExpiryDate = "2026-11-12";
    entry.offerEmailSubject = "Offer letter";
    return entry;
}

@test:Config {}
function theOfferDeadlineIsShownOnlyWhileItMatters() {
    ApplicationSummary open = applicationOf(offeredEntry("OFFER_SENT"));
    test:assertEquals(open?.offerExpiresOn, "2026-11-12");
    test:assertEquals(open?.offerEmailSubject, "Offer letter");

    ApplicationSummary expired = applicationOf(offeredEntry("EXPIRED"));
    test:assertEquals(expired?.offerExpiresOn, "2026-11-12");
    test:assertEquals(expired?.offerEmailSubject, ());

    ApplicationSummary accepted = applicationOf(offeredEntry("ACCEPTED"));
    test:assertEquals(accepted?.offerExpiresOn, ());
    test:assertEquals(accepted?.offerEmailSubject, ());
}

@test:Config {}
function anOfferAnswerIsChecked() {
    test:assertEquals(offerDecisionProblem({decision: "ACCEPTED"}), ());
    test:assertEquals(offerDecisionProblem({decision: "MAYBE"}), "The decision must be ACCEPTED or DECLINED.");
    test:assertEquals(offerDecisionProblem({decision: "DECLINED", declineReason: "Compensation"}), ());
    test:assertEquals(offerDecisionProblem({decision: "DECLINED"}), "Choose a reason for declining.");
    test:assertEquals(offerDecisionProblem({decision: "DECLINED", declineReason: "   "}), "Choose a reason for declining.");
    test:assertEquals(offerDecisionProblem({decision: "DECLINED", declineReason: "Other"}), ());
    test:assertEquals(offerDecisionProblem({decision: "DECLINED", declineReason: "x".padEnd(256, "x")}),
        "The reason is too long.");
}

@test:Config {}
function theDateOfAnApplicationWithAnOfferIsTheDateOfTheOffer() {
    AtsHistoryEntry entry = historyEntry(1, "HIRED");
    entry.updatedOn = "2026-11-01 09:00:00";
    test:assertEquals(applicationOf(entry).updatedDate, "2026-11-01 09:00:00");
    entry.offerStatus = "ACCEPTED";
    entry.offerUpdatedAt = "2026-11-05 14:30:00";
    test:assertEquals(applicationOf(entry).updatedDate, "2026-11-05 14:30:00");
}

@test:Config {}
function aCandidateFindsOnlyTheirOwnApplicationById() {
    AtsHistoryEntry[] history = [historyEntry(1), historyEntry(2, "HIRED"), historyEntry(3, "DELETED")];
    test:assertEquals(ownApplication(history, 2)?.status, "HIRED");
    test:assertEquals(ownApplication(history, 3)?.status, "DELETED");
    test:assertEquals(ownApplication(history, 99), ());
    test:assertEquals(ownApplication([], 1), ());
}
