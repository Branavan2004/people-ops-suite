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

import leave_scheduler.database;
import leave_scheduler.dates;
import leave_scheduler.email;
import leave_scheduler.employee;

import ballerina/log;
import ballerina/time;

# How many days before a sabbatical starts its lead is reminded.
configurable int sabbaticalReminderLeadTimeInDays = 28;

# How many days after submission a pending Other Authorized Leave gets its first approval reminder (at least 1).
configurable int approvalReminderFirstDelayInDays = ?;

# How many days after a reminder a still-pending Other Authorized Leave gets the next one (at least 1).
configurable int approvalReminderIntervalInDays = ?;

# How many days after a leave ends its sick note is deleted (at least 1).
configurable int sickNoteRetentionInDays = ?;

# Leave App page where a lead approves leaves; linked from the approval reminder.
configurable string approvalPageUrl = ?;

# Run the sabbatical reminder job: email the employee's current lead (from the HR entity service) about every
# approved sabbatical leave starting within the reminder window that has not had its reminder yet, then record
# the reminder as sent. One failed leave does not stop the others; the job reports an error at the end so the
# run visibly shows as failed, and the failed leaves are retried on the next run.
#
# + return - Error if the leaves could not be read, or if any reminder failed
function runSabbaticalReminder() returns error? {
    time:Utc now = time:utcNow();
    string today = time:utcToString(now).substring(0, 10);
    string windowEnd = time:utcToString(
            time:utcAddSeconds(now, <decimal>sabbaticalReminderLeadTimeInDays * 86400d)).substring(0, 10);
    log:printInfo("Sabbatical reminder run started", today = today, windowEnd = windowEnd,
            isDebug = email:isDebugMode());

    database:SabbaticalReminder[] reminders = check database:getDueSabbaticalReminders(today, windowEnd);
    log:printInfo("Sabbatical leaves due for a reminder", count = reminders.length());

    int failed = 0;
    foreach database:SabbaticalReminder reminder in reminders {
        error? result = sendReminder(reminder);
        if result is error {
            failed += 1;
            log:printError("Failed to send sabbatical reminder", result, leaveId = reminder.id);
        }
    }

    log:printInfo("Sabbatical reminder run completed", sent = reminders.length() - failed, failed = failed);
    if failed > 0 {
        return error(string `${failed} sabbatical reminder(s) failed — see logs for details`);
    }
}

# Send the reminder for one sabbatical leave and record it as sent.
#
# + reminder - Leave due for a reminder
# + return - Error if the email could not be sent or recorded
function sendReminder(database:SabbaticalReminder reminder) returns error? {
    employee:Employee|error employeeInfo = employee:getEmployee(reminder.email);
    if employeeInfo is error {
        log:printWarn("Could not fetch the employee from HR, using the approving lead and the email as name",
                employeeInfo, leaveId = reminder.id);
    }
    string employeeName = employeeInfo is employee:Employee
        ? employee:fullName(employeeInfo, reminder.email) : reminder.email;

    // The reminder goes to the employee's current lead in HR; the lead who approved the leave is the
    // fallback when HR has no lead on record.
    string? hrLeadEmail = employeeInfo is employee:Employee ? employee:leadEmail(employeeInfo) : ();
    // A blank approver counts as none, like a blank HR lead.
    string? approverEmail = reminder.approverEmail;
    string? approvingLeadEmail = approverEmail is string && approverEmail.trim() != "" ? approverEmail.trim() : ();
    string? leadEmail = hrLeadEmail ?: approvingLeadEmail;
    if leadEmail is () {
        return error("No lead in HR and no approving lead recorded for the leave");
    }
    if hrLeadEmail is () && employeeInfo is employee:Employee {
        log:printWarn("No lead recorded in HR, using the approving lead", leaveId = reminder.id);
    }

    employee:Employee|error leadInfo = employee:getEmployee(leadEmail);
    if leadInfo is error {
        log:printWarn("Could not fetch the lead from HR, greeting them by email", leadInfo,
                leaveId = reminder.id);
    }

    check email:sendSabbaticalReminder({
        employeeName,
        employeeEmail: reminder.email,
        leadEmail,
        leadName: leadInfo is employee:Employee ? employee:firstName(leadInfo, leadEmail) : leadEmail,
        startDate: reminder.startDate,
        endDate: reminder.endDate,
        durationDays: reminder.durationDays
    });
    // A debug run only reaches the debug recipients, so it must not use up the real reminder.
    boolean isDebugMode = email:isDebugMode();
    if isDebugMode {
        log:printInfo("Debug mode: sabbatical reminder sent to debug recipients, not marked as sent",
                leaveId = reminder.id);
        return;
    }
    check database:markSabbaticalReminderSent(reminder.id);
    log:printInfo("Sabbatical reminder sent", leaveId = reminder.id);
}

# Run the approval reminder job: remind the applicant's current lead (from the HR entity service) about every
# Other Authorized Leave still pending approval, first once it has waited `approvalReminderFirstDelayInDays`
# and then every `approvalReminderIntervalInDays`, recording each reminder as sent. One failed leave does not
# stop the others; the job reports an error at the end so the run visibly shows as failed, and the failed
# leaves are retried on the next run.
#
# + return - Error if the settings are invalid, the leaves could not be read, or any reminder failed
function runApprovalReminder() returns error? {
    check dates:requireAtLeastOne("approvalReminderFirstDelayInDays", approvalReminderFirstDelayInDays);
    check dates:requireAtLeastOne("approvalReminderIntervalInDays", approvalReminderIntervalInDays);
    if approvalPageUrl.trim() == "" {
        return error("approvalPageUrl must be set");
    }

    string today = time:utcToString(time:utcNow()).substring(0, 10);
    string firstCutoff = check dates:subtractDays(today, approvalReminderFirstDelayInDays);
    string repeatCutoff = check dates:subtractDays(today, approvalReminderIntervalInDays);
    log:printInfo("Approval reminder run started", today = today, firstCutoff = firstCutoff,
            repeatCutoff = repeatCutoff, isDebug = email:isDebugMode());

    database:ApprovalReminder[] reminders = check database:getDueApprovalReminders(firstCutoff, repeatCutoff);
    log:printInfo("Pending leaves due for an approval reminder", count = reminders.length());

    int failed = 0;
    foreach database:ApprovalReminder reminder in reminders {
        error? result = sendApprovalReminderFor(reminder, today);
        if result is error {
            failed += 1;
            log:printError("Failed to send approval reminder", result, leaveId = reminder.id);
        }
    }

    log:printInfo("Approval reminder run completed", sent = reminders.length() - failed, failed = failed);
    if failed > 0 {
        return error(string `${failed} approval reminder(s) failed — see logs for details`);
    }
}

# Send the approval reminder for one pending leave and record it as sent. The reminder goes only to the
# applicant's current lead in HR; when HR has no lead for the applicant, or no longer has the applicant (for
# example after they left), People Operations is alerted instead.
#
# + reminder - Leave due for a reminder
# + today - Today's date (yyyy-mm-dd)
# + return - Error if HR could not be reached, or the email could not be sent or recorded
function sendApprovalReminderFor(database:ApprovalReminder reminder, string today) returns error? {
    // Without HR there is no way to tell the current lead (the lead recorded on the leave may no longer be
    // one), so an HR error fails the leave and it is retried on the next run. An applicant HR no longer has is
    // treated like one with no lead, so the alert reaches People Operations instead of failing every run.
    employee:Employee|error employeeInfo = employee:getEmployee(reminder.email);
    if employeeInfo is error && employeeInfo !is employee:EmployeeNotFoundError {
        return employeeInfo;
    }
    string employeeName = employeeInfo is employee:Employee
        ? employee:fullName(employeeInfo, reminder.email) : reminder.email;
    int daysWaiting = check dates:daysBetween(reminder.createdOn, today);

    string? leadEmail = employeeInfo is employee:Employee ? employee:leadEmail(employeeInfo) : ();
    if leadEmail is () {
        log:printWarn(employeeInfo is employee:Employee
                ? "No lead recorded in HR, alerting People Operations"
                : "Employee not found in HR, alerting People Operations", leaveId = reminder.id);
        check email:sendNoLeadAlert({
            employeeName,
            employeeEmail: reminder.email,
            startDate: reminder.startDate,
            endDate: reminder.endDate,
            daysWaiting
        });
    } else {
        employee:Employee|error leadInfo = employee:getEmployee(leadEmail);
        if leadInfo is error {
            log:printWarn("Could not fetch the lead from HR, greeting them by email", leadInfo,
                    leaveId = reminder.id);
        }
        check email:sendApprovalReminder({
            employeeName,
            leadEmail,
            leadName: leadInfo is employee:Employee ? employee:firstName(leadInfo, leadEmail) : leadEmail,
            startDate: reminder.startDate,
            endDate: reminder.endDate,
            numberOfDays: reminder.numberOfDays,
            daysWaiting,
            hasStarted: reminder.startDate <= today,
            approvalUrl: approvalPageUrl
        });
    }

    // A debug run only reaches the debug recipients, so it must not use up the real reminder.
    boolean isDebugMode = email:isDebugMode();
    if isDebugMode {
        log:printInfo("Debug mode: approval reminder sent to debug recipients, not marked as sent",
                leaveId = reminder.id);
        return;
    }
    check database:markApprovalReminderSent(reminder.id);
    log:printInfo("Approval reminder sent", leaveId = reminder.id);
}

# Run the sick note retention job: clear the encrypted content of sick notes whose leave ended more than
# `sickNoteRetentionInDays` days ago, and of cancelled leaves. The rows are kept so the history can still say a
# note was provided and deleted. The job never needs the encryption key. Debug mode does not skip the deletion.
#
# + return - Error if the setting is invalid or the sick notes could not be cleared
function runSickNoteRetention() returns error? {
    check dates:requireAtLeastOne("sickNoteRetentionInDays", sickNoteRetentionInDays);

    string today = time:utcToString(time:utcNow()).substring(0, 10);
    string endedBefore = check dates:subtractDays(today, sickNoteRetentionInDays);
    log:printInfo("Sick note retention run started", today = today, endedBefore = endedBefore);

    int deleted = check database:deleteExpiredSickNotes(endedBefore);
    log:printInfo("Sick note retention run completed", deleted = deleted);
}
