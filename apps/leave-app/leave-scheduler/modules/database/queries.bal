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

# Query to fetch approved sabbatical leaves starting within the reminder window that have not had their
# reminder sent yet. A leave approved after its reminder date is still picked up on the next run.
#
# + today - Today's date (yyyy-mm-dd)
# + windowEnd - Last start date inside the reminder window (yyyy-mm-dd)
# + return - Select query
isolated function getDueSabbaticalRemindersQuery(string today, string windowEnd) returns sql:ParameterizedQuery => `
    SELECT
        id,
        email,
        approver_email,
        DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
        DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date,
        DATEDIFF(DATE(end_date), DATE(start_date)) + 1 AS duration_days
    FROM
        leave_submissions
    WHERE
        leave_type = 'sabbatical'
        AND status = 'APPROVED'
        AND sabbatical_reminder_sent_on IS NULL
        AND DATE(start_date) BETWEEN ${today} AND ${windowEnd}
    ORDER BY
        start_date ASC
`;

# Query to record that the reminder for a sabbatical leave has been sent.
#
# + leaveId - Leave id
# + return - Update query
isolated function markSabbaticalReminderSentQuery(int leaveId) returns sql:ParameterizedQuery => `
    UPDATE
        leave_submissions
    SET
        sabbatical_reminder_sent_on = CURRENT_TIMESTAMP
    WHERE
        id = ${leaveId} AND sabbatical_reminder_sent_on IS NULL
`;
