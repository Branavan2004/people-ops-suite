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

import ballerina/log;
import ballerina/sql;
import ballerina/time;

# Check the affected row count after an update operation.
#
# + affectedRowCount - Number of rows affected by the update operation
# + return - Error if no rows are updated
isolated function checkAffectedCount(int? affectedRowCount) returns error? {
    if affectedRowCount == 0 || affectedRowCount is () {
        return error("No rows were updated");
    }
    return;
}

# Auto-transition Marked leavers whose final day of employment is over where they work to Left.
#
# The day is over at the local midnight that ends it, in the timezone of the employee's work
# location (see dueLeavers), so the sweep runs often enough to catch each location's midnight.
#
# The due employees are read and updated in one transaction, with their rows locked by the
# read (see getExpiredLeaversQuery). An edit landing between the two, such as a final day
# moved out, therefore waits for the sweep instead of being skipped by the update while still
# appearing in the returned list and so in the summary email.
#
# + actor - System actor performing the update (e.g. "system-scheduler")
# + return - The employees that were transitioned (empty if none were due), or an error
public isolated function transitionExpiredLeavers(string actor) returns LeaverTransition[]|error {
    log:printInfo("Loading employees due for leaver transition");

    time:Utc now = time:utcNow();
    LeaverTransition[] transitions = [];
    transaction {
        stream<LeaverTransition, error?> expiredLeaversStream = databaseClient->query(getExpiredLeaversQuery());
        LeaverTransition[] candidates = check from LeaverTransition transition in expiredLeaversStream
            select transition;
        transitions = dueLeavers(candidates, now);

        log:printInfo("Loaded employees due for leaver transition", count = transitions.length());

        if transitions.length() > 0 {
            string[] employeeIds = from LeaverTransition t in transitions select t.employeeId;
            sql:ExecutionResult executionResult =
                check databaseClient->execute(transitionExpiredLeaversQuery(actor, employeeIds));
            check checkAffectedCount(executionResult.affectedRowCount);
        }
        check commit;
    }

    if transitions.length() > 0 {
        log:printInfo("Marked employees as Left", count = transitions.length());
    }

    return transitions;
}

# Make New joiners whose start date has begun where they work Active.
#
# The date begins at local midnight in the timezone of the employee's work location (see
# dueJoiners), so the sweep runs often enough to catch each location's midnight.
#
# Read and updated in one transaction with the rows locked, for the same reason as
# transitionExpiredLeavers: the list returned for the summary email is exactly what was updated.
#
# + actor - System actor performing the update (e.g. "system-scheduler")
# + return - The employees that were activated (empty if none were due), or an error
public isolated function activateDueNewJoiners(string actor) returns JoinerActivation[]|error {
    log:printInfo("Loading new joiners due for activation");

    time:Utc now = time:utcNow();
    JoinerActivation[] activations = [];
    transaction {
        stream<JoinerActivation, error?> dueJoinersStream = databaseClient->query(getDueNewJoinersQuery());
        JoinerActivation[] candidates = check from JoinerActivation activation in dueJoinersStream
            select activation;
        activations = dueJoiners(candidates, now);

        log:printInfo("Loaded new joiners due for activation", count = activations.length());

        if activations.length() > 0 {
            string[] employeeIds = from JoinerActivation a in activations select a.employeeId;
            sql:ExecutionResult executionResult =
                check databaseClient->execute(activateDueNewJoinersQuery(actor, employeeIds));
            check checkAffectedCount(executionResult.affectedRowCount);
        }
        check commit;
    }

    if activations.length() > 0 {
        log:printInfo("Marked employees as Active", count = activations.length());
    }

    return activations;
}

# Separator between the scheduler and the person whose change it is applying.
#
# The scheduler performs the write, but the decision was someone's: recording only
# "system-scheduler" would leave an audit trail that cannot answer who asked for the
# change. The backend's system-actor check matches on the scheduler prefix, so the
# combined value is still recognised as automation rather than a person acting.
const string ON_BEHALF_OF = " on behalf of ";

# Longest actor an audit column will hold, matching action_by and updated_by.
const int MAX_ACTOR_LENGTH = 254;

# Columns a scheduled change may set, mapped to the name a reader sees.
#
# The allowlist is the security boundary as well as the documentation: the sweep builds
# an UPDATE from whatever keys the stored change carries, so a key that is not here is
# never written. It is enforced again when the change is scheduled, so an unsupported
# field is refused while somebody is present to be told, not silently dropped months
# later.
final readonly & map<string> SCHEDULABLE_COLUMNS = {
    "epf": "EPF",
    "company_id": "Company",
    "work_location": "Work location",
    "work_email": "Work email",
    "start_date": "Start date",
    "secondary_job_title": "Secondary job title",
    "job_role": "Job role",
    "external_designation": "External designation",
    "manager_email": "Lead",
    "probation_end_date": "Probation end date",
    "agreement_end_date": "Agreement end date",
    "employment_type_id": "Employment type",
    "designation_id": "Designation",
    "office_id": "Office",
    "team_id": "Team",
    "sub_team_id": "Sub team",
    "business_unit_id": "Business unit",
    "unit_id": "Unit",
    "house_id": "House"
};

# Key under which a change carries the additional managers it wants the employee to end
# up with. Not a column: it is a separate table, synced rather than assigned.
const string ADDITIONAL_MANAGERS_KEY = "additional_manager_emails";

# Apply every scheduled change whose effective date has begun where the employee works.
#
# The date begins at local midnight in the timezone of the employee's work location (see
# dueScheduledChanges), so the sweep runs often enough to catch each location's midnight.
#
# The employee row is written by a plain UPDATE and the additional managers by the same
# add/deactivate sync an edit made by hand performs, so the audit triggers fire exactly
# as they would for a person's change and the profile history reads the same. The actor
# recorded is the scheduler, which the history already treats as a system actor.
#
# A change is applied only while the fields it targets still hold what they held when it
# was scheduled. A change queued months ahead can be overtaken by someone editing the
# same field directly; applying it regardless would quietly undo that more recent
# decision, so it is marked SUPERSEDED and reported instead.
#
# Each change is committed on its own. One bad row is recorded against itself and the
# sweep continues, rather than holding up everyone else's changes.
#
# + actor - System actor performing the updates (e.g. "system-scheduler")
# + return - What happened to each change that was due, or an error if they could not be read
public isolated function applyDueScheduledChanges(string actor)
    returns ScheduledChangeOutcome[]|error {

    log:printInfo("Loading scheduled changes due for application");

    time:Utc now = time:utcNow();
    stream<ScheduledChange, error?> dueStream = databaseClient->query(getDueScheduledChangesQuery());
    ScheduledChange[] candidates = check from ScheduledChange change in dueStream
        select change;
    ScheduledChange[] due = dueScheduledChanges(candidates, now);

    log:printInfo("Loaded scheduled changes due for application", count = due.length());

    ScheduledChangeOutcome[] outcomes = [];
    foreach ScheduledChange change in due {
        outcomes.push(applyOneScheduledChange(change, actor));
    }
    return outcomes;
}

# Apply a single scheduled change, recording the outcome against its own row.
#
# + change - The due change
# + actor - System actor performing the update
# + return - What happened to it
isolated function applyOneScheduledChange(ScheduledChange change, string actor)
    returns ScheduledChangeOutcome {

    string employeeName = string `${change.firstName} ${change.lastName}`.trim();
    map<json>|error changes = change.changes.cloneWithType();

    if changes is error {
        return closeWith(change, employeeName, [], SCHEDULED_CHANGE_FAILED,
                string `Stored change could not be read: ${changes.message()}`, actor);
    }

    string[] fieldNames = readerFacingNames(changes);

    string?|error supersededBy = findSupersedingField(change.employeePkId, change.expected);
    if supersededBy is error {
        // Left FAILED rather than applied: the check could not run, so whether this
        // change still makes sense is unknown. It surfaces in the summary for somebody
        // to look at instead of being written on an assumption.
        return closeWith(change, employeeName, fieldNames, SCHEDULED_CHANGE_FAILED,
                string `Could not verify the change is still valid: ${supersededBy.message()}`, actor);
    }
    if supersededBy is string {
        return closeWith(change, employeeName, fieldNames, SCHEDULED_CHANGE_SUPERSEDED,
                string `${supersededBy} was changed after this was scheduled`, actor);
    }

    // Attributed to the scheduler acting for whoever scheduled it, so the history names
    // the person accountable for the change rather than only the process that ran it.
    error? applied = writeScheduledChange(change.employeePkId, changes,
            actorOnBehalfOf(actor, change.createdBy));
    if applied is error {
        return closeWith(change, employeeName, fieldNames, SCHEDULED_CHANGE_FAILED,
                applied.message(), actor);
    }

    return closeWith(change, employeeName, fieldNames, SCHEDULED_CHANGE_APPLIED, (), actor);
}

# Write one scheduled change: the employee row, then its additional managers.
#
# Both parts share a transaction, so a change that sets a designation and a set of
# additional leads cannot half-apply and leave the record in a state nobody asked for.
#
# + employeePkId - Employee table primary key
# + changes - Column name to value, plus optionally the additional managers key
# + actor - System actor performing the update
# + return - Error if the write fails
isolated function writeScheduledChange(int employeePkId, map<json> changes, string actor)
    returns error? {

    sql:ParameterizedQuery[] assignments = [];
    foreach string column in changes.keys() {
        if column == ADDITIONAL_MANAGERS_KEY {
            continue;
        }
        sql:ParameterizedQuery? assignment = assignmentFor(column, changes.get(column));
        if assignment is () {
            // Refused at scheduling time, so reaching here means the row was written by
            // something other than the endpoint. Refuse it rather than write a column
            // nobody vetted.
            return error(string `${column} is not a schedulable field`);
        }
        assignments.push(assignment);
    }

    transaction {
        if assignments.length() > 0 {
            sql:ParameterizedQuery updateQuery = `UPDATE employee SET `;
            int index = 0;
            foreach sql:ParameterizedQuery assignment in assignments {
                updateQuery = index == 0
                    ? sql:queryConcat(updateQuery, assignment)
                    : sql:queryConcat(updateQuery, `, `, assignment);
                index += 1;
            }
            updateQuery = sql:queryConcat(updateQuery,
                    `, updated_by = ${actor}, updated_on = CURRENT_TIMESTAMP(6)`,
                    ` WHERE id = ${employeePkId}`);

            sql:ExecutionResult result = check databaseClient->execute(updateQuery);
            check checkAffectedCount(result.affectedRowCount);
        }

        if changes.hasKey(ADDITIONAL_MANAGERS_KEY) {
            check syncAdditionalManagers(employeePkId, changes.get(ADDITIONAL_MANAGERS_KEY), actor);
        }

        check commit;
    }
}

# Build the SET clause for one column.
#
# Each column is written out as a literal in its own branch rather than interpolated
# from the stored key, so a column name can never reach the SQL from data. A key that is
# not a schedulable field returns (), and the caller refuses the change.
#
# + column - Column the change targets
# + value - Value to set
# + return - The SET fragment, or () when the column is not schedulable
isolated function assignmentFor(string column, json value) returns sql:ParameterizedQuery? {
    string? text = value is () ? () : value.toString();
    int? number = value is int ? value : ();

    match column {
        "epf" => { return `epf = ${text}`; }
        "company_id" => { return `company_id = ${number}`; }
        "work_location" => { return `work_location = ${text}`; }
        "work_email" => { return `work_email = ${text}`; }
        "start_date" => { return `start_date = ${text}`; }
        "secondary_job_title" => { return `secondary_job_title = ${text}`; }
        "job_role" => { return `job_role = ${text}`; }
        "external_designation" => { return `external_designation = ${text}`; }
        "manager_email" => { return `manager_email = ${text}`; }
        "probation_end_date" => { return `probation_end_date = ${text}`; }
        "agreement_end_date" => { return `agreement_end_date = ${text}`; }
        "employment_type_id" => { return `employment_type_id = ${number}`; }
        "designation_id" => { return `designation_id = ${number}`; }
        "office_id" => { return `office_id = ${number}`; }
        "team_id" => { return `team_id = ${number}`; }
        "sub_team_id" => { return `sub_team_id = ${number}`; }
        "business_unit_id" => { return `business_unit_id = ${number}`; }
        "unit_id" => { return `unit_id = ${number}`; }
        "house_id" => { return `house_id = ${number}`; }
    }
    return ();
}

# Bring an employee's additional managers to the set a scheduled change asked for.
#
# Mirrors the sync an edit made by hand performs: emails already present are left alone,
# those no longer wanted are deactivated rather than deleted, and comparison is
# case-insensitive so a difference in casing is not read as a change.
#
# + employeePkId - Employee table primary key
# + desired - The additional manager emails the employee should end up with
# + actor - System actor performing the update
# + return - Error if the sync fails
isolated function syncAdditionalManagers(int employeePkId, json desired, string actor) returns error? {
    string[] desiredEmails = [];
    if desired is json[] {
        foreach json entry in desired {
            if entry is string {
                desiredEmails.push(entry.trim());
            }
        }
    }

    stream<record {|string email;|}, error?> currentStream =
        databaseClient->query(getActiveAdditionalManagersQuery(employeePkId));
    string[] currentEmails = check from record {|string email;|} row in currentStream
        select row.email;

    // Both sides keyed lowercase at the comparison itself. The query already lowercases
    // what it returns, but nothing here says so, and a caller that fetched these emails
    // any other way would silently deactivate and re-add every one of them.
    map<string> currentMap = map from string email in currentEmails
        select [email.toLowerAscii(), email];
    map<string> desiredMap = map from string email in desiredEmails
        select [email.toLowerAscii(), email];

    sql:ParameterizedQuery[] deactivations = from string current in currentEmails
        where !desiredMap.hasKey(current.toLowerAscii())
        select deactivateAdditionalManagerQuery(employeePkId, current, actor);
    if deactivations.length() > 0 {
        _ = check databaseClient->batchExecute(deactivations);
    }

    sql:ParameterizedQuery[] additions = from string email in desiredEmails
        where !currentMap.hasKey(email.toLowerAscii())
        select addAdditionalManagerQuery(employeePkId, email, actor);
    if additions.length() > 0 {
        _ = check databaseClient->batchExecute(additions);
    }
}

# The employee's active additional managers, normalised for comparison.
#
# + employeePkId - Employee table primary key
# + return - The distinct emails, lowercased and sorted, or an error
isolated function activeAdditionalManagers(int employeePkId) returns string[]|error {
    stream<record {|string email;|}, error?> currentStream =
        databaseClient->query(getActiveAdditionalManagersQuery(employeePkId));
    string[] emails = check from record {|string email;|} row in currentStream
        select row.email;
    return normalizedEmailSet(emails);
}

# Normalise a set of emails so that only membership matters to a comparison.
#
# Lowercased because these are written and matched case-insensitively, trimmed because the
# scheduled change carries whatever was typed, and sorted because neither the stored order
# nor the order somebody entered them says anything about the set. Without this,
# reordering two leads would read as somebody else's edit and supersede the change.
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

# Find the first targeted field that has moved on from what the change expected.
#
# Returns an error when the comparison could not be made at all, which the caller treats
# as a reason not to apply. "Could not check" is not "nothing has changed": a database
# hiccup on the day, or an expectation that was never captured, would otherwise wave the
# change through at exactly the moment this check exists for, quietly overwriting a more
# recent decision with nobody watching.
#
# + employeePkId - Employee table primary key
# + expected - What the targeted fields held when the change was scheduled
# + return - Reader-facing name of the first field that no longer matches, () when every
# field still holds what was expected, or an error when the comparison could not be made
isolated function findSupersedingField(int employeePkId, json expected)
    returns string?|error {

    map<json>|error expectedFields = expected.cloneWithType();
    if expectedFields is error {
        return error("the expected values recorded with this change could not be read");
    }
    if expectedFields.length() == 0 {
        // Written when the change was scheduled and empty ever since, which means the
        // snapshot was never captured rather than that there is nothing to compare.
        // Applying on that basis is the overwrite this check exists to prevent.
        return error("no expected values were recorded when this change was scheduled");
    }

    record {|json snapshot;|}|error row = databaseClient->queryRow(getEmployeeSnapshotQuery(employeePkId));
    if row is error {
        return error(string `the employee's current values could not be read: ${row.message()}`);
    }

    json|error parsed = row.snapshot is string ? (<string>row.snapshot).fromJsonString() : row.snapshot;
    if parsed is error {
        return error(string `the employee's current values could not be parsed: ${parsed.message()}`);
    }
    map<json>|error current = parsed.cloneWithType();
    if current is error {
        return error(string `the employee's current values could not be read: ${current.message()}`);
    }

    foreach string column in expectedFields.keys() {
        // Additional managers are a set in their own table, not a column on the snapshot
        // above, so they are read and compared as a set. Membership is what matters:
        // both sides are lowercased and sorted, since the sweep writes them
        // case-insensitively and neither side's ordering means anything.
        if column == ADDITIONAL_MANAGERS_KEY {
            string[]|error currentManagers = activeAdditionalManagers(employeePkId);
            if currentManagers is error {
                return error(string `the employee's additional leads could not be read: ${
                    currentManagers.message()}`);
            }
            string[] expectedManagers = normalizedEmailSet(expectedFields.get(column));
            if expectedManagers.toString() != currentManagers.toString() {
                return "Additional leads";
            }
            continue;
        }
        json expectedValue = expectedFields.get(column);
        json currentValue = current.hasKey(column) ? current.get(column) : ();
        if expectedValue.toString() != currentValue.toString() {
            return SCHEDULABLE_COLUMNS.hasKey(column)
                ? SCHEDULABLE_COLUMNS.get(column)
                : column;
        }
    }
    return ();
}

# The actor to record for a scheduled change: the scheduler, and who scheduled it.
#
# This records who asked for the change, not whether they may still make it. Authority
# is checked when the change is scheduled and deliberately not re-checked here: the
# decision was validly made then, and a promotion agreed in October is still owed to the
# employee if the person who entered it has since changed roles or left. The sweep also
# has no route to IAM group membership — it runs as a scheduled task with no user
# identity, which is the same reason it writes to the database rather than calling the
# API.
#
# The consequence worth knowing: a change queued by somebody who later loses the role
# still applies. Cancelling it is a person's job, and the pending change is visible on
# the employee's profile for exactly that.
#
# + actor - System actor running the sweep
# + requestedBy - Email of the person who scheduled the change
# + return - Combined actor, truncated to what the audit columns accept
isolated function actorOnBehalfOf(string actor, string requestedBy) returns string {
    if requestedBy.trim().length() == 0 {
        return actor;
    }
    string combined = actor + ON_BEHALF_OF + requestedBy.trim();
    return combined.length() > MAX_ACTOR_LENGTH
        ? combined.substring(0, MAX_ACTOR_LENGTH)
        : combined;
}

# Reader-facing names of the fields a change sets, for the summary email.
#
# + changes - Column name to value
# + return - The names a reader recognises, in the order the columns appear
isolated function readerFacingNames(map<json> changes) returns string[] {
    string[] names = [];
    foreach string column in changes.keys() {
        if column == ADDITIONAL_MANAGERS_KEY {
            names.push("Additional leads");
        } else if SCHEDULABLE_COLUMNS.hasKey(column) {
            names.push(SCHEDULABLE_COLUMNS.get(column));
        }
    }
    return names;
}

# Close a scheduled change out and describe what happened to it.
#
# + change - The change being closed
# + employeeName - Employee's full name, for the summary
# + fields - Reader-facing names of the fields it set
# + status - Status to record
# + failureReason - Why it was not applied, where that applies
# + actor - System actor closing the row out
# + return - The outcome to report
isolated function closeWith(ScheduledChange change, string employeeName, string[] fields,
        ScheduledChangeStatus status, string? failureReason, string actor)
    returns ScheduledChangeOutcome {

    sql:ExecutionResult|error closed = databaseClient->execute(
            closeScheduledChangeQuery(change.id, status, failureReason, actor));

    // The employee record is already written by the time this runs, so a close-out that
    // does not land leaves the row PENDING against a record that has moved. Tomorrow's
    // sweep then compares against `expected`, finds the field changed — by this run —
    // and reports SUPERSEDED for a change that actually applied. Reporting it here is
    // all that can be done about the inconsistency, but it is what puts it in front of
    // somebody instead of in a log nobody reads.
    // Only the APPLIED path has written to the employee record; the others are reporting
    // that nothing was written. Saying "the change was applied" regardless would describe
    // a superseded or failed change as having taken effect, which is the opposite of what
    // happened — and four of the five call sites pass a status other than APPLIED.
    string outcome = status == SCHEDULED_CHANGE_APPLIED
        ? "the change was applied"
        : string `the change was not applied (${status.toLowerAscii()})`;

    string? closeFailure = ();
    if closed is error {
        log:printError("Failed to record the outcome of a scheduled change",
                closed, id = change.id, status = status);
        closeFailure = string `${outcome} but could not be recorded as such: ${closed.message()}`;
    } else if closed.affectedRowCount == 0 {
        // Nothing to close: the row was cancelled while this sweep was working on it.
        log:printWarn("Scheduled change was no longer pending when its outcome was recorded",
                id = change.id, status = status);
        closeFailure = string `${outcome} but its row was no longer pending`;
    }

    // The reason the change did not apply is worth more to a reader than the close-out
    // problem alone, so it is carried alongside rather than replaced by it.
    if closeFailure is string && failureReason is string {
        closeFailure = string `${failureReason}; ${closeFailure}`;
    }

    return {
        id: change.id,
        employeeId: change.employeeId,
        employeeName,
        effectiveDate: change.effectiveDate,
        status: closeFailure is string ? SCHEDULED_CHANGE_FAILED : status,
        failureReason: closeFailure ?: failureReason,
        fields,
        workLocation: change.workLocation,
        timeZone: change.timeZone
    };
}
