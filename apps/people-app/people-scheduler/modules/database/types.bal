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

import ballerina/sql;

# [Configurable] People Ops database configs.
type DatabaseConfig record {|
    # User of the database
    string user;
    # Password of the database
    string password;
    # Name of the database
    string database;
    # Host of the database
    string host;
    # Port of the database
    int port;
    # Maximum number of open connections
    int maxOpenConnections;
    # Maximum lifetime of a connection
    decimal maxConnectionLifeTime;
    # Minimum number of open connections
    int minIdleConnections;
|};

# Row mapping for an employee whose Marked-leaver period has ended and who should transition to Left.
public type LeaverTransition record {|
    # External employee ID
    @sql:Column {name: "employee_id"}
    string employeeId;
    # First name
    @sql:Column {name: "first_name"}
    string firstName;
    # Last name
    @sql:Column {name: "last_name"}
    string lastName;
    # Work email
    @sql:Column {name: "work_email"}
    string workEmail;
    # Final day of employment
    @sql:Column {name: "final_day_of_employment"}
    string finalDayOfEmployment;
    # Work location, as stored on the employee
    @sql:Column {name: "work_location"}
    string workLocation;
    # Timezone of their work location, or nil when the location has none on record
    @sql:Column {name: "time_zone"}
    string? timeZone;
|};

# Row mapping for a New joiner whose start date has arrived and who should become Active.
public type JoinerActivation record {|
    # External employee ID
    @sql:Column {name: "employee_id"}
    string employeeId;
    # First name
    @sql:Column {name: "first_name"}
    string firstName;
    # Last name
    @sql:Column {name: "last_name"}
    string lastName;
    # Work email; the future-joiner placeholder when the account is still to be created
    @sql:Column {name: "work_email"}
    string workEmail;
    # Start date
    @sql:Column {name: "start_date"}
    string startDate;
    # Work location, as stored on the employee
    @sql:Column {name: "work_location"}
    string workLocation;
    # Timezone of their work location, or nil when the location has none on record
    @sql:Column {name: "time_zone"}
    string? timeZone;
|};

# A change to an employee's general information waiting for its effective date.
public type ScheduledChange record {|
    # Scheduled change id
    int id;
    # Employee table primary key the change applies to
    @sql:Column {name: "employee_pk_id"}
    int employeePkId;
    # External employee ID
    @sql:Column {name: "employee_id"}
    string employeeId;
    # First name
    @sql:Column {name: "first_name"}
    string firstName;
    # Last name
    @sql:Column {name: "last_name"}
    string lastName;
    # Date the change takes effect
    @sql:Column {name: "effective_date"}
    string effectiveDate;
    # Fields being changed, as column-name to value
    json changes;
    # What those same fields held when the change was scheduled
    json expected;
    # Who scheduled it
    @sql:Column {name: "created_by"}
    string createdBy;
    # Work location, as stored on the employee
    @sql:Column {name: "work_location"}
    string workLocation;
    # Timezone of the employee's work location, or nil when the location has none on record
    @sql:Column {name: "time_zone"}
    string? timeZone;
|};

# What the sweep did with one scheduled change, for the run's summary.
# Status a scheduled change is closed out with.
#
# Mirrors the status column's MySQL ENUM and the backend's ScheduledChangeStatus. Declared
# here rather than shared because people-scheduler is a separate deployable with its own
# database module; the values are fixed by the column both packages write.
public enum ScheduledChangeStatus {
    SCHEDULED_CHANGE_APPLIED = "APPLIED",
    SCHEDULED_CHANGE_SUPERSEDED = "SUPERSEDED",
    SCHEDULED_CHANGE_FAILED = "FAILED"
}

public type ScheduledChangeOutcome record {|
    # Scheduled change id
    int id;
    # External employee ID
    string employeeId;
    # Employee's full name
    string employeeName;
    # Date the change was due
    string effectiveDate;
    # Applied, superseded or failed
    ScheduledChangeStatus status;
    # Why it was not applied, where that applies
    string? failureReason;
    # Reader-facing names of the fields the change set
    string[] fields;
    # Employee's work location
    string workLocation;
    # Timezone of the work location, or nil when the location has none on record
    string? timeZone;
|};
