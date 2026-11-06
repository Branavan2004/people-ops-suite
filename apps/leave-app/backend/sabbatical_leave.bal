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
import leave_service.calendar_events;
import leave_service.database;
import leave_service.email;
import leave_service.employee;

import ballerina/log;
import ballerina/time;

configurable string[] sabbaticalMailGroups = ?;
configurable string sabbaticalLeaveApprovalUrl = ?;

# Create sabbatical leave event in calendar.
#
# + email - User email
# + leave - Sabbatical leave response
# + calendarEventId - Calendar event ID
# + return - Error if any
isolated function createSabbaticalLeaveEventInCalendar(string email, SabbaticalLeaveResponse leave,
        string calendarEventId) returns error? {
    SabbaticalLeaveResponse {id, startDate, endDate} = leave;
    string startDateString = getDateStringFromTimestamp(startDate);
    string endDateString = getDateStringFromTimestamp(endDate);

    calendar_events:Time startTime = {
        date: startDateString
    };
    string endDateForEvent = endDateString;
    string|error nextDayResult = getNextDay(endDateString);
    if nextDayResult is string {
        endDateForEvent = nextDayResult;
    } else {
        log:printError(string `Failed to compute next day for end date ${
                endDateString}, using endDateString as fallback`, nextDayResult);
    }

    calendar_events:Time endTime = {
        date: endDateForEvent
    };

    string summary = "On Sabbatical Leave";
    string|error? eventId = calendar_events:createEvent(
            email,
            {
                summary,
                description: summary,
                colorId: "4",
                'start: startTime,
                end: endTime,
                id: calendarEventId
            }
    );

    if eventId is string {
        log:printInfo(string `Sabbatical event created successfully with event id: ${eventId}. Leave id: ${id}.`);
    } else if eventId is error {
        log:printError(
                string `Error occurred while creating sabbatical event for leave id: ${id} with ID: ${calendarEventId}.`,
                eventId
        );
    } else {
        log:printError(
                string `Error occurred while creating sabbatical event for leave id: ${id} with ID: ${calendarEventId}.
            No ID returned.`
        );
    }
}

# Process sabbatical leaves based on actions.
#
# + payload - Sabbatical leave request process payload
# + return - Error if any
function processSabbaticalLeaveRequest(SabbaticalProcessPayload payload)
    returns error? {
    var {action, applicantEmail, approverEmail, leaveStartDate, leaveEndDate, leaveId, location, comment,
    numberOfDays} = payload;
    string[]|error recipients = getRecipientsForSabbaticalNotifications(applicantEmail, approverEmail);
    string[] recipientsList;
    if recipients is string[] {
        recipientsList = recipients;
    } else if action == CANCEL {
        // The leave is already cancelled, so the cancellation still goes out, without the lead's own lead.
        log:printWarn("Could not look up the lead of a cancelled sabbatical, so their lead is not notified",
                recipients, leadEmail = approverEmail);
        recipientsList = [...sabbaticalMailGroups, applicantEmail, approverEmail];
    } else {
        return recipients;
    }
    string emailSubject = "[Leave App] Sabbatical Leave Application - " + applicantEmail + " (" + leaveStartDate +
    " - " + leaveEndDate + ")";
    string emailBody = "";
    string year = time:utcToCivil(time:utcNow()).year.toString();
    string|error template = "";
    match (action) {
        APPROVE => {
            template = email:bindKeyValues(email:sabbaticalApprovalTemplate, {
                                                                                 APPLICANT_EMAIL: applicantEmail,
                                                                                 LEAD_EMAIL: approverEmail,
                                                                                 LEAVE_START_DATE: leaveStartDate,
                                                                                 LEAVE_END_DATE: leaveEndDate,
                                                                                 YEAR: year,
                                                                                 STATUS: "Approved",
                                                                                 STATUS_DESCRIPTION: "approved"
                                                                             });
            if leaveId is () {
                return error("Leave ID is required for REJECT action");
            }
            // Only a pending request is approved, so one cancelled or decided meanwhile is left as it is. The
            // calendar event ID is stored with the approval.
            string calendarEventId = createUuidForCalendarEvent();
            check database:approvePendingLeave(leaveId, approverEmail, calendarEventId);
            SabbaticalLeaveResponse leaveResponse = {
                id: calendarEventId,
                startDate: leaveStartDate,
                endDate: leaveEndDate,
                location: location
            };
            _ = check createSabbaticalLeaveEventInCalendar(applicantEmail, leaveResponse, calendarEventId);
        }
        REJECT => {
            template = email:bindKeyValues(email:sabbaticalApprovalTemplate, {
                                                                                 APPLICANT_EMAIL: applicantEmail,
                                                                                 LEAD_EMAIL: approverEmail,
                                                                                 LEAVE_START_DATE: leaveStartDate,
                                                                                 LEAVE_END_DATE: leaveEndDate,
                                                                                 YEAR: year,
                                                                                 STATUS: "Rejected",
                                                                                 STATUS_DESCRIPTION: "rejected"
                                                                             });
            if leaveId is () {
                return error("Leave ID is required for REJECT action");
            }
            // Only a pending request is rejected, as above.
            check database:rejectLeave(leaveId, approverEmail, ());
        }
        CANCEL => {
            template = email:bindKeyValues(email:sabbaticalCancellationTemplate, {
                                                                                     APPLICANT_EMAIL: applicantEmail,
                                                                                     LEAVE_START_DATE: leaveStartDate,
                                                                                     LEAVE_END_DATE: leaveEndDate,
                                                                                     YEAR: year
                                                                                 });
        }
        APPLY => {
            LeaveInput leaveInput = {
                startDate: leaveStartDate,
                endDate: leaveEndDate,
                leaveType: database:SABBATICAL_LEAVE,
                periodType: database:MULTIPLE_DAYS_LEAVE,
                email: applicantEmail,
                comment: comment,
                emailSubject: emailSubject,
                emailRecipients: recipientsList,
                isMorningLeave: (),
                status: PENDING,
                // The lead decides the request, so they are its approver from the start. Cancelling it and the
                // lead's own sabbatical report both look the approver up.
                approverEmail
            };

            template = email:bindKeyValues(email:sabbaticalApplicationTemplate, {
                                                                                    APPLICANT_EMAIL: applicantEmail,
                                                                                    LEAD_EMAIL: approverEmail,
                                                                                    LEAVE_START_DATE: leaveStartDate,
                                                                                    LEAVE_END_DATE: leaveEndDate,
                                                                                    ADDITIONAL_COMMENT:
                                                                                        (comment is () || comment is "")
                                                                                        ? "N/A" : comment,
                                                                                    YEAR: year,
                                                                                    LEAVE_APP_URL:
                                                                                    sabbaticalLeaveApprovalUrl
                                                                                });
            if location is string {
                _ = check database:insertLeave(leaveInput, numberOfDays ?: 0.0, location);
            }
        }
    }

    map<string> emailContent = {"CONTENT": emailBody};
    if template is error {
        log:printError("Failed to bind key values to sabbatical leave template", template);
        return;
    }
    error? notificationResult = email:processEmailNotification("", emailSubject, emailContent, recipientsList,
            template);
    if (notificationResult is error) {
        log:printError("Failed to process sabbatical approval notification", notificationResult);
    }
}

# Get recipients for sabbatical leave notifications.
# + applicantEmail - Applicant email
# + leadEmail - Reporting lead email. Blank only for a cancellation whose lead is not known, which then goes to the
# applicant and the sabbatical groups
# + return - List of recipient emails or an error
function getRecipientsForSabbaticalNotifications(string applicantEmail, string leadEmail)
    returns string[]|error {
    if leadEmail.trim() == "" {
        return [...sabbaticalMailGroups, applicantEmail];
    }
    Employee reportingLead = check employee:getEmployee(leadEmail);

    string[] recipientsList = [...sabbaticalMailGroups, applicantEmail, leadEmail];
    if reportingLead.leadEmail is () {
        log:printInfo("Functional Lead info is not available. Skipped notification for the functional lead.");
    }
    if reportingLead.leadEmail is string {
        string functionalLeadEmail = (<string>reportingLead.leadEmail).toLowerAscii(); // functional lead email
        boolean isOptedOut = false;
        foreach string optOutMail in sabbaticalFunctionalLeadOptOutMails {
            if functionalLeadEmail == optOutMail.toLowerAscii() {
                isOptedOut = true;
                break;
            }
        }
        if (!isOptedOut) {
            recipientsList.push(functionalLeadEmail);
        }
    }

    return recipientsList;
}

# Check eligibility criteria for sabbatical leave applications.
#
# + employmentStartDate - Employment start date
# + lastSabbaticalLeaveEndDate - Last sabbatical leave end date
# + leaveStartDate - Leave start date
# + return - Error if not eligible
isolated function checkEligibilityForSabbaticalApplication(string employmentStartDate,
        string? lastSabbaticalLeaveEndDate, string leaveStartDate) returns boolean|error {

    int|error daysSinceEmployment = check getDateDiffInDays(leaveStartDate, employmentStartDate);
    int|error daysSinceLastSabbaticalLeave = 0;
    if lastSabbaticalLeaveEndDate is string {
        daysSinceLastSabbaticalLeave = getDateDiffInDays(leaveStartDate, lastSabbaticalLeaveEndDate);
    }
    if daysSinceEmployment is int {
        if lastSabbaticalLeaveEndDate == () && daysSinceEmployment > sabbaticalLeaveEligibilityDuration {
            return true;
        }

    }
    // Eligibility: employed for longer than the eligibility duration, and the last sabbatical leave ended longer
    // than the eligibility duration ago
    if daysSinceEmployment is int && daysSinceLastSabbaticalLeave is int {
        if (daysSinceEmployment > sabbaticalLeaveEligibilityDuration &&
        daysSinceLastSabbaticalLeave > sabbaticalLeaveEligibilityDuration) {
            return true;
        }

    }
    return false;
}

# Calculate date difference in days.
#
# + endDate - End date (yyyy-mm-dd)
# + startDate - Start date (yyyy-mm-dd)
# + return - Difference in days or error
isolated function getDateDiffInDays(string endDate, string startDate) returns int|error {
    time:Utc utc1 = check time:utcFromString(endDate + "T00:00:00Z");
    time:Utc utc2 = check time:utcFromString(startDate + "T00:00:00Z");

    time:Seconds diffSeconds = time:utcDiffSeconds(utc1, utc2);

    return <int>(diffSeconds / 86400) + 1;
}

# Get subordinate count for a specific lead.
#
# + leadEmail - email of the reporting lead
# + return - subordinate count as an integer or an error on failure
isolated function getSubordinateCount(string leadEmail) returns int|error {
    Employee employee = check employee:getEmployee(leadEmail);
    return employee.subordinateCount;
}

# Get the next day from a given date string.
#
# + dateString - Date string in yyyy-mm-dd format
# + return - Next day in yyyy-mm-dd format or error
isolated function getNextDay(string dateString) returns string|error {
    time:Utc utc = check time:utcFromString(dateString + "T00:00:00Z");
    time:Utc nextDay = time:utcAddSeconds(utc, 86400); // Add 24 hours
    return time:utcToString(nextDay).substring(0, 10);
}
