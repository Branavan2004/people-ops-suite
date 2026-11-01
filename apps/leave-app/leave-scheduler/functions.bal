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
import leave_scheduler.email;
import leave_scheduler.employee;

import ballerina/log;
import ballerina/time;

# How many days before a sabbatical starts its lead is reminded.
configurable int sabbaticalReminderLeadTimeInDays = 28;

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
