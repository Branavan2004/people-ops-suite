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
import leave_service.database;
import leave_service.email;
import leave_service.employee;
import leave_service.policy;

import ballerina/http;
import ballerina/log;

# Link to the Leave App page where leads approve or reject Other Authorized Leave requests.
configurable string otherAuthorizedApprovalUrl = ?;

const OTHER_AUTHORIZED_ALERT_HEADER = "Other Authorized Leave";

# Save an Other Authorized Leave request as pending and ask the applicant's reporting lead to approve it.
#
# The team email and the calendar event wait for the approval. The email subject and recipients are worked out and
# stored now, exactly as a self-service leave would, so the approval sends the usual leave notification.
#
# + input - Leave input
# + jwt - JWT token of the applicant
# + return - Ok when the request is saved, BadRequest if the applicant has no reporting lead, otherwise
# InternalServerError
function submitForApproval(LeaveInput input, string jwt) returns http:Ok|http:BadRequest|http:InternalServerError {
    do {
        employee:Employee & readonly applicant = check employee:getEmployee(input.email);
        // A blank lead from HR counts as none, as it does on withdrawal and in the scheduler.
        string? leadEmail = nonBlankEmail(applicant.leadEmail);
        if leadEmail is () {
            string errMsg = "A reporting lead is required to apply for Other Authorized Leave.";
            log:printWarn(errMsg);
            return <http:BadRequest>{
                body: {
                    message: errMsg
                }
            };
        }
        input.status = PENDING;
        input.approverEmail = leadEmail;

        database:LeaveType leaveType = check input.leaveType.ensureType();
        database:LeavePeriodType periodType = check input.periodType.ensureType();
        LeavePayload leavePayload = {
            startDate: input.startDate,
            endDate: input.endDate,
            isMorningLeave: input.isMorningLeave,
            periodType,
            leaveType
        };
        email:EmailNotificationDetails leaveContent = check email:generateContentForLeave(jwt, input.email,
                leavePayload);
        input.emailSubject = leaveContent.subject;
        input.emailRecipients = check getAllEmailRecipientsForUser(input.email, input.emailRecipients, jwt);
        // The calendar event is created on approval.
        input.calendarEventId = ();

        LeaveDetails leave = check insertLeaveToDatabase(input, false, jwt);
        email:EmailNotificationDetails approvalRequest = email:approvalRequestContent(
                getEmployeeDisplayName(applicant),
                leave.startDate,
                leave.endDate,
                leave.numberOfDays ?: 0.0,
                input?.comment,
                otherAuthorizedApprovalUrl
        );
        _ = start sendOtherAuthorizedLeaveEmail(approvalRequest.cloneReadOnly(),
                [leadEmail, input.email].cloneReadOnly());

        return <http:Ok>{
            body: {
                message: "Leave request sent to your lead for approval"
            }
        };

    } on fail error internalErr {
        string errMsg = "Error occurred while submitting a leave";
        log:printError(errMsg, internalErr);
        return <http:InternalServerError>{
            body: {
                message: errMsg
            }
        };
    }
}

# Approve or reject a pending Other Authorized Leave request.
#
# The caller must already have checked that the current user is the applicant's current reporting lead.
#
# + leave - Leave to decide
# + action - Approve or reject
# + leadEmail - Email of the reporting lead deciding the request
# + payload - Decision payload. A reason is required to reject
# + jwt - JWT token of the reporting lead
# + return - Ok when the decision is saved, BadRequest if the request cannot be decided or the reason is invalid,
# otherwise InternalServerError
function decideOtherAuthorizedLeave(database:Leave leave, Action action, string leadEmail, DecisionPayload? payload,
        string jwt) returns http:Ok|http:BadRequest|http:InternalServerError {

    error? decidable = policy:checkDecidable(leave.status ?: "");
    if decidable is error {
        return <http:BadRequest>{
            body: {
                message: decidable.message()
            }
        };
    }

    if action == APPROVE_ACTION {
        error? approvalResult = approveOtherAuthorizedLeave(leave, leadEmail, jwt);
        if approvalResult is database:LeaveNotPendingError {
            return <http:BadRequest>{
                body: {
                    message: approvalResult.message()
                }
            };
        }
        if approvalResult is error {
            string errMsg = "Error occurred while approving Other Authorized Leave!";
            log:printError(string `${errMsg} Leave ID: ${leave.id}.`, approvalResult);
            return <http:InternalServerError>{
                body: {
                    message: errMsg
                }
            };
        }
        return <http:Ok>{
            body: {
                message: "Leave request approved"
            }
        };
    }

    string|error reason = policy:normaliseRejectionReason(payload?.reason);
    if reason is error {
        return <http:BadRequest>{
            body: {
                message: reason.message()
            }
        };
    }
    error? rejectionResult = rejectOtherAuthorizedLeave(leave, leadEmail, reason);
    if rejectionResult is database:LeaveNotPendingError {
        return <http:BadRequest>{
            body: {
                message: rejectionResult.message()
            }
        };
    }
    if rejectionResult is error {
        string errMsg = "Error occurred while rejecting Other Authorized Leave!";
        log:printError(string `${errMsg} Leave ID: ${leave.id}.`, rejectionResult);
        return <http:InternalServerError>{
            body: {
                message: errMsg
            }
        };
    }
    return <http:Ok>{
        body: {
            message: "Leave request rejected"
        }
    };
}

# Approve a pending Other Authorized Leave request, then send what a self-service leave sends: the usual leave
# notification to the stored recipients, the additional comment email when there is a comment, and the calendar event.
#
# + leave - Pending leave to approve
# + leadEmail - Email of the reporting lead approving the request
# + jwt - JWT token of the reporting lead
# + return - `database:LeaveNotPendingError` if the request is no longer pending, or an error if the approval fails
function approveOtherAuthorizedLeave(database:Leave leave, string leadEmail, string jwt) returns error? {
    LeaveDetails leaveDetails = check getLeaveEntityFromDbRecord(leave, jwt);
    string calendarEventId = createUuidForCalendarEvent();
    LeaveResponse leaveResponse = {
        id: leaveDetails.id,
        startDate: leaveDetails.startDate,
        endDate: leaveDetails.endDate,
        status: APPROVED,
        leaveType: leaveDetails.leaveType,
        periodType: leaveDetails.periodType,
        email: leaveDetails.email,
        createdDate: leaveDetails.createdDate,
        numberOfDays: leaveDetails.numberOfDays ?: 0.0,
        isMorningLeave: leaveDetails.isMorningLeave,
        calendarEventId,
        location: leaveDetails.location
    };
    email:EmailNotificationDetails & readonly leaveContent = check email:generateContentForLeave(jwt, leave.email,
            leaveResponse, emailSubject = leave.emailSubject);
    readonly & string[] recipients = leaveDetails.emailRecipients.cloneReadOnly();

    // The stored comment goes out as at submission: to everyone notified if public, otherwise privately.
    (email:EmailNotificationDetails & readonly)? commentContent = ();
    readonly & string[] commentRecipients = [];
    string? comment = leave.submitComment;
    if comment is string && !checkIfEmptyString(comment) {
        commentContent = email:generateContentForAdditionalComment(leaveContent.subject, comment).cloneReadOnly();
        commentRecipients = leave.isPublicComment == true
            ? recipients
            : getPrivateCommentRecipients(recipients).cloneReadOnly();
    }

    // A single guarded update: a request decided or withdrawn meanwhile is left as it is, and nothing is sent.
    check database:approvePendingLeave(leave.id, leadEmail, calendarEventId);

    _ = start sendApprovedLeaveNotifications(leaveContent, recipients, commentContent, commentRecipients);
    _ = start createLeaveEventInCalendar(leave.email, leaveResponse.cloneReadOnly(), calendarEventId);
}

# Send the usual leave notification for an approved request and, only if it succeeds, the additional comment email,
# as a self-service leave does.
#
# + leaveContent - Leave notification content
# + recipients - Leave notification recipients
# + commentContent - Additional comment email content, if the leave has a comment
# + commentRecipients - Additional comment email recipients
# + return - Error if sending an email fails
isolated function sendApprovedLeaveNotifications(readonly & email:EmailNotificationDetails leaveContent,
        readonly & string[] recipients, (readonly & email:EmailNotificationDetails)? commentContent,
        readonly & string[] commentRecipients) returns error? {

    check email:sendLeaveNotification(leaveContent, recipients);
    if commentContent is email:EmailNotificationDetails {
        check email:sendAdditionalComment(commentContent, commentRecipients);
    }
}

# Get the recipients of a private comment from the stored recipients of a leave: everyone except the default
# recipients and the leave notification group, as `getPrivateRecipientsForUser` works them out at submission.
#
# + storedRecipients - Recipients stored with the leave
# + return - Private comment recipients
function getPrivateCommentRecipients(string[] storedRecipients) returns string[] {
    map<true> recipientMap = {};
    foreach string recipient in storedRecipients {
        recipientMap[recipient] = true;
    }
    foreach string defaultRecipient in defaultRecipients {
        if recipientMap.hasKey(defaultRecipient) {
            _ = recipientMap.remove(defaultRecipient);
        }
    }
    if recipientMap.hasKey(emailGroupToNotify) {
        _ = recipientMap.remove(emailGroupToNotify);
    }
    return recipientMap.keys();
}

# Reject a pending Other Authorized Leave request and email the reason to the applicant and the reporting lead.
#
# + leave - Pending leave to reject
# + leadEmail - Email of the reporting lead rejecting the request
# + reason - Validated rejection reason
# + return - `database:LeaveNotPendingError` if the request is no longer pending, or an error if the rejection fails
function rejectOtherAuthorizedLeave(database:Leave leave, string leadEmail, string reason) returns error? {
    check database:rejectLeave(leave.id, leadEmail, reason);

    email:EmailNotificationDetails rejection = email:rejectionContent(getEmployeeName(leave.email), leave.startDate,
            leave.endDate, reason);
    _ = start sendOtherAuthorizedLeaveEmail(rejection.cloneReadOnly(), [leave.email, leadEmail].cloneReadOnly());
}

# Cancel a pending Other Authorized Leave request and tell the applicant and the reporting lead it was withdrawn.
#
# The notice goes to the lead the approval reminders go to: the applicant's current lead in HR, or the approver stored
# with the leave when HR has none. There is no team email to retract and no calendar event to delete, as both wait for
# the approval.
#
# + leave - Pending leave to cancel
# + return - `database:LeaveNotPendingError` if the request is no longer pending (nothing is changed or sent), or an
# error if the cancellation fails
function withdrawOtherAuthorizedLeave(database:Leave leave) returns error? {
    check database:cancelPendingLeave(leave.id);

    employee:Employee & readonly|error applicant = employee:getEmployee(leave.email);
    if applicant is error {
        log:printWarn(string `Failed to fetch employee info for email: ${leave.email}. Using the email address and ` +
                "the stored approver for the withdrawal notice instead.", applicant);
    }
    string employeeName = applicant is error ? leave.email : getEmployeeDisplayName(applicant);
    string? hrLeadEmail = applicant is error ? () : nonBlankEmail(applicant.leadEmail);
    string? leadEmail = hrLeadEmail ?: nonBlankEmail(leave.approverEmail);

    string[] recipients = [leave.email];
    if leadEmail is string {
        recipients.unshift(leadEmail);
    } else {
        log:printWarn(string `No reporting lead is available for leave with ID: ${leave.id}. ` +
                "The withdrawal notice goes to the applicant only.");
    }
    email:EmailNotificationDetails withdrawal = email:withdrawalContent(employeeName, leave.startDate, leave.endDate);
    _ = start sendOtherAuthorizedLeaveEmail(withdrawal.cloneReadOnly(), recipients.cloneReadOnly());
}

# Get an email address, treating a blank one as none.
#
# + email - Email address, if any
# + return - The trimmed email address, or nil when it is missing or blank
isolated function nonBlankEmail(string? email) returns string? =>
    email is string && email.trim() != "" ? email.trim() : ();

# Send an Other Authorized Leave email to the given recipients, all as To recipients.
#
# + details - Email subject and body
# + recipients - Email recipients
# + return - Error if sending the email fails
isolated function sendOtherAuthorizedLeaveEmail(readonly & email:EmailNotificationDetails details,
        readonly & string[] recipients) returns error? {

    check email:processEmailNotification(OTHER_AUTHORIZED_ALERT_HEADER, details.subject, {"CONTENT": details.body},
            recipients);
}

# Get an employee's name for an email, falling back to their email address if the lookup fails.
#
# + email - Employee email
# + return - Employee name or email address
isolated function getEmployeeName(string email) returns string {
    employee:Employee & readonly|error employeeInfo = employee:getEmployee(email);
    if employeeInfo is error {
        log:printWarn(string `Failed to fetch employee info for email: ${email}. Using the email address instead.`,
                employeeInfo);
        return email;
    }
    return getEmployeeDisplayName(employeeInfo);
}

# Get an employee's name for an email, as the leave notification shows it.
#
# + employeeInfo - Employee record
# + return - First and last name, or the work email if the first name is missing
isolated function getEmployeeDisplayName(employee:Employee employeeInfo) returns string {
    string? firstName = employeeInfo.firstName;
    return firstName is string ? string `${firstName} ${employeeInfo.lastName ?: ""}`.trim() : employeeInfo.workEmail;
}
