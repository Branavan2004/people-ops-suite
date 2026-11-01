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

final AtsBusinessUnit[] & readonly UNITS = [
    {id: 1, departments: [{id: 10, department: "Engineering"}, {id: 11, department: "People"}]},
    {id: 2}
];

final AtsCompany[] & readonly COMPANIES = [
    {location: "Sri Lanka", offices: [{id: 5, office: "Colombo"}]},
    {location: "USA", offices: [{id: 6, office: "Mountain View"}]}
];

final AtsCareerFunction[] & readonly CAREER_FUNCTIONS = [
    {designations: [{id: 100, designation: "Software Engineer"}, {id: 101, designation: "Tech Lead"}]}
];

function vacancy(int id, string[] locations = ["Sri Lanka"], string employmentType = "Permanent",
        string mode = "Office") returns AtsVacancy => {
    id,
    title: "Engineer",
    designationId: 100,
    businessUnitId: 1,
    departmentId: 10,
    officeId: 5,
    employmentType,
    modeOfWork: mode,
    hiringLocations: locations,
    visibility: "All",
    jdHtmlObject: {mainContent: "<p>Main</p>", taskInformation: "Task"},
    status: "PUBLISHED",
    publishedOn: "2026-01-01"
};

function application(string address = "1 Main Street", string? university = ()) returns CandidateApplication {
    CandidateApplication candidate = {
        firstName: "Ada",
        lastName: "Lovelace",
        personalEmail: "ada@example.test",
        contactNo: "+94771234567",
        address,
        resume: [1, 2, 3]
    };
    if university is string {
        candidate.university = university;
    }
    return candidate;
}

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
    test:assertEquals(applicationStatusOf("HIRED"), "Offer Accepted");
    test:assertEquals(applicationStatusOf("REJECTED"), "Rejected");
    test:assertEquals(applicationStatusOf("NOT_SHORTLISTED"), "Rejected");
    test:assertEquals(applicationStatusOf("VACANCY_CLOSED"), "Applied");
    test:assertEquals(applicationStatusOf("SOMETHING_NEW"), "Applied");
}

@test:Config {}
function applicationsAreNewestFirstWithoutDeletedOnes() {
    AtsHistoryEntry[] history = [historyEntry(1), historyEntry(3, "DELETED"), historyEntry(2, "HIRED", 8)];
    ApplicationSummary[] applications = applicationsOf(history, {"7": "Engineering"});
    test:assertEquals(applications.length(), 2);
    test:assertEquals(applications[0].id, "2");
    test:assertEquals(applications[0].department, "");
    test:assertEquals(applications[0].status, "Offer Accepted");
    test:assertEquals(applications[1].id, "1");
    test:assertEquals(applications[1].jobId, "7");
    test:assertEquals(applications[1].jobTitle, "Engineer");
    test:assertEquals(applications[1].department, "Engineering");
    test:assertEquals(applications[1].appliedDate, "2026-01-01T00:00:00Z");
    // An application that was never changed was last updated when it was made.
    test:assertEquals(applications[1].updatedDate, "2026-01-01T00:00:00Z");
}

@test:Config {}
function anApplicationShowsWhenItLastChanged() {
    AtsHistoryEntry shortlisted = historyEntry(5, "SHORTLISTED");
    shortlisted.updatedOn = "2026-01-04T09:30:00Z";
    ApplicationSummary[] applications = applicationsOf([shortlisted], {});
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
    ApplicationSummary[] applications = applicationsOf(converted.candidates, {});
    test:assertEquals(applications[0].jobTitle, "");
    test:assertEquals(applications[0].appliedDate, "");
}

@test:Config {}
function noProfileWithoutAnApplication() {
    test:assertEquals(profileOf([], "ada@example.test"), ());
    test:assertEquals(profileOf([historyEntry(1, "DELETED")], "ada@example.test"), ());
}

@test:Config {}
function departmentsComeFromTheJobList() {
    json jobs = [{"id": 7, "team": "Engineering"}, {"id": "x", "team": "Ignored"}, "not a job"];
    test:assertEquals(departmentsOf(jobs), {"7": "Engineering"});
    test:assertEquals(departmentsOf(()), {});
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
function aFailedJobLookupIsABadGatewayNotTheJobsOwnStatus() {
    error refused = asLookupFailure(error UpstreamError("not found", status = 404));
    test:assertTrue(refused is UpstreamError && refused.detail().status == 502);
    error unreadable = asLookupFailure(error("unreadable"));
    test:assertFalse(unreadable is UpstreamError);
}

@test:Config {}
function peekingAtTheCacheNeverLoadsIt() returns error? {
    VacancyCache cache = new (120, 21600, 5);
    test:assertEquals(cache.peek("jobs"), ());

    json|http:Response|error loaded = cache.get("jobs", isolated function() returns http:Response|error {
        http:Response resp = new;
        resp.setJsonPayload([1, 2]);
        return resp;
    });
    test:assertEquals(check loaded, [1, 2]);
    test:assertEquals(cache.peek("jobs"), [1, 2]);
    test:assertEquals(cache.peek("job:7"), ());
}

@test:Config {}
function aVacancyThatCannotBeReadIsSkippedNotTheWholeList() returns error? {
    json readable = {
        "id": 1, "title": "Engineer", "designationId": 100, "businessUnitId": 1, "departmentId": 10,
        "employmentType": "Permanent", "modeOfWork": "Office", "hiringLocations": ["Sri Lanka"],
        "visibility": "All", "status": "PUBLISHED"
    };
    json incomplete = {
        "id": 2, "title": "Draft", "designationId": 100, "businessUnitId": 1, "departmentId": null,
        "employmentType": "Permanent", "modeOfWork": "Office", "hiringLocations": null,
        "visibility": "All", "status": "PUBLISHED"
    };
    AtsVacancy[] vacancies = check vacanciesOf({"vacancies": [readable, incomplete]}, "test-request");
    test:assertEquals(vacancies.length(), 1);
    test:assertEquals(vacancies[0].id, 1);
}

@test:Config {}
function anUnreadableVacancyListIsAnError() {
    test:assertTrue(vacanciesOf("not an object", "test-request") is error);
    test:assertTrue(vacanciesOf({"vacancies": "none"}, "test-request") is error);
    test:assertTrue(vacanciesOf({}, "test-request") is error);
}

@test:Config {}
function nullNestedListsInTheOrgDataAreTreatedAsEmpty() returns error? {
    AtsCompany[] companies = check (<json>[{"location": "Sri Lanka", "offices": null}]).fromJsonWithType();
    test:assertEquals(officeNameOf(companies, 5), ());
    AtsCareerFunction[] functions = check (<json>[{"designations": null}]).fromJsonWithType();
    test:assertTrue(designationNameOf(functions, 100) is error);
}

@test:Config {}
function theVacancyQueryAsksOnlyForPubliclyListedVacancies() returns error? {
    string query = check vacancyQuery((), ());
    test:assertTrue(query.startsWith("status=PUBLISHED"));
    test:assertTrue(query.includes("visibility=All"));
    test:assertTrue(query.includes("visibility=External"));
    test:assertFalse(query.includes("Internal"));
    test:assertFalse(query.includes("designationId"));

    string similar = check vacancyQuery(100, "Permanent");
    test:assertTrue(similar.includes("designationId=100"));
    test:assertTrue(similar.includes("employmentType=Permanent"));
    test:assertTrue(similar.includes("visibility=All"));
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
function onlyOurOwnRefusalsKeepTheStatus422() {
    http:Response refused = new;
    refused.statusCode = 422;
    test:assertEquals(atsReply(refused).statusCode, 400);

    http:Response created = new;
    created.statusCode = 201;
    test:assertEquals(atsReply(created).statusCode, 201);

    http:Response duplicate = new;
    duplicate.statusCode = 409;
    test:assertEquals(atsReply(duplicate).statusCode, 409);
}

@test:Config {}
function permanentIsShownAsFullTime() {
    test:assertEquals(jobTypeOf("Permanent"), "Full Time");
    test:assertEquals(jobTypeOf("Internship"), "Internship");
}

@test:Config {}
function departmentNameFallsBackToUnknown() {
    test:assertEquals(departmentNameOf(UNITS, 1, 11), "People");
    test:assertEquals(departmentNameOf(UNITS, 1, 99), "Unknown");
    test:assertEquals(departmentNameOf(UNITS, 2, 10), "Unknown");
    test:assertEquals(departmentNameOf(UNITS, 3, 10), "Unknown");
}

@test:Config {}
function basicInfoUsesTheOrgNamesAndAnEmptyDateWhenUnpublished() {
    AtsVacancy unpublished = vacancy(1);
    unpublished.publishedOn = ();
    VacancyBasicInfo info = basicInfoOf(unpublished, UNITS);
    test:assertEquals(info.team, "Engineering");
    test:assertEquals(info.job_type, "Full Time");
    test:assertEquals(info.publish_status, "All");
    test:assertEquals(info.published_on, "");
}

@test:Config {}
function similarListingsShareTheSameLocationsInAnyOrder() {
    AtsVacancy current = vacancy(1, ["Sri Lanka", "USA"]);
    AtsVacancy[] sameDesignation = [
        current,
        vacancy(2, ["USA", "Sri Lanka"]),
        vacancy(3, ["Sri Lanka"])
    ];
    VacancyBasicInfo[] similar = similarListings(current, sameDesignation, UNITS);
    test:assertEquals(similar.length(), 1);
    test:assertEquals(similar[0].id, 2);
}

@test:Config {}
function designationMustBeFoundOnce() {
    test:assertEquals(designationNameOf(CAREER_FUNCTIONS, 101), "Tech Lead");
    test:assertTrue(designationNameOf(CAREER_FUNCTIONS, 999) is error);
    AtsCareerFunction[] duplicated = [...CAREER_FUNCTIONS, ...CAREER_FUNCTIONS];
    test:assertTrue(designationNameOf(duplicated, 101) is error);
}

@test:Config {}
function remoteVacancyHasNoOfficeAndAllowsRemote() {
    JobDetail|error detail = detailOf(vacancy(1, mode = "Remote"), COMPANIES, UNITS, CAREER_FUNCTIONS, []);
    if detail is error {
        test:assertFail(detail.message());
    }
    test:assertEquals(detail.office_locations, {});
    test:assertTrue(detail.allow_remote);
    test:assertEquals(detail.designation, "Software Engineer");
    test:assertEquals(detail.mainContent, "<p>Main</p>");
    test:assertEquals(detail.taskInformation, "Task");
    test:assertEquals(detail.additionalContent, ());
}

@test:Config {}
function officeVacancyNamesItsOffice() {
    JobDetail|error detail = detailOf(vacancy(1), COMPANIES, UNITS, CAREER_FUNCTIONS, []);
    if detail is error {
        test:assertFail(detail.message());
    }
    test:assertEquals(detail.office_locations, {"0": "Colombo"});
    test:assertFalse(detail.allow_remote);

    JobDetail|error hybrid = detailOf(vacancy(1, mode = "Hybrid"), COMPANIES, UNITS, CAREER_FUNCTIONS, []);
    test:assertTrue(hybrid is JobDetail && hybrid.allow_remote);
}

@test:Config {}
function aVacancyWithoutAKnownOfficeHasNoOfficeLocation() {
    AtsVacancy noOffice = vacancy(1);
    noOffice.officeId = ();
    test:assertEquals(officeLocationsOf(noOffice, COMPANIES), {});

    AtsVacancy unlisted = vacancy(1);
    unlisted.officeId = 99;
    test:assertEquals(officeLocationsOf(unlisted, COMPANIES), {});
    test:assertEquals(officeLocationsOf(unlisted, []), {});
}

@test:Config {}
function aMissingDescriptionIsEmpty() {
    AtsVacancy withoutDescription = vacancy(1);
    withoutDescription.jdHtmlObject = ();
    JobDetail|error detail = detailOf(withoutDescription, COMPANIES, UNITS, CAREER_FUNCTIONS, []);
    if detail is error {
        test:assertFail(detail.message());
    }
    test:assertEquals(detail.mainContent, "");
    test:assertEquals(detail.taskInformation, ());
}

@test:Config {}
function aDescriptionSentAsAJsonStringIsRead() {
    AtsVacancy asString = vacancy(1);
    asString.jdHtmlObject = "{\"mainContent\": \"<p>Main</p>\", \"additionalContent\": \"More\"}";
    JobDetail|error detail = detailOf(asString, COMPANIES, UNITS, CAREER_FUNCTIONS, []);
    if detail is error {
        test:assertFail(detail.message());
    }
    test:assertEquals(detail.mainContent, "<p>Main</p>");
    test:assertEquals(detail.additionalContent, "More");
}

@test:Config {}
function aPlainTextDescriptionIsTheMainContent() {
    AtsVacancy plain = vacancy(1);
    plain.jdHtmlObject = "<p>Join us</p>";
    JobDetail|error detail = detailOf(plain, COMPANIES, UNITS, CAREER_FUNCTIONS, []);
    if detail is error {
        test:assertFail(detail.message());
    }
    test:assertEquals(detail.mainContent, "<p>Join us</p>");
}

@test:Config {}
function aDescriptionOfTheWrongKindIsShownAsText() {
    test:assertEquals(jdContentOf(5).mainContent, "5");
    test:assertEquals(jdContentOf("2024").mainContent, "2024");
    test:assertEquals(jdContentOf(true).mainContent, "true");
}

@test:Config {}
function aSectionThatIsNotTextIsLeftOutAndTheRestIsKept() {
    JdContent jd = jdContentOf({mainContent: (), taskInformation: "Task", additionalContent: 7});
    test:assertEquals(jd.mainContent, "");
    test:assertEquals(jd.taskInformation, "Task");
    test:assertEquals(jd.additionalContent, ());
    test:assertEquals(jdContentOf("{\"mainContent\": null}").mainContent, "");
}

@test:Config {}
function aMissingDesignationIsShownAsUnknown() {
    JobDetail|error detail = detailOf(vacancy(1), COMPANIES, UNITS, [], []);
    if detail is error {
        test:assertFail(detail.message());
    }
    test:assertEquals(detail.designation, "Unknown");
}

@test:Config {}
function orgStructureWithoutConfigListsCompanyLocationsAsTheyAre() {
    OrgStructure org = orgStructureOf(COMPANIES, UNITS, ());
    test:assertEquals(org.location_list, {"0": "Sri Lanka", "1": "USA"});
    test:assertEquals(org.team_list, {"0": "Engineering", "1": "People"});
}

@test:Config {}
function orgStructureWithConfigPutsTheGlobalTitleFirstAndRemovesDuplicates() {
    AtsAppConfig config = {
        globalHiringTitle: "Global",
        customHiringLocationMap: [{location: "Europe", customMap: ["Germany", " usa "]}]
    };
    OrgStructure org = orgStructureOf(COMPANIES, UNITS, config);
    test:assertEquals(org.location_list, {"0": "GLOBAL", "1": "EUROPE", "2": "GERMANY", "3": "SRI LANKA", "4": "USA"});
}

@test:Config {}
function internshipNeedsAUniversityAndTakesNoAddress() {
    test:assertEquals(atsCandidateOf(application(), "Internship", 7), "University is required for internship applications.");
    test:assertEquals(atsCandidateOf(application(university = "  "), "Internship", 7),
        "University is required for internship applications.");

    AtsCandidate|string candidate = atsCandidateOf(application(university = "State University"), "Internship", 7);
    if candidate is string {
        test:assertFail(candidate);
    }
    test:assertEquals(candidate.address, "N/A");
    test:assertEquals(candidate?.university, "State University");
}

@test:Config {}
function otherVacanciesNeedAnAddressAndTakeNoUniversity() {
    test:assertEquals(atsCandidateOf(application(address = " "), "Permanent", 7), "Address is required for this vacancy.");

    AtsCandidate|string candidate = atsCandidateOf(application(university = "State University"), "Permanent", 7);
    if candidate is string {
        test:assertFail(candidate);
    }
    test:assertEquals(candidate.address, "1 Main Street");
    test:assertEquals(candidate?.university, ());
    test:assertEquals(candidate.vacancyId, 7);
    test:assertEquals(candidate.status, "CREATED");
    test:assertEquals(candidate.appliedFrom, "Career Site");
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
