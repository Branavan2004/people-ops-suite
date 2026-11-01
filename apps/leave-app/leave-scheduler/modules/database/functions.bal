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

# Fetch approved sabbatical leaves that are due for their reminder email.
#
# + today - Today's date (yyyy-mm-dd)
# + windowEnd - Last start date inside the reminder window (yyyy-mm-dd)
# + return - Leaves due for a reminder, or an error
public isolated function getDueSabbaticalReminders(string today, string windowEnd)
    returns SabbaticalReminder[]|error {

    stream<SabbaticalReminder, error?> resultStream =
        databaseClient->query(getDueSabbaticalRemindersQuery(today, windowEnd));
    return from SabbaticalReminder reminder in resultStream
        select reminder;
}

# Record that the reminder for a sabbatical leave has been sent.
#
# + leaveId - Leave id
# + return - Error if the update fails
public isolated function markSabbaticalReminderSent(int leaveId) returns error? {
    sql:ExecutionResult result = check databaseClient->execute(markSabbaticalReminderSentQuery(leaveId));
    if result.affectedRowCount == 0 {
        return error(string `Reminder was already marked as sent for leave id: ${leaveId}`);
    }
}
