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

# Generates a common SQL query to fetch leave records from the database.
#
# + return - Select query
isolated function getCommonLeaveQuery() returns sql:ParameterizedQuery => `
    SELECT 
        id, 
        email, 
        leave_type,
        leave_period_type,
        copy_email_list,
        notify_everyone,
        submit_note,
        cancel_note,
        created_date,
        updated_date,
        email_id,
        email_subject,
        start_date,
        end_date,
        start_half,
        end_half,
        canceled_date,
        num_days,
        public_submit_note,
        calendar_event_id,
        location,
        status,
        approver_email,
        rejection_reason,
        EXISTS (
            SELECT 1 FROM leave_attachments attachment WHERE attachment.leave_id = leave_submissions.id
        ) AS has_sick_note,
        (
            SELECT attachment.deleted_at FROM leave_attachments attachment
            WHERE attachment.leave_id = leave_submissions.id
        ) AS sick_note_deleted_on
    FROM leave_submissions
`;

# Query to fetch leaves from the database.
#
# + filter - Query filter  
# + 'limit - Maximum records limit  
# + offset - Offset value
# + return - Select query fetch leaves
isolated function getLeavesQuery(LeaveFilter filter, int? 'limit = (), int? offset = ())
    returns sql:ParameterizedQuery {

    sql:ParameterizedQuery mainQuery = getCommonLeaveQuery();

    sql:ParameterizedQuery[] filterQueries = [];

    string[]? emails = filter?.emails;
    if emails is string[] && emails.length() > 0 {
        filterQueries.push(sql:queryConcat(`email IN (`, sql:arrayFlattenQuery(emails), `)`));
    }
    string? startDate = filter?.startDate;
    string? endDate = filter?.endDate;
    if startDate is string && endDate is string {
        filterQueries.push(`((start_date BETWEEN ${startDate} AND ${endDate}) 
            OR (end_date BETWEEN ${startDate} AND ${endDate}) 
            OR (start_date < ${startDate} AND end_date > ${endDate}))`);
    } else if startDate is string {
        filterQueries.push(
            `(start_date >= ${startDate} OR (end_date >= ${startDate} AND start_date < ${startDate}))`
        );
    } else if endDate is string {
        filterQueries.push(`(end_date <= ${endDate} OR (start_date <= ${endDate} AND end_date > ${endDate}))`);
    }

    if filter?.approverEmail is string {
        filterQueries.push(sql:queryConcat(` approver_email = ${filter?.approverEmail} `));
    }
    Status[]? statuses = filter?.statuses;
    if statuses is Status[] && statuses.length() > 0 {
        filterQueries.push(sql:queryConcat(` status IN (`, sql:arrayFlattenQuery(statuses), `) `));
    }

    string[]? leaveTypes = filter?.leaveTypes;
    if leaveTypes is string[] && leaveTypes.length() != 0 {
        filterQueries.push(sql:queryConcat(`leave_type IN (`, sql:arrayFlattenQuery(leaveTypes), `)`));
    }
    string[]? excludedLeaveTypes = filter?.excludedLeaveTypes;
    if excludedLeaveTypes is string[] && excludedLeaveTypes.length() != 0 {
        filterQueries.push(
            sql:queryConcat(`leave_type NOT IN (`, sql:arrayFlattenQuery(excludedLeaveTypes), `)`));
    }

    sql:ParameterizedQuery sqlQuery = buildSqlQuery(mainQuery, filterQueries);
    sql:ParameterizedQuery orderBy = filter?.orderBy == ASC ? `ASC` : `DESC`;
    return sql:queryConcat(sqlQuery, ` ORDER BY created_date `, orderBy,
            ` LIMIT ${'limit ?: MAXIMUM_LIMIT_VALUE} OFFSET ${offset ?: 0}`);
}

# Query to insert leave to the database.
#
# + input - Leave input data  
# + numberOfDays - Number of days for the leave  
# + location - Employee location
# + return - Insert Query
isolated function insertLeaveQuery(LeaveInput input, float numberOfDays, string location)
    returns sql:ParameterizedQuery {

    boolean? isMorningLeave = input.isMorningLeave;
    sql:ParameterizedQuery insertQuery = `
        INSERT INTO leave_submissions (
            email,
            leave_type,
            leave_period_type,
            copy_email_list,
            notify_everyone,
            submit_note,
            cancel_note,
            created_date,
            email_id,
            email_subject,
            status,
            approver_email,
            start_date,
            end_date,
            start_half,
            num_days,
            public_submit_note,
            calendar_event_id,
            location
        ) VALUES (
            ${input.email},
            ${input.leaveType},
            ${input.periodType},
            ${string:'join(",", ...input.emailRecipients)},
            0,
            ${input?.comment ?: ""},
            '',
            NOW(),
            ${input.emailId ?: ""},
            ${input.emailSubject},
            ${input.status},
            ${input.approverEmail},
            TIMESTAMP(${input.startDate}, ${isMorningLeave is boolean ? (isMorningLeave ? "00:00:00" : "13:00:00") : "00:00:00"}),
            TIMESTAMP(${input.endDate}, ${isMorningLeave is boolean ? (isMorningLeave ? "13:00:00" : "23:59:00") : "23:59:00"}),
            ${isMorningLeave is boolean ? !isMorningLeave : ()},
            ${numberOfDays},
            ${input?.isPublicComment ?: false},
            ${input?.calendarEventId},
            ${location} 
            )
    `;

    return insertQuery;
}

# Query to insert the sick note of a leave.
#
# + leaveId - ID of the leave the note belongs to
# + sickNote - Encrypted sick note
# + return - Insert query
isolated function insertSickNoteQuery(int leaveId, SickNoteInput sickNote) returns sql:ParameterizedQuery => `
        INSERT INTO leave_attachments (
            leave_id,
            content,
            iv,
            key_id,
            content_type,
            size_bytes,
            uploaded_by
        ) VALUES (
            ${leaveId},
            ${sickNote.content},
            ${sickNote.iv},
            ${sickNote.keyId},
            ${sickNote.contentType},
            ${sickNote.sizeBytes},
            ${sickNote.uploadedBy}
        )
    `;

# Query to get the details of a leave's sick note, without its content, with the email of the employee the leave
# belongs to.
#
# + leaveId - Leave ID
# + return - Select query
isolated function getSickNoteQuery(int leaveId) returns sql:ParameterizedQuery => `
        SELECT
            attachment.id AS id,
            attachment.leave_id AS leave_id,
            leave_submissions.email AS email,
            attachment.key_id AS key_id,
            attachment.content_type AS content_type,
            attachment.deleted_at AS deleted_at
        FROM
            leave_attachments attachment
            JOIN leave_submissions ON leave_submissions.id = attachment.leave_id
        WHERE
            attachment.leave_id = ${leaveId}
    `;

# Query to get the encrypted content of a sick note.
#
# + attachmentId - ID of the sick note attachment
# + return - Select query
isolated function getSickNoteContentQuery(int attachmentId) returns sql:ParameterizedQuery => `
        SELECT
            content,
            iv
        FROM
            leave_attachments
        WHERE
            id = ${attachmentId}
    `;

# Query to record a sick note download.
#
# + attachmentId - ID of the sick note attachment
# + leaveId - ID of the leave the note belongs to
# + downloadedBy - Email of the user who downloaded the note
# + return - Insert query
isolated function recordSickNoteDownloadQuery(int attachmentId, int leaveId, string downloadedBy)
    returns sql:ParameterizedQuery => `
        INSERT INTO leave_attachment_downloads (
            attachment_id,
            leave_id,
            downloaded_by
        ) VALUES (
            ${attachmentId},
            ${leaveId},
            ${downloadedBy}
        )
    `;

# Query to list sick leaves in France that have a sick note and overlap the given dates, newest first.
#
# + startDate - Start of the date range (yyyy-mm-dd)
# + endDate - End of the date range (yyyy-mm-dd), inclusive
# + return - Select query
isolated function getSickNotesQuery(string startDate, string endDate) returns sql:ParameterizedQuery => `
        SELECT
            leave_submissions.id AS leave_id,
            leave_submissions.email AS email,
            leave_submissions.start_date AS start_date,
            leave_submissions.end_date AS end_date,
            leave_submissions.num_days AS num_days,
            leave_submissions.status AS status,
            attachment.uploaded_at AS uploaded_at,
            attachment.deleted_at AS deleted_at,
            attachment.size_bytes AS size_bytes,
            attachment.content_type AS content_type
        FROM
            leave_attachments attachment
            JOIN leave_submissions ON leave_submissions.id = attachment.leave_id
        WHERE
            leave_submissions.leave_type = ${SICK_LEAVE} AND leave_submissions.location = ${FRANCE} AND
            leave_submissions.start_date < DATE_ADD(${endDate}, INTERVAL 1 DAY) AND
            leave_submissions.end_date >= ${startDate}
        ORDER BY
            leave_submissions.start_date DESC, leave_submissions.id DESC
    `;

# Set the status of a leave application.
#
# + status - Status of the leave to be set (APPROVED, REJECTED, CANCELLED...etc)
# + leaveId - ID of the leave record 
# + return - Update query to approve or reject leave application
isolated function setLeaveStatusQuery(Status status, int leaveId, string? approverEmail = ())
    returns sql:ParameterizedQuery {
    if approverEmail is string {
        return `
            UPDATE
                leave_submissions
            SET
                status = ${status},
                approver_email = ${approverEmail}
            WHERE
                id = ${leaveId}
        `;
    }
    return `
        UPDATE
            leave_submissions
        SET
            status = ${status}
        WHERE
            id = ${leaveId}
    `;
}

# Query to reject a pending leave request.
#
# + leaveId - ID of the leave record
# + approverEmail - Email of the approver rejecting the request
# + reason - Reason for the rejection, or nil when none is given
# + return - Update query that only changes the leave while it is pending
isolated function rejectLeaveQuery(int leaveId, string approverEmail, string? reason)
    returns sql:ParameterizedQuery => `
        UPDATE
            leave_submissions
        SET
            status = ${REJECTED},
            approver_email = ${approverEmail},
            rejection_reason = ${reason}
        WHERE
            id = ${leaveId} AND status = ${PENDING}
    `;

# Query to approve a pending leave request and store its calendar event ID.
#
# + leaveId - ID of the leave record
# + approverEmail - Email of the approver approving the request
# + calendarEventId - ID of the calendar event to be created for the leave
# + return - Update query that only changes the leave while it is pending
isolated function approvePendingLeaveQuery(int leaveId, string approverEmail, string calendarEventId)
    returns sql:ParameterizedQuery => `
        UPDATE
            leave_submissions
        SET
            status = ${APPROVED},
            approver_email = ${approverEmail},
            calendar_event_id = ${calendarEventId}
        WHERE
            id = ${leaveId} AND status = ${PENDING}
    `;

# Query to cancel a pending leave request.
#
# + leaveId - ID of the leave record
# + return - Update query that only changes the leave while it is pending
isolated function cancelPendingLeaveQuery(int leaveId) returns sql:ParameterizedQuery => `
        UPDATE
            leave_submissions
        SET
            status = ${CANCELLED}
        WHERE
            id = ${leaveId} AND status = ${PENDING}
    `;

# Query to get the end date of the last approved sabbatical leave for an employee.
#
# + employeeEmail - Email of the employee
# + return - Query to get the end date of the last sabbatical leave
isolated function getLastSabbaticalLeaveEndDateQuery(string employeeEmail) returns sql:ParameterizedQuery => `
        SELECT 
            end_date
        FROM 
            leave_submissions
        WHERE 
            email = ${employeeEmail} AND leave_type = ${SABBATICAL_LEAVE} AND status = ${APPROVED}
        ORDER BY 
            end_date DESC
        LIMIT 1
    `;

# Query to get subordinates count on sabbatical leave.
#
# + leadEmail - Email of the lead
# + return - Select query to get count of subordinates on sabbatical leave
isolated function getSubordinateCountOnSabbaticalLeaveQuery(string leadEmail) returns sql:ParameterizedQuery => `
        SELECT 
            COUNT(id)
        FROM 
            leave_submissions
        WHERE
            approver_email = ${leadEmail} AND status = ${APPROVED} AND leave_type = ${SABBATICAL_LEAVE} AND
            start_date <= UTC_TIMESTAMP() AND end_date >= UTC_TIMESTAMP()
    `;

# Query to get most recent email notification recipient list (general leave) for a leave applicant.
#
# + applicantEmail - Email of the leave applicant
# + return - Select query to get email notification list
isolated function getEmailNotificationRecipientListQuery(string applicantEmail) returns sql:ParameterizedQuery => `
        SELECT
            copy_email_list
        FROM
            leave_submissions
        WHERE 
            email = ${applicantEmail} AND leave_type <> ${SABBATICAL_LEAVE}
        ORDER BY
            created_date DESC
        LIMIT 1
    `;

# Query to set the calendar event ID for a sabbatical leave record.
#
# + leaveId - Leave ID
# + calendarEventId - Calendar event ID
# + return - Update query to set calendar event ID
isolated function setSabbaticalLeaveCalendarEventIdQuery(int leaveId, string calendarEventId)
    returns sql:ParameterizedQuery => `
        UPDATE 
            leave_submissions
        SET 
            calendar_event_id = ${calendarEventId}
        WHERE
            id = ${leaveId}
    `;
