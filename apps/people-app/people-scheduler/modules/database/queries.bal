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

# Fetch Marked leavers whose final day of employment could be over somewhere, with the
# timezone of their work location.
#
# A final day is over once the next day has begun where the employee works. No timezone is
# more than a day ahead of UTC, so every leaver that could be due has a final day on or
# before today in UTC; dueLeavers then keeps those whose day is over locally.
#
# FOR UPDATE locks the rows it reads until the sweep's transaction ends, so they cannot change
# between this read and the update that follows it. Run it inside that transaction.
#
# + return - Query to select employees who may be due to auto-transition to Left
isolated function getExpiredLeaversQuery() returns sql:ParameterizedQuery =>
    `SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.work_email,
        r.final_day_of_employment,
        e.work_location,
        cal.time_zone
    FROM employee e
    JOIN resignation r ON r.employee_id = e.id
    LEFT JOIN companies_allowed_locations cal
        ON cal.company_id = e.company_id AND cal.allowed_location = TRIM(e.work_location)
    WHERE e.employee_status = 'Marked leaver'
        AND r.final_day_of_employment IS NOT NULL
        AND r.final_day_of_employment <= UTC_DATE()
    FOR UPDATE;`;

# Build an SQL IN clause for a list of string values.
#
# + values - List of string values to include in the IN clause
# + return - Parameterized query representing the IN clause
isolated function buildInClause(string[] values) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery clause = ``;
    foreach int i in 0 ..< values.length() {
        clause = i == 0
            ? sql:queryConcat(clause, `${values[i]}`)
            : sql:queryConcat(clause, `, `, `${values[i]}`);
    }
    return clause;
}

# Transition Marked leavers to Left.
#
# The date condition is the candidate window from getExpiredLeaversQuery; which of those are
# actually due is decided per employee before this runs, and passed in as employeeIds.
#
# + actor - System actor performing the update
# + employeeIds - External employee IDs to restrict the update to (the due ones the SELECT found)
# + return - Query to update matching employees' status to Left
isolated function transitionExpiredLeaversQuery(string actor, string[] employeeIds) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery inClause = buildInClause(employeeIds);
    return sql:queryConcat(
        `UPDATE employee e
        JOIN resignation r ON r.employee_id = e.id
        SET e.employee_status = 'Left', e.updated_by = ${actor}
        WHERE e.employee_status = 'Marked leaver'
            AND r.final_day_of_employment IS NOT NULL
            AND r.final_day_of_employment <= UTC_DATE()
            AND e.employee_id IN (`,
        inClause,
        `);`
    );
}

# Fetch New joiners whose start date could have begun somewhere, with the timezone of
# their work location.
#
# Zones ahead of UTC reach a date up to a day before UTC does, so the window runs to
# tomorrow in UTC; dueJoiners then keeps those whose start date has begun locally. FOR UPDATE
# locks the rows for the sweep's transaction, as in getExpiredLeaversQuery.
#
# + return - Query to select employees who may be due to become Active
isolated function getDueNewJoinersQuery() returns sql:ParameterizedQuery =>
    `SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.work_email,
        e.start_date,
        e.work_location,
        cal.time_zone
    FROM employee e
    LEFT JOIN companies_allowed_locations cal
        ON cal.company_id = e.company_id AND cal.allowed_location = TRIM(e.work_location)
    WHERE e.employee_status = 'New joiner'
        AND e.start_date <= UTC_DATE() + INTERVAL 1 DAY
    FOR UPDATE;`;

# Make New joiners Active.
#
# The date condition is the candidate window from getDueNewJoinersQuery; which of those are
# actually due is decided per employee before this runs, and passed in as employeeIds.
#
# + actor - System actor performing the update
# + employeeIds - External employee IDs to restrict the update to (the due ones the SELECT found)
# + return - Query to update matching employees' status to Active
isolated function activateDueNewJoinersQuery(string actor, string[] employeeIds) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery inClause = buildInClause(employeeIds);
    return sql:queryConcat(
        `UPDATE employee e
        SET e.employee_status = 'Active', e.updated_by = ${actor}
        WHERE e.employee_status = 'New joiner'
            AND e.start_date <= UTC_DATE() + INTERVAL 1 DAY
            AND e.employee_id IN (`,
        inClause,
        `);`
    );
}

# Fetch every pending scheduled change whose effective date could have begun somewhere,
# with the timezone of the employee's work location.
#
# Ordered by effective date then id, so two changes to the same employee land in the
# order they were meant to take effect rather than in whatever order they were entered.
#
# Zones ahead of UTC reach a date up to a day before UTC does, so the window runs to
# tomorrow in UTC; dueScheduledChanges then keeps those whose date has begun where the
# employee works, the same reckoning the backend uses to accept the date as a future one.
# UTC_DATE rather than CURDATE so the window does not move with the server's own timezone.
#
# + return - Query returning candidate scheduled_employee_change rows with employee details
isolated function getDueScheduledChangesQuery() returns sql:ParameterizedQuery =>
    `SELECT
        sc.id,
        sc.employee_id AS employee_pk_id,
        e.employee_id,
        pi.first_name,
        pi.last_name,
        DATE_FORMAT(sc.effective_date, '%Y-%m-%d') AS effective_date,
        sc.changes,
        sc.expected,
        sc.created_by,
        e.work_location,
        cal.time_zone
     FROM scheduled_employee_change sc
     INNER JOIN employee e ON e.id = sc.employee_id
     INNER JOIN personal_info pi ON pi.id = e.personal_info_id
     LEFT JOIN companies_allowed_locations cal
        ON cal.company_id = e.company_id AND cal.allowed_location = TRIM(e.work_location)
     WHERE sc.status = 'PENDING'
       AND sc.effective_date <= UTC_DATE() + INTERVAL 1 DAY
     ORDER BY sc.effective_date ASC, sc.id ASC`;

# Move a scheduled change out of PENDING.
#
# Conditional on the row still being PENDING, so a change cancelled between the sweep
# reading it and writing the outcome is not resurrected.
#
# + id - Scheduled change id
# + status - Status to record
# + failureReason - Why it was not applied, where that applies
# + actor - System actor closing the row out
# + return - Query to close out one scheduled change
isolated function closeScheduledChangeQuery(int id, ScheduledChangeStatus status,
        string? failureReason, string actor) returns sql:ParameterizedQuery =>
    `UPDATE scheduled_employee_change
     SET status = ${status},
         applied_on = CASE WHEN ${status} = 'APPLIED' THEN CURRENT_TIMESTAMP(6) ELSE applied_on END,
         failure_reason = ${failureReason},
         updated_by = ${actor}
     WHERE id = ${id}
       AND status = 'PENDING'`;

# Read the columns a scheduled change targets, so they can be compared with what the
# change expected before it is applied.
#
# + employeePkId - Employee table primary key
# + return - Query returning the employee row as a single JSON object
isolated function getEmployeeSnapshotQuery(int employeePkId) returns sql:ParameterizedQuery =>
    `SELECT JSON_OBJECT(
        'epf', epf,
        'company_id', company_id,
        'work_location', work_location,
        'work_email', work_email,
        'start_date', DATE_FORMAT(start_date, '%Y-%m-%d'),
        'secondary_job_title', secondary_job_title,
        'job_role', job_role,
        'external_designation', external_designation,
        'manager_email', manager_email,
        'probation_end_date', DATE_FORMAT(probation_end_date, '%Y-%m-%d'),
        'agreement_end_date', DATE_FORMAT(agreement_end_date, '%Y-%m-%d'),
        'employment_type_id', employment_type_id,
        'designation_id', designation_id,
        'office_id', office_id,
        'team_id', team_id,
        'sub_team_id', sub_team_id,
        'business_unit_id', business_unit_id,
        'unit_id', unit_id,
        'house_id', house_id
     ) AS snapshot
     FROM employee
     WHERE id = ${employeePkId}`;

# Read an employee's active additional managers, lowercased for comparison.
#
# + employeePkId - Employee table primary key
# + return - Query returning one row per active additional manager
isolated function getActiveAdditionalManagersQuery(int employeePkId) returns sql:ParameterizedQuery =>
    `SELECT LOWER(additional_manager_email) AS email
     FROM employee_additional_managers
     WHERE employee_pk_id = ${employeePkId}
       AND is_active = 1`;

# Soft-delete one additional manager, matching the behaviour of an edit made by hand.
#
# + employeePkId - Employee table primary key
# + email - Additional manager email to deactivate
# + actor - System actor performing the update
# + return - Query to deactivate one additional manager
isolated function deactivateAdditionalManagerQuery(int employeePkId, string email, string actor)
    returns sql:ParameterizedQuery =>
    `UPDATE employee_additional_managers
     SET is_active = 0,
         updated_by = ${actor},
         updated_on = CURRENT_TIMESTAMP(6)
     WHERE employee_pk_id = ${employeePkId}
       AND LOWER(additional_manager_email) = LOWER(${email})
       AND is_active = 1`;

# Add one additional manager, or reactivate them if they were removed before.
#
# Removal deactivates the row rather than deleting it, and the unique key spans the
# employee and the email regardless of is_active, so a plain insert fails for anyone who
# has ever held the role. Reinstating somebody who was removed earlier is ordinary, and
# this matches how the employee endpoint writes the same table.
#
# + employeePkId - Employee table primary key
# + email - Additional manager email
# + actor - System actor performing the update
# + return - Query to insert or reactivate one additional manager
isolated function addAdditionalManagerQuery(int employeePkId, string email, string actor)
    returns sql:ParameterizedQuery =>
    `INSERT INTO employee_additional_managers
        (employee_pk_id, additional_manager_email, is_active, created_by, updated_by)
     VALUES (${employeePkId}, ${email}, 1, ${actor}, ${actor})
     ON DUPLICATE KEY UPDATE
        is_active = 1,
        updated_by = ${actor},
        updated_on = CURRENT_TIMESTAMP(6)`;
