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

import ballerina/constraint;
import ballerina/lang.regexp;
import ballerina/sql;

# Email validation pattern.
public final regexp:RegExp EMAIL_PATTERN = re `^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`;

# Phone number validation pattern.
public final regexp:RegExp PHONE_PATTERN = re `^[0-9+\-()\s]*[0-9][0-9+\-()\s]*$`;

# Date validation pattern (YYYY-MM-DD).
public final regexp:RegExp DATE_PATTERN = re `^\d{4}-\d{2}-\d{2}$`;

# URL validation pattern.
public final regexp:RegExp URL_PATTERN = re `^(https?|ftp)://[^\s/$.?#].[^\s]*$`;

# Constrained email string type.
@constraint:String {maxLength: 254, pattern: re `${EMAIL_PATTERN}`}
public type Email string;

# Distinct error returned when a PATCH targets an entity ID that does not exist.
public type EntityNotFoundError distinct error;

# Distinct error returned when a PATCH payload carries no fields to update.
public type NoFieldsToUpdateError distinct error;

# Distinct error returned when a parking reservation insert violates an
# active-reservation unique index (slot/date or employee/date already active).
public type DuplicateActiveReservationError distinct error;

# Raised when an active designation with the same name already exists in the career function.
public type DuplicateDesignationError distinct error;

# Raised when a career function with the same name already exists. Unlike designations, this
# applies to every row regardless of `is_active` — a career function name is never reusable.
public type DuplicateCareerFunctionError distinct error;

# Raised when a leadership attribute name collides with an existing one (the unique key on
# leadership_group.name is case-insensitive), so the caller gets a 400 rather than a 500.
public type DuplicateLeadershipGroupError distinct error;

# Raised when retiring a leadership attribute that current employees still hold. Retiring
# is refused rather than silently hiding the attribute from their records.
public type LeadershipGroupInUseError distinct error;

# Raised when a designation references a career function that does not exist (foreign key
# violation), so the caller gets a 400 rather than an opaque 500.
public type UnknownCareerFunctionError distinct error;

# Raised when a departure's final day of employment precedes its last day in office, so the
# caller gets a 400 naming the problem rather than an opaque 500. The type carries that
# meaning, not the message: RESIGNATION_DATE_ORDER_ERROR supplies the wording and can be
# reworded without changing which status the caller receives.
public type InvalidResignationDatesError distinct error;

# [Configurable] Database configs.
# Deliberately flat (primitive fields only) rather than embedding mysql:Options/
# sql:ConnectionPool directly: Choreo's config UI introspects configurable variable
# types, so nesting the actual library types here would expose their entire field
# surface (many more knobs than we use) as configurable entries. initPeopleOpsDbClient()
# in client.bal builds the real mysql:Options/sql:ConnectionPool values internally
# from these primitives, which stays invisible to that introspection.
type DatabaseConfig record {|
    # If the MySQL server is secured, the username
    string user;
    # The password of the MySQL server for the provided username
    string password;
    # The name of the database
    string database;
    # Hostname of the MySQL server
    string host;
    # Port number of the MySQL server
    int port;
    # Max open connections in the pool
    int maxOpenConnections = 10;
    # Max connection lifetime (seconds)
    decimal maxConnectionLifeTime = 1800;
    # Min idle connections in the pool
    int minIdleConnections = 0;
    # Connection timeout (seconds)
    decimal connectTimeout = 30;
    # SSL mode for DB connection 
    string sslMode = "PREFERRED";
|};

# Employee basic information.
public type EmployeeBasicInfo record {|
    # Employee ID of the user
    @sql:Column {name: "employee_id"}
    string employeeId;
    # First name of the user
    @sql:Column {name: "first_name"}
    string firstName;
    # Last name of the user
    @sql:Column {name: "last_name"}
    string lastName;
    # Work email of the user
    @sql:Column {name: "work_email"}
    string workEmail;
    # Thumbnail URL of the user
    @sql:Column {name: "employee_thumbnail"}
    string? employeeThumbnail;
    # Combined designation (designation + job role + secondary job title)
    string designation?;
    # External-facing designation
    string? externalDesignation?;
    # Work location of the Employee
    @sql:Column {name: "work_location"}
    string workLocation?;
|};

# Employee information for the employee directory listing.
public type EmployeeDirectoryInfo record {|
    *EmployeeBasicInfo;
    # Job band of the employee's designation
    int? jobBand;
    # Start date of employment
    string startDate;
    # Manager email
    string managerEmail;
    # Business unit
    string businessUnit;
    # Team
    string team;
    # Sub-team
    string? subTeam;
    # Unit
    string? unit;
    # Employment type
    string employmentType;
    # Company name
    string company;
    # Work location
    string workLocation;
    # Employee status ("Active" or "Marked leaver")
    string employeeStatus;
|};

# User information with privileges.
public type UserInfo record {|
    *EmployeeBasicInfo;
    # Privileges assigned to the user
    int[] privileges = [];
|};

# Request payload for EPF uniqueness validation.
public type EpfValidationPayload record {|
    # EPF number to validate
    @constraint:String {maxLength: 45}
    string epf;
|};

# Response for EPF uniqueness validation.
public type EpfValidationResponse record {|
    # Whether the EPF already exists
    boolean epfExists;
|};

# Payload for recognising a returning employee by NIC/Passport. Sent in a body rather than the
# URL so the NIC stays out of access logs.
public type ReturningEmployeeLookupPayload record {|
    # NIC/Passport entered on the onboarding form
    @constraint:String {maxLength: 20}
    string nicOrPassport;
|};

# Who the onboarding form is dealing with, as far as the NIC/Passport tells.
public type ReturningEmployeeLookupResponse record {|
    # The person's latest employment, nil for someone new
    EmploymentMatch? latestEmployment;
    # Whether the person is employed now or already onboarded (Active or New joiner)
    boolean isCurrentEmployee;
    # The latest real work email they held, nil when their records hold only placeholders. A
    # rehire must use one of their earlier real emails; this is the one the form fills in.
    string? formerWorkEmail;
|};

# Context record returned by the employee ID generation query.
public type EmployeeIdContext record {|
    # Company prefix
    string companyPrefix;
    # Employment type
    EmploymentTypeName employmentType;
    # Whether the employment type is active (inactive types cannot be onboarded)
    boolean isActive;
|};

# Result record for the last numeric suffix query used in employee ID generation.
public type EmployeeIdSequence record {|
    # Last numeric ID used for the given prefix and employment type sequence
    decimal lastNumericId;
|};

# IDs fetched from the employee row before a compensating delete.
type EmployeeDeleteIds record {|
    # Primary key of the employee row
    int id;
    # Foreign key to the personal_info row
    int personalInfoId;
|};

# TODO: Add structured types for org structure fields and company details
# Employee information.
public type Employee record {|
    *EmployeeBasicInfo;
    # Employees' provident fund number
    string? epf;
    # Company name
    string company;
    # Company ID
    int companyId;
    # Work location
    string workLocation;
    # Start date
    string startDate;
    # Manager email
    string managerEmail;
    # Manager full name (resolved from DB join)
    string? managerName;
    # Additional manager email
    string? additionalManagerEmails;
    # Leadership attribute IDs held by this employee — drives the edit form
    int[]? leadershipGroupIds = ();
    # Leadership attribute names, comma-joined and alphabetical — drives the report preview column
    string? leadershipGroups = ();
    # In a lead's whole-chain list, the employee ID of the lead's additional report every route
    # to this member starts from; nil everywhere else
    string? throughEmployeeId = ();
    # First name of that additional report
    string? throughFirstName = ();
    # Last name of that additional report
    string? throughLastName = ();
    # Gender (from employee personal info)
    string? gender;
    # NIC or passport number (from employee personal info)
    string? nicOrPassport;
    # Date of birth (from employee personal info)
    string? dateOfBirth;
    # Nationality (from employee personal info)
    string? nationality;
    # Personal email address (from employee personal info)
    string? personalEmail;
    # Personal phone number (from employee personal info)
    string? personalPhone;
    # Resident number (from employee personal info)
    string? residentNumber;
    # Address line 1 (from employee personal info)
    string? addressLine1;
    # Address line 2 (from employee personal info)
    string? addressLine2;
    # City (from employee personal info)
    string? city;
    # State or province (from employee personal info)
    string? stateOrProvince;
    # Postal code (from employee personal info)
    string? postalCode;
    # Country (from employee personal info)
    string? country;
    # Emergency contacts, flattened as "name - relationship - mobile" entries
    string? emergencyContacts;
    # Employee status
    string employeeStatus;
    # Primary key (`employee.id`) of the prior employment this record continues from
    int? continuousServiceRecord;
    # Start date of the continuous service record (resolved via DB join)
    string? continuousServiceDate;
    # Probation end date
    string? probationEndDate;
    # Agreement end date
    string? agreementEndDate;
    # Resignation date
    string? resignationDate;
    # Final day in office
    string? finalDayInOffice;
    # Final day of employment
    string? finalDayOfEmployment;
    # Resignation reason
    string? resignationReason;
    # Employment type
    string employmentType;
    # Employment type ID
    int employmentTypeId;
    # Career Function ID
    int careerFunctionId;
    # Designation
    string designation;
    # Designation ID
    int designationId;
    # Job band
    int? jobBand;
    # Secondary job title
    string? secondaryJobTitle;
    # Job role
    string? jobRole;
    # External-facing designation
    string? externalDesignation;
    # Office
    string? office;
    # Office ID
    int? officeId;
    # Business unit
    string businessUnit;
    # Business unit ID
    int businessUnitId;
    # Team
    string team;
    # Team ID
    int teamId;
    # Sub-team
    string? subTeam;
    # Sub-team ID
    int? subTeamId;
    # Unit
    string? unit;
    # Unit ID
    int? unitId;
    # House
    string? house;
    # House ID
    int? houseId;
    # Computed field: number of subordinates this employee manages
    int subordinateCount;
|};

# Filters for getting employees.
public type EmployeeFilters record {|
    # Title
    string? title = ();
    # First name
    string? firstName = ();
    # Last name
    string? lastName = ();
    # National Identity Card number or Passport
    int|string? nicOrPassport = ();
    # Date of birth
    string? dateOfBirth = ();
    # Gender
    string? gender = ();
    # Personal email
    string? personalEmail = ();
    # Personal phone number
    string? personalPhone = ();
    # Resident number
    string? residentNumber = ();
    # City
    string? city = ();
    # Country
    string? country = ();
    # Career function ID
    int? careerFunctionId = ();
    # Manager email
    string? managerEmail = ();
    # Company ID
    int? companyId = ();
    # Office ID
    int? officeId = ();
    # Business unit ID
    int? businessUnitId = ();
    # Team ID
    int? teamId = ();
    # Sub-team ID
    int? subTeamId = ();
    # Unit ID
    int? unitId = ();
    # Designation ID
    int? designationId = ();
    # Employment type ID
    int? employmentTypeId = ();
    # Employment type IDs (multi-select). When non-empty, takes precedence over employmentTypeId.
    int[]? employmentTypeIds = ();
    # Leadership attribute IDs (multi-select). Matches employees holding ALL of the
    # given attributes — deliberately AND, unlike the OR multi-selects above.
    int[]? leadershipGroupIds = ();
    # Employee Status
    string? employeeStatus = ();
    # Employee Statuses (multi-select). When non-empty, takes precedence over employeeStatus/includeMarkedLeavers.
    string[]? employeeStatuses = ();
    # Direct reports only (true = direct only, false = all subordinates recursively)
    boolean? directReports = ();
    # When true, excludes employees whose start date is in the future
    boolean? excludeFutureStartDate = ();
    # Matches employees whose start date is exactly this day
    string? startDate = ();
    # When true, includes employees with "Marked leaver" status alongside the primary employeeStatus filter
    boolean? includeMarkedLeavers = ();
|};

# Payload for the employee report generation endpoint.
public type EmployeeReportPayload record {|
    # Filters to apply to the employee export; mirrors EmployeeFilters used by /employees/search
    EmployeeFilters filters = {};
    # Optional column allowlist (canonical key strings). nil or empty = all columns for the report type.
    string[]? columns = ();
|};

# Pagination information.
public type Pagination record {|
    # Limit of records per page
    @constraint:Int {minValue: 1, maxValue: 100}
    int 'limit = DEFAULT_RECORDS_PER_PAGE;
    # Offset for pagination
    @constraint:Int {minValue: 0}
    int offset = 0;
|};

# Allowlisted sort order values and their SQL fragments.
public final map<sql:ParameterizedQuery> & readonly SortOrder = {
    "ASC": `ASC`,
    "DESC": `DESC`,
    "asc": `ASC`,
    "desc": `DESC`,
    "Asc": `ASC`,
    "Desc": `DESC`
};

# Allowed Employee sort fields with their corresponding database columns.
public final map<sql:ParameterizedQuery> & readonly EmployeeSortField = {
    "employeeId": `e.employee_id`,
    "firstName": `e.first_name`,
    "lastName": `e.last_name`,
    "fullName": `CONCAT(e.first_name, ' ', e.last_name)`,
    "workEmail": `e.work_email`,
    "startDate": `e.start_date`,
    "employeeStatus": `e.employee_status`,
    "employmentType": `et.name`,
    "designation": `d.designation`,
    "businessUnit": `bu.name`,
    "team": `t.name`,
    "company": `c.name`
};

# Sort configuration for employee listing.
public type Sort record {|
    # Field to sort by
    string sortField = "employeeId";
    # Sort order: "ASC" for ascending, "DESC" for descending
    string sortOrder = "ASC";
|};

# Filter payload for getting employees.
public type EmployeeSearchPayload record {|
    # Search query
    @constraint:String {
        maxLength: 100,
        pattern: re `^[\p{L}\p{M}0-9\s@._'+-]*$`
    }
    string? searchString = ();
    # Filters
    EmployeeFilters filters;
    # Pagination
    Pagination pagination;
    # Sort configuration
    Sort sort;
    # When true, restricts results to the caller's direct and additional subordinates
    # even if the caller has admin access. Used by the "My Team" view.
    boolean leadOnly = false;
|};

# Employee record with total count.
public type EmployeeRecord record {|
    *Employee;
    # Total count of matching employees
    int totalCount;
|};

# Filtered employees response with total count.
public type EmployeesResponse record {|
    # List of filtered employees
    Employee[] employees;
    # Total count of matching employees
    int totalCount;
|};

# Employee record for QR code export — extends EmployeeBasicInfo with house and status fields.
public type EmployeeQrInfo record {|
    *EmployeeBasicInfo;
    # House
    string? house;
    # House ID
    int? houseId;
    # Employee status
    string employeeStatus;
|};

# QR code export response.
public type EmployeeQrInfoResponse record {|
    # List of employees
    EmployeeQrInfo[] employees;
    # Total count of matching employees
    int totalCount;
|};

# Filters relevant to the QR code employee search.
public type QrCodeSearchFilters record {|
    # Employee status
    string? employeeStatus = ();
    # Matches employees whose start date is exactly this day, so a joining cohort can be
    # selected for badge printing without picking each person out of the search
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string? startDate = ();
|};

# Search payload for the QR code export endpoint.
public type QrCodeSearchPayload record {|
    # Search query
    @constraint:String {
        maxLength: 100,
        pattern: re `^[\p{L}\p{M}0-9\s@._'+-]*$`
    }
    string? searchString = ();
    # Filters
    QrCodeSearchFilters filters;
    # Pagination
    Pagination pagination;
    # Sort configuration
    Sort sort;
|};

# Personal information of an employee.
public type EmployeePersonalInfo record {|
    # National Identity Card number
    @sql:Column {name: "nic_or_passport"}
    string nicOrPassport;
    # First name
    string firstName;
    # Last name
    string lastName;
    # Full name
    @sql:Column {name: "full_name"}
    string fullName;
    # Title (Mr./Ms./Dr./etc.)
    string title;
    # Date of birth
    string dob;
    # Gender of the person
    string gender;
    # Personal email address
    @sql:Column {name: "personal_email"}
    string? personalEmail;
    # Personal phone number
    @sql:Column {name: "personal_phone"}
    string? personalPhone;
    # Resident number
    @sql:Column {name: "resident_number"}
    string? residentNumber;
    # Address line 1
    @sql:Column {name: "address_line_1"}
    string? addressLine1;
    # Address line 2
    @sql:Column {name: "address_line_2"}
    string? addressLine2;
    # City
    string? city;
    # State or province
    @sql:Column {name: "state_or_province"}
    string? stateOrProvince;
    # Postal code
    @sql:Column {name: "postal_code"}
    string? postalCode;
    # Country of residence
    string? country;
    # Nationality
    string nationality;
    # Emergency contacts
    EmergencyContact[] emergencyContacts = [];
|};

# An employment found when recognising a person at onboarding — by NIC/Passport for a returning
# employee, or by work email for someone currently employed.
public type EmploymentMatch record {|
    # Employee ID
    string employeeId;
    # First name
    string firstName;
    # Last name
    string lastName;
    # Work email held on that employment
    string workEmail;
    # Employee status
    string employeeStatus;
|};

# Continuous service record information.
public type ContinuousServiceRecordInfo record {|
    # Employee table primary key, the value a continuous service record link stores
    int id;
    # Employee ID of the user
    string employeeId;
    # First name
    string firstName;
    # Last name
    string lastName;
    # Company name
    string company;
    # Work location
    string workLocation;
    # Start date
    string startDate;
    # Employee status; only a Left employment can be carried over as continuous service
    string employeeStatus;
    # Manager email
    string managerEmail;
    # Additional manager emails
    string? additionalManagerEmails;
    # Designation
    string designation;
    # Job role of the user
    string? secondaryJobTitle;
    # Office
    string? office;
    # Business unit
    string businessUnit;
    # Team
    string team;
    # Sub-team
    string? subTeam;
    # Unit
    string? unit;
|};

# Base record for org structure nodes (id and name only).
public type OrgEntityBase record {|
    # Entity ID.
    int id;
    # Entity name.
    string name;
|};

# Base record for company org chart entities (business unit, team, sub-team, unit).
public type OrgStructureBase record {|
    *OrgEntityBase;
    # Email of the entity head.
    @sql:Column {name: "head_email"}
    string headEmail;
    # Whether the entity is active.
    @sql:Column {name: "is_active"}
    boolean isActive;
    # Number of active employees currently assigned to this entity.
    @sql:Column {name: "active_employee_count"}
    int activeEmployeeCount;
|};

# Business unit — a company org chart entity.
public type BusinessUnit OrgStructureBase;

# Team — a company org chart entity.
public type Team OrgStructureBase;

# Sub-team — a company org chart entity.
public type SubTeam OrgStructureBase;

# Unit — a company org chart entity.
public type Unit OrgStructureBase;

# Organization structure unit (read-only public hierarchy).
public type OrgStructureUnit OrgEntityBase;

# Organization structure sub-team (read-only public hierarchy).
public type OrgStructureSubTeam record {|
    *OrgEntityBase;
    # Units under this sub-team.
    OrgStructureUnit[] units = [];
|};

# Organization structure team (read-only public hierarchy).
public type OrgStructureTeam record {|
    *OrgEntityBase;
    # Sub-teams under this team.
    OrgStructureSubTeam[] subTeams = [];
|};

# Organization structure business unit (read-only public hierarchy).
public type OrgStructureBusinessUnit record {|
    *OrgEntityBase;
    # Teams under this business unit.
    OrgStructureTeam[] teams = [];
|};

# [Database] Organization structure business unit row with teams as a JSON string.
type OrgStructureBusinessUnitRow record {|
    # Business unit ID
    int id;
    # Business unit name
    string name;
    # Teams under this business unit with their nested sub-teams and units
    json teams;
|};

# Career function.
public type CareerFunction record {|
    # Career function ID
    int id;
    # Career function name
    @sql:Column {name: "career_function"}
    string careerFunction;
    # Whether the career function is active
    @sql:Column {name: "is_active"}
    boolean isActive;
    # Number of active employees across this career function's designations
    @sql:Column {name: "active_employee_count"}
    int activeEmployeeCount;
|};

# Designation.
public type Designation record {|
    # Designation ID
    int id;
    # Designation name
    string designation;
    # Job band
    @sql:Column {name: "job_band"}
    int? jobBand;
    # Parent career function ID, nil when unassigned
    @sql:Column {name: "career_function_id"}
    int? careerFunctionId;
    # Whether the designation is active
    @sql:Column {name: "is_active"}
    boolean isActive;
    # Number of active employees holding this designation
    @sql:Column {name: "active_employee_count"}
    int activeEmployeeCount;
|};

# Payload to create a career function.
public type CreateCareerFunctionPayload record {|
    # Career function name. The pattern rejects whitespace-only input: minLength alone
    # sees the raw value, and the name is trimmed only after validation passes.
    @constraint:String {maxLength: 150, pattern: re `^\s*\S.*$`}
    string careerFunction;
|};

# Payload to update a career function (all fields optional for PATCH).
public type UpdateCareerFunctionPayload record {|
    # Career function name; whitespace-only is rejected (see CreateCareerFunctionPayload)
    @constraint:String {maxLength: 150, pattern: re `^\s*\S.*$`}
    string? careerFunction = ();
    # Whether the career function is active
    boolean? isActive = ();
|};

# Payload to create a designation.
public type CreateDesignationPayload record {|
    # Designation name
    @constraint:String {maxLength: 150, pattern: re `^\s*\S.*$`}
    string designation;
    # Job band (optional): nil, 0, or any positive integer. Negatives are rejected so a
    # real band can never collide with JOB_BAND_CLEAR_SENTINEL (-1), which means
    # "clear to NULL" on the update path only.
    @constraint:Int {minValue: 0}
    int? jobBand = ();
    # Parent career function ID. Required: every designation must belong to a career
    # function. Must be a real id — a bad value would otherwise violate the foreign key
    # and surface as a 500. Rows predating this rule may still hold NULL in the column
    # (the column stays nullable so they remain readable and reassignable), but no new
    # designation can be created without a career function.
    @constraint:Int {minValue: 1}
    int careerFunctionId;
|};

# Payload to update a designation (all fields optional for PATCH).
# NOTE: jobBand and careerFunctionId are deliberately NOT constrained here, unlike on
# `CreateDesignationPayload`. On the update path -1 is meaningful: it is
# JOB_BAND_CLEAR_SENTINEL / CAREER_FUNCTION_CLEAR_SENTINEL, meaning "clear this column to
# NULL". Adding a minValue constraint here would silently break unassigning a designation
# and clearing its job band.
public type UpdateDesignationPayload record {|
    # Designation name
    @constraint:String {maxLength: 150, pattern: re `^\s*\S.*$`}
    string? designation = ();
    # Job band; -1 (JOB_BAND_CLEAR_SENTINEL) clears it, nil leaves it unchanged
    int? jobBand = ();
    # Parent career function ID; -1 (CAREER_FUNCTION_CLEAR_SENTINEL) clears it, nil
    # leaves it unchanged
    int? careerFunctionId = ();
    # Whether the designation is active
    boolean? isActive = ();
|};

# [Database] The timezone of one of a company's work locations.
public type LocationTimeZone record {|
    # Company ID
    @sql:Column {name: "company_id"}
    int companyId;
    # Work location name, as stored on the employee
    @sql:Column {name: "allowed_location"}
    string allowedLocation;
    # IANA timezone name, e.g. "Asia/Colombo"
    @sql:Column {name: "time_zone"}
    string timeZone;
|};

# [Database] Company record with allowed locations as a JSON string.
public type CompanyRow record {|
    # Company ID
    int id;
    # Company name
    string name;
    # Company prefix
    string prefix;
    # Company location
    string location;
    # Allowed locations
    string? allowedLocations;
|};

# Allowed location with probation period.
public type AllowedLocation record {|
    # Work location name
    string location;
    # Probation period in months
    int? probationPeriod;
|};

# Company with parsed allowed locations.
public type CompanyResponse record {|
    # Company ID
    int id;
    # Company name
    string name;
    # Company prefix
    string prefix;
    # Company location
    string location;
    # Allowed work locations with probation periods
    AllowedLocation[] allowedLocations;
|};

# Office.
public type Office record {|
    # Office ID
    int id;
    # Office name
    string name;
    # Office location
    string location;
|};

# A university already recorded for an intern.
type UniversityRow record {|
    # University name
    string university;
|};

# Employment type.
public type EmploymentType record {|
    # ID of the employment type
    int id;
    # Name of the employment type
    string name;
    # Whether the employment type is active
    @sql:Column {name: "is_active"}
    boolean isActive;
|};

# House.
public type House record {|
    # House ID
    int id;
    # House name
    string name;
|};

# A leadership attribute an employee can hold.
public type LeadershipGroup record {|
    # Identifier
    int id;
    # Display name — also the CSV column header for this attribute
    string name;
    # Whether it can still be assigned
    boolean isActive;
|};

# A leadership attribute as the master data screen lists it.
public type LeadershipGroupWithUsage record {|
    *LeadershipGroup;
    # Active and Marked-leaver employees holding it; these are what block retiring it
    int holderCount;
|};

# Create a leadership attribute.
public type CreateLeadershipGroupPayload record {|
    # Attribute name, also its CSV column header. It must start with a letter, then use only
    # letters, digits, spaces, &, -, ' and . (surrounding spaces are trimmed after
    # validation). Starting with a letter means the header can never begin with =, +, - or @
    # and be run as a spreadsheet formula; leaving out the comma matters because a holder's
    # attributes travel comma-joined (GROUP_CONCAT) and are split on commas.
    @constraint:String {maxLength: 100, pattern: re `^ *\p{L}[\p{L}\p{M}\p{N} &'.-]*$`}
    string name;
|};

# Rename, retire or reactivate a leadership attribute.
public type UpdateLeadershipGroupPayload record {|
    # New name, under the same rules as CreateLeadershipGroupPayload
    @constraint:String {maxLength: 100, pattern: re `^ *\p{L}[\p{L}\p{M}\p{N} &'.-]*$`}
    string? name = ();
    # false retires the attribute, true reactivates it
    boolean? isActive = ();
|};

# Manager payload.
public type Manager record {|
    # Employee ID of the manager
    @sql:Column {name: "employee_id"}
    string employeeId;
    # Manager work email
    @sql:Column {name: "work_email"}
    string workEmail;
|};

# Work email row mapping.
public type WorkEmailRow record {|
    # Work email address
    @sql:Column {name: "work_email"}
    string workEmail;
|};

# NIC or passport row mapping.
public type NicOrPassportRow record {|
    # NIC or passport value
    @sql:Column {name: "nic_or_passport"}
    string nicOrPassport;
|};

# EPF row mapping.
public type EpfRow record {|
    # EPF number
    string epf;
|};

# Emergency contact information.
public type EmergencyContact record {|
    # Name of the emergency contact
    string name;
    # Relationship with the employee
    string relationship;
    # Telephone number of the emergency contact
    string? telephone;
    # Mobile number of the emergency contact
    string mobile;
|};

# Emergency contact row mapping.
public type EmergencyContactRow record {|
    # Name of the emergency contact
    string name;
    # Telephone number of the emergency contact
    string? telephone;
    # Relationship with the employee
    string relationship;
    # Mobile number of the emergency contact
    string mobile;
|};

# [Database] Employee name row mapping for email-to-name lookups.
type EmployeeNameRow record {|
    # Work email of the employee
    @sql:Column {name: "work_email"}
    string workEmail;
    # Full name of the employee
    @sql:Column {name: "full_name"}
    string fullName;
|};

# Additional manager email row mapping.
public type AdditionalManagerEmailRow record {|
    # Additional manager email
    @sql:Column {name: "additional_manager_email"}
    string additionalManagerEmail;
|};

# A single leadership assignment row, as read back for diffing.
type LeadershipGroupIdRow record {|
    # Leadership attribute (leadership_group) ID
    int leadershipGroupId;
|};

# Bulk onboarding validation error.
public type BulkEmployeeError record {|
    # CSV row number (1-based, including header row)
    int row;
    # Field name that failed validation
    string 'field;
    # Validation error message
    string message;
|};

# Records an employee whose SCIM provisioning failed during bulk onboarding.
public type BulkProvisioningError record {|
    # Employee ID of the affected record
    string employeeId;
    # Work email of the affected record
    string workEmail;
    # Failure reason from the provisioning step
    string reason;
|};

# Records an employee who was created successfully but whose group assignment was partially or fully skipped.
public type BulkGroupAssignmentWarning record {|
    # Employee ID of the affected employee
    string employeeId;
    # Work email of the affected employee
    string workEmail;
    # Groups that could not be assigned
    string[] failedGroups;
|};

public type OrphanedScimUser record {|
    string employeeId;
    string workEmail;
    string reason;
|};

public type BulkOnboardingResult record {|
    int created;
    int failed;
|};

# Bulk onboarding response payload.
public type BulkUploadResponse record {|
    # Number of employees created
    int created;
    # Number of rows skipped (empty rows)
    int skipped;
    # Validation errors (empty when success)
    BulkEmployeeError[] errors;
    # Employees for whom SCIM provisioning failed and whose DB records were rolled back
    BulkProvisioningError[] provisioningErrors = [];
    # Asgardeo users created but DB rows were rolled back due to downstream failures
    OrphanedScimUser[] orphanedScimUsers = [];
    # Employees who were created in the DB and Asgardeo but had one or more group-assignment failures
    BulkGroupAssignmentWarning[] groupAssignmentWarnings = [];
|};

# Create personal info payload.
public type CreatePersonalInfoPayload record {|
    # National Identity Card number or Passport
    string nicOrPassport;
    # First name
    @constraint:String {maxLength: 100}
    string firstName;
    # Last name
    @constraint:String {maxLength: 100}
    string lastName;
    # Full name
    @constraint:String {maxLength: 255}
    string fullName;
    # Title (Mr./Ms./Dr./etc.)
    @constraint:String {maxLength: 20}
    string title;
    # Date of birth
    @constraint:String {pattern: re `^\d{4}-\d{2}-\d{2}$`}
    string dob;
    # Gender of the person
    @constraint:String {maxLength: 20}
    string gender;
    # Personal email address
    @constraint:String {maxLength: 254, pattern: re `${EMAIL_PATTERN}`}
    string? personalEmail = ();
    # Personal phone number
    @constraint:String {maxLength: 100, pattern: re `${PHONE_PATTERN}`}
    string? personalPhone = ();
    # Resident number
    @constraint:String {maxLength: 100, pattern: re `${PHONE_PATTERN}`}
    string? residentNumber = ();
    # Address line 1
    @constraint:String {maxLength: 255}
    string? addressLine1 = ();
    # Address line 2
    @constraint:String {maxLength: 255}
    string? addressLine2 = ();
    # City
    @constraint:String {maxLength: 100}
    string? city = ();
    # State or province
    @constraint:String {maxLength: 100}
    string? stateOrProvince = ();
    # Postal code
    @constraint:String {maxLength: 20}
    string? postalCode = ();
    # Country of residence
    @constraint:String {maxLength: 100}
    string? country = ();
    # Nationality
    @constraint:String {maxLength: 100}
    string nationality;
    # Emergency contacts
    EmergencyContact[]? emergencyContacts = ();
|};

# Create employee payload.
public type CreateEmployeePayload record {|
    # First name of the user
    @constraint:String {maxLength: 150}
    string firstName;
    # Last name of the user
    @constraint:String {maxLength: 150}
    string lastName;
    # Employee's Provident Fund number
    @constraint:String {maxLength: 45}
    string? epf = ();
    # Company ID
    int companyId;
    # Work location
    @constraint:String {maxLength: 100}
    string workLocation;
    # Work email of the user. Left out for a joiner whose account does not exist yet, in which
    # case FUTURE_JOINER_EMAIL is stored; onboarding fills it in before the record is written.
    @constraint:String {maxLength: 254, pattern: re `${EMAIL_PATTERN}`}
    string? workEmail = ();
    # Start date
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string startDate;
    # Secondary job title
    @constraint:String {maxLength: 100}
    string? secondaryJobTitle = ();
    # Job role
    @constraint:String {maxLength: 100}
    string? jobRole = ();
    # External-facing designation
    @constraint:String {maxLength: 100}
    string? externalDesignation = ();
    # Manager email
    @constraint:String {maxLength: 254, pattern: re `${EMAIL_PATTERN}`}
    string managerEmail;
    # Additional manager emails
    Email[] additionalManagerEmails = [];
    # Employee thumbnail URL
    @constraint:String {maxLength: 2048, pattern: re `${URL_PATTERN}`}
    string? employeeThumbnail = ();
    # Probation end date
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string? probationEndDate = ();
    # Agreement end date
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string? agreementEndDate = ();
    # Employment type ID
    int employmentTypeId;
    # Designation ID
    int designationId;
    # Office ID
    int? officeId = ();
    # Team ID
    int teamId;
    # Sub-team ID
    int? subTeamId = ();
    # Business unit ID
    int businessUnitId;
    # Unit ID
    int? unitId = ();
    # House ID
    int? houseId = ();
    # Primary key (`employee.id`) of the prior employment this record continues from
    int? continuousServiceRecord = ();
    # Employee Status
    EmployeeStatus employeeStatus = EMPLOYEE_ACTIVE;
    # Employee ID (required for fixed-term employment type)
    @constraint:String {maxLength: 50}
    string? employeeId = ();
    # University an intern attends. Saved to `internship` only when the employment type is
    # INTERNSHIP; ignored for every other type.
    @constraint:String {maxLength: 200}
    string? university = ();
    # Employee personal information
    CreatePersonalInfoPayload personalInfo;
|};

# Employee personal information update payload.
public type UpdateEmployeePersonalInfoPayload record {|
    # National Identity Card number or Passport
    @constraint:String {maxLength: 100}
    string? nicOrPassport = ();
    # First name. minLength guards against a blank string being accepted as "set the name to
    # empty" — see updateEmployeeNameQuery, which forwards this value into employee.first_name
    # whenever it is non-nil, with no separate blank check of its own.
    @constraint:String {minLength: 1, maxLength: 100}
    string? firstName = ();
    # Last name. Same minLength rationale as firstName above.
    @constraint:String {minLength: 1, maxLength: 100}
    string? lastName = ();
    # Full name
    @constraint:String {maxLength: 255}
    string? fullName = ();
    # Title (Mr./Ms./Dr./etc.)
    @constraint:String {maxLength: 20}
    string? title = ();
    # Date of birth
    @constraint:String {pattern: re `^\d{4}-\d{2}-\d{2}$`}
    string? dob = ();
    # Gender of the person
    @constraint:String {maxLength: 20}
    string? gender = ();
    # Nationality
    @constraint:String {maxLength: 100}
    string? nationality = ();
    # Personal email address
    @constraint:String {maxLength: 254, pattern: re `${EMAIL_PATTERN}`}
    string? personalEmail = ();
    # Personal phone number
    @constraint:String {maxLength: 100, pattern: re `${PHONE_PATTERN}`}
    string? personalPhone = ();
    # Resident number
    @constraint:String {maxLength: 100, pattern: re `${PHONE_PATTERN}`}
    string? residentNumber = ();
    # Address line 1
    @constraint:String {maxLength: 255}
    string? addressLine1 = ();
    # Address line 2
    @constraint:String {maxLength: 255}
    string? addressLine2 = ();
    # City
    @constraint:String {maxLength: 100}
    string? city = ();
    # State or province
    @constraint:String {maxLength: 100}
    string? stateOrProvince = ();
    # Postal code
    @constraint:String {maxLength: 20}
    string? postalCode = ();
    # Country of residence
    @constraint:String {maxLength: 100}
    string? country = ();
    # Emergency contacts
    EmergencyContact[]? emergencyContacts = ();
|};

# Employee job information update payload.
public type UpdateEmployeeJobInfoPayload record {|
    # Employee's Provident Fund number
    @constraint:String {maxLength: 45}
    string? epf = ();
    # Company ID
    int? companyId = ();
    # Work location
    @constraint:String {maxLength: 100}
    string? workLocation = ();
    # Work email - WARNING: Identity key used for authorization checks
    @constraint:String {maxLength: 254, pattern: re `${EMAIL_PATTERN}`}
    string? workEmail = ();
    # Start date    
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string? startDate = ();
    # Secondary job title
    @constraint:String {maxLength: 100}
    string? secondaryJobTitle = ();
    # Job role
    @constraint:String {maxLength: 100}
    string? jobRole = ();
    # External-facing designation
    @constraint:String {maxLength: 100}
    string? externalDesignation = ();
    # Manager email
    @constraint:String {maxLength: 254, pattern: re `${EMAIL_PATTERN}`}
    string? managerEmail = ();
    # Additional manager emails
    Email[]? additionalManagerEmails = ();
    # Employee thumbnail URL
    @constraint:String {maxLength: 2048, pattern: re `${URL_PATTERN}`}
    string? employeeThumbnail = ();
    # Probation end date; an empty string clears it
    @constraint:String {pattern: re `^(\d{4}-\d{2}-\d{2})?$`}
    string? probationEndDate = ();
    # Agreement end date
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string? agreementEndDate = ();
    # Employment type ID
    int? employmentTypeId = ();
    # Designation ID
    int? designationId = ();
    # Office ID; -1 (OFFICE_CLEAR_SENTINEL) clears it to NULL, nil leaves it unchanged.
    # NOTE: the edit form only sends this field when it actually changed, so nil (absent from
    # the request) must NEVER be treated as "clear" here — see updateEmployeeJobInfoQuery.
    int? officeId = ();
    # Team ID
    int? teamId = ();
    # Sub-team ID
    int? subTeamId = ();
    # Business unit ID
    int? businessUnitId = ();
    # Unit ID; -1 (UNIT_CLEAR_SENTINEL) clears it to NULL, nil leaves it unchanged.
    # NOTE: same caveat as officeId above — absence must never be treated as "clear."
    int? unitId = ();
    # House ID. The House selection does not provide a "None" option,
    # so there is no way to clear houseId through this payload and no clear
    # sentinel is required.
    int? houseId = ();
    # Primary key (`employee.id`) of the prior employment this record continues from.
    # `CONTINUOUS_SERVICE_RECORD_CLEAR_SENTINEL` clears the link.
    int? continuousServiceRecord = ();
    # Employee Status
    EmployeeStatus? employeeStatus = ();
    # Final day in office
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string? finalDayInOffice = ();
    # Final day of employment 
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string? finalDayOfEmployment = ();
    # Resignation reason; whitespace-only is rejected (see UpdateResignationPayload). Left
    # optional: absence means the field is not part of this edit, not a blank reason.
    @constraint:String {maxLength: 300, pattern: re `^\s*\S.*$`}
    string? resignationReason = ();
    # Leadership attribute IDs to assign. Omitted (nil) leaves assignments unchanged;
    # an empty array clears every assignment. Unknown or inactive ids reject the whole update.
    int[]? leadershipGroupIds = ();
|};

# [Database] Payload for updating an employee's resignation details.
#
# Employment status is deliberately absent: recording a departure is what makes someone
# a leaver, so the status is derived from this call rather than supplied by the caller.
# Accepting it would let a narrow resignation permission set an arbitrary status.
public type UpdateResignationPayload record {|
    # Last day the employee is physically in office
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string finalDayInOffice;
    # Final day of employment
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string finalDayOfEmployment;
    # Reason for leaving. The pattern rejects whitespace-only input: minLength alone sees
    # the raw value, so "   " satisfies it and stores a reason that reads as blank
    # wherever a departure is displayed. Same rule as CreateCareerFunctionPayload.
    @constraint:String {maxLength: 300, pattern: re `^\s*\S.*$`}
    string resignationReason;
|};

# [Database] Insert type for vehicle.
public type AddVehiclePayload record {|
    # Owner of the vehicle
    string owner;
    # Registration number of the vehicle
    string vehicleRegistrationNumber;
    # Type of the vehicle
    VehicleTypes vehicleType;
    # Status of the vehicle
    VehicleStatus vehicleStatus;
    # User who created the vehicle record
    string createdBy;
|};

# [Database] Vehicle type.
public type Vehicle record {|
    *AddVehiclePayload;
    # Auto-increment vehicle ID
    int vehicleId;
    # Timestamp when created
    string createdOn;
    # Timestamp when updated
    string updatedOn;
    # Person who updated the vehicle record
    string updatedBy;
|};

# Database records of vehicle
public type FetchVehicleResponse record {|
    *Vehicle;
    # Total count of the query
    int totalCount;
|};

# Vehicles array with total count.
public type Vehicles record {|
    # List of vehicles.
    Vehicle[] vehicles;
    # Total number of records.
    int totalCount;
|};

# [Database] Update payload of the vehicle.
public type UpdateVehiclePayload record {|
    # Id of the vehicle.
    int vehicleId;
    # Status of the vehicle
    VehicleStatus? vehicleStatus;
    # User who created the vehicle record
    string updatedBy;
|};

# [Database] Parking floor.
public type ParkingFloor record {|
    # Floor identifier
    int id;
    # Floor name (e.g. "Ground Floor")
    string name;
    # Display order of the floor
    int displayOrder;
    # Number of coins per slot on the floor
    decimal coinsPerSlot;
|};

# [Database] Parking slot.
public type ParkingSlot record {|
    # Slot identifier (e.g. B-01)
    string slotId;
    # Floor identifier
    int floorId;
    # Floor name
    string floorName;
    # Number of coins per slot
    decimal coinsPerSlot;
    # Availability status for the given date
    boolean isBooked;
|};

# [Database] Parking slot row mapping.
public type ParkingSlotRow record {|
    # Slot identifier (e.g. B-01)
    string slotId;
    # Floor identifier
    int floorId;
    # Floor name
    string floorName;
    # Number of coins per slot
    decimal coinsPerSlot;
    # Booked status flag (0 = available, 1 = booked)
    int isBooked;
|};

# [Database] Parking reservation.
public type ParkingReservation record {|
    # Reservation identifier
    int id;
    # Slot identifier
    string slotId;
    # Booking date
    string bookingDate;
    # Employee email
    string employeeEmail;
    # Registered vehicle ID
    int vehicleId;
    # Reservation status
    ParkingReservationStatus status;
    # Payment reference
    string? paymentReference;
    # Amount to be paid in coins
    decimal coinsAmount;
    # Timestamp when created
    string createdOn;
    # Person who created the parking reservation record
    string createdBy;
    # Timestamp when updated
    string updatedOn;
    # Person who updated the parking reservation record
    string updatedBy;
|};

# [Database] Payload to create parking reservation.
public type AddParkingReservationPayload record {|
    # Slot identifier
    string slotId;
    # Booking date
    string bookingDate;
    # Employee email
    string employeeEmail;
    # Registered vehicle ID
    int vehicleId;
    # Amount to be paid in coins
    decimal coinsAmount;
    # Transaction hash minted at create, reused as the payment idempotency key on confirm
    string transactionHash;
    # User who created the parking reservation record
    string createdBy;
|};

# [Database] Parking reservation details (slot, floor, vehicle).
public type ParkingReservationDetails record {|
    # Reservation identifier
    int id;
    # Slot identifier
    string slotId;
    # Booking date
    string bookingDate;
    # Employee email
    string employeeEmail;
    # Registered vehicle ID
    int vehicleId;
    # Vehicle registration number
    string vehicleRegistrationNumber;
    # Vehicle type
    string? vehicleType;
    # Reservation status
    ParkingReservationStatus status;
    # Payment reference
    string? paymentReference;
    # Amount to be paid in coins
    decimal coinsAmount;
    # Floor name (e.g. "Ground Floor")
    string floorName;
    # Timestamp when created
    string createdOn;
    # Person who created the parking reservation record
    string createdBy;
    # Timestamp when updated
    string updatedOn;
    # Person who updated the parking reservation record
    string updatedBy;
|};

# [Database] Reservation id row (existence check).
public type ReservationIdRow record {|
    # Reservation identifier
    int id;
|};

# [Database] Active reservation summary for an employee/date lookup.
public type ActiveParkingReservationRow record {|
    # Reservation identifier
    int id;
    # Slot identifier
    string slotId;
    # Registered vehicle ID on the reservation
    int vehicleId;
    # Reservation status
    ParkingReservationStatus status;
    # Amount to be paid in coins
    decimal coinsAmount;
|};

# Payload to create a company org chart entity (business unit, team, sub-team, or unit).
public type CreateCompanyOrgChartEntityPayload record {|
    # Name of the entity
    @constraint:String {maxLength: 45}
    string name;
    # Head email of the entity (optional, empty string treated as no head)
    @constraint:String {maxLength: 254}
    string? headEmail = ();
|};

# Payload to update a company org chart entity (all fields optional for PATCH).
public type UpdateCompanyOrgChartEntityPayload record {|
    # Name of the entity
    @constraint:String {maxLength: 45}
    string? name = ();
    # Head email of the entity (empty string clears the value)
    @constraint:String {maxLength: 254}
    string? headEmail = ();
    # Whether the entity is active
    boolean? isActive = ();
|};

# Payload to create a business-unit → team mapping.
public type CreateBusinessUnitTeamPayload record {|
    # Business unit ID
    int businessUnitId;
    # Team ID
    int teamId;
    # Head email for this specific BU+Team combination (optional)
    @constraint:String {maxLength: 254}
    string? headEmail = ();
|};

# Payload to create a business-unit-team → sub-team mapping.
public type CreateBusinessUnitTeamSubTeamPayload record {|
    # Business unit team mapping ID
    int businessUnitTeamId;
    # Sub-team ID
    int subTeamId;
    # Head email for this specific BU+Team+SubTeam combination (optional)
    @constraint:String {maxLength: 254}
    string? headEmail = ();
|};

# Payload to create a business-unit-team-sub-team → unit mapping.
public type CreateBusinessUnitTeamSubTeamUnitPayload record {|
    # Business unit team sub-team mapping ID
    int businessUnitTeamSubTeamId;
    # Unit ID
    int unitId;
    # Head email for this specific BU+Team+SubTeam+Unit combination (optional)
    @constraint:String {maxLength: 254}
    string? headEmail = ();
|};

# Payload to update any mapping (all fields optional for PATCH).
public type UpdateMappingPayload record {|
    # Head email for the mapping combination (empty string clears the value)
    @constraint:String {maxLength: 254}
    string? headEmail = ();
    # Whether the mapping is active
    boolean? isActive = ();
|};

# Base fields for company org chart nodes: entity metadata + mapping metadata.
public type CompanyOrgChartNode record {|
    # Entity ID.
    int id;
    # Entity name.
    string name;
    # Email of the entity head.
    @sql:Column {name: "head_email"}
    string headEmail;
    # Whether the entity is active.
    @sql:Column {name: "is_active"}
    boolean isActive;
    # ID of the mapping record linking this entity to its parent.
    @sql:Column {name: "mapping_id"}
    int mappingId;
    # Email of the head responsible for this mapping.
    @sql:Column {name: "mapping_head_email"}
    string mappingHeadEmail;
    # Whether the mapping is active.
    @sql:Column {name: "mapping_is_active"}
    boolean mappingIsActive;
|};

# Company org chart: unit node.
public type CompanyOrgChartUnit CompanyOrgChartNode;

# Company org chart: sub-team node with its child units.
public type CompanyOrgChartSubTeam record {|
    *CompanyOrgChartNode;
    # Units belonging to this sub-team.
    CompanyOrgChartUnit[] units = [];
|};

# Company org chart: team node with its child sub-teams.
public type CompanyOrgChartTeam record {|
    *CompanyOrgChartNode;
    # Sub-teams belonging to this team.
    CompanyOrgChartSubTeam[] subTeams = [];
|};

# Company org chart: business unit node (top level) with its child teams.
public type CompanyOrgChartBusinessUnit record {|
    *OrgStructureBase;
    # Teams belonging to this business unit.
    CompanyOrgChartTeam[] teams = [];
|};

# [Database] Company org chart business unit row with teams as a JSON string.
type CompanyOrgChartBusinessUnitRow record {|
    # Business unit ID.
    int id;
    # Business unit name.
    string name;
    # Email of the entity head.
    @sql:Column {name: "head_email"}
    string headEmail;
    # Whether the business unit is active.
    @sql:Column {name: "is_active"}
    boolean isActive;
    # Number of active employees currently assigned to this business unit.
    @sql:Column {name: "active_employee_count"}
    int activeEmployeeCount;
    # Teams with nested sub-teams and units as raw JSON.
    json teams;
|};

# One employment period for a person.
public type EmploymentPeriod record {|
    # Employee table primary key
    int id;
    # Employee ID (e.g. "EP 10006")
    string? employeeId;
    # Employment type name
    string employmentType;
    # Start date
    string startDate;
    # Final day of employment, if the period has ended
    string? endDate;
    # Work email
    string workEmail;
    # Employee ID of the prior linked employment, if any
    string? continuousServiceRecord;
|};

# A raw audit row awaiting diffing.
public type AuditSnapshot record {|
    # Employee table primary key this snapshot belongs to
    int employeePkId;
    # Source table this snapshot came from
    string sourceTable;
    # INSERT or UPDATE
    string actionType;
    # Who performed the action
    string actionBy;
    # When the action occurred
    string actionOn;
    # The full row snapshot as JSON
    json data;
|};

# One field-level change derived from consecutive audit snapshots.
public type HistoryEvent record {|
    # Employee table primary key this event belongs to
    int employeePkId;
    # Canonical field key (e.g. "team_id")
    string 'field;
    # Audit table the change came from, so the client can group events by kind
    # (employment vs personal information) without inferring it from the field name
    string sourceTable;
    # Value before the change, if any
    string? previousValue;
    # Value after the change
    string? currentValue;
    # When the change occurred
    string occurredOn;
    # Who made the change
    string actionBy;
    # True when actionBy is a system actor rather than a person
    boolean isSystem;
|};

# One id-to-name mapping row used to resolve history event values.
public type HistoryLookupName record {|
    # The audit field this mapping applies to, e.g. "unit_id"
    string 'field;
    # The lookup row's primary key
    int id;
    # The human-readable name
    string name;
|};

# Status of a scheduled change.
public enum ScheduledChangeStatus {
    SCHEDULED_CHANGE_PENDING = "PENDING",
    SCHEDULED_CHANGE_APPLIED = "APPLIED",
    SCHEDULED_CHANGE_CANCELLED = "CANCELLED",
    SCHEDULED_CHANGE_SUPERSEDED = "SUPERSEDED",
    SCHEDULED_CHANGE_FAILED = "FAILED"
}

# A change to an employee's general information waiting for its effective date.
public type ScheduledChange record {|
    # Scheduled change id
    int id;
    # Employee table primary key the change applies to
    int employeeId;
    # Employee ID as people refer to it. Every read path joins the employee table for
    # it, so a caller can tell whose rows these are without resolving the primary key:
    # the profile page checks it before rendering, since a response can arrive after the
    # viewer has moved to somebody else.
    string employeeIdentifier;
    # Date the change takes effect
    string effectiveDate;
    # Fields being changed, keyed by database column rather than by the payload field
    # names the form uses — house_id, not houseId — because that is the shape the sweep
    # applies and the shape expected below is captured in.
    json changes;
    # What those same fields held when the change was scheduled, keyed the same way
    json expected;
    # Where the change is in its life. Typed as the enum rather than a string: the column
    # is a MySQL ENUM over exactly these five values, so nothing else can be read back.
    ScheduledChangeStatus status;
    # When it was written to the employee record, if it was
    string? appliedOn;
    # Why it could not be applied, if it could not
    string? failureReason;
    # Who scheduled it
    string createdBy;
    # When it was scheduled
    string createdOn;
|};

# Payload for scheduling a change to an employee's general information.
public type ScheduleChangePayload record {|
    # Date the change takes effect; today or later
    @constraint:String {pattern: re `${DATE_PATTERN}`}
    string effectiveDate;
    # Fields to change when that date arrives
    UpdateEmployeeJobInfoPayload changes;
|};


# A lead's additional report through whom someone is in that lead's team.
public type ReportingLinePerson record {|
    # Employee ID
    string employeeId;
    # First name
    string firstName;
    # Last name
    string lastName;
|};

# How a team member is linked to the lead viewing them.
public type ReportingLine record {|
    # How the member relates to the lead
    ReportingRelation relation;
    # For an indirect report, the lead's additional report every route to them starts from;
    # nil when any route starts from a direct report
    ReportingLinePerson? through;
|};

# Reporting line as the query returns it.
public type ReportingLineRow record {|
    # How the member relates to the lead
    ReportingRelation relation;
    # Employee ID of the additional report every route starts from, if any
    string? throughEmployeeId = ();
    # First name of that additional report
    string? throughFirstName = ();
    # Last name of that additional report
    string? throughLastName = ();
|};
