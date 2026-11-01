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

import people.database;
import people.promotion;

import ballerina/constraint;

# One field-level change as returned to the client.
#
# `actionBy` is optional rather than required because the reduced projection strips it
# server-side. The field is absent from the payload entirely for those callers rather than
# blanked, so the client is never handed an actor it is not permitted to display.
public type HistoryEventResponse record {|
    # Employee table primary key this event belongs to
    int employeePkId;
    # Canonical field key (e.g. "team_id")
    string 'field;
    # Audit table the change came from, so the client can group events by kind
    string sourceTable;
    # Value before the change, if any
    string? previousValue;
    # Value after the change
    string? currentValue;
    # When the change occurred
    string occurredOn;
    # Who made the change. Omitted entirely under the reduced projection.
    string actionBy?;
    # True when the change was made by an automated process rather than a person.
    # Always false under the reduced projection, whose system events are dropped outright.
    boolean isSystem;
|};

# One employment period with the promotions that fall inside it.
public type EmploymentPeriodResponse record {|
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
    # Approved promotions that took effect during this period
    promotion:PromotionRecord[] promotions;
|};

# Employee history timeline: employment periods, field-level changes, and promotions.
public type EmployeeHistoryResponse record {|
    # Employment periods for the person, newest first, each carrying its promotions
    EmploymentPeriodResponse[] periods;
    # Field-level change events, newest first, already filtered for the caller's privilege
    HistoryEventResponse[] events;
    # True when the HRIS promotion lookup failed. The rest of the response is still valid;
    # the client should indicate that promotions could not be loaded rather than that there
    # were none.
    boolean promotionsUnavailable;
|};

// # Payload for adding a vehicle.
type NewVehicle record {|
    # Registration number of the vehicle
    @constraint:String {
        pattern: {
            value: re `^([A-Za-z]{1,3}|\d{1,3}) \d{4}$`,
            message: "Vehicle registration number should be a valid pattern in Sri Lanka."
        }
    }
    string vehicleRegistrationNumber;
    # Type of the vehicle
    database:VehicleTypes vehicleType;
|};

# Request body for creating a parking reservation (before payment).
type CreateParkingReservationRequest record {|
    # Slot identifier (e.g. B-01)
    string slotId;
    # Booking date (YYYY-MM-DD), same-day only
    @constraint:String {
        pattern: {
            value: re `${database:DATE_PATTERN}`,
            message: "Booking date must be in YYYY-MM-DD format."
        }
    }
    string bookingDate;
    # Registered vehicle ID (car only)
    int vehicleId;
|};

# Response after creating a PENDING reservation.
type CreateParkingReservationResponse record {|
    # Reservation identifier
    int reservationId;
    # Amount to be paid in coins
    decimal coinsAmount;
|};

# Request body for confirming a reservation with the selected payer wallet.
type ConfirmParkingReservationRequest record {|
    # Reservation identifier (from create response)
    int reservationId;
    # Payer wallet address selected by the user
    string fromAddress;
|};

# Car park config returned to the micro app.
type CarParkConfigResponse record {|
    # First hour (Asia/Colombo) when same-day reservations are allowed.
    int reservationWindowStartHour;
    # Hour after which same-day reservations are no longer allowed.
    int reservationWindowEndHour;
|};

# Response for employee creation.
type EmployeeCreatedResponse record {|
    # ID of the newly created employee
    int employeeId;
    # Status message
    string message;
    # Whether there was a warning during group assignment
    boolean hasGroupAssignmentWarning;
|};

# A parsed CSV data row paired with its spreadsheet row number.
type CsvRowInfo record {|
    # 1-based row number (header = row 1, first data row = row 2)
    int rowNumber;
    # Typed CSV row mapped directly from the CSV headers
    BulkEmployeeCsvRow values;
|};

# Normalized name-to-ID lookup maps for all reference data.
type BulkRefData record {|
    # Normalized business unit name to ID
    map<int> businessUnitIds;
    # Normalized team name to ID
    map<int> teamIds;
    # Normalized sub-team name to ID
    map<int> subTeamIds;
    # Normalized unit name to ID
    map<int> unitIds;
    # Normalized designation name to ID
    map<int> designationIds;
    # Normalized employment type name to ID
    map<int> employmentTypeIds;
    # Normalized company name to ID
    map<int> companyIds;
    # Normalized office name to ID
    map<int> officeIds;
    # Work location to timezone, keyed for database:localDateAt
    map<string> locationTimeZones;
|};

# Result of the first pass over a bulk CSV upload.
type BulkFirstPassResult record {|
    # Parsed data rows with row numbers
    CsvRowInfo[] rowInfos;
    # Validation and intra-CSV duplicate errors
    database:BulkEmployeeError[] errors;
    # Number of blank rows skipped
    int skipped;
    # Normalized work email to row number for DB duplicate detection
    map<int> rowByEmail;
    # NIC/Passport value to row number for DB duplicate detection
    map<int> rowByNic;
    # EPF value to row number for DB duplicate detection
    map<int> rowByEpf;
    # Work emails to batch-check against the DB
    string[] candidateEmails;
    # NIC/Passport values to batch-check against the DB
    string[] candidateNics;
    # EPF values to batch-check against the DB
    string[] candidateEpfs;
|};

# A fully resolved employee with a generated ID and a complete payload ready for DB insertion.
type ResolvedEmployee record {|
    # Auto-generated employee ID
    string employeeId;
    # Complete payload with all reference IDs resolved
    database:CreateEmployeePayload payload;
    # 1-based source row number
    int rowNumber;
|};

# Result of the second pass containing all resolved employees ready for bulk DB insertion.
type BulkPayloadResult record {|
    # Resolved employees with generated IDs and complete payloads
    ResolvedEmployee[] employees;
|};

# Typed record mapped directly from a bulk employee onboarding CSV row.
type BulkEmployeeCsvRow record {|
    # First name
    string firstName = "";
    # Last name
    string lastName = "";
    # Work email
    string workEmail = "";
    # Manager email
    string managerEmail = "";
    # Job designation
    string designation = "";
    # Business unit
    string businessUnit = "";
    # Team
    string team = "";
    # Sub-team
    string subTeam = "";
    # Unit (optional)
    string unit = "";
    # Employment start date (YYYY-MM-DD)
    string startDate = "";
    # Employment type
    string employmentType = "";
    # Company
    string company = "";
    # Work location
    string workLocation = "";
    # Office (optional)
    string office = "";
    # Title
    string title = "";
    # NIC or passport number
    string nicOrPassport = "";
    # Date of birth (YYYY-MM-DD)
    string dob = "";
    # Gender
    string gender = "";
    # Nationality
    string nationality = "";
    # Personal email (optional)
    string personalEmail = "";
    # Personal phone number (optional)
    string personalPhone = "";
    # Resident phone number (optional)
    string residentNumber = "";
    # Address line 1 (optional)
    string addressLine1 = "";
    # Address line 2 (optional)
    string addressLine2 = "";
    # City (optional)
    string city = "";
    # State or province (optional)
    string stateOrProvince = "";
    # Postal code (optional)
    string postalCode = "";
    # Country (optional)
    string country = "";
    # EPF number (optional)
    string epf = "";
    # Secondary job title (optional)
    string secondaryJobTitle = "";
    # Probation end date (YYYY-MM-DD, optional)
    string probationEndDate = "";
    # Agreement end date (YYYY-MM-DD, optional)
    string agreementEndDate = "";
    # Comma-separated additional manager emails (optional)
    string additionalManagerEmails = "";
    # Emergency contact name (optional — mobile and relationship required if provided)
    string emergencyContactName = "";
    # Emergency contact mobile (required when name is provided)
    string emergencyContactMobile = "";
    # Emergency contact relationship (required when name is provided)
    string emergencyContactRelationship = "";
    # Emergency contact telephone (optional)
    string emergencyContactTelephone = "";
|};

# App configuration parameters.
public type AppConfig record {|
    # Whether maintenance mode is enabled
    boolean isMaintenanceMode = false;
|};
