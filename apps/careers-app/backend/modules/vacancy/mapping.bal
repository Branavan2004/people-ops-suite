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

import ballerina/lang.array;
import ballerina/lang.value;
import ballerina/log;

isolated function jobTypeOf(string employmentType) returns string =>
    employmentType == EMPLOYMENT_PERMANENT ? EMPLOYMENT_FULL_TIME : employmentType;

isolated function departmentNameOf(AtsBusinessUnit[] units, int businessUnitId, int departmentId) returns string {
    foreach AtsBusinessUnit unit in units {
        if unit.id != businessUnitId {
            continue;
        }
        foreach AtsDepartment department in unit.departments ?: [] {
            if department.id == departmentId {
                return department.department;
            }
        }
    }
    return UNKNOWN_NAME;
}

// The name of the office, or nothing when the vacancy has no office or it is not in the companies.
isolated function officeNameOf(AtsCompany[] companies, int? officeId) returns string? {
    if officeId is () {
        return ();
    }
    foreach AtsCompany company in companies {
        foreach AtsOffice office in company.offices ?: [] {
            if office.id === officeId {
                return office.office;
            }
        }
    }
    return ();
}

// The offices of a vacancy keyed by position; none for a remote vacancy or one without a known office.
isolated function officeLocationsOf(AtsVacancy vacancy, AtsCompany[] companies) returns map<string> {
    string? office = vacancy.modeOfWork == MODE_REMOTE ? () : officeNameOf(companies, vacancy.officeId);
    return office is string ? {"0": office} : {};
}

isolated function designationNameOf(AtsCareerFunction[] careerFunctions, int designationId) returns string|error {
    string[] names = [];
    foreach AtsCareerFunction careerFunction in careerFunctions {
        foreach AtsDesignation designation in careerFunction.designations ?: [] {
            if designation.id == designationId {
                names.push(designation.designation);
            }
        }
    }
    if names.length() == 0 {
        return error(string `No designation found for ${designationId}`);
    }
    if names.length() > 1 {
        return error(string `Multiple designations found for ${designationId}`);
    }
    return names[0];
}

isolated function basicInfoOf(AtsVacancy vacancy, AtsBusinessUnit[] units) returns VacancyBasicInfo => {
    id: vacancy.id,
    title: vacancy.title,
    publish_status: vacancy.visibility,
    country: vacancy.hiringLocations,
    job_type: jobTypeOf(vacancy.employmentType),
    team: departmentNameOf(units, vacancy.businessUnitId, vacancy.departmentId),
    published_on: vacancy.publishedOn ?: ""
};

// The other vacancies with the same hiring locations.
isolated function similarListings(AtsVacancy current, AtsVacancy[] sameDesignation, AtsBusinessUnit[] units)
        returns VacancyBasicInfo[] {
    string[] currentLocations = array:sort(current.hiringLocations.clone());
    VacancyBasicInfo[] similar = [];
    foreach AtsVacancy vacancy in sameDesignation {
        if vacancy.id != current.id && array:sort(vacancy.hiringLocations.clone()) == currentLocations {
            similar.push(basicInfoOf(vacancy, units));
        }
    }
    return similar;
}

// The sections of the job description. A description that is not in the expected shape never fails the job page: a
// section that is not text is left out, and any other value is shown as text.
isolated function jdContentOf(json jdHtmlObject) returns JdContent {
    json content = jdHtmlObject;
    if jdHtmlObject is string {
        json|error parsed = value:fromJsonString(jdHtmlObject);
        if parsed is error {
            return {mainContent: jdHtmlObject};
        }
        content = parsed;
    }
    if content is () {
        return {};
    }
    if content is string {
        return {mainContent: content};
    }
    if content is map<json> {
        return {
            mainContent: sectionOf(content["mainContent"]) ?: "",
            taskInformation: sectionOf(content["taskInformation"]),
            additionalContent: sectionOf(content["additionalContent"])
        };
    }
    return {mainContent: jdHtmlObject is string ? jdHtmlObject : content.toString()};
}

// The text of a job description section, or nothing when it is missing or not text.
isolated function sectionOf(json section) returns string? => section is string ? section : ();

isolated function detailOf(AtsVacancy vacancy, AtsCompany[] companies, AtsBusinessUnit[] units,
        AtsCareerFunction[] careerFunctions, AtsVacancy[] sameDesignation) returns JobDetail|error {
    JdContent jd = jdContentOf(vacancy.jdHtmlObject);
    string|error foundDesignation = designationNameOf(careerFunctions, vacancy.designationId);
    if foundDesignation is error {
        log:printWarn("The vacancy's designation is not in the career functions exactly once", vacancyId = vacancy.id,
            designationId = vacancy.designationId);
    }
    string designation = foundDesignation is string ? foundDesignation : UNKNOWN_NAME;
    boolean isRemote = vacancy.modeOfWork == MODE_REMOTE;
    return {
        id: vacancy.id,
        title: vacancy.title,
        designation,
        team: departmentNameOf(units, vacancy.businessUnitId, vacancy.departmentId),
        country: vacancy.hiringLocations,
        job_type: jobTypeOf(vacancy.employmentType),
        allow_remote: isRemote || vacancy.modeOfWork == MODE_HYBRID,
        office_locations: officeLocationsOf(vacancy, companies),
        publish_status: vacancy.visibility,
        published_on: vacancy.publishedOn,
        mainContent: jd.mainContent,
        taskInformation: jd.taskInformation,
        additionalContent: jd.additionalContent,
        similar_job_listing: similarListings(vacancy, sameDesignation, units)
    };
}

// Keys each value by its position in the list.
isolated function indexed(string[] values) returns map<string> {
    map<string> byIndex = {};
    foreach int i in 0 ..< values.length() {
        byIndex[i.toString()] = values[i];
    }
    return byIndex;
}

// The team names and hiring locations.
isolated function orgStructureOf(AtsCompany[] companies, AtsBusinessUnit[] units, AtsAppConfig? config)
        returns OrgStructure {
    string[] teams = [];
    foreach AtsBusinessUnit unit in units {
        foreach AtsDepartment department in unit.departments ?: [] {
            if teams.indexOf(department.department) is () {
                teams.push(department.department);
            }
        }
    }

    string[] companyLocations = from AtsCompany company in companies
        select company.location;
    string[] locations = companyLocations;
    if config is AtsAppConfig {
        map<string> unique = {};
        foreach AtsCustomHiringLocation custom in config.customHiringLocationMap {
            string location = custom.location.toUpperAscii().trim();
            unique[location] = location;
            foreach string mapped in custom.customMap {
                string mappedLocation = mapped.toUpperAscii().trim();
                unique[mappedLocation] = mappedLocation;
            }
        }
        foreach string companyLocation in companyLocations {
            string location = companyLocation.toUpperAscii().trim();
            unique[location] = location;
        }
        locations = [];
        if config.globalHiringTitle != "" {
            locations.push(config.globalHiringTitle.toUpperAscii().trim());
        }
        locations.push(...unique.toArray().sort());
    }
    return {location_list: indexed(locations), team_list: indexed(teams)};
}

// The status the web app shows for an ATS interview status.
isolated function interviewStatusOf(string atsStatus) returns string {
    match atsStatus {
        "COMPLETED" => {
            return "Completed";
        }
        "WITHDRAWN" => {
            return "Cancelled";
        }
    }
    return "Upcoming";
}

// The place of a physical interview: the custom location when there is one, otherwise the room and the floor.
isolated function physicalPlaceOf(AtsInterview interview) returns string {
    string? custom = interview.customLocation;
    if custom is string && custom.trim() != "" {
        return custom.trim();
    }
    string[] parts = [];
    string? room = interview.roomName;
    if room is string && room.trim() != "" {
        parts.push(room.trim());
    }
    string? floor = interview.floorNumber;
    if floor is string && floor.trim() != "" {
        parts.push(string `floor ${floor.trim()}`);
    }
    return string:'join(", ", ...parts);
}

// An interview in the shape the web app reads. Nothing but the fields it shows is passed on.
isolated function interviewOf(AtsInterview interview) returns ApplicationInterview {
    boolean isVirtual = interview.interviewModality == "Virtual";
    string? link = interview.meetingUrl;
    string? stage = interview.interviewStage;
    string? title = interview.title;
    string round = stage is string && stage.trim() != "" ? stage.trim()
        : title is string && title.trim() != "" ? title.trim() : "Interview";
    return {
        id: interview.id.toString(),
        round,
        dateTime: interview.startTime ?: "",
        mode: isVirtual ? "Video" : "Onsite",
        location: isVirtual ? (link is string ? link.trim() : "") : physicalPlaceOf(interview),
        status: interviewStatusOf(interview.status)
    };
}

// The interviews of an application in the order they take place.
isolated function interviewsOf(AtsInterview[] interviews) returns ApplicationInterview[] =>
    from AtsInterview interview in interviews
    let ApplicationInterview shown = interviewOf(interview)
    order by shown.dateTime ascending
    select shown;

// The status the web app shows for an ATS candidate status.
isolated function applicationStatusOf(string atsStatus) returns string {
    match atsStatus {
        "SHORTLISTED" => {
            return "Screening";
        }
        "INTERVIEW_IN_PROGRESS"|"INTERVIEW_COMPLETED" => {
            return "Interview";
        }
        "HIRED" => {
            return "Offer Accepted";
        }
        "REJECTED"|"NOT_SHORTLISTED" => {
            return "Rejected";
        }
    }
    return "Applied";
}

// The team of each published vacancy, keyed by vacancy id.
isolated function departmentsOf(json jobs) returns map<string> {
    map<string> departments = {};
    if jobs is json[] {
        foreach json job in jobs {
            if job is map<json> {
                json id = job["id"];
                json team = job["team"];
                if id is int && team is string {
                    departments[id.toString()] = team;
                }
            }
        }
    }
    return departments;
}

// The candidate's applications, newest first, without the ones that were deleted.
isolated function applicationsOf(AtsHistoryEntry[] history, map<string> departments) returns ApplicationSummary[] =>
    from AtsHistoryEntry entry in history
    where entry.status != CANDIDATE_STATUS_DELETED
    order by entry.id descending
    select {
        id: entry.id.toString(),
        jobId: entry.vacancyId.toString(),
        jobTitle: entry.vacancyTitle ?: "",
        department: departments[entry.vacancyId.toString()] ?: "",
        appliedDate: entry.createdOn ?: "",
        updatedDate: entry.updatedOn ?: entry.createdOn ?: "",
        status: applicationStatusOf(entry.status)
    };

// The candidate's most recent application that was not deleted.
isolated function latestEntry(AtsHistoryEntry[] history) returns AtsHistoryEntry? {
    AtsHistoryEntry[] latest = from AtsHistoryEntry entry in history
        where entry.status != CANDIDATE_STATUS_DELETED
        order by entry.id descending
        limit 1
        select entry;
    return latest.length() == 0 ? () : latest[0];
}

// The candidate's details from their most recent application.
isolated function profileOf(AtsHistoryEntry[] history, string email) returns CandidateProfile? {
    AtsHistoryEntry? entry = latestEntry(history);
    if entry is () {
        return ();
    }
    string? address = entry.address;
    return {
        firstName: entry.firstName ?: "",
        lastName: entry.lastName ?: "",
        gender: entry.gender ?: "",
        personalEmail: email,
        contactNo: entry.contactNo ?: "",
        address: address is string && address.trim() != "" && address != ADDRESS_NOT_APPLICABLE ? address : (),
        university: entry.university
    };
}

// The changes in the form the ATS takes, or the reason they cannot be accepted.
isolated function atsUpdateOf(ProfileChanges changes) returns AtsCandidateUpdate|string {
    AtsCandidateUpdate update = {};
    string? firstName = changes?.firstName;
    if firstName is string {
        if firstName.trim() == "" {
            return "Enter your first name.";
        }
        if firstName.trim().length() > MAX_NAME_LENGTH {
            return DETAIL_TOO_LONG_MESSAGE;
        }
        update.firstName = firstName.trim();
    }
    string? lastName = changes?.lastName;
    if lastName is string {
        if lastName.trim() == "" {
            return "Enter your last name.";
        }
        if lastName.trim().length() > MAX_NAME_LENGTH {
            return DETAIL_TOO_LONG_MESSAGE;
        }
        update.lastName = lastName.trim();
    }
    string? gender = changes?.gender;
    if gender is string {
        if gender !is "Male"|"Female"|"Prefer not to say" {
            return "Choose Male, Female or Prefer not to say as the gender.";
        }
        update.gender = gender;
    }
    string? contactNo = changes?.contactNo;
    if contactNo is string {
        if !apply:isValidPhone(contactNo.trim()) {
            return "Enter the phone number in international format, for example +94771234567.";
        }
        update.contactNo = contactNo.trim();
    }
    if changes.hasKey("address") {
        string address = (changes?.address ?: "").trim();
        if address.length() > MAX_ADDRESS_LENGTH {
            return DETAIL_TOO_LONG_MESSAGE;
        }
        update.address = address;
    }
    if changes.hasKey("university") {
        string university = (changes?.university ?: "").trim();
        if university.length() > MAX_UNIVERSITY_LENGTH {
            return DETAIL_TOO_LONG_MESSAGE;
        }
        update.university = university;
    }
    return update;
}

// The candidate in the form the ATS takes, or the reason it cannot be accepted.
isolated function atsCandidateOf(CandidateApplication candidate, string employmentType, int vacancyId)
        returns AtsCandidate|string {
    AtsCandidate atsCandidate = {
        ...candidate,
        vacancyId,
        status: CANDIDATE_STATUS_CREATED,
        appliedFrom: APPLIED_FROM_CAREER_SITE
    };
    if employmentType == EMPLOYMENT_INTERNSHIP {
        string? university = candidate?.university;
        if university is () || university.trim() == "" {
            return "University is required for internship applications.";
        }
        atsCandidate.address = ADDRESS_NOT_APPLICABLE;
    } else {
        if candidate.address.trim() == "" {
            return "Address is required for this vacancy.";
        }
        _ = atsCandidate.removeIfHasKey("university");
    }
    return atsCandidate;
}
