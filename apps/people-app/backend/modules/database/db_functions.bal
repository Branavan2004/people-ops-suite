// Copyright (c) 2025 WSO2 LLC. (https://www.wso2.com).
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

import ballerina/sql;

# Fetch employee basic information.
#
# + email - Employee's work email address
# + return - Employee basic information
public isolated function getEmployeeBasicInfo(string email) returns EmployeeBasicInfo|error? {
    EmployeeBasicInfo|error employeeBasicInfo = databaseClient->queryRow(getEmployeeBasicInfoQuery(email));
    return employeeBasicInfo is sql:NoRowsError ? () : employeeBasicInfo;
}

# Fetch directory information for all currently employed staff (Active and Marked leaver).
#
# + return - Directory information for Active and Marked leaver employees
public isolated function getAllEmployeesBasicInfo() returns EmployeeDirectoryInfo[]|error {
    stream<EmployeeDirectoryInfo, error?> employeeDirectoryInfoStream =
        databaseClient->query(getAllEmployeesBasicInfoQuery());
    return from EmployeeDirectoryInfo employeeDirectoryInfo in employeeDirectoryInfoStream
        select employeeDirectoryInfo;
}

# Get employee ID by EPF.
#
# + epf - Employee Provident Fund number
# + return - Employee ID string, nil if not found, or error
public isolated function getEmployeeIdByEpf(string epf) returns string|error? {
    string|error result = databaseClient->queryRow(getEmployeeIdByEpfQuery(epf));
    return result is sql:NoRowsError ? () : result;
}

# Fetch every employment of the person behind a NIC/Passport, newest first.
#
# + nicOrPassport - NIC/Passport from the onboarding submission
# + return - The person's employments (empty for someone new), or error
public isolated function getEmploymentsByNic(string nicOrPassport) returns EmploymentMatch[]|error {
    stream<EmploymentMatch, sql:Error?> resultStream = databaseClient->query(getEmploymentsByNicQuery(nicOrPassport));
    return from EmploymentMatch employment in resultStream
        select employment;
}

# Find an Active or New joiner employee holding a work email (a Marked leaver frees it for relocation).
#
# + workEmail - Work email to look for
# + excludeEmployeeId - Employee ID to leave out (the employee being edited), nil for none
# + return - The employee, nil when no current employee holds it, or error
public isolated function getCurrentEmployeeByWorkEmail(string workEmail, string? excludeEmployeeId = ())
        returns EmploymentMatch|error? {
    EmploymentMatch|error result =
        databaseClient->queryRow(getCurrentEmployeeByWorkEmailQuery(workEmail, excludeEmployeeId));
    return result is sql:NoRowsError ? () : result;
}

# Fetch employee detailed information.
#
# + employeeId - Employee ID
# + return - Employee detailed information
public isolated function getEmployeeInfo(string employeeId) returns Employee|error? {
    Employee|error employeeInfo = databaseClient->queryRow(getEmployeeInfoQuery(employeeId));
    return employeeInfo is sql:NoRowsError ? () : employeeInfo;
}

# Fetch employees with filters.
#
# + payload - Get employees filter payload
# + leadEmail - If provided, restricts results to subordinates of this lead
# + return - List of employees or error
public isolated function getEmployees(EmployeeSearchPayload payload, string? leadEmail = (),
        boolean includePersonalInfo = false) returns EmployeesResponse|error {
    stream<EmployeeRecord, error?> resultStream =
        databaseClient->query(getEmployeesQuery(payload, leadEmail, includePersonalInfo));

    int totalCount = 0;
    Employee[] employees = [];

    check from EmployeeRecord employeeRecord in resultStream
        do {
            EmployeeRecord {totalCount: count, ...employeeData} = employeeRecord;
            totalCount = count;
            employees.push(employeeData);
        };

    return {employees, totalCount};
}

# Fetch continuous service record by work email.
#
# + workEmail - Work email of the employee
# + return - Continuous service record information or error
public isolated function getContinuousServiceRecordsByEmail(string workEmail)
    returns ContinuousServiceRecordInfo[]|error {

    // A placeholder is shared by unrelated people, so their employments are not one
    // person's earlier service.
    if isPlaceholderWorkEmail(workEmail) {
        return [];
    }

    stream<ContinuousServiceRecordInfo, sql:Error?> recordStream = databaseClient->query(
        getContinuousServiceRecordQuery(workEmail)
    );
    return from ContinuousServiceRecordInfo serviceRecord in recordStream
        select serviceRecord;
}

# Fetch employee personal information.
#
# + employeeId - Employee ID
# + return - Employee personal information
public isolated function getEmployeePersonalInfo(string employeeId) returns EmployeePersonalInfo|error? {
    EmployeePersonalInfo|error employeePersonalInfo = databaseClient->queryRow(getEmployeePersonalInfoQuery(employeeId));

    if employeePersonalInfo is sql:NoRowsError {
        return ();
    }
    if employeePersonalInfo is error {
        return employeePersonalInfo;
    }

    stream<EmergencyContact, error?> contactsStream =
        databaseClient->query(getEmergencyContactsByEmployeeIdQuery(employeeId));

    employeePersonalInfo.emergencyContacts = check from EmergencyContact contact in contactsStream
        select contact;
    return employeePersonalInfo;
}

# Get business units.
#
# + includeInactive - If true return all including inactive
# + return - Business units
public isolated function getBusinessUnits(boolean includeInactive = false) returns BusinessUnit[]|error {
    stream<BusinessUnit, error?> businessUnitStream = databaseClient->query(getBusinessUnitsQuery(includeInactive));
    return from BusinessUnit businessUnit in businessUnitStream
        select businessUnit;
}

# Get teams.
#
# + buId - Business unit ID (optional)
# + includeInactive - If true, include inactive entities
# + return - Teams
public isolated function getTeams(int? buId = (), boolean includeInactive = false) returns Team[]|error {
    stream<Team, error?> teamStream = databaseClient->query(getTeamsQuery(buId, includeInactive));
    return from Team team in teamStream
        select team;
}

# Get sub teams.
#
# + teamId - Team ID (optional)
# + includeInactive - If true, include inactive entities
# + return - Sub teams
public isolated function getSubTeams(int? teamId = (), boolean includeInactive = false) returns SubTeam[]|error {
    stream<SubTeam, error?> subTeamStream = databaseClient->query(getSubTeamsQuery(teamId, includeInactive));
    return from SubTeam subTeam in subTeamStream
        select subTeam;
}

# Fetch existing work emails from the employee table.
#
# + emails - List of lowercased work emails
# + return - Existing work emails
public isolated function getExistingWorkEmails(string[] emails) returns string[]|error {
    if emails.length() == 0 {
        return [];
    }
    stream<WorkEmailRow, error?> emailStream = databaseClient->query(getExistingWorkEmailsQuery(emails));
    return from WorkEmailRow row in emailStream
        select row.workEmail;
}

# Fetch existing NIC or passport values from personal_info.
#
# + nics - List of NIC or passport values
# + return - Existing NIC or passport values
public isolated function getExistingNicOrPassport(string[] nics) returns string[]|error {
    if nics.length() == 0 {
        return [];
    }
    stream<NicOrPassportRow, error?> nicStream =
        databaseClient->query(getExistingNicOrPassportQuery(nics));
    return from NicOrPassportRow row in nicStream
        select row.nicOrPassport;
}

# Fetch existing EPF values from the employee table.
#
# + epfs - List of EPF values to check
# + return - Existing EPF values found in the DB, or error
public isolated function getExistingEpfs(string[] epfs) returns string[]|error {
    if epfs.length() == 0 {
        return [];
    }
    stream<EpfRow, error?> epfStream = databaseClient->query(getExistingEpfsQuery(epfs));
    return from EpfRow row in epfStream
        select row.epf;
}

# Get units.
#
# + subTeamId - Sub team ID (optional)
# + includeInactive - If true, include inactive entities
# + return - Units
public isolated function getUnits(int? subTeamId = (), boolean includeInactive = false) returns Unit[]|error {
    stream<Unit, error?> unitStream = databaseClient->query(getUnitsQuery(subTeamId, includeInactive));
    return from Unit unit in unitStream
        select unit;
}

# Fetch organization structure with business units, teams, sub-teams and units.
#
# + return - Organization structure data or error
public isolated function getFullOrganizationStructure() returns OrgStructureBusinessUnit[]|error {
    stream<OrgStructureBusinessUnitRow, sql:Error?> orgStructureStream =
        databaseClient->query(getFullOrganizationStructureQuery());

    return from OrgStructureBusinessUnitRow row in orgStructureStream
        select {
            id: row.id,
            name: row.name,
            teams: check row.teams.fromJsonWithType()
        };
}

# Get career functions.
#
# + includeInactive - If true, return all rows including inactive; otherwise active-only
# + return - Career functions
public isolated function getCareerFunctions(boolean includeInactive = false) returns CareerFunction[]|error {
    stream<CareerFunction, error?> careerFunctionStream =
        databaseClient->query(getCareerFunctionsQuery(includeInactive));
    return from CareerFunction careerFunction in careerFunctionStream
        select careerFunction;
}

# Get designations.
#
# + careerFunctionId - Career function ID (optional)
# + includeInactive - If true, return all rows including inactive; otherwise active-only
# + return - Designations
public isolated function getDesignations(int? careerFunctionId = (), boolean includeInactive = false)
        returns Designation[]|error {

    stream<Designation, error?> designationStream =
        databaseClient->query(getDesignationsQuery(careerFunctionId, includeInactive));
    return from Designation designation in designationStream
        select designation;
}

# Create a career function.
#
# + payload - Career function creation payload
# + createdBy - Email of the admin performing the action
# + return - ID of the newly created career function, or error
public isolated function createCareerFunction(CreateCareerFunctionPayload payload, string createdBy)
        returns int|error {

    // Trim before storing: both unique indexes compare LOWER(TRIM(...)), so an untrimmed
    // value would occupy the slot for its trimmed form and render padded in every list.
    sql:ExecutionResult|error result = databaseClient->execute(
        createCareerFunctionQuery(payload.careerFunction.trim(), createdBy));

    if result is sql:DatabaseError && result.detail().errorCode == MYSQL_DUPLICATE_ENTRY_ERROR_CODE {
        return error DuplicateCareerFunctionError("A career function with this name already exists.");
    }
    if result is error {
        return result;
    }
    return check result.lastInsertId.ensureType(int);
}

# Update a career function.
#
# + id - Career function ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil, EntityNotFoundError, NoFieldsToUpdateError, or error
public isolated function updateCareerFunction(int id, UpdateCareerFunctionPayload payload, string updatedBy)
        returns error? {

    string? trimmedName = payload.careerFunction is string ? (<string>payload.careerFunction).trim() : ();
    sql:ParameterizedQuery query =
        check updateCareerFunctionQuery(id, trimmedName, payload.isActive, updatedBy);

    sql:ExecutionResult|error result = databaseClient->execute(query);
    if result is sql:DatabaseError && result.detail().errorCode == MYSQL_DUPLICATE_ENTRY_ERROR_CODE {
        return error DuplicateCareerFunctionError("A career function with this name already exists.");
    }
    if result is error {
        return result;
    }
    if result.affectedRowCount == 0 {
        return error EntityNotFoundError(string `Career function with ID ${id} not found`);
    }
}

# Create a designation.
#
# + payload - Designation creation payload
# + createdBy - Email of the admin performing the action
# + return - ID of the new designation, DuplicateDesignationError on a unique-index
# violation, or error
public isolated function createDesignation(CreateDesignationPayload payload, string createdBy) returns int|error {
    // Trim before storing — see the note in createCareerFunction.
    sql:ExecutionResult|error result = databaseClient->execute(
        createDesignationQuery(payload.designation.trim(), payload.jobBand, payload.careerFunctionId,
            createdBy));

    if result is sql:DatabaseError && result.detail().errorCode == MYSQL_DUPLICATE_ENTRY_ERROR_CODE {
        return error DuplicateDesignationError(
            "An active designation with this name already exists in this career function.");
    }
    if result is sql:DatabaseError && result.detail().errorCode == MYSQL_FK_CONSTRAINT_ERROR_CODE {
        return error UnknownCareerFunctionError("The specified career function does not exist.");
    }
    if result is error {
        return result;
    }
    return check result.lastInsertId.ensureType(int);
}

# Update a designation.
#
# + id - Designation ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil, EntityNotFoundError, NoFieldsToUpdateError, DuplicateDesignationError,
# or error
public isolated function updateDesignation(int id, UpdateDesignationPayload payload, string updatedBy)
        returns error? {

    string? trimmedName = payload.designation is string ? (<string>payload.designation).trim() : ();
    sql:ParameterizedQuery query = check updateDesignationQuery(id, trimmedName, payload.jobBand,
            payload.careerFunctionId, payload.isActive, updatedBy);

    sql:ExecutionResult|error result = databaseClient->execute(query);
    if result is sql:DatabaseError && result.detail().errorCode == MYSQL_DUPLICATE_ENTRY_ERROR_CODE {
        return error DuplicateDesignationError(
            "An active designation with this name already exists in this career function.");
    }
    if result is error {
        return result;
    }
    if result.affectedRowCount == 0 {
        return error EntityNotFoundError(string `Designation with ID ${id} not found`);
    }
}

# Check whether any active employees hold a designation.
#
# + id - Designation ID
# + return - True if active employees exist, false otherwise, or error
public isolated function hasActiveEmployeesInDesignation(int id) returns boolean|error {
    record {int count;} result = check databaseClient->queryRow(countActiveEmployeesInDesignationQuery(id));
    return result.count > 0;
}

# Check whether any active employees sit in a career function's designations.
#
# + id - Career function ID
# + return - True if active employees exist, false otherwise, or error
public isolated function hasActiveEmployeesInCareerFunction(int id) returns boolean|error {
    record {int count;} result = check databaseClient->queryRow(countActiveEmployeesInCareerFunctionQuery(id));
    return result.count > 0;
}

# Get companies.
#
# + return - Companies with allowed locations and probation periods
public isolated function getCompanies() returns CompanyResponse[]|error {
    stream<CompanyRow, error?> companyStream = databaseClient->query(getCompaniesQuery());

    return check from CompanyRow company in companyStream
        select check mapToCompanyResponse(company);
}

# Map company DB row to CompanyResponse.
#
# + company - Raw company record from DB
# + return - CompanyResponse with parsed allowedLocations
isolated function mapToCompanyResponse(CompanyRow company) returns CompanyResponse|error {
    AllowedLocation[] allowedLocations = [];

    string? rawLocations = company.allowedLocations;
    if rawLocations is string {
        allowedLocations = check rawLocations.fromJsonStringWithType();
    }

    return {
        id: company.id,
        name: company.name,
        prefix: company.prefix,
        location: company.location,
        allowedLocations: allowedLocations
    };
}

# Get the timezone of every company work location, keyed for localDateAt.
#
# + return - Location key to IANA timezone name, or an error
public isolated function getLocationTimeZones() returns map<string>|error {
    stream<LocationTimeZone, error?> locationStream = databaseClient->query(getLocationTimeZonesQuery());
    LocationTimeZone[] locations = check from LocationTimeZone location in locationStream
        select location;
    return toLocationTimeZoneMap(locations);
}

# Get offices.
#
# + companyId - Company ID (optional)
# + return - Offices
public isolated function getOffices(int? companyId = ()) returns Office[]|error {
    stream<Office, error?> officeStream = databaseClient->query(getOfficesQuery(companyId));
    return from Office office in officeStream
        select office;
}

# Get employment types.
#
# + return - Employment types
public isolated function getEmploymentTypes() returns EmploymentType[]|error {
    stream<EmploymentType, error?> employmentTypeStream = databaseClient->query(getEmploymentTypesQuery());
    return from EmploymentType employmentType in employmentTypeStream
        select employmentType;
}

# Fetch the universities already recorded for interns, most common first.
#
# + return - University names, or error
public isolated function getUniversities() returns string[]|error {
    stream<UniversityRow, error?> universityStream = databaseClient->query(getUniversitiesQuery());
    return from UniversityRow row in universityStream
        select row.university;
}

# Fetch IDP group names mapped to an employment type.
#
# + employmentTypeId - Employment type ID
# + return - Group names, or error
public isolated function getAsgardeoGroupsByEmploymentType(int employmentTypeId) returns string[]|error {
    stream<record {|string groupName;|}, error?> rows =
        databaseClient->query(getAsgardeoGroupsForEmploymentTypeQuery(employmentTypeId));
    return from var row in rows
        select row.groupName;
}

# Fetch Asgardeo group names assigned to a specific team and employment type.
#
# + teamId - The team ID to look up
# + employmentTypeId - The employment type ID to look up
# + return - Array of Asgardeo group names, or error
public isolated function getAsgardeoGroupsByTeam(int teamId, int employmentTypeId) returns string[]|error {
    stream<record {|string groupName;|}, error?> rows =
        databaseClient->query(getAsgardeoGroupsForTeamQuery(teamId, employmentTypeId));
    return from var groupRow in rows
        select groupRow.groupName;
}

# Get houses.
#
# + return - Houses
public isolated function getHouses() returns House[]|error {
    stream<House, sql:Error?> resultStream = databaseClient->query(getHousesQuery());
    return from House house in resultStream
        select house;
}

# Fetch the assignable leadership attributes.
#
# + return - Active leadership attributes, or an error
public isolated function getLeadershipGroups() returns LeadershipGroup[]|error {
    stream<LeadershipGroup, error?> result = databaseClient->query(getLeadershipGroupsQuery());
    return from LeadershipGroup group in result
        select group;
}

# Fetch every leadership attribute, retired ones included, with its current holder count.
#
# + return - Leadership attributes with usage, active first, or an error
public isolated function getLeadershipGroupsWithUsage() returns LeadershipGroupWithUsage[]|error {
    stream<LeadershipGroupWithUsage, error?> result =
        databaseClient->query(getLeadershipGroupsWithUsageQuery());
    return from LeadershipGroupWithUsage group in result
        select group;
}

# Create a leadership attribute.
#
# + payload - Creation payload
# + createdBy - Email of the admin performing the action
# + return - New attribute ID, DuplicateLeadershipGroupError, or error
public isolated function createLeadershipGroup(CreateLeadershipGroupPayload payload, string createdBy)
        returns int|error {

    // Trimmed before storing so a padded name cannot sit beside its trimmed form.
    sql:ExecutionResult|error result = databaseClient->execute(
        createLeadershipGroupQuery(payload.name.trim(), createdBy));
    if result is sql:DatabaseError && result.detail().errorCode == MYSQL_DUPLICATE_ENTRY_ERROR_CODE {
        return error DuplicateLeadershipGroupError("A leadership attribute with this name already exists.");
    }
    if result is error {
        return result;
    }
    return check result.lastInsertId.ensureType(int);
}

# Rename, retire or reactivate a leadership attribute.
#
# + id - Leadership attribute ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil, EntityNotFoundError, NoFieldsToUpdateError, DuplicateLeadershipGroupError,
# LeadershipGroupInUseError, or error
public isolated function updateLeadershipGroup(int id, UpdateLeadershipGroupPayload payload, string updatedBy)
        returns error? {

    string? name = payload.name;
    string? trimmedName = name is string ? name.trim() : ();
    sql:ParameterizedQuery query = check updateLeadershipGroupQuery(id, trimmedName, payload.isActive, updatedBy);

    sql:ExecutionResult|error result = databaseClient->execute(query);
    if result is sql:DatabaseError && result.detail().errorCode == MYSQL_DUPLICATE_ENTRY_ERROR_CODE {
        return error DuplicateLeadershipGroupError("A leadership attribute with this name already exists.");
    }
    if result is error {
        return result;
    }
    if result.affectedRowCount != 0 {
        return;
    }

    // No row matched: the ID is unknown, or the retire guard held it back. The guard only
    // applies to a retire, so any other update that matched nothing on a known ID changed
    // nothing (possible if the driver ever reports changed rather than matched rows) and
    // is a success, not a refusal to retire.
    int exists = check databaseClient->queryRow(leadershipGroupExistsQuery(id));
    if exists == 0 {
        return error EntityNotFoundError(string `Leadership attribute with ID ${id} not found`);
    }
    if payload.isActive != false {
        return;
    }
    int holders = check databaseClient->queryRow(countLeadershipGroupHoldersQuery(id));
    string holdersText = holders == 1 ? "1 current employee holds" : string `${holders} current employees hold`;
    return error LeadershipGroupInUseError(
        string `Cannot retire: ${holdersText} this attribute. Remove it from them first.`);
}

# Get managers.
#
# + return - Managers
public isolated function getManagers() returns Manager[]|error {
    stream<Manager, error?> managerStream = databaseClient->query(getManagersQuery());
    return from Manager manager in managerStream
        select manager;
}

# Check if a target employee is a direct or additional subordinate of a lead.
#
# + leadEmail - Work email of the potential lead
# + employeeId - Employee ID of the target employee
# + return - True if the employee is a subordinate, false if not, or error
public isolated function isSubordinateOfLead(string leadEmail, string employeeId) returns boolean|error {
    int|error result = databaseClient->queryRow(isSubordinateOfLeadQuery(leadEmail, employeeId));
    if result is sql:NoRowsError {
        return false;
    }
    if result is error {
        return result;
    }
    return true;
}

# How a team member is linked to a lead.
#
# + leadEmail - Work email of the lead
# + employeeId - Employee ID of the team member
# + return - The reporting line, nil when the member is not in the lead's chain, or an error
public isolated function getReportingLine(string leadEmail, string employeeId) returns ReportingLine|error? {
    ReportingLineRow|error row = databaseClient->queryRow(reportingLineQuery(leadEmail, employeeId));
    if row is sql:NoRowsError {
        return;
    }
    if row is error {
        return row;
    }
    return reportingLineFromRow(row);
}

# Check if an employee is a lead (manages at least one employee).
#
# + leadEmail - Work email of the employee
# + return - True if the employee is a lead, false if not, or error
public isolated function isLead(string leadEmail) returns boolean|error {
    int|error result = databaseClient->queryRow(isLeadQuery(leadEmail));
    if result is sql:NoRowsError {
        return false;
    }
    if result is error {
        return result;
    }
    return true;
}

# Add new employee.
#
# + payload - Add employee payload
# + createdBy - Creator of the employee record
# + employeeId - Pre-resolved employee ID string
# + return - Created employee record ID or error
public isolated function addEmployee(CreateEmployeePayload payload, string createdBy, string employeeId)
        returns int|error {

    int lastInsertedId = 0;

    retry transaction {
        int personalInfoId = check addPersonalInfo(payload.personalInfo, createdBy);
        lastInsertedId = check addEmployeeRecord(payload, createdBy, personalInfoId, employeeId);
        check syncEmergencyContacts(employeeId, payload.personalInfo.emergencyContacts ?: [], createdBy);
        check syncAdditionalManagers(employeeId, payload.additionalManagerEmails, createdBy);
        string university = (payload.university ?: "").trim();
        if university != "" {
            _ = check databaseClient->execute(addInternshipQuery(lastInsertedId, university, createdBy));
        }
        check commit;
    }
    return lastInsertedId;
}

# Compensating delete used to roll back `addEmployee` when downstream provisioning fails.
#
# + employeeId - Employee ID string
# + return - Nil on success or error
public isolated function deleteEmployeeById(string employeeId) returns error? {
    retry transaction {
        EmployeeDeleteIds ids = check databaseClient->queryRow(
            `SELECT id, personal_info_id as personalInfoId FROM employee WHERE employee_id = ${employeeId}`);
        int employeePkId = ids.id;
        int personalInfoId = ids.personalInfoId;
        _ = check databaseClient->execute(deleteEmployeeAdditionalManagersAuditQuery(employeePkId));
        _ = check databaseClient->execute(deleteEmployeeLeadershipAuditQuery(employeePkId));
        _ = check databaseClient->execute(deleteEmployeeEmergencyContactsAuditQuery(personalInfoId));
        _ = check databaseClient->execute(deleteEmployeeAuditQuery(employeePkId));
        _ = check databaseClient->execute(deletePersonalInfoAuditQuery(personalInfoId));
        // `internship` references the employee row, so it goes first.
        _ = check databaseClient->execute(deleteInternshipQuery(employeePkId));
        _ = check databaseClient->execute(deleteEmployeeQuery(employeeId));
        _ = check databaseClient->execute(deletePersonalInfoQuery(personalInfoId));
        check commit;
    }
}

# Add multiple employees in a single transaction with retry on concurrent ID conflicts.
#
# + payloads - Create employee payloads
# + createdBy - Creator of the employee records
# + return - Ordered array of [employeeId, statusCode] tuples, or error
public isolated function addEmployeesBulk(CreateEmployeePayload[] payloads, string createdBy)
        returns [string, int][] {

    int maxRetries = 3;
    int attempt = 0;

    while attempt < maxRetries {
        attempt += 1;
        [string, int][] attemptResults = [];
        map<EmployeeIdContext> contextCache = {};
        map<int> sequenceCache = {};
        error? txErr = ();

        transaction {
            foreach CreateEmployeePayload payload in payloads {
                string employeeId = check generateBulkEmployeeId(payload, contextCache, sequenceCache);
                // House is assigned automatically — a returning employee keeps the one they
                // had, everyone else gets it from the employee ID's numeric part. Not known
                // until the ID above is resolved, so this can't happen in buildBulkPayloads.
                payload.houseId = check resolveHouseIdForNewEmployee(payload.personalInfo.nicOrPassport,
                        payload.workEmail ?: FUTURE_JOINER_EMAIL, employeeId);
                int personalInfoId = check addPersonalInfo(payload.personalInfo, createdBy);
                _ = check addEmployeeRecord(payload, createdBy, personalInfoId, employeeId);
                check syncEmergencyContacts(employeeId, payload.personalInfo.emergencyContacts ?: [], createdBy);
                check syncAdditionalManagers(employeeId, payload.additionalManagerEmails, createdBy);
                attemptResults.push([employeeId, BULK_INSERT_SUCCESS]);
            }
            check commit;
        } on fail error err {
            txErr = err;
        }

        if txErr is () {
            return attemptResults;
        }

        int errorCode = getErrorCode(txErr);
        int finalStatus = errorCode == 1062 ? BULK_INSERT_DUPLICATE : BULK_INSERT_FAILED;

        if finalStatus == BULK_INSERT_DUPLICATE && attempt < maxRetries {
            continue;
        }

        [string, int][] result = [];
        foreach var _ in payloads {
            result.push(["", finalStatus]);
        }
        return result;
    }

    [string, int][] result = [];
    foreach var _ in payloads {
        result.push(["", BULK_INSERT_FAILED]);
    }
    return result;
}

# Generates an employee ID for a single CSV row during bulk onboarding.
#
# + payload - Partially built payload for the current row
# + contextCache - Cache mapping `"companyId:employmentTypeId"` to `EmployeeIdContext`
# + sequenceCache - Cache mapping sequence key to last used numeric suffix
# + return - Auto-generated employee ID, or an error on DB failure
isolated function generateBulkEmployeeId(CreateEmployeePayload payload,
        map<EmployeeIdContext> contextCache, map<int> sequenceCache) returns string|error {

    string ctxKey = string `${payload.companyId}:${payload.employmentTypeId}`;

    EmployeeIdContext context;
    EmployeeIdContext? cached = contextCache[ctxKey];
    if cached is EmployeeIdContext {
        context = cached;
    } else {
        context = check getEmployeeIdContext(payload.companyId, payload.employmentTypeId);
        contextCache[ctxKey] = context;
    }

    match context.employmentType {
        PERMANENT|INTERNSHIP|PROBATION => {
            // Normalize the prefix once so a value like " SG " can't pass the guard, leak spaces
            // into the ID, or fork a separate sequence from "SG".
            string companyPrefix = context.companyPrefix.trim();
            if companyPrefix.length() == 0 {
                return error(string `Company (ID: ${payload.companyId}) has no employee ID prefix configured`);
            }
            // PERMANENT and PROBATION share the "1" digit family; INTERNSHIP uses "5". Scoping by
            // this digit directly on the ID string (not by employment_type) means an employee
            // tagged with any other or legacy type can never be invisible to this count, and the
            // in-batch cache key stays shared for interleaved Permanent/Probation batch rows.
            int digit = context.employmentType == INTERNSHIP ? 5 : 1;
            string seqKey = companyPrefix + ":" + digit.toString();
            if !sequenceCache.hasKey(seqKey) {
                EmployeeIdSequence seq = check getFamilyMax(companyPrefix, digit);
                sequenceCache[seqKey] = <int>seq.lastNumericId;
            }
            int next = nextNumberInFamily(sequenceCache[seqKey] ?: 0, digit, 6);
            sequenceCache[seqKey] = next;
            return companyPrefix + next.toString();
        }
        CONSULTANCY|ADVISORY_CONSULTANCY|PART_TIME_CONSULTANCY => {
            string seqKey = CONSULTANCY_ID_PREFIX + ":0";
            if !sequenceCache.hasKey(seqKey) {
                EmployeeIdSequence seq = check getFamilyMax(CONSULTANCY_ID_PREFIX, 0);
                sequenceCache[seqKey] = <int>seq.lastNumericId;
            }
            int next = (sequenceCache[seqKey] ?: 0) + 1;
            string nextStr = next.toString();
            if nextStr.length() >= 6 {
                return error(string `Zero-padded ID family (digit '0', prefix '${CONSULTANCY_ID_PREFIX}') ` +
                    string `is exhausted at width 6; cannot generate the next ID.`);
            }
            sequenceCache[seqKey] = next;
            return CONSULTANCY_ID_PREFIX + padZero(next, 6);
        }
        _ => {
            return error("Unsupported employment type: " + context.employmentType.toString());
        }
    }
}

# Fetch employee ID generation context.
#
# + companyId - Company ID of the new employee
# + employmentTypeId - Employment type ID of the new employee
# + return - EmployeeIdContext or error
public isolated function getEmployeeIdContext(int companyId, int employmentTypeId)
        returns EmployeeIdContext|error {

    return databaseClient->queryRow(getEmployeeIdContextQuery(companyId, employmentTypeId));
}

# Fetch the current numeric maximum for a digit-family sequence.
#
# + prefix - The ID prefix (company prefix or CONSULTANCY_ID_PREFIX)
# + digit - The required leading digit for this family (0, 1, or 5)
# + return - EmployeeIdSequence (lastNumericId is 0 if the family has no members yet) or error
isolated function getFamilyMax(string prefix, int digit) returns EmployeeIdSequence|error {
    return databaseClient->queryRow(getNextIdInFamilyQuery(prefix, digit.toString()));
}

# Compute 10 raised to the given exponent, for small non-negative exponents (ID-width arithmetic
# only — not a general-purpose power function).
#
# + exponent - Non-negative exponent
# + return - 10^exponent
isolated function pow10(int exponent) returns int {
    int result = 1;
    foreach int i in 0 ..< exponent {
        result *= 10;
    }
    return result;
}

# Zero-pad `n` to exactly `width` characters. If `n` already has `width` or more digits, it is
# returned unpadded (the caller is responsible for rejecting values that don't fit; see the
# zero-padded capacity check in `getNextIdInFamily` and `generateBulkEmployeeId`).
#
# + n - The number to pad
# + width - Target string width
# + return - `n` as a string, left-padded with zeros to `width` characters
isolated function padZero(int n, int width) returns string {
    string s = n.toString();
    int padCount = width - s.length();
    if padCount <= 0 {
        return s;
    }
    string zerosStr = "";
    foreach int i in 0 ..< padCount {
        zerosStr += "0";
    }
    return zerosStr + s;
}

# Pure computation: given the current max numeric value observed for a digit-family, compute the
# next number in that family. This is a plain increment, unless incrementing would flip the
# leading digit, in which case it rolls over to the next order of magnitude that still starts
# with the required digit (e.g. maxNum=199999, digit=1 -> next=1000000, not 200000). This mirrors
# a rollover that already happened once in this system's real data, rather than inventing new
# behavior.
#
# `minWidth` is a true floor, not just a cold-start default: if `maxNum` is 0 (no rows yet) or a
# stray short value already exists in the family (e.g. a legacy ID left the max at 1 or 19), the
# result is always clamped up to at least `digit * 10^(minWidth-1)` (e.g. 100000 for digit 1,
# width 6) so every generated ID honors the family's minimum width convention.
#
# + maxNum - Current max numeric value in the family (0 if none exist yet)
# + digit - The required leading digit for this family (0, 1, or 5)
# + minWidth - Minimum digit width for the family (e.g. 6 means the family starts at 100000 for
# digit 1, and no generated value is ever narrower than this)
# + return - The next numeric value in this family
isolated function nextNumberInFamily(int maxNum, int digit, int minWidth) returns int {
    int floor = digit * pow10(minWidth - 1);
    if maxNum == 0 {
        return floor;
    }
    int candidate = maxNum + 1;
    if candidate < floor {
        return floor;
    }
    int candidateWidth = candidate.toString().length();
    int candidateLeadingDigit = candidate / pow10(candidateWidth - 1);
    if candidateLeadingDigit == digit {
        return candidate;
    }
    return digit * pow10(candidateWidth);
}

# Generate the next employee ID within a digit-family sequence (single-onboarding path).
#
# + prefix - The ID prefix (company prefix or CONSULTANCY_ID_PREFIX)
# + digit - The required leading digit for this family (0, 1, or 5)
# + minWidth - Minimum digit width (default 6)
# + zeroPadded - True for the digit-0 (Consultancy) family, which must be zero-padded to
# `minWidth` since a plain integer can never have a leading zero. Once that padded space is
# exhausted there is no valid next value, so this returns an error rather than overflowing.
# + return - The next employee ID string, or an error on DB failure or exhausted zero-padded capacity
public isolated function getNextIdInFamily(string prefix, int digit, int minWidth = 6, boolean zeroPadded = false)
        returns string|error {

    EmployeeIdSequence row = check getFamilyMax(prefix, digit);
    int maxNum = <int>row.lastNumericId;

    if zeroPadded {
        int candidate = maxNum + 1;
        string candidateStr = candidate.toString();
        if candidateStr.length() >= minWidth {
            return error(string `Zero-padded ID family (digit '${digit}', prefix '${prefix}') is exhausted ` +
                string `at width ${minWidth}; cannot generate the next ID.`);
        }
        return prefix + padZero(candidate, minWidth);
    }

    int nextNum = nextNumberInFamily(maxNum, digit, minWidth);
    return prefix + nextNum.toString();
}

# Extract the leading run of digits from an employee ID string (e.g. "LK1014231" -> 1014231).
# Works regardless of prefix content or length, including manually-entered FIXED_TERM IDs.
#
# + employeeId - The employee ID to extract the numeric part from
# + return - The numeric part as an int, or an error if the ID has no digits
isolated function extractNumericSuffix(string employeeId) returns int|error {
    int i = 0;
    while i < employeeId.length() {
        if re `[0-9]`.isFullMatch(employeeId.substring(i, i + 1)) {
            break;
        }
        i += 1;
    }
    if i >= employeeId.length() {
        return error(string `Employee ID '${employeeId}' has no numeric part`);
    }
    return check int:fromString(employeeId.substring(i));
}

# Resolve the house for an employee being onboarded.
#
# Someone returning to WSO2 keeps the house they had before: the house is a long-standing
# affiliation rather than a property of the employee ID, and giving a returning colleague a
# different one because their new ID divides differently would be arbitrary to them.
#
# Their previous employment is found by NIC/Passport first, which recognises the person even
# when their work email has changed or is a placeholder, and otherwise by work email, which
# covers earlier employments migrated in under a different NIC. A placeholder email is never
# matched: it is shared by unrelated employees. The most recent employment is taken only.
# Where there is no previous employment, or that employment carries no house, the house is
# derived from the employee ID as it always has been — house assignment is recent, so most
# records have none yet and fall through to that.
#
# + nicOrPassport - NIC/Passport of the employee being onboarded
# + workEmail - Work email of the employee being onboarded
# + employeeId - The employee's newly assigned employee ID
# + return - The house ID to assign, or an error if the employee ID has no numeric part
public isolated function resolveHouseIdForNewEmployee(string nicOrPassport, string workEmail, string employeeId)
    returns int|error {

    // Nullable, not int: the row exists whenever there is a previous employment, and
    // carries a null house when that employment predates house assignment or its house has
    // since been removed. Both take the same fallback as having no previous employment.
    record {|int? houseId;|}|error previous =
        databaseClient->queryRow(getPreviousHouseIdByNicQuery(nicOrPassport));
    if previous is sql:NoRowsError && !isPlaceholderWorkEmail(workEmail) {
        previous = databaseClient->queryRow(getPreviousHouseIdQuery(workEmail));
    }

    if previous is record {|int? houseId;|} {
        int? previousHouseId = previous.houseId;
        if previousHouseId is int {
            return previousHouseId;
        }
        return houseIdForEmployeeId(employeeId);
    }
    // sql:NoRowsError is the ordinary case — a first-time joiner. Anything else is a real
    // fault and is left to surface rather than silently falling back.
    if previous !is sql:NoRowsError {
        return previous;
    }
    return houseIdForEmployeeId(employeeId);
}

# Compute the automatically-assigned house for a newly created employee, deterministically
# derived from their employee ID's numeric part: `numericPart % 4` selects the house by a fixed
# mapping (0 -> CloudBots, 1 -> Titans, 2 -> Legions, 3 -> Wild Boars), matching this system's
# house IDs 1-4 in that same order.
#
# + employeeId - The employee's assigned employee ID (e.g. "LK1014231")
# + return - The house ID to assign, or an error if the employee ID has no numeric part
public isolated function houseIdForEmployeeId(string employeeId) returns int|error {
    int numericPart = check extractNumericSuffix(employeeId);
    int remainder = numericPart % 4;
    if remainder == 0 {
        return 1; // CloudBots
    }
    if remainder == 1 {
        return 2; // Titans
    }
    if remainder == 2 {
        return 3; // Legions
    }
    return 4; // Wild Boars
}

# Add employee personal information.
#
# + personalInfo - Personal information of the employee
# + createdBy - Creator of the personal info record
# + return - Created personal info ID or error
isolated function addPersonalInfo(CreatePersonalInfoPayload personalInfo, string createdBy) returns int|error {
    _ = check databaseClient->execute(addEmployeePersonalInfoQuery(personalInfo, createdBy));
    // Not result.lastInsertId: the personal_info_audit AFTER trigger's own auto-increment
    // insert makes the JDBC driver's generated-keys result unreliable (returns nil) once that
    // trigger fires. LAST_INSERT_ID() queried explicitly on this connection is unaffected.
    record {|int id;|} row = check databaseClient->queryRow(`SELECT LAST_INSERT_ID() AS id`);
    return row.id;
}

# Add employee record.
#
# + payload - Add employee payload
# + createdBy - Creator of the employee record
# + personalInfoId - Personal info ID to be linked with the employee record
# + employeeId - Employee ID to be used in the employee record
# + return - Created employee ID or error
isolated function addEmployeeRecord(CreateEmployeePayload payload, string createdBy, int personalInfoId, string employeeId)
    returns int|error {

    sql:ExecutionResult result = check databaseClient->execute(addEmployeeQuery(payload, createdBy, personalInfoId, employeeId));
    return check result.lastInsertId.ensureType(int);
}

# Get the generated employee ID based on the last inserted employee record ID.
#
# + lastInsertedEmployeeId - Last inserted employee record ID
# + return - Generated employee ID or error
isolated function getGeneratedEmployeeId(int lastInsertedEmployeeId) returns string|error {
    return check databaseClient->queryRow(getEmployeeIdQuery(lastInsertedEmployeeId));
}

# Sync emergency contacts for an employee based on the desired set of contacts.
#
# + employeeId - Employee ID string
# + desiredContacts - The full desired set of emergency contacts
# + actor - User performing the operation
# + return - Nil or error
isolated function syncEmergencyContacts(string employeeId, EmergencyContact[] desiredContacts, string actor)
    returns error? {

    stream<EmergencyContactRow, error?> currentStream =
        databaseClient->query(getEmergencyContactRowsQuery(employeeId));

    EmergencyContactRow[] currentRows = check from EmergencyContactRow contactRow in currentStream
        select contactRow;

    map<EmergencyContactRow> currentByMobile = map from EmergencyContactRow contactRow in currentRows
        select [contactRow.mobile, contactRow];

    string[] desiredMobiles = from EmergencyContact contact in desiredContacts
        select contact.mobile;

    string[] toRemove = from string mobile in currentByMobile.keys()
        where desiredMobiles.indexOf(mobile) is ()
        select mobile;

    EmergencyContact[] toAdd = from EmergencyContact contact in desiredContacts
        where !currentByMobile.hasKey(contact.mobile)
        select contact;

    EmergencyContact[] toUpdate = from EmergencyContact contact in desiredContacts
        let EmergencyContactRow? existing = currentByMobile[contact.mobile]
        where existing != () &&
            (existing.name != contact.name ||
                (existing.telephone ?: "") != (contact.telephone ?: "") ||
                existing.relationship != contact.relationship)
        select contact;

    sql:ParameterizedQuery[] deleteQueries = from string mobile in toRemove
        select deleteEmergencyContactQuery(employeeId, mobile, actor);

    if deleteQueries.length() > 0 {
        _ = check databaseClient->batchExecute(deleteQueries);
    }

    sql:ParameterizedQuery[] insertQueries = from EmergencyContact contact in toAdd
        select addPersonalInfoEmergencyContactQuery(employeeId, contact, actor);

    if insertQueries.length() > 0 {
        _ = check databaseClient->batchExecute(insertQueries);
    }

    sql:ParameterizedQuery[] updateQueries = from EmergencyContact contact in toUpdate
        select addPersonalInfoEmergencyContactQuery(employeeId, contact, actor);

    if updateQueries.length() > 0 {
        _ = check databaseClient->batchExecute(updateQueries);
    }
}

# Update employee personal information.
#
# + employeeId - Employee ID  
# + payload - Personal info update payload  
# + updatedBy - Updater of the personal info record
# + return - Nil if the update was successful or error
public isolated function updateEmployeePersonalInfo(string employeeId, UpdateEmployeePersonalInfoPayload payload,
        string updatedBy)
    returns error? {

    transaction {
        sql:ExecutionResult executionResult = check databaseClient->execute(
            updateEmployeePersonalInfoQuery(employeeId, payload, updatedBy));

        EmergencyContact[]? contactsOpt = payload.emergencyContacts;
        if contactsOpt is EmergencyContact[] {
            check syncEmergencyContacts(employeeId, contactsOpt, updatedBy);
        }
        check checkAffectedCount(executionResult.affectedRowCount);

        // employee.first_name/last_name are denormalized copies of personal_info's, read by
        // the directory, search, and employee-detail views. Keep them in sync whenever a name
        // field is part of this edit, or those views keep showing the pre-edit name.
        if payload.firstName != () || payload.lastName != () {
            sql:ExecutionResult nameUpdateResult = check databaseClient->execute(
                updateEmployeeNameQuery(employeeId, payload, updatedBy));
            check checkAffectedCount(nameUpdateResult.affectedRowCount);
        }

        check commit;
    }
}

# Sync additional managers for an employee based on the desired set of manager emails.
#
# + employeeId - Employee ID string
# + desiredEmails - The full desired set of additional manager emails
# + actor - User performing the operation
# + return - Nil or error
isolated function syncAdditionalManagers(string employeeId, Email[] desiredEmails, string actor)
    returns error? {

    stream<AdditionalManagerEmailRow, error?> currentStream =
        databaseClient->query(getAdditionalManagerEmailsQuery(employeeId));

    string[] currentEmails = check from AdditionalManagerEmailRow emailRow in currentStream
        select emailRow.additionalManagerEmail.toLowerAscii();

    string[] desiredLower = from Email email in desiredEmails
        select email.trim().toLowerAscii();

    map<string> currentEmailMap = map from string email in currentEmails
        select [email, email];
    map<string> desiredEmailMap = map from string email in desiredLower
        select [email, email];

    string[] toRemove = from string current in currentEmails
        where !desiredEmailMap.hasKey(current)
        select current;

    Email[] toAdd = from Email email in desiredEmails
        where !currentEmailMap.hasKey(email.trim().toLowerAscii())
        select email;

    sql:ParameterizedQuery[] deleteQueries = from string email in toRemove
        select deleteAdditionalManagerQuery(employeeId, email, actor);

    if deleteQueries.length() > 0 {
        _ = check databaseClient->batchExecute(deleteQueries);
    }

    if toAdd.length() > 0 {
        int employeePkId = check databaseClient->queryRow(
            `SELECT id FROM employee WHERE employee_id = ${employeeId}`
        );
        sql:ParameterizedQuery[] insertQueries = from Email email in toAdd
            select addEmployeeAdditionalManagerQuery(employeePkId, email.trim(), actor);

        _ = check databaseClient->batchExecute(insertQueries);
    }
}

# Fetch the leadership attribute IDs an employee currently holds.
#
# + employeeId - Employee business key
# + return - Active leadership attribute IDs, or an error
public isolated function getEmployeeLeadershipIds(string employeeId) returns int[]|error {
    stream<LeadershipGroupIdRow, error?> result =
        databaseClient->query(getEmployeeLeadershipIdsQuery(employeeId));
    return check from LeadershipGroupIdRow row in result
        select row.leadershipGroupId;
}

# Replace an employee's leadership attributes with the given set.
#
# Attributes the employee holds but that are absent from groupIds are deactivated;
# attributes in groupIds are assigned, reviving a previously removed row rather than
# inserting a duplicate. An empty groupIds clears every attribute.
#
# Only active attributes are ever removed. A retired attribute is hidden from the edit form,
# so it is never in groupIds; deactivating it here would silently strip it from the
# employee, and reactivating the attribute later would not bring it back for them.
#
# Runs inside the caller's transaction, like syncAdditionalManagers, so the employee's
# attributes commit or roll back together with the rest of the job-info update.
#
# + employeeId - Employee business key
# + groupIds - The complete desired set of attribute IDs
# + actor - Email of the user making the change, recorded in the audit trail
# + return - An error if any statement fails
isolated function syncEmployeeLeadership(string employeeId, int[] groupIds, string actor)
    returns error? {

    // Deactivate removals first so clearing an attribute is never skipped by an early return.
    _ = check databaseClient->execute(deactivateEmployeeLeadershipQuery(employeeId, groupIds, actor));
    foreach int groupId in groupIds {
        _ = check databaseClient->execute(assignEmployeeLeadershipQuery(employeeId, groupId, actor));
    }
}

# Update employee job information.
#
# + employeeId - Employee ID
# + payload - Job information update payload
# + updatedBy - Updater of the job info record
# + return - Nil if the update was successful or error
public isolated function updateEmployeeJobInfo(string employeeId, UpdateEmployeeJobInfoPayload payload, string updatedBy)
    returns error? {

    check validateResignationDateOrder(employeeId, payload);

    transaction {
        sql:ExecutionResult executionResult =
            check databaseClient->execute(updateEmployeeJobInfoQuery(employeeId, payload, updatedBy));

        // A resignation-only payload updates just `updated_by` on the employee row; the real change
        // lands in the resignation table below, so a zero affected count is not an error for it.
        if !hasLeaverFields(payload) {
            check checkAffectedCount(executionResult.affectedRowCount);
        }

        Email[]? additionalManagerEmails = payload.additionalManagerEmails;
        if additionalManagerEmails is Email[] {
            check syncAdditionalManagers(employeeId, additionalManagerEmails, updatedBy);
        }
        int[]? leadershipGroupIds = payload.leadershipGroupIds;
        if leadershipGroupIds is int[] {
            check syncEmployeeLeadership(employeeId, leadershipGroupIds, updatedBy);
        }
        check syncResignationRecord(employeeId, payload, updatedBy);
        check commit;
    }
}

# Record an employee's resignation details and mark them a leaver.
#
# Status is derived rather than accepted: recording a departure is what makes someone a
# leaver, so this reuses the job-info update with the status set here. That keeps the
# resignation table sync and the transaction identical to the admin path, rather than a
# second way to write the same rows.
#
# + employeeId - Employee ID
# + payload - Resignation details
# + updatedBy - User performing the update
# + return - Nil or error
public isolated function updateResignation(string employeeId, UpdateResignationPayload payload, string updatedBy)
    returns error? {

    Employee|error? employee = getEmployeeInfo(employeeId);
    if employee is error {
        return employee;
    }
    if employee is () {
        return error(string `Employee not found for ID: ${employeeId}`);
    }

    UpdateEmployeeJobInfoPayload jobInfoPayload = {
        employeeStatus: statusAfterResignation(employee.employeeStatus),
        finalDayInOffice: payload.finalDayInOffice,
        finalDayOfEmployment: payload.finalDayOfEmployment,
        resignationReason: payload.resignationReason
    };

    return updateEmployeeJobInfo(employeeId, jobInfoPayload, updatedBy);
}

# Reject a departure whose employment ends before the employee stops coming in.
#
# Either date may be absent from the payload while the other is being changed, so the
# effective pair is the incoming value falling back to what is already stored — checking
# only the payload would let a one-sided edit produce an impossible pair.
#
# Dates are ISO "YYYY-MM-DD", which compares correctly as a string.
#
# + employeeId - Employee ID
# + payload - Job information update payload
# + return - Nil when the order is possible, otherwise an error
isolated function validateResignationDateOrder(string employeeId, UpdateEmployeeJobInfoPayload payload)
    returns error? {

    string? incomingInOffice = payload.finalDayInOffice;
    string? incomingOfEmployment = payload.finalDayOfEmployment;

    if incomingInOffice is () && incomingOfEmployment is () {
        return;
    }

    string? storedInOffice = ();
    string? storedOfEmployment = ();
    if incomingInOffice is () || incomingOfEmployment is () {
        Employee|error? employee = getEmployeeInfo(employeeId);
        if employee is error {
            return employee;
        }
        if employee is Employee {
            storedInOffice = employee.finalDayInOffice;
            storedOfEmployment = employee.finalDayOfEmployment;
        }
    }

    string? inOffice = incomingInOffice ?: storedInOffice;
    string? ofEmployment = incomingOfEmployment ?: storedOfEmployment;

    if inOffice is string && ofEmployment is string && ofEmployment < inOffice {
        return error InvalidResignationDatesError(RESIGNATION_DATE_ORDER_ERROR);
    }
}

# Check whether the job-info update payload contains any leaver-specific fields.
#
# + payload - Job information update payload
# + return - True if any resignation field is present
public isolated function hasLeaverFields(UpdateEmployeeJobInfoPayload payload) returns boolean =>
    payload.finalDayInOffice is string
    || payload.finalDayOfEmployment is string
    || payload.resignationReason is string;

# Inactivate any additional-manager relationships where the employee is listed as the additional manager for others.
#
# + employeeId - Employee ID of the employee who is leaving
# + actor - User performing the operation
# + return - Nil or error
isolated function inactivateEmployeeRelationshipsOnOffboarding(string employeeId, string actor)
    returns error? {

    WorkEmailRow|error workEmailRow =
        databaseClient->queryRow(getEmployeeWorkEmailQuery(employeeId));
    if workEmailRow is sql:NoRowsError {
        return ();
    }
    if workEmailRow is error {
        return workEmailRow;
    }

    string employeeEmail = workEmailRow.workEmail;
    _ = check databaseClient->execute(inactivateAdditionalManagerRelationshipsQuery(employeeEmail, actor));
}

# Sync the resignation table row for an employee based on the job-info update payload.
# Retains any existing resignation record when the employee is reactivated, so historical details are preserved.
#
# + employeeId - Employee ID
# + payload - Job information update payload
# + updatedBy - User performing the operation
# + return - Nil or error
isolated function syncResignationRecord(string employeeId, UpdateEmployeeJobInfoPayload payload, string updatedBy)
    returns error? {

    if hasLeaverFields(payload) {
        _ = check databaseClient->execute(upsertResignationQuery(employeeId, payload, updatedBy));
    }
    if payload.employeeStatus == EMPLOYEE_LEFT {
        check inactivateEmployeeRelationshipsOnOffboarding(employeeId, updatedBy);
    }
}

# Fetch vehicles.
#
# + owner - Filter : owner of the vehicles  
# + vehicleStatus - Filter :  status of the vehicle
# + vehicleType - Filter :  type of the vehicle (e.g. CAR for parking booking, excluding bikes)
# + 'limit - Limit of the response  
# + offset - Offset of the response
# + return - Vehicles | Error
public isolated function fetchVehicles(string? owner = (), VehicleStatus? vehicleStatus = (),
        VehicleTypes? vehicleType = (), int? 'limit = (), int? offset = ()) returns Vehicles|error {

    stream<FetchVehicleResponse, error?> vehiclesResponse = databaseClient->query(
            fetchVehiclesQuery(owner, vehicleStatus, vehicleType, 'limit, offset));

    Vehicle[] vehicles = [];
    int totalCount = 0;
    _ = check from FetchVehicleResponse vehicle in vehiclesResponse
        do {
            vehicles.push({
                vehicleId: vehicle.vehicleId,
                owner: vehicle.owner,
                vehicleRegistrationNumber: vehicle.vehicleRegistrationNumber,
                updatedBy: vehicle.updatedBy,
                createdBy: vehicle.createdBy,
                vehicleStatus: vehicle.vehicleStatus,
                updatedOn: vehicle.updatedOn,
                createdOn: vehicle.createdOn,
                vehicleType: vehicle.vehicleType
            });

            totalCount = vehicle.totalCount;
        };

    return {
        vehicles,
        totalCount
    };
}

# Get owner email of a vehicle by id.
#
# + vehicleId - Vehicle identifier
# + return - Owner email or error
public isolated function getVehicleOwner(int vehicleId) returns string|error? {
    record {|string owner;|}|error row = databaseClient->queryRow(getVehicleOwnerQuery(vehicleId));
    if row is sql:NoRowsError {
        return ();
    }
    if row is error {
        return row;
    }
    return row.owner;
}

# Persist new vehicle.
#
# + payload - Payload containing the vehicle details
# + return - Id of the vehicle | Error
public isolated function addVehicle(AddVehiclePayload payload) returns int|error {
    sql:ExecutionResult executionResults = check databaseClient->execute(addVehicleQuery(payload));
    return executionResults.lastInsertId.ensureType(int);
}

# Update specific vehicle.
#
# + payload - Payload containing the update details
# + return - true if the update was successful or error
public isolated function updateVehicle(UpdateVehiclePayload payload) returns boolean|error {
    sql:ExecutionResult executionResults = check databaseClient->execute(updateVehicleQuery(payload));
    if executionResults.affectedRowCount > 0 {
        return true;
    }
    return false;
}

# Get active parking floors.
#
# + return - Parking floors
public isolated function getParkingFloors() returns ParkingFloor[]|error {
    stream<ParkingFloor, error?> floorStream = databaseClient->query(getParkingFloorsQuery());
    return from ParkingFloor f in floorStream
        select f;
}

# Get parking slots for a floor for a date.
#
# + floorId - Floor id
# + bookingDate - Booking date (YYYY-MM-DD)
# + pendingExpiryMinutes - Pending expiry duration in minutes
# + return - Parking slots (with isBooked)
public isolated function getParkingSlotsByFloor(int floorId, string bookingDate, int pendingExpiryMinutes)
        returns ParkingSlot[]|error {

    stream<ParkingSlotRow, error?> slotStream = databaseClient->query(
        getParkingSlotsByFloorQuery(floorId, bookingDate, pendingExpiryMinutes));
    return from ParkingSlotRow r in slotStream
        select {
            slotId: r.slotId,
            floorId: r.floorId,
            floorName: r.floorName,
            coinsPerSlot: r.coinsPerSlot,
            isBooked: r.isBooked == 1
        };
}

# Get parking slot by ID.
#
# + slotId - Slot id
# + return - Parking slot or nil
public isolated function getParkingSlotById(string slotId) returns ParkingSlot|error? {
    ParkingSlotRow|error row = databaseClient->queryRow(getParkingSlotByIdQuery(slotId));
    if row is sql:NoRowsError {
        return ();
    }
    if row is error {
        return row;
    }
    return {
        slotId: row.slotId,
        floorId: row.floorId,
        floorName: row.floorName,
        coinsPerSlot: row.coinsPerSlot,
        isBooked: row.isBooked == 1
    };
}

# Check if slot is unavailable for date.
#
# + slotId - Slot id
# + bookingDate - Booking date (YYYY-MM-DD)
# + pendingExpiryMinutes - Pending expiry duration in minutes
# + return - True if slot has an active reservation (CONFIRMED, or PENDING within `pendingExpiryMinutes`), false
# otherwise, or error
public isolated function isParkingSlotBookedForDate(string slotId, string bookingDate, int pendingExpiryMinutes)
        returns boolean|error {

    ReservationIdRow|error row = databaseClient->queryRow(
        getActiveParkingReservationForSlotDateQuery(slotId, bookingDate, pendingExpiryMinutes));
    if row is sql:NoRowsError {
        return false;
    }
    if row is error {
        return row;
    }
    return true;
}

# Expire stale PENDING reservations (PENDING -> EXPIRED) for slot/date.
#
# + slotId - Slot id
# + bookingDate - Booking date (YYYY-MM-DD)
# + expiryMinutes - Expiry duration in minutes
# + return - True if any rows updated
public isolated function expireStalePendingParkingReservationForSlotDate(string slotId, string bookingDate,
        int expiryMinutes) returns boolean|error {

    sql:ExecutionResult result = check databaseClient->execute(
        expireStalePendingParkingReservationForSlotDateQuery(slotId, bookingDate, expiryMinutes));
    return result.affectedRowCount > 0;
}

# Get the caller's active reservation (CONFIRMED, or PENDING within `pendingExpiryMinutes`) for a date.
#
# + employeeEmail - Employee email
# + bookingDate - Booking date (YYYY-MM-DD)
# + pendingExpiryMinutes - Pending expiry duration in minutes
# + return - Active reservation summary, nil if none, or error
public isolated function getActiveParkingReservationForEmployeeDate(string employeeEmail, string bookingDate,
        int pendingExpiryMinutes) returns ActiveParkingReservationRow|error? {

    ActiveParkingReservationRow|error row = databaseClient->queryRow(
        getActiveParkingReservationForEmployeeDateQuery(employeeEmail, bookingDate, pendingExpiryMinutes));
    return row is sql:NoRowsError ? () : row;
}

# Expire the caller's stale PENDING reservations (PENDING -> EXPIRED) for a date (any slot).
#
# + employeeEmail - Employee email
# + bookingDate - Booking date (YYYY-MM-DD)
# + expiryMinutes - Expiry duration in minutes
# + return - True if any rows updated, or error
public isolated function expireStalePendingParkingReservationsForEmployeeDate(string employeeEmail,
        string bookingDate, int expiryMinutes) returns boolean|error {

    sql:ExecutionResult result = check databaseClient->execute(
        expireStalePendingParkingReservationsForEmployeeDateQuery(employeeEmail, bookingDate, expiryMinutes));
    return result.affectedRowCount > 0;
}

# Update the vehicle on a parking reservation.
#
# + reservationId - Reservation id
# + vehicleId - Registered vehicle id to set
# + updatedBy - User performing the update
# + return - True if updated, or error
public isolated function updateParkingReservationVehicle(int reservationId, int vehicleId, string updatedBy)
        returns boolean|error {

    sql:ExecutionResult result = check databaseClient->execute(
        updateParkingReservationVehicleQuery(reservationId, vehicleId, updatedBy));
    return result.affectedRowCount > 0;
}

# Create parking reservation (PENDING).
#
# + payload - Reservation payload
# + return - New reservation id, `DuplicateActiveReservationError` if an active reservation already
# exists for the slot/date or employee/date (unique index violation), or error
public isolated function addParkingReservation(AddParkingReservationPayload payload) returns int|error {
    sql:ExecutionResult|error result = databaseClient->execute(addParkingReservationQuery(payload));
    if result is sql:DatabaseError && result.detail().errorCode == MYSQL_DUPLICATE_ENTRY_ERROR_CODE {
        return error DuplicateActiveReservationError(
            "An active reservation already exists for this slot or employee on this date.");
    }
    if result is error {
        return result;
    }
    return result.lastInsertId.ensureType(int);
}

# Get parking reservation by ID.
#
# + reservationId - Reservation id
# + return - Reservation details or nil
public isolated function getParkingReservationById(int reservationId) returns ParkingReservationDetails|error? {
    ParkingReservationDetails|error row = databaseClient->queryRow(getParkingReservationByIdQuery(reservationId));
    return row is sql:NoRowsError ? () : row;
}

# Atomically confirm a pending parking reservation (PENDING -> CONFIRMED).
#
# + reservationId - Reservation id
# + paymentReference - Payment reference to persist
# + updatedBy - User performing the confirmation
# + return - True if a pending reservation was transitioned, false if none matched (already transitioned), or error
public isolated function confirmParkingReservation(int reservationId, string paymentReference, string updatedBy)
    returns boolean|error {
    sql:ExecutionResult result = check databaseClient->execute(
        confirmParkingReservationQuery(reservationId, paymentReference, updatedBy));
    return result.affectedRowCount > 0;
}

# Get a map of employee work email to full name for all employees.
#
# + return - Map of work_email -> full_name, or error
public isolated function getEmployeeEmailToNameMap() returns map<string>|error {
    stream<EmployeeNameRow, error?> resultStream = databaseClient->query(getEmployeeEmailToNameMapQuery());
    map<string> nameMap = {};
    check from EmployeeNameRow row in resultStream
        do {
            nameMap[row.workEmail.toLowerAscii()] = row.fullName;
        };
    return nameMap;
}

# Get parking reservations by employee.
#
# + employeeEmail - Employee email
# + fromDate - From date (optional)
# + toDate - To date (optional)
# + return - Reservations
public isolated function getParkingReservationsByEmployee(string employeeEmail, string? fromDate = (),
        string? toDate = ()) returns ParkingReservationDetails[]|error {

    stream<ParkingReservationDetails, error?> resStream = databaseClient->query(
        getParkingReservationsByEmployeeQuery(employeeEmail, fromDate, toDate));
    return from ParkingReservationDetails r in resStream
        select r;
}

# Create a business unit.
#
# + payload - Business unit creation payload
# + createdBy - Email of the admin performing the action
# + return - ID of the newly created business unit, or error
public isolated function createBusinessUnit(CreateCompanyOrgChartEntityPayload payload, string createdBy)
        returns int|error {

    sql:ExecutionResult result = check databaseClient->execute(
        createBusinessUnitQuery(payload.name, payload.headEmail ?: "", createdBy));
    return check result.lastInsertId.ensureType(int);
}

# Update a business unit.
#
# + id - Business unit ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil or error
public isolated function updateBusinessUnit(int id, UpdateCompanyOrgChartEntityPayload payload, string updatedBy)
        returns error? {

    sql:ParameterizedQuery query = check updateBusinessUnitQuery(id, payload.name, payload.headEmail, payload.isActive,
            updatedBy);

    sql:ExecutionResult result = check databaseClient->execute(query);
    if result.affectedRowCount == 0 {
        return error EntityNotFoundError(string `Business unit with ID ${id} not found`);
    }
}

# Create a team.
#
# + payload - Team creation payload
# + createdBy - Email of the admin performing the action
# + return - ID of the newly created team, or error
public isolated function createTeam(CreateCompanyOrgChartEntityPayload payload, string createdBy) returns int|error {
    sql:ExecutionResult result = check databaseClient->execute(
        createTeamQuery(payload.name, payload.headEmail ?: "", createdBy));
    return check result.lastInsertId.ensureType(int);
}

# Update a team.
#
# + id - Team ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil or error
public isolated function updateTeam(int id, UpdateCompanyOrgChartEntityPayload payload, string updatedBy)
        returns error? {

    sql:ParameterizedQuery query = check updateTeamQuery(id, payload.name, payload.headEmail, payload.isActive,
            updatedBy);
    sql:ExecutionResult result = check databaseClient->execute(query);
    if result.affectedRowCount == 0 {
        return error EntityNotFoundError(string `Team with ID ${id} not found`);
    }
}

# Create a sub-team.
#
# + payload - Sub-team creation payload
# + createdBy - Email of the admin performing the action
# + return - ID of the newly created sub-team, or error
public isolated function createSubTeam(CreateCompanyOrgChartEntityPayload payload, string createdBy)
        returns int|error {

    sql:ExecutionResult result = check databaseClient->execute(
        createSubTeamQuery(payload.name, payload.headEmail ?: "", createdBy));
    return check result.lastInsertId.ensureType(int);
}

# Update a sub-team.
#
# + id - Sub-team ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil or error
public isolated function updateSubTeam(int id, UpdateCompanyOrgChartEntityPayload payload, string updatedBy)
        returns error? {

    sql:ParameterizedQuery query = check updateSubTeamQuery(id, payload.name, payload.headEmail, payload.isActive,
            updatedBy);
    sql:ExecutionResult result = check databaseClient->execute(query);
    if result.affectedRowCount == 0 {
        return error EntityNotFoundError(string `Sub-team with ID ${id} not found`);
    }
}

# Create a unit.
#
# + payload - Unit creation payload
# + createdBy - Email of the admin performing the action
# + return - ID of the newly created unit, or error
public isolated function createUnit(CreateCompanyOrgChartEntityPayload payload, string createdBy) returns int|error {
    sql:ExecutionResult result = check databaseClient->execute(
        createUnitQuery(payload.name, payload.headEmail ?: "", createdBy));
    return check result.lastInsertId.ensureType(int);
}

# Update a unit.
#
# + id - Unit ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil or error
public isolated function updateUnit(int id, UpdateCompanyOrgChartEntityPayload payload, string updatedBy)
        returns error? {

    sql:ParameterizedQuery query = check updateUnitQuery(id, payload.name, payload.headEmail, payload.isActive,
            updatedBy);
    sql:ExecutionResult result = check databaseClient->execute(query);
    if result.affectedRowCount == 0 {
        return error EntityNotFoundError(string `Unit with ID ${id} not found`);
    }
}

# Create a business-unit → team mapping.
#
# + payload - Mapping creation payload
# + createdBy - Email of the admin performing the action
# + return - ID of the newly created mapping, or error
public isolated function createBusinessUnitTeam(CreateBusinessUnitTeamPayload payload, string createdBy)
        returns int|error {

    sql:ExecutionResult result = check databaseClient->execute(
        createBusinessUnitTeamQuery(payload.businessUnitId, payload.teamId, payload.headEmail ?: "", createdBy));
    return check result.lastInsertId.ensureType(int);
}

# Update a business-unit → team mapping.
#
# + id - Mapping ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil or error
public isolated function updateBusinessUnitTeam(int id, UpdateMappingPayload payload, string updatedBy) returns error? {
    sql:ParameterizedQuery query = check updateBusinessUnitTeamQuery(id, payload.headEmail, payload.isActive,
            updatedBy);
    sql:ExecutionResult result = check databaseClient->execute(query);
    if result.affectedRowCount == 0 {
        return error EntityNotFoundError(string `Business unit team mapping with ID ${id} not found`);
    }
}

# Create a business-unit-team → sub-team mapping.
#
# + payload - Mapping creation payload
# + createdBy - Email of the admin performing the action
# + return - ID of the newly created mapping, or error
public isolated function createBusinessUnitTeamSubTeam(CreateBusinessUnitTeamSubTeamPayload payload, string createdBy)
        returns int|error {

    sql:ExecutionResult result = check databaseClient->execute(
        createBusinessUnitTeamSubTeamQuery(payload.businessUnitTeamId, payload.subTeamId, payload.headEmail ?: "",
            createdBy));
    return check result.lastInsertId.ensureType(int);
}

# Update a business-unit-team → sub-team mapping.
#
# + id - Mapping ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil or error
public isolated function updateBusinessUnitTeamSubTeam(int id, UpdateMappingPayload payload, string updatedBy)
        returns error? {

    sql:ParameterizedQuery query = check updateBusinessUnitTeamSubTeamQuery(id, payload.headEmail, payload.isActive,
            updatedBy);
    sql:ExecutionResult result = check databaseClient->execute(query);
    if result.affectedRowCount == 0 {
        return error EntityNotFoundError(string `Business unit team sub-team mapping with ID ${id} not found`);
    }
}

# Create a business-unit-team-sub-team → unit mapping.
#
# + payload - Mapping creation payload
# + createdBy - Email of the admin performing the action
# + return - ID of the newly created mapping, or error
public isolated function createBusinessUnitTeamSubTeamUnit(CreateBusinessUnitTeamSubTeamUnitPayload payload,
        string createdBy) returns int|error {

    sql:ExecutionResult result = check databaseClient->execute(
        createBusinessUnitTeamSubTeamUnitQuery(payload.businessUnitTeamSubTeamId, payload.unitId,
            payload.headEmail ?: "", createdBy));
    return check result.lastInsertId.ensureType(int);
}

# Update a business-unit-team-sub-team → unit mapping.
#
# + id - Mapping ID
# + payload - Update payload (all fields optional)
# + updatedBy - Email of the admin performing the action
# + return - Nil or error
public isolated function updateBusinessUnitTeamSubTeamUnit(int id, UpdateMappingPayload payload, string updatedBy)
        returns error? {

    sql:ParameterizedQuery query = check updateBusinessUnitTeamSubTeamUnitQuery(id, payload.headEmail, payload.isActive,
            updatedBy);
    sql:ExecutionResult result = check databaseClient->execute(query);
    if result.affectedRowCount == 0 {
        return error EntityNotFoundError(string `Business unit team sub-team unit mapping with ID ${id} not found`);
    }
}

# Fetch the full company org chart structure with all mapping metadata.
#
# + return - Company org chart structure or error
public isolated function getCompanyOrgChartStructure() returns CompanyOrgChartBusinessUnit[]|error {
    stream<CompanyOrgChartBusinessUnitRow, sql:Error?> orgStructureStream =
        databaseClient->query(getCompanyOrgChartStructureQuery());
    return from CompanyOrgChartBusinessUnitRow row in orgStructureStream
        select {
            id: row.id,
            name: row.name,
            headEmail: row.headEmail,
            isActive: row.isActive,
            activeEmployeeCount: row.activeEmployeeCount,
            teams: check row.teams.fromJsonWithType()
        };
}

# Check whether any active employees are assigned to a business unit.
#
# + id - Business unit ID
# + return - True if active employees exist, false otherwise, or error
public isolated function hasActiveEmployeesInBusinessUnit(int id) returns boolean|error {
    record {int count;} result = check databaseClient->queryRow(countActiveEmployeesInBusinessUnitQuery(id));
    return result.count > 0;
}

# Check whether any active employees are assigned to a team.
#
# + id - Team ID
# + return - True if active employees exist, false otherwise, or error
public isolated function hasActiveEmployeesInTeam(int id) returns boolean|error {
    record {int count;} result = check databaseClient->queryRow(countActiveEmployeesInTeamQuery(id));
    return result.count > 0;
}

# Check whether any active employees are assigned to a sub-team.
#
# + id - Sub-team ID
# + return - True if active employees exist, false otherwise, or error
public isolated function hasActiveEmployeesInSubTeam(int id) returns boolean|error {
    record {int count;} result = check databaseClient->queryRow(countActiveEmployeesInSubTeamQuery(id));
    return result.count > 0;
}

# Check whether any active employees are assigned to a unit.
#
# + id - Unit ID
# + return - True if active employees exist, false otherwise, or error
public isolated function hasActiveEmployeesInUnit(int id) returns boolean|error {
    record {int count;} result = check databaseClient->queryRow(countActiveEmployeesInUnitQuery(id));
    return result.count > 0;
}

# Check whether any active employees are in a business-unit–team mapping.
#
# + id - business_unit_team mapping ID
# + return - True if active employees exist, false otherwise, or error
public isolated function hasActiveEmployeesInBUTeamMapping(int id) returns boolean|error {
    record {int count;} result = check databaseClient->queryRow(countActiveEmployeesInBUTeamMappingQuery(id));
    return result.count > 0;
}

# Check whether any active employees are in a business-unit–team–sub-team mapping.
#
# + id - business_unit_team_sub_team mapping ID
# + return - True if active employees exist, false otherwise, or error
public isolated function hasActiveEmployeesInBUTeamSubTeamMapping(int id) returns boolean|error {
    record {int count;} result = check databaseClient->queryRow(countActiveEmployeesInBUTeamSubTeamMappingQuery(id));
    return result.count > 0;
}

# Check whether any active employees are in a business-unit–team–sub-team–unit mapping.
#
# + id - business_unit_team_sub_team_unit mapping ID
# + return - True if active employees exist, false otherwise, or error
public isolated function hasActiveEmployeesInBUTeamSubTeamUnitMapping(int id) returns boolean|error {
    record {int count;} result = check databaseClient->queryRow(
            countActiveEmployeesInBUTeamSubTeamUnitMappingQuery(id));
    return result.count > 0;
}

# Resolve the person behind a work email to their personal_info ID.
#
# Callers authorizing "may this user see this record" must compare people, not employee IDs. A
# rehired person holds several employee IDs against one personal_info row, so comparing employee
# IDs would deny them access to their own earlier employment.
#
# + workEmail - Work email of the person
# + return - personal_info ID, nil if no matching employee record, or error
public isolated function getPersonalInfoIdByWorkEmail(string workEmail) returns int?|error {
    int|error result = databaseClient->queryRow(getPersonalInfoIdByWorkEmailQuery(workEmail));
    return result is sql:NoRowsError ? () : result;
}

# Resolve the person behind an employee ID to their personal_info ID.
#
# + employeeId - Employee ID of any one of the person's employment records
# + return - personal_info ID, nil if no matching employee record, or error
public isolated function getPersonalInfoIdByEmployeeId(string employeeId) returns int?|error {
    int|error result = databaseClient->queryRow(getPersonalInfoIdByEmployeeIdQuery(employeeId));
    return result is sql:NoRowsError ? () : result;
}

# Fetch every employment period for the person behind an employee ID.
#
# + employeeId - Employee ID of any one of the person's employment records
# + return - Employment periods for the person, newest first
public isolated function getEmploymentPeriods(string employeeId) returns EmploymentPeriod[]|error {
    stream<EmploymentPeriod, error?> periodStream = databaseClient->query(getEmploymentPeriodsQuery(employeeId));
    return from EmploymentPeriod period in periodStream
        select period;
}

# Fetch raw audit snapshots across all audit tables for a person's employee rows.
#
# Each source table is queried and ordered independently, then merged and re-sorted by action_on
# ascending across the combined set, since Task 3 diffs consecutive rows and depends on one
# globally-ordered timeline rather than three independently-ordered ones.
#
# + employeePkIds - Employee table primary keys belonging to the person
# + return - Audit snapshots from employee_audit, personal_info_audit,
# employee_additional_managers_audit, employee_leadership_audit, and resignation_audit,
# ordered by action_on ascending across all five
public isolated function getAuditSnapshots(int[] employeePkIds) returns AuditSnapshot[]|error {
    stream<AuditSnapshot, error?> employeeAuditStream =
        databaseClient->query(getEmployeeAuditSnapshotsQuery(employeePkIds));
    AuditSnapshot[] employeeAuditSnapshots = check from AuditSnapshot snapshot in employeeAuditStream
        select snapshot;

    stream<AuditSnapshot, error?> personalInfoAuditStream =
        databaseClient->query(getPersonalInfoAuditSnapshotsQuery(employeePkIds));
    AuditSnapshot[] personalInfoAuditSnapshots = check from AuditSnapshot snapshot in personalInfoAuditStream
        select snapshot;

    stream<AuditSnapshot, error?> additionalManagersAuditStream =
        databaseClient->query(getEmployeeAdditionalManagersAuditSnapshotsQuery(employeePkIds));
    AuditSnapshot[] additionalManagersAuditSnapshots =
        check from AuditSnapshot snapshot in additionalManagersAuditStream
        select snapshot;

    stream<AuditSnapshot, error?> leadershipAuditStream =
        databaseClient->query(getEmployeeLeadershipAuditSnapshotsQuery(employeePkIds));
    AuditSnapshot[] leadershipAuditSnapshots =
        check from AuditSnapshot snapshot in leadershipAuditStream
        select snapshot;

    stream<AuditSnapshot, error?> resignationAuditStream =
        databaseClient->query(getResignationAuditSnapshotsQuery(employeePkIds));
    AuditSnapshot[] resignationAuditSnapshots = check from AuditSnapshot snapshot in resignationAuditStream
        select snapshot;

    AuditSnapshot[] allSnapshots = [
        ...employeeAuditSnapshots,
        ...personalInfoAuditSnapshots,
        ...additionalManagersAuditSnapshots,
        ...leadershipAuditSnapshots,
        ...resignationAuditSnapshots
    ];
    return from AuditSnapshot snapshot in allSnapshots
        order by snapshot.actionOn ascending
        select snapshot;
}

# Build a lookup of audit field -> id -> human-readable name.
#
# History events carry raw foreign keys from the audit snapshots. Rendering "87" tells a
# reader nothing, so ids are resolved to names before the response is built.
#
# + return - Nested map keyed by field then by id, or an error
public isolated function getHistoryLookupNames() returns map<map<string>>|error {
    stream<HistoryLookupName, error?> resultStream =
        databaseClient->query(getHistoryLookupNamesQuery());

    map<map<string>> lookup = {};
    check from HistoryLookupName row in resultStream
        do {
            map<string> byId = lookup.hasKey(row.'field) ? lookup.get(row.'field) : {};
            byId[row.id.toString()] = row.name;
            lookup[row.'field] = byId;
        };

    return lookup;
}

# Whether an employee ID names the person's current (most recent) employment.
#
# + employeeId - Employee ID to test
# + return - True when this is the person's latest employment row, or an error
public isolated function isCurrentEmployment(string employeeId) returns boolean|error {
    int|error result = databaseClient->queryRow(isCurrentEmploymentQuery(employeeId));
    if result is sql:NoRowsError {
        return false;
    }
    if result is error {
        return result;
    }
    return true;
}

# Schedule a change to an employee's general information.
#
# The caller supplies what the fields hold now, so the sweep can tell on the day whether
# the change still makes sense or whether somebody has since edited the same field.
#
# + employeeId - Employee ID
# + payload - Effective date and the fields to change
# + expected - What those fields hold at the time of scheduling
# + createdBy - Email of the person scheduling the change
# + return - The new scheduled change id, or an error
public isolated function scheduleEmployeeChange(string employeeId, string effectiveDate,
        string columnChanges, string expected, string createdBy) returns int|error {

    Employee|error? employee = getEmployeeInfo(employeeId);
    if employee is error {
        return employee;
    }
    if employee is () {
        return error(string `No employee found for the ID: ${employeeId}`);
    }

    int employeePkId = check databaseClient->queryRow(
        `SELECT id FROM employee WHERE employee_id = ${employeeId}`);

    sql:ExecutionResult result = check databaseClient->execute(
        insertScheduledChangeQuery(employeePkId, effectiveDate, columnChanges, expected, createdBy));

    int|string? lastInsertId = result.lastInsertId;
    if lastInsertId !is int {
        return error("Unable to obtain the scheduled change ID");
    }
    return lastInsertId;
}

# Fetch the scheduled changes for an employee.
#
# + employeeId - Employee ID
# + pendingOnly - Limit to changes still waiting for their date
# + return - Scheduled changes, soonest first, or an error
public isolated function getScheduledChanges(string employeeId, boolean pendingOnly)
    returns ScheduledChange[]|error {

    Employee|error? employee = getEmployeeInfo(employeeId);
    if employee is error {
        return employee;
    }
    if employee is () {
        return error(string `No employee found for the ID: ${employeeId}`);
    }

    int employeePkId = check databaseClient->queryRow(
        `SELECT id FROM employee WHERE employee_id = ${employeeId}`);

    stream<ScheduledChange, error?> resultStream =
        databaseClient->query(getScheduledChangesQuery(employeePkId, pendingOnly));
    return from ScheduledChange change in resultStream
        select change;
}

# Fetch one scheduled change by id.
#
# + id - Scheduled change id
# + return - The change, () when no such row exists, or an error
public isolated function getScheduledChangeById(int id) returns ScheduledChange|error? {
    ScheduledChange|error change = databaseClient->queryRow(getScheduledChangeByIdQuery(id));
    return change is sql:NoRowsError ? () : change;
}

# Withdraw a scheduled change before its date arrives.
#
# The update is conditional on the row still being PENDING, so cancelling a change the
# sweep has already applied reports as not found rather than rewriting a closed row.
#
# + id - Scheduled change id
# + cancelledBy - Email of the person cancelling
# + return - True when a pending row was cancelled, false when there was none, or an error
public isolated function cancelScheduledChange(int id, string cancelledBy) returns boolean|error {
    sql:ExecutionResult result = check databaseClient->execute(
        updateScheduledChangeStatusQuery(id, SCHEDULED_CHANGE_CANCELLED, (), cancelledBy));
    return result.affectedRowCount > 0;
}
