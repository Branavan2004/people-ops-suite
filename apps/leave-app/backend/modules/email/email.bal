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
import leave_service.database;
import leave_service.employee;

import ballerina/http;
import ballerina/log;

configurable boolean isDebug = false;
configurable boolean emailNotificationsEnabled = false;
configurable string[] debugRecipients = ?;
configurable EmailServiceConfig emailServiceConfig = ?;
configurable string additionalCommentTemplate = ?;
final string appName = isDebug ? APP_NAME_DEV : APP_NAME;

# Send an email alert of given type with the given body to the given recipients.
#
# + alertHeader - Descriptive header of the alert
# + subject - Email subject
# + body - Email body
# + recipients - Email recipients
# + template - Email template (Base64 encoded HTML content).
# + return - Error if sending the email fails
public isolated function processEmailNotification(string alertHeader, string subject, map<string> body,
        string[] recipients, string? template = ()) returns error? {

    if !emailNotificationsEnabled {
        log:printInfo("Email notifications are disabled. Skipping the email alert.");
        return;
    }

    string[] to = isDebug ? debugRecipients : getValidEmailRecipientsFromList(recipients);

    // Build HTML email content
    string htmlContent = string `
        <html>
            <body>
                <p>${body.get("CONTENT")}</p>
                <p><i>***This is a system-generated email***</i></p>
            </body>
        </html>
    `;

    // Base64 encode the HTML content
    string encodedTemplate;
    if template is () {
        encodedTemplate = htmlContent.toBytes().toBase64();
    } else {
        encodedTemplate = template;
    }

    json payload = {
        template: encodedTemplate,
        'from: emailServiceConfig.emailFrom,
        to: to,
        subject
    };

    // Retries email sending 3 times
    retry transaction {
        json|error alertResult = emailClient->/send\-email.post(payload);
        if alertResult is error {
            string errBody = alertResult is http:ApplicationResponseError ?
                alertResult.detail().body.toString() : alertResult.message();
            fail error error:Retriable(string `Failed to send ${alertHeader} alert to ${
                string:'join(", ", ...to)}: ${errBody}`);
        }

        check commit;

    } on fail error err {
        log:printError(err.message());
        return err;
    }
    log:printInfo(string `Successfully sent the email notification to ${string:'join(", ", ...to)}.`);
}

# Send an email alert to the given recipients when a leave is submitted or cancelled.
#
# + details - EmailNotificationDetails record
# + emailRecipients - Email recipients
# + return - Error if sending the email fails
public isolated function sendLeaveNotification(EmailNotificationDetails details, string[] emailRecipients)
    returns error? {

    map<string> body = {
        APP_NAME: appName,
        ALERT_TYPE: ALERT_HEADER,
        CONTENT: details.body
    };
    check processEmailNotification(ALERT_HEADER, details.subject, body, emailRecipients);
}

# Send an email alert to the given recipients when an additional comment is added to a leave.
#
# + details - EmailNotificationDetails record
# + emailRecipients - Email recipients
# + return - Error if sending the email fails
public isolated function sendAdditionalComment(EmailNotificationDetails details, string[] emailRecipients)
    returns error? {

    map<string> body = {
        APP_NAME: appName,
        ALERT_TYPE: ALERT_HEADER,
        CONTENT: details.body
    };
    check processEmailNotification(ALERT_HEADER, details.subject, body, emailRecipients);
}

# Generate the email content for a leave.
#
# + token - JWT token
# + employeeEmail - Employee email
# + leave - Leave entity
# + isCancel - Whether the leave is cancelled
# + isPastLeave - Whether the leave is in the past
# + emailSubject - Email subject
# + return - EmailNotificationDetails record
public isolated function generateContentForLeave(string token, string employeeEmail, LeaveResponse|LeavePayload leave,
        boolean isCancel = false, boolean isPastLeave = false, string? emailSubject = ()
        ) returns readonly & EmailNotificationDetails|error {

    EmailNotificationDetails notificationDetails;
    string startDateString = getEmailDateStringFromTimestamp(leave.startDate);
    string? firstName = ();
    string? lastName = ();
    Employee|error? employee = employee:getEmployee(employeeEmail);
    if employee is error {
        return employee;
    }
    if employee is Employee {
        firstName = employee.firstName;
        lastName = employee.lastName;
    }
    string employeeName = firstName is string ? string `${firstName} ${lastName ?: ""}` : employeeEmail;
    match leave.periodType {
        database:ONE_DAY_LEAVE => {
            notificationDetails = generateContentForOneDayLeave(
                    employeeName,
                    isCancel,
                    leave.leaveType,
                    startDateString,
                    isPastLeave,
                    emailSubject
            );
        }
        database:HALF_DAY_LEAVE => {
            boolean? isMorningLeave = leave.isMorningLeave;
            if isMorningLeave is () {
                log:printError("Leave in invalid state at generateContentForLeave. isMorningLeave is not set for the Leave!");
                return error("isMorningLeave is not set for the leave");
            }
            notificationDetails = generateContentForHalfDayLeave(
                    employeeName,
                    isCancel,
                    leave.leaveType,
                    startDateString,
                    leave.isMorningLeave ?: false,
                    isPastLeave,
                    emailSubject
            );
        }
        _ => {
            string endDateString = getEmailDateStringFromTimestamp(leave.endDate);
            notificationDetails = generateContentForMultipleDaysLeave(employeeName, isCancel, leave.leaveType, startDateString, endDateString, isPastLeave, emailSubject);
        }
    }

    return notificationDetails.cloneReadOnly();
}

# Generate the email content for a half day leave.
#
# + employeeName - Employee name
# + isCancel - Whether the leave is cancelled
# + leaveType - Leave type
# + date - Leave date
# + isMorningHalf - Whether the leave is for the morning half
# + isPastLeave - Whether the leave is in the past
# + emailSubject - Email subject
# + return - EmailNotificationDetails record
isolated function generateContentForHalfDayLeave(string employeeName, boolean isCancel, string leaveType, string date,
        boolean isMorningHalf, boolean isPastLeave, string? emailSubject = ()) returns EmailNotificationDetails {

    string subject = emailSubject ?: getPrefixedEmailSubject(
            string `${employeeName} ${isPastLeave ? "was" : "is"} on half-day ${leaveType is database:LIEU_LEAVE ? string `${database:LIEU_LEAVE} ` : ""}leave (${isMorningHalf ? "first" : "second"} half) on ${date}`);
    string body = !isCancel ?
        (string `
            <p>
                Hi All,
                <br/>
                Please note that ${employeeName} ${isPastLeave ? "was" : "will be"} on half-day ${leaveType is database:LIEU_LEAVE ? string `${database:LIEU_LEAVE} ` : ""}leave (${isMorningHalf ? "first" : "second"} half) on ${date}.
            <p>
        `)
        :
        (string `
            <p>
                Hi All,
                <br/>
                Please note that ${employeeName} has cancelled the half-day ${leaveType is database:LIEU_LEAVE ? string `${database:LIEU_LEAVE} ` : ""}leave applied for ${date}.
            <p>
        `);

    return {
        subject,
        body
    };
};

# Generate the email content for a one day leave.
#
# + employeeName - Employee name
# + isCancel - Whether the leave is cancelled
# + leaveType - Leave type
# + date - Leave date
# + isPastLeave - Whether the leave is in the past
# + emailSubject - Email subject
# + return - EmailNotificationDetails record
isolated function generateContentForOneDayLeave(string employeeName, boolean isCancel, string leaveType, string date,
        boolean isPastLeave, string? emailSubject = ()) returns EmailNotificationDetails {

    string subject = emailSubject ?: getPrefixedEmailSubject(
            string `${employeeName} ${isPastLeave ? "was" : "will be"} on ${leaveType is database:LIEU_LEAVE ? string `${database:LIEU_LEAVE} ` : ""}leave on ${date}`);
    string body = !isCancel ?
        (string `
            <p>
                Hi All,
                <br/>
                Please note that ${employeeName} ${isPastLeave ? "was" : "will be"} on ${leaveType is database:LIEU_LEAVE ? string `${database:LIEU_LEAVE} ` : ""}leave on ${date}.
            <p>
        `)
        :
        (string `
            <p>
                Hi All,
                <br/>
                Please note that ${employeeName} has cancelled the ${leaveType is database:LIEU_LEAVE ? string `${database:LIEU_LEAVE} ` : ""}leave applied for ${date}.
            <p>
        `);
    return {
        subject,
        body
    };
};

# Generate the email content for a multiple days leave.
#
# + employeeName - Employee name
# + isCancel - Whether the leave is cancelled
# + leaveType - Leave type
# + fromDate - Leave start date
# + toDate - Leave end date
# + isPastLeave - Whether the leave is in the past
# + emailSubject - Email subject
# + return - EmailNotificationDetails record
isolated function generateContentForMultipleDaysLeave(string employeeName, boolean isCancel, string leaveType,
        string fromDate, string toDate, boolean isPastLeave, string? emailSubject = ())
        returns EmailNotificationDetails {

    string subject = emailSubject ?: getPrefixedEmailSubject(string `${employeeName} ${isPastLeave ? "was" : "will be"} on ${leaveType is database:LIEU_LEAVE ? string `${database:LIEU_LEAVE} ` : ""}leave from ${fromDate} to ${toDate}`);
    string body = !isCancel ?
        (string `
            <p>
                Hi All,
                <br/>
                Please note that ${employeeName} ${isPastLeave ? "was" : "will be"} on ${leaveType is database:LIEU_LEAVE ? string `${database:LIEU_LEAVE} ` : ""}leave from ${fromDate} to ${toDate}.
            <p>
        `)
        :
        (string `
            <p>
                Hi All,
                <br/>
                Please note that ${employeeName} has cancelled the ${leaveType is database:LIEU_LEAVE ? string `${database:LIEU_LEAVE} ` : ""}leave applied from ${fromDate} to ${toDate}.
            <p>
        `);
    return {
        subject,
        body
    };
}

# Generate the email content for an additional comment.
#
# + subject - Email subject
# + additionalComment - Additional comment
# + return - EmailNotificationDetails record
public isolated function generateContentForAdditionalComment(string subject, string additionalComment)
    returns EmailNotificationDetails {

    string body = string `
            <p>
                Additional Comment: ${additionalComment}
            <p>
        `;
    return {
        subject,
        body
    };
}

# Generate the email content asking the reporting lead to approve an Other Authorized Leave request.
#
# + employeeName - Name of the applicant
# + startDate - Leave start date (ISO 8601)
# + endDate - Leave end date (ISO 8601)
# + numberOfDays - Number of working days requested
# + comment - Comment from the applicant, if any
# + approvalUrl - Link to the page where the lead approves or rejects the request
# + return - EmailNotificationDetails record
public isolated function approvalRequestContent(string employeeName, string startDate, string endDate,
        float numberOfDays, string? comment, string approvalUrl) returns EmailNotificationDetails {

    string period = getEmailLeavePeriod(startDate, endDate);
    string workingDays = getWorkingDaysText(numberOfDays);
    string commentLine = comment is string && comment.trim().length() > 0
        ? string `<br/><br/>Comment: ${escapeHtml(comment)}`
        : "";
    return {
        subject: getPrefixedEmailSubject(
                string `Approval requested: ${employeeName}'s Other Authorized Leave ${period}`),
        body: string `
            <p>
                Hi,
                <br/><br/>
                ${escapeHtml(employeeName)} has requested Other Authorized Leave ${period} (${workingDays}).
                The request is waiting for the reporting lead's approval.${commentLine}
                <br/><br/>
                The reporting lead can approve or reject the request in the Leave App:
                <a href="${approvalUrl}">${approvalUrl}</a>
            </p>
        `
    };
}

# Generate the email content telling the applicant that their Other Authorized Leave request was rejected.
#
# + employeeName - Name of the applicant
# + startDate - Leave start date (ISO 8601)
# + endDate - Leave end date (ISO 8601)
# + reason - Reason given by the reporting lead
# + return - EmailNotificationDetails record
public isolated function rejectionContent(string employeeName, string startDate, string endDate, string reason)
    returns EmailNotificationDetails {

    string period = getEmailLeavePeriod(startDate, endDate);
    return {
        subject: getPrefixedEmailSubject(string `Rejected: ${employeeName}'s Other Authorized Leave ${period}`),
        body: string `
            <p>
                Hi,
                <br/><br/>
                The Other Authorized Leave request of ${escapeHtml(employeeName)} ${period} has been rejected
                by the reporting lead.
                <br/><br/>
                Reason: ${escapeHtml(reason)}
            </p>
        `
    };
}

# Generate the email content telling the applicant and the reporting lead that a pending Other Authorized Leave
# request was withdrawn. The wording does not say who cancelled it, as People Operations may cancel it too.
#
# + employeeName - Name of the applicant
# + startDate - Leave start date (ISO 8601)
# + endDate - Leave end date (ISO 8601)
# + return - EmailNotificationDetails record
public isolated function withdrawalContent(string employeeName, string startDate, string endDate)
    returns EmailNotificationDetails {

    string period = getEmailLeavePeriod(startDate, endDate);
    return {
        subject: getPrefixedEmailSubject(string `Withdrawn: ${employeeName}'s Other Authorized Leave ${period}`),
        body: string `
            <p>
                Hi,
                <br/><br/>
                The Other Authorized Leave request of ${escapeHtml(employeeName)} ${period} has been withdrawn.
                No action is needed.
            </p>
        `
    };
}

# Describe a leave period for an email, e.g. "on Mon, 2 Nov 2026" or "from Mon, 2 Nov 2026 to Fri, 6 Nov 2026".
#
# + startDate - Leave start date (ISO 8601)
# + endDate - Leave end date (ISO 8601)
# + return - Leave period text
isolated function getEmailLeavePeriod(string startDate, string endDate) returns string {
    string startDateString = getEmailDateStringFromTimestamp(startDate);
    string endDateString = getEmailDateStringFromTimestamp(endDate);
    return startDateString == endDateString
        ? string `on ${startDateString}`
        : string `from ${startDateString} to ${endDateString}`;
}

# Describe a number of working days for an email, e.g. "0.5 working day" or "3 working days".
#
# + numberOfDays - Number of working days
# + return - Working days text
isolated function getWorkingDaysText(float numberOfDays) returns string {
    string count = numberOfDays == numberOfDays.floor() ? (<int>numberOfDays).toString() : numberOfDays.toString();
    return string `${count} working day${numberOfDays > 1.0 ? "s" : ""}`;
}

# Escape text typed by a user so it shows as plain text in an HTML email.
#
# + text - Text to escape
# + return - Text with &, <, >, " and ' replaced by HTML entities
isolated function escapeHtml(string text) returns string {
    string escaped = re `&`.replaceAll(text, "&amp;");
    escaped = re `<`.replaceAll(escaped, "&lt;");
    escaped = re `>`.replaceAll(escaped, "&gt;");
    escaped = re `"`.replaceAll(escaped, "&quot;");
    return re `'`.replaceAll(escaped, "&#39;");
}
