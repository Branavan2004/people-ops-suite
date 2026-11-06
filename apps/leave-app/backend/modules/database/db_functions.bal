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

import ballerina/sql;
import ballerinax/mysql;

// Initializing Db client for leave database
final mysql:Client leaveDbClient = check initializeLeaveClient();

# Get leaves from database with the given filter.
#
# + filter - Leave filter 
# + 'limit - Maximum records limit  
# + offset - Offset value
# + return - List of Leaves or an error on failure
public isolated function getLeaves(LeaveFilter filter, int? 'limit = (), int? offset = ()) returns Leave[]|error {
    sql:ParameterizedQuery sqlQuery = getLeavesQuery(filter, getValidatedLimit('limit), getValidatedOffset(offset));
    stream<LeaveRow, sql:Error?> resultStream = leaveDbClient->query(sqlQuery);
    return from LeaveRow leave in resultStream
        select toLeave(leave);
}

# Get a leave from database with the given id.
#
# + id - Leave ID
# + return - Requested leave or an error on failure
public isolated function getLeave(int id) returns Leave|error? {
    sql:ParameterizedQuery mainQuery = getCommonLeaveQuery();
    sql:ParameterizedQuery finalQuery = sql:queryConcat(mainQuery, ` WHERE id = ${id}`);
    LeaveRow|error leave = leaveDbClient->queryRow(finalQuery);
    if leave is sql:NoRowsError {
        return ();
    }
    if leave is error {
        return error("Error occurred while fetching leave!", leave);
    }

    return toLeave(leave);
}

# Create a new leave in the database.
#
# + input - Input data for the leave
# + numDaysForLeave - Number of days for leave
# + location - Employee location
# + return - The inserted Leave record if successful; otherwise, an error
public isolated function insertLeave(LeaveInput input, float numDaysForLeave, string location) returns Leave|error {
    sql:ExecutionResult|error result = leaveDbClient->execute(insertLeaveQuery(input, numDaysForLeave, location));
    if result is error {
        return error("Error occurred while inserting leave!", result);
    }
    int lastInsertId = check result.lastInsertId.ensureType();
    Leave|error? insertedLeave = getLeave(lastInsertId);
    if insertedLeave is () {
        return error("Inserted leave not found after insertion");
    }
    if insertedLeave is error {
        return error("Error occurred while fetching inserted leave!", insertedLeave);
    }
    return insertedLeave;
}

# Create a new leave and its sick note in one transaction: both are saved, or neither.
#
# + input - Input data for the leave
# + numDaysForLeave - Number of days for leave
# + location - Employee location
# + sickNote - Encrypted sick note
# + return - The inserted Leave record if successful; otherwise, an error
public isolated function insertLeaveWithSickNote(LeaveInput input, float numDaysForLeave, string location,
        SickNoteInput sickNote) returns Leave|error {

    int leaveId;
    transaction {
        sql:ExecutionResult result = check leaveDbClient->execute(insertLeaveQuery(input, numDaysForLeave, location));
        leaveId = check result.lastInsertId.ensureType();
        _ = check leaveDbClient->execute(insertSickNoteQuery(leaveId, sickNote));
        check commit;
    } on fail error err {
        return error("Error occurred while inserting leave with sick note!", err);
    }
    Leave|error? insertedLeave = getLeave(leaveId);
    if insertedLeave is () {
        return error("Inserted leave not found after insertion");
    }
    if insertedLeave is error {
        return error("Error occurred while fetching inserted leave!", insertedLeave);
    }
    return insertedLeave;
}

# Get the details of a leave's sick note, without its content, so access can be checked before the file is read.
#
# + leaveId - Leave ID
# + return - The sick note details, nil if the leave has none, or an error on failure
public isolated function getSickNote(int leaveId) returns StoredSickNote|error? {
    StoredSickNote|error sickNote = leaveDbClient->queryRow(getSickNoteQuery(leaveId));
    if sickNote is sql:NoRowsError {
        return ();
    }
    if sickNote is error {
        return error("Error occurred while fetching the sick note!", sickNote);
    }
    return sickNote;
}

# Get the encrypted content of a sick note.
#
# + attachmentId - ID of the sick note attachment
# + return - The encrypted content, nil if the attachment does not exist, or an error on failure
public isolated function getSickNoteContent(int attachmentId) returns SickNoteContent|error? {
    SickNoteContent|error content = leaveDbClient->queryRow(getSickNoteContentQuery(attachmentId));
    if content is sql:NoRowsError {
        return ();
    }
    if content is error {
        return error("Error occurred while fetching the sick note content!", content);
    }
    return content;
}

# Record that a user downloaded a sick note.
#
# + attachmentId - ID of the sick note attachment
# + leaveId - ID of the leave the note belongs to
# + downloadedBy - Email of the user who downloaded the note
# + return - Nil on success, or an error on failure
public isolated function recordSickNoteDownload(int attachmentId, int leaveId, string downloadedBy) returns error? {
    sql:ExecutionResult|sql:Error result = leaveDbClient->execute(
            recordSickNoteDownloadQuery(attachmentId, leaveId, downloadedBy));
    if result is sql:Error {
        return error("Error occurred while recording the sick note download!", result);
    }
}

# Get the sick leaves in France that have a sick note and overlap the given dates, newest first.
#
# + startDate - Start of the date range (yyyy-mm-dd)
# + endDate - End of the date range (yyyy-mm-dd), inclusive
# + return - Sick note summaries, or an error on failure
public isolated function getSickNotes(string startDate, string endDate) returns SickNoteSummary[]|error {
    stream<SickNoteSummary, sql:Error?> resultStream = leaveDbClient->query(getSickNotesQuery(startDate, endDate));
    SickNoteSummary[]|sql:Error sickNotes = from SickNoteSummary sickNote in resultStream
        select sickNote;
    if sickNotes is sql:Error {
        return error("Error occurred while fetching sick notes!", sickNotes);
    }
    return sickNotes;
}

# Cancel an existing active leave.
#
# + id - Leave ID  
# + return - Returns nil on success, error on failure
public isolated function cancelLeave(int id) returns error? {
    sql:ExecutionResult|sql:Error result = leaveDbClient->execute(setLeaveStatusQuery(CANCELLED, id));
    if result is error {
        return error("Error occurred while cancelling leave!", result);
    }
}

# Update leave status for a sabbatical leave application.
#
# + leaveId - ID of the sabbatical leave application
# + approvalStatus - Approval status to be set (APPROVED, REJECTED, CANCELLED...etc)
# + return - Nil on success, error on failure
public isolated function setLeaveStatus(int leaveId, Status approvalStatus, string? approverEmail = ())
    returns sql:ExecutionResult|error {

    sql:ParameterizedQuery sqlQuery = setLeaveStatusQuery(approvalStatus, leaveId, approverEmail);
    return check leaveDbClient->execute(sqlQuery);
}

# Reject a pending leave request, storing the approver and the reason.
#
# + leaveId - Leave ID
# + approverEmail - Email of the approver rejecting the request
# + reason - Reason for the rejection, or nil when none is given
# + return - Nil on success, `LeaveNotPendingError` if the leave is no longer pending, or an error on failure
public isolated function rejectLeave(int leaveId, string approverEmail, string? reason) returns error? {
    sql:ExecutionResult|sql:Error result = leaveDbClient->execute(rejectLeaveQuery(leaveId, approverEmail, reason));
    if result is sql:Error {
        return error("Error occurred while rejecting leave!", result);
    }
    if result.affectedRowCount == 0 {
        return error LeaveNotPendingError(ERR_MSG_LEAVE_NOT_PENDING);
    }
}

# Approve a pending leave request, storing the approver and the calendar event ID in the same update.
#
# + leaveId - Leave ID
# + approverEmail - Email of the approver approving the request
# + calendarEventId - ID of the calendar event to be created for the leave
# + return - Nil on success, `LeaveNotPendingError` if the leave is no longer pending, or an error on failure
public isolated function approvePendingLeave(int leaveId, string approverEmail, string calendarEventId)
    returns error? {

    sql:ExecutionResult|sql:Error result = leaveDbClient->execute(
            approvePendingLeaveQuery(leaveId, approverEmail, calendarEventId));
    if result is sql:Error {
        return error("Error occurred while approving leave!", result);
    }
    if result.affectedRowCount == 0 {
        return error LeaveNotPendingError(ERR_MSG_LEAVE_NOT_PENDING);
    }
}

# Cancel a leave request only while it is pending.
#
# + leaveId - Leave ID
# + return - Nil on success, `LeaveNotPendingError` if the leave is no longer pending, or an error on failure
public isolated function cancelPendingLeave(int leaveId) returns error? {
    sql:ExecutionResult|sql:Error result = leaveDbClient->execute(cancelPendingLeaveQuery(leaveId));
    if result is sql:Error {
        return error("Error occurred while cancelling leave!", result);
    }
    if result.affectedRowCount == 0 {
        return error LeaveNotPendingError(ERR_MSG_LEAVE_NOT_PENDING);
    }
}

# Get the end date of the last sabbatical leave for an employee.
#
# + employeeEmail - Email of the employee
# + return - End date of the last sabbatical leave or an error on failure
public isolated function getLastSabbaticalLeaveEndDate(string employeeEmail) returns string?|error {
    string|error lastSabbaticalEndDate = leaveDbClient->queryRow(getLastSabbaticalLeaveEndDateQuery(employeeEmail));
    if lastSabbaticalEndDate is sql:NoRowsError {
        return ();
    }
    if lastSabbaticalEndDate is error {
        return error("Error occurred while retrieving last sabbatical leave end date", lastSabbaticalEndDate);
    }
    // format timestamp to date string YYYY-MM-DD
    string formattedDate = lastSabbaticalEndDate.toString().substring(0, 10);
    return formattedDate;
}

# Get subordinate count who are on sabbatical leave under a specific lead.
#
# + leadEmail - Email of the lead
# + return - subordinate count or an error on failure
public isolated function getSubordinateCountOnSabbaticalLeave(string leadEmail) returns int|error {
    return check leaveDbClient->queryRow(getSubordinateCountOnSabbaticalLeaveQuery(leadEmail));
}

# Get most recent email notification recipient list (general leave) for a leave applicant.
#
# + applicantEmail - Email of the leave applicant
# + return - List of email recipients as a string, or an error on failure
public isolated function getEmailNotificationRecipientList(string applicantEmail) returns string|error {
    return check leaveDbClient->queryRow(getEmailNotificationRecipientListQuery(applicantEmail));
};

# Set calendar event ID for an approved sabbatical leave application.
#
# + leaveId - Leave ID  
# + calendarEventId - Calendar event ID
# + return - SQL execution result or an error on failure
public isolated function setCalendarEventIdForSabbaticalLeave(int leaveId, string calendarEventId)
    returns sql:ExecutionResult|error {

    return check leaveDbClient->execute(setSabbaticalLeaveCalendarEventIdQuery(leaveId, calendarEventId));
}
