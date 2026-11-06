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

import ballerina/http;
import ballerina/time;

# Whether reminders are redirected to the debug recipients (non-production runs).
#
# + return - True when `isDebug` is set
public isolated function isDebugMode() returns boolean => isDebug;

# Check that a debug run has somewhere to send to, so it never falls back to the real recipients.
#
# + return - Error if `isDebug` is set without any `debugRecipients`
public isolated function validateDebugConfig() returns error? {
    if isDebug && debugRecipients.length() == 0 {
        return error("isDebug is true but debugRecipients is empty");
    }
}

# Send the sabbatical reminder to the lead, copying People Operations and the employee.
#
# + details - Reminder details
# + return - Error if the email could not be sent
public isolated function sendSabbaticalReminder(SabbaticalReminderDetails details) returns error? {
    string startDate = formatDisplayDate(details.startDate);
    string endDate = formatDisplayDate(details.endDate);
    string template = check bindKeyValues(sabbaticalReminderTemplate, {
        LEAD_NAME: details.leadName,
        EMPLOYEE_NAME: details.employeeName,
        LEAVE_DURATION: formatDuration(details.durationDays),
        LEAVE_START_DATE: startDate,
        LEAVE_END_DATE: endDate,
        YEAR: time:utcToCivil(time:utcNow()).year.toString()
    });

    EmailPayload payload = {
        to: isDebug ? debugRecipients : [details.leadEmail],
        cc: isDebug ? [] : [...emailServiceConfig.peopleOperationsRecipients, details.employeeEmail],
        'from: emailServiceConfig.'from,
        subject: string `[Leave App] Upcoming Sabbatical Leave Reminder - ${details.employeeName} (${
            startDate} - ${endDate})`,
        template
    };

    http:Response response = check emailClient->/send\-email.post(payload);
    if response.statusCode != http:STATUS_OK {
        return error(string `Email service responded with HTTP ${response.statusCode}`);
    }
}

# Send the approval reminder to the lead, with no CC.
#
# + details - Reminder details
# + return - Error if the email could not be sent
public isolated function sendApprovalReminder(ApprovalReminderDetails details) returns error? {
    string startDate = formatDisplayDate(details.startDate);
    string endDate = formatDisplayDate(details.endDate);
    string template = check bindKeyValues(approvalReminderTemplate, {
        LEAD_NAME: details.leadName,
        EMPLOYEE_NAME: details.employeeName,
        LEAVE_START_DATE: startDate,
        LEAVE_END_DATE: endDate,
        LEAVE_DAYS: formatDays(details.numberOfDays),
        DAYS_WAITING: formatDays(details.daysWaiting),
        START_NOTE: details.hasStarted
            ? "The leave has already started, so please review it as soon as possible."
            : "Please review it before the leave starts.",
        APPROVAL_URL: details.approvalUrl,
        YEAR: time:utcToCivil(time:utcNow()).year.toString()
    });

    EmailPayload payload = {
        to: isDebug ? debugRecipients : [details.leadEmail],
        'from: emailServiceConfig.'from,
        subject: string `[Leave App] Other Authorized Leave Awaiting Your Approval - ${details.employeeName} (${
            startDate} - ${endDate})`,
        template
    };

    http:Response response = check emailClient->/send\-email.post(payload);
    if response.statusCode != http:STATUS_OK {
        return error(string `Email service responded with HTTP ${response.statusCode}`);
    }
}

# Alert People Operations that a pending leave has no lead in HR to approve it: HR has no lead for the employee, or
# no longer has the employee.
#
# + details - Alert details
# + return - Error if the email could not be sent
public isolated function sendNoLeadAlert(NoLeadAlertDetails details) returns error? {
    string startDate = formatDisplayDate(details.startDate);
    string endDate = formatDisplayDate(details.endDate);
    string template = check bindKeyValues(noLeadAlertTemplate, {
        EMPLOYEE_NAME: details.employeeName,
        EMPLOYEE_EMAIL: details.employeeEmail,
        LEAVE_START_DATE: startDate,
        LEAVE_END_DATE: endDate,
        DAYS_WAITING: formatDays(details.daysWaiting),
        YEAR: time:utcToCivil(time:utcNow()).year.toString()
    });

    EmailPayload payload = {
        to: isDebug ? debugRecipients : emailServiceConfig.peopleOperationsRecipients,
        'from: emailServiceConfig.'from,
        subject: string `[Leave App] No Lead in HR to Approve Leave - ${details.employeeName} (${
            startDate} - ${endDate})`,
        template
    };

    http:Response response = check emailClient->/send\-email.post(payload);
    if response.statusCode != http:STATUS_OK {
        return error(string `Email service responded with HTTP ${response.statusCode}`);
    }
}
