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
import people.database;
import people.promotion;

import ballerina/data.csv;
import ballerina/http;
import ballerina/log;
import ballerina/mime;
import ballerina/time;

# Generate the next employee ID for the given payload.
#
# + payload - Add employee payload
# + return - Generated or manually provided employee ID string or an HTTP error response in case of failure
public isolated function generateEmployeeId(database:CreateEmployeePayload payload)
        returns string|http:BadRequest|http:InternalServerError {

    database:EmployeeIdContext|error ctx = database:getEmployeeIdContext(
            payload.companyId, payload.employmentTypeId
    );
    if ctx is error {
        string customErr = "Error occurred while fetching employee ID context";
        log:printError(customErr, ctx);
        return <http:InternalServerError>{
            body: {
                message: customErr
            }
        };
    }

    // Reject inactive employment types before ID generation. The frontend already hides them,
    // but a direct API call could still submit an inactive (yet otherwise supported) type.
    if !ctx.isActive {
        string customErr = string `Employment type (ID: ${payload.employmentTypeId}) is inactive ` +
            "and cannot be used for onboarding.";
        log:printWarn(customErr, employmentTypeId = payload.employmentTypeId, employmentType = ctx.employmentType);
        return <http:BadRequest>{
            body: {
                message: customErr
            }
        };
    }

    // Normalize the prefix once so a value like " SG " can't pass the empty-prefix guard, leak
    // spaces into the ID, or fork a separate numeric sequence from "SG".
    string companyPrefix = ctx.companyPrefix.trim();

    match ctx.employmentType {
        database:PERMANENT|database:INTERNSHIP|database:PROBATION => {
            if companyPrefix.length() == 0 {
                string customErr = string `The selected company (ID: ${payload.companyId}) has no employee ` +
                    "ID prefix configured. Set the company prefix before onboarding.";
                log:printWarn(customErr, companyId = payload.companyId, employmentType = ctx.employmentType);
                return <http:BadRequest>{
                    body: {
                        message: customErr
                    }
                };
            }
            // PERMANENT and PROBATION share the "1" digit family (an employee keeps the same ID
            // across probation -> permanent); INTERNSHIP uses "5". Scoping by this digit directly
            // on the ID string (not by employment_type) means an employee tagged with any other
            // or legacy type can never be invisible to this count.
            int digit = ctx.employmentType == database:INTERNSHIP ? 5 : 1;
            string|error nextId = database:getNextIdInFamily(companyPrefix, digit);
            if nextId is error {
                string customErr = "Error occurred while generating the next employee ID";
                log:printError(customErr, nextId, employmentType = ctx.employmentType, companyPrefix = companyPrefix);
                return <http:InternalServerError>{
                    body: {
                        message: customErr
                    }
                };
            }
            return nextId;
        }
        database:CONSULTANCY|database:ADVISORY_CONSULTANCY|database:PART_TIME_CONSULTANCY => {
            string|error nextId = database:getNextIdInFamily(database:CONSULTANCY_ID_PREFIX, 0, zeroPadded = true);
            if nextId is error {
                string customErr = "Error occurred while generating the next employee ID";
                log:printError(customErr, nextId, employmentType = ctx.employmentType);
                return <http:InternalServerError>{
                    body: {
                        message: customErr
                    }
                };
            }
            return nextId;
        }
        database:FIXED_TERM => {
            string manualId = (payload.employeeId ?: "").trim();
            if manualId.length() == 0 {
                string customErr = "Employee ID must be provided manually for fixed-term employment type";
                log:printWarn(customErr);
                return <http:BadRequest>{
                    body: {
                        message: customErr
                    }
                };
            }

            if manualId.startsWith(companyPrefix) && re `[0-9]+`.isFullMatch(manualId.substring(companyPrefix.length()))
                || manualId.startsWith(database:CONSULTANCY_ID_PREFIX) && re `[0-9]+`.
                    isFullMatch(manualId.substring(database:CONSULTANCY_ID_PREFIX.length())) {
                string customErr = string `Employee ID '${manualId}' is reserved for auto-generation and cannot be assigned manually`;
                log:printWarn(customErr, employeeId = manualId);
                return <http:BadRequest>{
                    body: {
                        message: customErr
                    }
                };
            }

            database:Employee|error? existing = database:getEmployeeInfo(manualId);
            if existing is error {
                string customErr = "Error occurred while checking existing employee ID";
                log:printError(customErr, existing, employeeId = manualId);
                return <http:InternalServerError>{
                    body: {
                        message: customErr
                    }
                };
            }
            if existing is database:Employee {
                string customErr = string `Employee ID already in use: ${manualId}`;
                log:printWarn(customErr, employeeId = manualId);
                return <http:BadRequest>{
                    body: {
                        message: customErr
                    }
                };
            }
            return manualId;
        }
        _ => {
            string customErr = string `Unsupported employment type: ${ctx.employmentType}`;
            log:printError(customErr, employmentType = ctx.employmentType);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
    }
}

# Roll back an employee record after a downstream provisioning step fails.
#
# + employeeId - Employee ID to delete
# + workEmail - Work email of the affected user
isolated function rollbackEmployeeCreation(string employeeId, string workEmail) {
    error? rollbackErr = database:deleteEmployeeById(employeeId);
    if rollbackErr is error {
        log:printError("Failed to roll back employee record; manual cleanup required",
                rollbackErr, employeeId = employeeId, workEmail = workEmail);
    }
}

# Validate a continuous service record link before it is written.
#
# The link stores the prior employment's `employee.id`. Only a record the
# continuous-service-records endpoint would offer for this work email is accepted, and only
# one that has ended or is ending (Left or Marked leaver) and started before this employment;
# anything else, including an unrelated person's record, this employment itself, or a later record that would link
# forwards or form a cycle, is refused as a bad request instead of reaching the database.
#
# + linkedId - `employee.id` of the prior employment being linked
# + workEmail - Work email the employment will hold once the request is applied
# + startDate - Start date (YYYY-MM-DD) the employment will hold once the request is applied
# + employeeId - Employee ID of the employment being updated, or () when creating one
# + return - A BadRequest or InternalServerError response when the link is refused, else ()
isolated function validateContinuousServiceRecord(int linkedId, string workEmail, string startDate,
        string? employeeId = ()) returns http:BadRequest|http:InternalServerError? {

    database:ContinuousServiceRecordInfo[]|error priorRecords =
        database:getContinuousServiceRecordsByEmail(workEmail);
    if priorRecords is error {
        log:printError("Error occurred while validating the continuous service record", priorRecords,
                linkedId = linkedId, workEmail = workEmail);
        return <http:InternalServerError>{
            body: {
                message: "Error occurred while validating the continuous service record"
            }
        };
    }

    foreach database:ContinuousServiceRecordInfo priorRecord in priorRecords {
        if priorRecord.id == linkedId && database:isEligiblePriorEmployment(priorRecord, startDate, employeeId) {
            return;
        }
    }

    log:printWarn("Continuous service record is not an eligible prior employment",
            linkedId = linkedId, workEmail = workEmail, startDate = startDate, employeeId = employeeId);
    return <http:BadRequest>{
        body: {
            message: "Continuous service record must be an earlier employment under the same work email "
                + "that has ended or is ending (status Left or Marked leaver)"
        }
    };
}

# Validate who is being onboarded, before anything is written.
#
# The NIC/Passport decides whether this is someone new, a rehire, or someone already
# employed (see database:checkReturningEmployee). A work email that is given must not belong
# to an Active or New joiner employee. A former employee's or a Marked leaver's email is fine:
# that is how someone returning, or relocating under a different NIC, keeps their email, house
# and continuous service.
#
# + nicOrPassport - NIC/Passport from the submission
# + workEmail - Work email from the submission, nil when left empty
# + return - The BadRequest or InternalServerError to send, or nil when onboarding may go ahead
isolated function validateOnboardingIdentity(string nicOrPassport, string? workEmail)
        returns http:BadRequest|http:InternalServerError? {

    database:EmploymentMatch[]|error employments = database:getEmploymentsByNic(nicOrPassport);
    if employments is error {
        log:printError("Error occurred while checking existing employee personal information", employments,
                nicOrPassport = nicOrPassport);
        return <http:InternalServerError>{body: {message: ERROR_EMPLOYEE_CREATION_FAILED}};
    }
    string? refusal = database:checkReturningEmployee(employments, workEmail);
    if refusal is string {
        log:printWarn(refusal, nicOrPassport = nicOrPassport, workEmail = workEmail);
        return <http:BadRequest>{body: {message: refusal}};
    }

    if workEmail is () {
        return;
    }
    database:EmploymentMatch|error? holder = database:getCurrentEmployeeByWorkEmail(workEmail);
    if holder is error {
        log:printError("Error occurred while checking whether the work email is in use", holder,
                workEmail = workEmail);
        return <http:InternalServerError>{body: {message: ERROR_EMPLOYEE_CREATION_FAILED}};
    }
    if holder is database:EmploymentMatch {
        string customErr = string `Work email ${workEmail} is already in use by ${holder.firstName} `
            + string `${holder.lastName} (${holder.employeeId})`;
        log:printWarn(customErr, workEmail = workEmail, holderEmployeeId = holder.employeeId);
        return <http:BadRequest>{body: {message: customErr}};
    }
}

# Validate that an edit does not leave the same person with two current employments.
#
# After a relocation the old employment is Marked leaver and the new one Active or New joiner.
# Setting the old one back to Active, or giving an employee a work email another current
# employee holds, would leave two current records for the same person or address. See
# database:identityChecksForEdit for when each check applies.
#
# + employeeInfo - The employee as stored, before the edit
# + requestedStatus - Status the edit sets, nil when it leaves the status alone
# + requestedEmail - Work email the edit sets, nil when it leaves the email alone
# + return - The BadRequest or InternalServerError to send, or nil when the edit may go ahead
isolated function validateEditIdentity(database:Employee employeeInfo, string? requestedStatus,
        string? requestedEmail) returns http:BadRequest|http:InternalServerError? {

    string employeeId = employeeInfo.employeeId;
    var checks = database:identityChecksForEdit(employeeInfo.employeeStatus, requestedStatus,
            employeeInfo.workEmail, requestedEmail);

    string workEmail = requestedEmail ?: employeeInfo.workEmail;
    if checks.email && !database:isPlaceholderWorkEmail(workEmail) {
        database:EmploymentMatch|error? holder = database:getCurrentEmployeeByWorkEmail(workEmail, employeeId);
        if holder is error {
            log:printError("Error occurred while checking whether the work email is in use", holder,
                    employeeId = employeeId, workEmail = workEmail);
            return <http:InternalServerError>{body: {message: ERROR_EMPLOYEE_INFO_UPDATE_FAILED}};
        }
        if holder is database:EmploymentMatch {
            string customErr = string `Work email ${workEmail} is already in use by ${holder.firstName} `
                + string `${holder.lastName} (${holder.employeeId})`;
            log:printWarn(customErr, employeeId = employeeId, holderEmployeeId = holder.employeeId);
            return <http:BadRequest>{body: {message: customErr}};
        }
    }

    if !checks.nic {
        return;
    }
    // The single-employee lookup does not load the NIC/Passport, so it is read here.
    database:EmployeePersonalInfo|error? personalInfo = database:getEmployeePersonalInfo(employeeId);
    if personalInfo is error {
        log:printError("Error occurred while fetching the employee's NIC/Passport", personalInfo,
                employeeId = employeeId);
        return <http:InternalServerError>{body: {message: ERROR_EMPLOYEE_INFO_UPDATE_FAILED}};
    }
    string nicOrPassport = personalInfo is () ? "" : personalInfo.nicOrPassport.trim();
    if nicOrPassport != "" {
        database:EmploymentMatch[]|error employments = database:getEmploymentsByNic(nicOrPassport);
        if employments is error {
            log:printError("Error occurred while checking the employee's other employments", employments,
                    employeeId = employeeId);
            return <http:InternalServerError>{body: {message: ERROR_EMPLOYEE_INFO_UPDATE_FAILED}};
        }
        database:EmploymentMatch? other = database:otherCurrentEmployment(employments, employeeId);
        if other is database:EmploymentMatch {
            string customErr = string `This NIC/Passport already has a current employment: ${other.firstName} `
                + string `${other.lastName} (${other.employeeId}, ${other.employeeStatus})`;
            log:printWarn(customErr, employeeId = employeeId, otherEmployeeId = other.employeeId);
            return <http:BadRequest>{body: {message: customErr}};
        }
    }
}

# Validate the leadership attributes submitted for an employee.
#
# Every id must be an active attribute; an unknown or inactive one rejects the whole update
# rather than applying it partially. Duplicates are tolerated and removed.
#
# + requested - Attribute ids from the request
# + employeeId - Employee ID the attributes are being set on, for the log
# + return - The de-duplicated ids, or the BadRequest or InternalServerError response to send
isolated function validateLeadershipGroupIds(int[] requested, string employeeId)
        returns int[]|http:BadRequest|http:InternalServerError {

    database:LeadershipGroup[]|error active = database:getLeadershipGroups();
    if active is error {
        log:printError("Error validating leadership attributes", active, employeeId = employeeId);
        return <http:InternalServerError>{body: {message: "Error updating employee"}};
    }
    int[] activeIds = from database:LeadershipGroup g in active select g.id;

    int[] deduped = [];
    foreach int id in requested {
        if activeIds.indexOf(id) == () {
            log:printWarn("Unknown or inactive leadership attribute", employeeId = employeeId,
                    leadershipGroupId = id);
            return <http:BadRequest>{
                body: {message: string `Unknown or inactive leadership attribute: ${id}`}
            };
        }
        if deduped.indexOf(id) == () {
            deduped.push(id);
        }
    }
    return deduped;
}

# Validates that a date string is a valid calendar date in the format YYYY-MM-DD.
#
# + date - Date string to validate (expected format YYYY-MM-DD)
# + return - `true` if the string is a valid calendar date in the expected format, `false` otherwise
isolated function isValidCalendarDate(string date) returns boolean {
    time:Civil|error civil = time:civilFromString(date + "T00:00:00Z");
    if civil is error {
        return false;
    }
    return string `${civil.year}-${civil.month.toString().padStart(2, "0")}-${civil.day.toString().padStart(2, "0")}` == date;
}

# Normalizes a string into a lowercase alphanumeric key.
#
# + value - Raw string to normalize
# + return - Lowercase alphanumeric string
public isolated function normalizeKey(string value) returns string {
    string stripped = value.startsWith("\u{FEFF}") ? value.substring(1) : value;
    return re `[^a-zA-Z0-9]+`.replaceAll(stripped.trim(), "").toLowerAscii();
}

# Loads all reference data required for bulk CSV validation from the database
# and builds normalized name-to-ID lookup maps.
#
# + return - `BulkRefData` with lookup maps, or an error if any DB query fails
isolated function loadBulkReferenceData() returns BulkRefData|error {
    future<database:BusinessUnit[]|error> bu = start database:getBusinessUnits();
    future<database:Team[]|error> t = start database:getTeams();
    future<database:SubTeam[]|error> st = start database:getSubTeams();
    future<database:Unit[]|error> u = start database:getUnits();
    future<database:Designation[]|error> d = start database:getDesignations();
    future<database:EmploymentType[]|error> et = start database:getEmploymentTypes();
    future<database:CompanyResponse[]|error> c = start database:getCompanies();
    future<database:Office[]|error> o = start database:getOffices();
    future<map<string>|error> lt = start database:getLocationTimeZones();

    database:BusinessUnit[] businessUnits = check wait bu;
    database:Team[] teams = check wait t;
    database:SubTeam[] subTeams = check wait st;
    database:Unit[] units = check wait u;
    database:Designation[] designations = check wait d;
    database:EmploymentType[] employmentTypes = check wait et;
    database:CompanyResponse[] companies = check wait c;
    database:Office[] offices = check wait o;
    map<string> locationTimeZones = check wait lt;

    return {
        businessUnitIds: map from database:BusinessUnit bu_row in businessUnits
            select [normalizeKey(bu_row.name), bu_row.id],
        teamIds: map from database:Team t_row in teams
            select [normalizeKey(t_row.name), t_row.id],
        subTeamIds: map from database:SubTeam st_row in subTeams
            select [normalizeKey(st_row.name), st_row.id],
        unitIds: map from database:Unit u_row in units
            select [normalizeKey(u_row.name), u_row.id],
        designationIds: map from database:Designation d_row in designations
            select [normalizeKey(d_row.designation), d_row.id],
        // Only active types are valid for onboarding; mirrors the frontend filter so a CSV row
        // naming an inactive employment type is rejected during validation.
        employmentTypeIds: map from database:EmploymentType et_row in employmentTypes
            where et_row.isActive
            select [normalizeKey(et_row.name), et_row.id],
        companyIds: map from database:CompanyResponse c_row in companies
            select [normalizeKey(c_row.name), c_row.id],
        officeIds: map from database:Office o_row in offices
            select [normalizeKey(o_row.name), o_row.id],
        locationTimeZones
    };
}

# Validates a single CSV data row for required fields, formats, and reference data.
#
# + rowNumber - 1-based row number used in error reporting
# + row - Typed CSV row to validate
# + refData - Pre-loaded reference data lookup maps
# + return - Validation errors for the row; empty if valid
isolated function validateBulkRow(int rowNumber, BulkEmployeeCsvRow row, BulkRefData refData)
    returns database:BulkEmployeeError[] {

    database:BulkEmployeeError[] errors = [];

    // Required field presence checks
    if row.firstName.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_FIRST_NAME, message: "First name is required"});
    }
    if row.lastName.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_LAST_NAME, message: "Last name is required"});
    }
    // An empty work email is a joiner whose account does not exist yet; FUTURE_JOINER_EMAIL is
    // stored for them. A placeholder typed in is refused, as in single onboarding.
    string workEmail = row.workEmail.trim();
    if workEmail.length() > 0 && !database:EMAIL_PATTERN.isFullMatch(workEmail) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_WORK_EMAIL, message: "Invalid work email format"});
    } else if database:isPlaceholderWorkEmail(workEmail) {
        errors.push({
            row: rowNumber,
            'field: CSV_FIELD_WORK_EMAIL,
            message: "Leave the work email empty when the employee's account is not created yet"
        });
    }
    if row.managerEmail.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_MANAGER_EMAIL, message: "Manager email is required"});
    } else if !database:EMAIL_PATTERN.isFullMatch(row.managerEmail.trim()) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_MANAGER_EMAIL, message: "Invalid manager email format"});
    }
    if row.designation.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_DESIGNATION, message: "Designation is required"});
    }
    if row.businessUnit.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_BUSINESS_UNIT, message: "Business unit is required"});
    }
    if row.team.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_TEAM, message: "Team is required"});
    }
    if row.startDate.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_START_DATE, message: "Start date is required"});
    } else if !isValidCalendarDate(row.startDate.trim()) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_START_DATE, message: "Start date must be a valid date in YYYY-MM-DD format"});
    }
    if row.employmentType.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_EMPLOYMENT_TYPE, message: "Employment type is required"});
    }
    if row.company.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_COMPANY, message: "Company is required"});
    }
    if row.workLocation.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_WORK_LOCATION, message: "Work location is required"});
    }
    if row.title.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_TITLE, message: "Title is required"});
    }
    if row.nicOrPassport.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_NIC_OR_PASSPORT, message: "NIC / Passport is required"});
    }
    if row.dob.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_DOB, message: "Date of birth is required"});
    } else if !isValidCalendarDate(row.dob.trim()) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_DOB, message: "Date of birth must be a valid date in YYYY-MM-DD format"});
    }
    if row.gender.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_GENDER, message: "Gender is required"});
    }
    if row.nationality.trim().length() == 0 {
        errors.push({row: rowNumber, 'field: CSV_FIELD_NATIONALITY, message: "Nationality is required"});
    }

    // Optional field format checks
    if row.personalEmail.trim().length() > 0 && !database:EMAIL_PATTERN.isFullMatch(row.personalEmail.trim()) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_PERSONAL_EMAIL, message: "Invalid personal email format"});
    }
    if row.probationEndDate.trim().length() > 0 && !isValidCalendarDate(row.probationEndDate.trim()) {
        errors.push({
            row: rowNumber,
            'field: CSV_FIELD_PROBATION_END_DATE,
            message: "Probation end date must be a valid date in YYYY-MM-DD format"
        });
    }
    if row.agreementEndDate.trim().length() > 0 && !isValidCalendarDate(row.agreementEndDate.trim()) {
        errors.push({
            row: rowNumber,
            'field: CSV_FIELD_AGREEMENT_END_DATE,
            message: "Agreement end date must be a valid date in YYYY-MM-DD format"
        });
    }

    if row.additionalManagerEmails.trim().length() > 0 {
        string[] parts = re `,`.split(row.additionalManagerEmails);
        foreach string part in parts {
            string email = part.trim();
            if email.length() > 0 && !database:EMAIL_PATTERN.isFullMatch(email) {
                errors.push({
                    row: rowNumber,
                    'field: CSV_FIELD_ADDITIONAL_MANAGER_EMAILS,
                    message: "Invalid email in additionalManagerEmails: " + email
                });
            }
        }
    }

    string ecName = row.emergencyContactName.trim();
    if ecName.length() > 0 {
        if row.emergencyContactMobile.trim().length() == 0 {
            errors.push({
                row: rowNumber,
                'field: CSV_FIELD_EMERGENCY_CONTACT_MOBILE,
                message: "Emergency contact mobile is required when name is provided"
            });
        }
        if row.emergencyContactRelationship.trim().length() == 0 {
            errors.push({
                row: rowNumber,
                'field: CSV_FIELD_EMERGENCY_CONTACT_RELATIONSHIP,
                message: "Emergency contact relationship is required when name is provided"
            });
        }
    } else if row.emergencyContactMobile.trim().length() > 0
            || row.emergencyContactRelationship.trim().length() > 0
            || row.emergencyContactTelephone.trim().length() > 0 {
        errors.push({
            row: rowNumber,
            'field: CSV_FIELD_EMERGENCY_CONTACT_NAME,
            message: "Emergency contact name is required when mobile, relationship, or telephone is provided"
        });
    }

    if row.designation.trim().length() > 0 && !refData.designationIds.hasKey(normalizeKey(row.designation)) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_DESIGNATION, message: "Unknown designation"});
    }
    if row.businessUnit.trim().length() > 0 && !refData.businessUnitIds.hasKey(normalizeKey(row.businessUnit)) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_BUSINESS_UNIT, message: "Unknown business unit"});
    }
    if row.team.trim().length() > 0 && !refData.teamIds.hasKey(normalizeKey(row.team)) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_TEAM, message: "Unknown team"});
    }
    if row.subTeam.trim().length() > 0 && !refData.subTeamIds.hasKey(normalizeKey(row.subTeam)) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_SUB_TEAM, message: "Unknown sub team"});
    }
    if row.unit.trim().length() > 0 && !refData.unitIds.hasKey(normalizeKey(row.unit)) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_UNIT, message: "Unknown unit"});
    }
    if row.employmentType.trim().length() > 0 && !refData.employmentTypeIds.hasKey(normalizeKey(row.employmentType)) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_EMPLOYMENT_TYPE, message: "Unknown employment type"});
    } else if row.employmentType.trim().length() > 0 && normalizeKey(row.employmentType) == normalizeKey(database:FIXED_TERM) {
        errors.push({
            row: rowNumber,
            'field: CSV_FIELD_EMPLOYMENT_TYPE,
            message: "Fixed-term contract is not supported for bulk onboarding. Use the single employee form instead."
        });
    }
    if row.company.trim().length() > 0 && !refData.companyIds.hasKey(normalizeKey(row.company)) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_COMPANY, message: "Unknown company"});
    }
    if row.office.trim().length() > 0 && !refData.officeIds.hasKey(normalizeKey(row.office)) {
        errors.push({row: rowNumber, 'field: CSV_FIELD_OFFICE, message: "Unknown office: '" + row.office.trim() + "'"});
    }

    return errors;
}

# Builds a `CreateEmployeePayload` from a validated CSV row.
#
# + row - Typed CSV row to build the payload from
# + refData - Pre-loaded reference data lookup maps
# + return - Fully populated `CreateEmployeePayload` ready for DB insertion; houseId is left
#   unset here — it's assigned automatically once the employee ID is resolved (see addEmployeesBulk)
isolated function buildBulkEmployeePayload(BulkEmployeeCsvRow row, BulkRefData refData)
    returns database:CreateEmployeePayload {

    string firstName = row.firstName.trim();
    string lastName = row.lastName.trim();

    string officeRaw = row.office.trim();
    string subTeamRaw = row.subTeam.trim();
    string unitRaw = row.unit.trim();
    int? officeId = officeRaw.length() > 0 ? refData.officeIds[normalizeKey(officeRaw)] : ();
    int? subTeamId = subTeamRaw.length() > 0 ? refData.subTeamIds[normalizeKey(subTeamRaw)] : ();
    int? unitId = unitRaw.length() > 0 ? refData.unitIds[normalizeKey(unitRaw)] : ();

    database:Email[] additionalManagerEmails = [];
    if row.additionalManagerEmails.trim().length() > 0 {
        string[] parts = re `,`.split(row.additionalManagerEmails);
        foreach string part in parts {
            string email = part.trim();
            if email.length() > 0 {
                additionalManagerEmails.push(email);
            }
        }
    }

    database:EmergencyContact[]? emergencyContacts = ();
    string ecName = row.emergencyContactName.trim();
    if ecName.length() > 0 {
        string ecTelephone = row.emergencyContactTelephone.trim();
        emergencyContacts = [
            {
                name: ecName,
                mobile: row.emergencyContactMobile.trim(),
                relationship: row.emergencyContactRelationship.trim(),
                telephone: ecTelephone.length() > 0 ? ecTelephone : ()
            }
        ];
    }

    int companyId = refData.companyIds[normalizeKey(row.company)] ?: 0;
    string workLocation = row.workLocation.trim();
    string today = database:localDateAt(refData.locationTimeZones, companyId, workLocation, time:utcNow());

    return {
        firstName,
        lastName,
        epf: row.epf.trim().length() > 0 ? row.epf.trim() : (),
        companyId,
        workLocation,
        workEmail: row.workEmail.trim().length() > 0 ? row.workEmail.trim() : (),
        startDate: row.startDate.trim(),
        employeeStatus: database:initialEmployeeStatus(row.startDate.trim(), today),
        managerEmail: row.managerEmail.trim(),
        secondaryJobTitle: row.secondaryJobTitle.trim().length() > 0 ? row.secondaryJobTitle.trim() : (),
        employmentTypeId: refData.employmentTypeIds[normalizeKey(row.employmentType)] ?: 0,
        designationId: refData.designationIds[normalizeKey(row.designation)] ?: 0,
        teamId: refData.teamIds[normalizeKey(row.team)] ?: 0,
        subTeamId,
        unitId,
        businessUnitId: refData.businessUnitIds[normalizeKey(row.businessUnit)] ?: 0,
        officeId,
        houseId: (),
        additionalManagerEmails,
        probationEndDate: row.probationEndDate.trim().length() > 0 ? row.probationEndDate.trim() : (),
        agreementEndDate: row.agreementEndDate.trim().length() > 0 ? row.agreementEndDate.trim() : (),
        personalInfo: {
            nicOrPassport: row.nicOrPassport.trim(),
            firstName,
            lastName,
            fullName: (firstName + " " + lastName).trim(),
            title: row.title.trim(),
            dob: row.dob.trim(),
            gender: row.gender.trim(),
            nationality: row.nationality.trim(),
            personalEmail: row.personalEmail.trim().length() > 0 ? row.personalEmail.trim() : (),
            personalPhone: row.personalPhone.trim().length() > 0 ? row.personalPhone.trim() : (),
            residentNumber: row.residentNumber.trim().length() > 0 ? row.residentNumber.trim() : (),
            addressLine1: row.addressLine1.trim().length() > 0 ? row.addressLine1.trim() : (),
            addressLine2: row.addressLine2.trim().length() > 0 ? row.addressLine2.trim() : (),
            city: row.city.trim().length() > 0 ? row.city.trim() : (),
            stateOrProvince: row.stateOrProvince.trim().length() > 0 ? row.stateOrProvince.trim() : (),
            postalCode: row.postalCode.trim().length() > 0 ? row.postalCode.trim() : (),
            country: row.country.trim().length() > 0 ? row.country.trim() : (),
            emergencyContacts
        }
    };
}

# Extracts the CSV file bytes from a multipart HTTP request.
#
# + req - Incoming HTTP request containing multipart form-data
# + return - File contents as a byte array, or `http:BadRequest` if missing or unreadable
public isolated function extractCsvFileBytes(http:Request req) returns byte[]|http:BadRequest {
    mime:Entity[]|error bodyParts = req.getBodyParts();
    if bodyParts is error {
        return <http:BadRequest>{
            body: {
                message: "Invalid multipart payload"
            }
        };
    }

    foreach mime:Entity part in bodyParts {
        string|mime:HeaderNotFoundError cd = part.getHeader(mime:CONTENT_DISPOSITION);
        if cd is string {
            mime:ContentDisposition disposition = mime:getContentDispositionObject(cd);
            if disposition.name == "file" {
                byte[]|mime:ParserError fileBytes = part.getByteArray();
                if fileBytes is mime:ParserError {
                    return <http:BadRequest>{
                        body: {
                            message: "Failed to read uploaded file"
                        }
                    };
                }
                return fileBytes;
            }
        }
    }
    return <http:BadRequest>{
        body: {
            message: "Missing 'file' field in multipart form data"
        }
    };
}

# Returns true when every field in the row is blank after trimming.
#
# + row - Typed CSV row to inspect
# + return - `true` if every field (required and optional) is empty after trimming
isolated function isEmptyBulkRow(BulkEmployeeCsvRow row) returns boolean {
    return row.firstName.trim().length() == 0
        && row.lastName.trim().length() == 0
        && row.workEmail.trim().length() == 0
        && row.managerEmail.trim().length() == 0
        && row.designation.trim().length() == 0
        && row.businessUnit.trim().length() == 0
        && row.team.trim().length() == 0
        && row.subTeam.trim().length() == 0
        && row.unit.trim().length() == 0
        && row.startDate.trim().length() == 0
        && row.employmentType.trim().length() == 0
        && row.company.trim().length() == 0
        && row.workLocation.trim().length() == 0
        && row.office.trim().length() == 0
        && row.title.trim().length() == 0
        && row.nicOrPassport.trim().length() == 0
        && row.dob.trim().length() == 0
        && row.gender.trim().length() == 0
        && row.nationality.trim().length() == 0
        && row.personalEmail.trim().length() == 0
        && row.personalPhone.trim().length() == 0
        && row.residentNumber.trim().length() == 0
        && row.addressLine1.trim().length() == 0
        && row.addressLine2.trim().length() == 0
        && row.city.trim().length() == 0
        && row.stateOrProvince.trim().length() == 0
        && row.postalCode.trim().length() == 0
        && row.country.trim().length() == 0
        && row.epf.trim().length() == 0
        && row.secondaryJobTitle.trim().length() == 0
        && row.probationEndDate.trim().length() == 0
        && row.agreementEndDate.trim().length() == 0
        && row.additionalManagerEmails.trim().length() == 0
        && row.emergencyContactName.trim().length() == 0
        && row.emergencyContactMobile.trim().length() == 0
        && row.emergencyContactRelationship.trim().length() == 0
        && row.emergencyContactTelephone.trim().length() == 0;
}

# Processes all CSV data rows in a single pass: skips fully-empty rows,
# validates each non-empty row, and builds intra-CSV email and NIC duplicate indices.
#
# + rows - Typed CSV rows parsed from the uploaded file
# + refData - Pre-loaded reference data lookup maps
# + return - `BulkFirstPassResult` with parsed rows, errors, duplicate indices, and skip count
isolated function processBulkCsvRows(BulkEmployeeCsvRow[] rows, BulkRefData refData)
        returns BulkFirstPassResult {
    CsvRowInfo[] rowInfos = [];
    database:BulkEmployeeError[] errors = [];
    map<int> rowByEmail = {};
    map<int> rowByNic = {};
    map<int> rowByEpf = {};
    string[] candidateEmails = [];
    string[] candidateNics = [];
    string[] candidateEpfs = [];
    int skipped = 0;

    foreach int i in 0 ..< rows.length() {
        BulkEmployeeCsvRow row = rows[i];
        int rowNumber = i + 2;

        if isEmptyBulkRow(row) {
            skipped += 1;
            continue;
        }

        errors.push(...validateBulkRow(rowNumber, row, refData));

        string normEmail = row.workEmail.trim().toLowerAscii();
        if normEmail.length() > 0 {
            if rowByEmail.hasKey(normEmail) {
                errors.push({
                    row: rowNumber,
                    'field: CSV_FIELD_WORK_EMAIL,
                    message: string `Duplicate work email in CSV: ${normEmail}`
                });
            } else {
                rowByEmail[normEmail] = rowNumber;
                candidateEmails.push(normEmail);
            }
        }

        string normNic = row.nicOrPassport.trim().toLowerAscii();
        if normNic.length() > 0 {
            if rowByNic.hasKey(normNic) {
                errors.push({
                    row: rowNumber,
                    'field: CSV_FIELD_NIC_OR_PASSPORT,
                    message: string `Duplicate NIC/Passport in CSV: ${normNic}`
                });
            } else {
                rowByNic[normNic] = rowNumber;
                candidateNics.push(normNic);
            }
        }

        string normEpf = row.epf.trim().toLowerAscii();
        if normEpf.length() > 0 {
            if rowByEpf.hasKey(normEpf) {
                errors.push({row: rowNumber, 'field: CSV_FIELD_EPF, message: string `Duplicate EPF in CSV: ${normEpf}`});
            } else {
                rowByEpf[normEpf] = rowNumber;
                candidateEpfs.push(normEpf);
            }
        }

        rowInfos.push({rowNumber, values: row});
    }

    return {
        rowInfos,
        errors,
        skipped,
        rowByEmail,
        rowByNic,
        rowByEpf,
        candidateEmails,
        candidateNics,
        candidateEpfs
    };
}

# Checks for database-level duplicate work emails and NIC/Passport numbers.
#
# + rowByEmail - Normalized work email to row number map
# + rowByNic - NIC/Passport value to row number map
# + rowByEpf - EPF value to row number map
# + candidateEmails - Work emails to batch-check against the DB
# + candidateNics - NIC/Passport values to batch-check against the DB
# + candidateEpfs - EPF values to batch-check against the DB
# + return - Duplicate errors found in the DB, or an error if the DB query fails
public isolated function detectDbDuplicates(map<int> rowByEmail, map<int> rowByNic, map<int> rowByEpf,
        string[] candidateEmails, string[] candidateNics, string[] candidateEpfs)
    returns database:BulkEmployeeError[]|error {
    database:BulkEmployeeError[] errors = [];

    if candidateEmails.length() > 0 {
        string[] existingEmails = check database:getExistingWorkEmails(candidateEmails);
        foreach string existing in existingEmails {
            int? rowNum = rowByEmail[existing.trim().toLowerAscii()];
            if rowNum is int {
                errors.push({
                    row: rowNum,
                    'field: CSV_FIELD_WORK_EMAIL,
                    message: string `Work email already exists: ${existing.trim()}`
                });
            }
        }
    }

    if candidateNics.length() > 0 {
        string[] existingNics = check database:getExistingNicOrPassport(candidateNics);
        foreach string existing in existingNics {
            int? rowNum = rowByNic[existing.trim()];
            if rowNum is int {
                errors.push({
                    row: rowNum,
                    'field: CSV_FIELD_NIC_OR_PASSPORT,
                    message: string `NIC/Passport already exists: ${existing.trim()}`
                });
            }
        }
    }

    if candidateEpfs.length() > 0 {
        string[] existingEpfs = check database:getExistingEpfs(candidateEpfs);
        foreach string existing in existingEpfs {
            int? rowNum = rowByEpf[existing.trim()];
            if rowNum is int {
                errors.push({
                    row: rowNum,
                    'field: CSV_FIELD_EPF,
                    message: string `EPF already exists: ${existing.trim()}`
                });
            }
        }
    }

    return errors;
}

# Builds `CreateEmployeePayload` records for all validated rows.
#
# + rowInfos - Parsed and validated data rows from `processBulkCsvRows`
# + refData - Pre-loaded reference data lookup maps
# + return - `BulkPayloadResult` with resolved employees
isolated function buildBulkPayloads(CsvRowInfo[] rowInfos, BulkRefData refData)
        returns BulkPayloadResult {
    ResolvedEmployee[] employees = [];

    foreach CsvRowInfo rowInfo in rowInfos {
        // House is assigned automatically from the employee ID's numeric part once the ID is
        // resolved in addEmployeesBulk — it doesn't exist yet at this point, so houseId is left
        // unset here.
        database:CreateEmployeePayload payload = buildBulkEmployeePayload(rowInfo.values, refData);
        employees.push({employeeId: "", payload, rowNumber: rowInfo.rowNumber});
    }

    return {employees};
}

# Parses raw CSV bytes into typed `BulkEmployeeCsvRow` records.
# Requires at least one data row after the header.
#
# + fileBytes - Raw bytes of the uploaded CSV file
# + return - Array of typed CSV rows, or an error on failure
public isolated function parseCsvBytes(byte[] fileBytes) returns BulkEmployeeCsvRow[]|error {
    BulkEmployeeCsvRow[] rows = check csv:parseBytes(fileBytes);
    if rows.length() == 0 {
        return error("CSV must contain a header row and at least one data row");
    }
    return rows;
}

# Reduce history events to what the calling privilege level is permitted to receive.
#
# The filtering happens here, on the server, and never on the client. An event the caller may
# not see is absent from the payload rather than flagged for the client to hide, so the data
# is not merely unrendered but never transmitted.
#
# The full projection is granted to ADMINs and to a lead viewing their own subordinate; the
# reduced projection applies to someone viewing their own record.
#
# Under the reduced projection:
# - `actionBy` is omitted from every event: an employee sees *that* their team changed, not
#   which HR administrator changed it.
# - Events made by system actors are dropped: migrations and scheduled jobs are operational
#   noise that would read as unexplained changes to their own record.
#
# Leaver events (employee_status transitions and resignation reason) are returned in BOTH
# projections. This is deliberate: the employee already knows they are leaving, and hiding the
# transition would leave an unexplained gap at the end of their own timeline.
#
# + events - Derived history events, newest first
# + hasFullProjection - True when the caller may see attribution and system rows
# + return - Events the caller is permitted to receive, newest first
public isolated function projectHistoryEvents(database:HistoryEvent[] events, boolean hasFullProjection)
        returns HistoryEventResponse[] {

    if hasFullProjection {
        return from database:HistoryEvent event in events
            select {
                employeePkId: event.employeePkId,
                'field: event.'field,
                sourceTable: event.sourceTable,
                previousValue: event.previousValue,
                currentValue: event.currentValue,
                occurredOn: event.occurredOn,
                actionBy: event.actionBy,
                isSystem: event.isSystem
            };
    }

    return from database:HistoryEvent event in events
        where !event.isSystem
        select {
            employeePkId: event.employeePkId,
            'field: event.'field,
            sourceTable: event.sourceTable,
            previousValue: event.previousValue,
            currentValue: event.currentValue,
            occurredOn: event.occurredOn,
            isSystem: false
        };
}

# Attach each promotion to the employment period it was raised during.
#
# A promotion belongs to the period whose startDate..endDate range contains its `createdOn`.
# An open period (no endDate) extends to the present. The promoted date is deliberately not
# used: HRIS frequently leaves it null, whereas a request is always raised while the employee
# is employed, so its created date falls inside exactly one period.
#
# A promotion matching no period is logged and omitted rather than reassigned. That should not
# happen for well-formed data — it means the created date falls outside every employment
# period, which points at bad data rather than a case needing a fallback.
#
# + periods - Employment periods for the person, newest first
# + promotions - Approved promotions for the person
# + return - Periods in their original order, each carrying its promotions
public isolated function assignPromotionsToPeriods(database:EmploymentPeriod[] periods,
        promotion:PromotionRecord[] promotions) returns EmploymentPeriodResponse[] {

    promotion:PromotionRecord[][] bucketed = from database:EmploymentPeriod _ in periods
        select [];

    foreach promotion:PromotionRecord promotionRecord in promotions {
        int? targetIndex = ();
        string createdOn = promotionRecord.createdOn;

        // A promotion request is raised while the employee is employed, so its created date
        // always falls inside exactly one employment period. That containment is what
        // attributes the promotion to the right employment — the promoted date is not used
        // here, since HRIS frequently leaves it unpopulated.
        foreach int index in 0 ..< periods.length() {
            database:EmploymentPeriod period = periods[index];
            string? endDate = period.endDate;
            boolean startedBy = createdOn >= period.startDate;
            boolean endedAfter = endDate is () || createdOn <= endDate;
            if startedBy && endedAfter {
                targetIndex = index;
                break;
            }
        }

        if targetIndex is int {
            bucketed[targetIndex].push(promotionRecord);
        } else {
            // No period contains it. This should not happen for well-formed data; it means the
            // promotion's created date falls outside every employment period, which points at
            // bad data rather than a timeline that needs a fallback.
            log:printWarn("Promotion created date falls outside every employment period; omitted",
                    createdOn = createdOn, cycleName = promotionRecord.cycleName);
        }
    }

    return from int index in 0 ..< periods.length()
        select {
            id: periods[index].id,
            employeeId: periods[index].employeeId,
            employmentType: periods[index].employmentType,
            startDate: periods[index].startDate,
            endDate: periods[index].endDate,
            workEmail: periods[index].workEmail,
            continuousServiceRecord: periods[index].continuousServiceRecord,
            promotions: bucketed[index]
        };
}

# Payload field name to the employee column it writes, for scheduled changes.
#
# The map is the allowlist: a field absent from it cannot be scheduled, and the scheduler
# refuses anything outside the same set when it applies the change. Resignation fields
# and employment status are deliberately absent — recording a departure is its own
# action with its own endpoint, not a field edit deferred.
final readonly & map<string> SCHEDULABLE_FIELD_COLUMNS = {
    "epf": "epf",
    "companyId": "company_id",
    "workLocation": "work_location",
    "workEmail": "work_email",
    "startDate": "start_date",
    "secondaryJobTitle": "secondary_job_title",
    "jobRole": "job_role",
    "externalDesignation": "external_designation",
    "managerEmail": "manager_email",
    "probationEndDate": "probation_end_date",
    "agreementEndDate": "agreement_end_date",
    "employmentTypeId": "employment_type_id",
    "designationId": "designation_id",
    "officeId": "office_id",
    "teamId": "team_id",
    "subTeamId": "sub_team_id",
    "businessUnitId": "business_unit_id",
    "unitId": "unit_id",
    "houseId": "house_id",
    "additionalManagerEmails": "additional_manager_emails"
};

# Employee record field holding the current value of each schedulable column.
#
# The employee record exposes resolved names for some fields and raw ids for others; this
# names the one the column is compared against, so the supersede check reads the same
# value the scheduler will.
final readonly & map<string> SCHEDULABLE_COLUMN_SOURCES = {
    "epf": "epf",
    "company_id": "companyId",
    "work_location": "workLocation",
    "work_email": "workEmail",
    "start_date": "startDate",
    "secondary_job_title": "secondaryJobTitle",
    "job_role": "jobRole",
    "external_designation": "externalDesignation",
    "manager_email": "managerEmail",
    "probation_end_date": "probationEndDate",
    "agreement_end_date": "agreementEndDate",
    "employment_type_id": "employmentTypeId",
    "designation_id": "designationId",
    "office_id": "officeId",
    "team_id": "teamId",
    "sub_team_id": "subTeamId",
    "business_unit_id": "businessUnitId",
    "unit_id": "unitId",
    "house_id": "houseId"
};

# True when a date string is later than today where the employee works.
#
# Today is excluded rather than allowed: the sweep applies a change once its date has begun
# where the employee works, so a change dated today would land at the next hourly run. That
# is an edit made now in all but name, so it is refused and the caller is told to apply now
# or pick a later date.
#
# + date - Date in YYYY-MM-DD form
# + today - Today's date where the employee works, from todayAt
# + return - True when the date is tomorrow or later
isolated function isFutureDate(string date, string today) returns boolean =>
    date > today;

# Today's date where an employee works, the same reckoning the scheduler acts on.
#
# + companyId - Employee's company ID
# + workLocation - Employee's work location
# + return - Today's date in YYYY-MM-DD form, or an error if the location timezones cannot be read
isolated function todayAt(int companyId, string workLocation) returns string|error {
    map<string> locationTimeZones = check database:getLocationTimeZones();
    return database:localDateAt(locationTimeZones, companyId, workLocation, time:utcNow());
}

# Translate a job-info payload into the columns a scheduled change writes.
#
# Only the fields actually set are carried, so a scheduled change records the edit that
# was made rather than every field the payload could hold. A field outside the allowlist
# is an error rather than a silent omission: the caller asked for something that cannot
# be scheduled and should be told so.
#
# + payload - The fields to change
# + return - Column name to value, or an error naming the field that cannot be scheduled
isolated function toSchedulableColumns(database:UpdateEmployeeJobInfoPayload payload)
    returns map<json>|error {

    map<json> asMap = check payload.toJson().cloneWithType();
    map<json> columns = {};

    foreach string 'field in asMap.keys() {
        json value = asMap.get('field);
        // An unset optional field is absent from the change, not a request to null the
        // column: the payload cannot tell the two apart, and clearing a field nobody
        // touched would be the more damaging reading.
        if value is () {
            continue;
        }
        if !SCHEDULABLE_FIELD_COLUMNS.hasKey('field) {
            return error(string `${'field} cannot be scheduled for a future date`);
        }
        // An empty probation end date is a request to clear it; the scheduler sets NULL from a null value.
        json columnValue = 'field == "probationEndDate" && value == "" ? () : value;
        columns[SCHEDULABLE_FIELD_COLUMNS.get('field)] = columnValue;
    }

    if columns.length() == 0 {
        return error("No schedulable fields were provided");
    }
    return columns;
}

# Capture what the targeted columns hold now, for the supersede check on the day.
#
# + employee - The employee's current record
# + changes - The change, as column name to value
# + return - Column name to current value, or an error when they could not be read
isolated function expectedValuesFor(database:Employee employee, map<json> changes)
    returns map<json>|error {

    // An error rather than an empty map: an empty expectation reads to the sweep as
    // "nothing to compare", which is how a failure here would silently disable the
    // supersede check months later, when the change applies.
    map<json>|error current = employee.toJson().cloneWithType();
    if current is error {
        return error(string `Could not read the employee's current values: ${current.message()}`);
    }

    map<json> expected = {};
    foreach string column in changes.keys() {
        // Additional managers live in their own table rather than in an employee column,
        // so they are snapshotted as the normalised set the sweep will compare against
        // rather than read from SCHEDULABLE_COLUMN_SOURCES.
        if column == SCHEDULED_ADDITIONAL_MANAGERS_COLUMN {
            expected[column] = normalizedEmailSet(employee.additionalManagerEmails);
            continue;
        }
        if !SCHEDULABLE_COLUMN_SOURCES.hasKey(column) {
            continue;
        }
        string sourceField = SCHEDULABLE_COLUMN_SOURCES.get(column);
        expected[column] = current.hasKey(sourceField) ? current.get(sourceField) : ();
    }

    // The promise this function's own contract makes, and the one the endpoint relies on
    // to refuse a change while somebody is present to be told. An empty map reaches the
    // sweep as "nothing to compare" months later, where it is refused far from anyone who
    // could act on it.
    if expected.length() == 0 {
        return error("The current values for this change could not be recorded");
    }
    return expected;
}

# Column name the additional managers set is carried under in a scheduled change.
#
# Matches ADDITIONAL_MANAGERS_KEY in the scheduler, which reads these same rows.
const string SCHEDULED_ADDITIONAL_MANAGERS_COLUMN = "additional_manager_emails";

# Normalise a set of emails so that only membership matters to a comparison.
#
# Lowercased because the sweep writes and matches these case-insensitively, trimmed
# because the payload carries whatever was typed, and sorted because neither the stored
# order nor the order somebody entered them says anything about the set itself. Without
# this, reordering two leads would read as a change somebody else had made and supersede
# the scheduled one.
#
# + emails - Comma-separated emails, an email array, or ()
# + return - The distinct emails, lowercased and sorted
isolated function normalizedEmailSet(json emails) returns string[] {
    string[] parts = [];
    if emails is string {
        parts = re `,`.split(emails);
    } else if emails is json[] {
        foreach json entry in emails {
            if entry is string {
                parts.push(entry);
            }
        }
    }

    map<()> seen = {};
    foreach string part in parts {
        string trimmed = part.trim().toLowerAscii();
        if trimmed.length() > 0 {
            seen[trimmed] = ();
        }
    }
    string[] unique = seen.keys();
    return unique.sort();
}
