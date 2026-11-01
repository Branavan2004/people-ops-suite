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

import people_scheduler.database;

import ballerina/http;
import ballerina/log;
import ballerina/time;

# Send a summary email listing the scheduled changes this sweep processed.
#
# Superseded and failed changes are reported alongside applied ones. A change that did
# not happen is the item someone needs to act on, so leaving it out of the summary would
# hide the only signal that a planned change was dropped.
#
# + outcomes - What the sweep did with each due change (must be non-empty)
# + return - Error if the email notification fails to send
public isolated function notifyScheduledChanges(database:ScheduledChangeOutcome[] outcomes)
    returns error? {

    [string, string] [summaryDate, heading] = summaryDateAndHeading(
            from database:ScheduledChangeOutcome o in outcomes select o.effectiveDate,
            from database:ScheduledChangeOutcome o in outcomes select o.workLocation);

    map<string> keyValues = {
        APP_NAME: appName,
        SUMMARY_DATE: summaryDate,
        COUNT: outcomes.length().toString(),
        EMPLOYEE_LIST: buildScheduledChangeRows(outcomes),
        YEAR: time:utcToCivil(time:utcNow()).year.toString()
    };

    string|error boundTemplate = bindKeyValues(scheduledChangeSummaryTemplate, keyValues);
    if boundTemplate is error {
        log:printError("Failed to bind email template for scheduled change summary notification",
                boundTemplate);
        return boundTemplate;
    }

    int notApplied = 0;
    foreach database:ScheduledChangeOutcome outcome in outcomes {
        if outcome.status != database:SCHEDULED_CHANGE_APPLIED {
            notApplied += 1;
        }
    }

    // The subject leads with what needs attention: a run where everything applied is
    // information, one where something did not is a prompt to go and look.
    string subject = notApplied > 0
        ? string `Scheduled Changes (${heading}): ${outcomes.length()} processed, ${notApplied} need attention`
        : string `Scheduled Changes (${heading}): ${outcomes.length()} applied`;

    string[] recipients = emailServiceConfig.scheduledChangeRecipients;

    EmailPayload emailPayload = {
        to: recipients,
        'from: emailServiceConfig.'from,
        subject,
        template: boundTemplate
    };

    log:printInfo("Sending scheduled change summary email", count = outcomes.length(),
            recipientCount = recipients.length());

    http:Response|http:ClientError response = emailClient->/send\-email.post(emailPayload);
    if response is http:ClientError {
        string customError = "Client Error occurred while sending the scheduled change summary email!";
        log:printError(customError, response);
        return error(customError);
    }
    if response.statusCode != http:STATUS_OK {
        string customError = string `Error occurred while sending the scheduled change summary email! - HTTP ${response.statusCode}`;
        json|error responseBody = response.getJsonPayload();
        log:printError(customError,
                responseBody = responseBody is json ? responseBody.toJsonString() : responseBody.message());
        return error(customError);
    }
    log:printInfo(string `Scheduled change summary email sent for ${summaryDate} with ${outcomes.length()} change(s)`);
}

# Build the table rows for the scheduled change summary.
#
# Ordered so anything that did not apply is read first: an applied change is a record,
# a superseded or failed one is work for somebody.
#
# + outcomes - What the sweep did with each due change
# + return - HTML table rows
isolated function buildScheduledChangeRows(database:ScheduledChangeOutcome[] outcomes)
    returns string {

    database:ScheduledChangeOutcome[] sorted = from database:ScheduledChangeOutcome o in outcomes
        order by o.status == database:SCHEDULED_CHANGE_APPLIED ? 1 : 0 ascending, o.employeeId ascending
        select o;

    string cellBase = "padding:10px 12px; border-bottom:1px solid #eef1f4; vertical-align:top;";
    string rows = "";

    foreach database:ScheduledChangeOutcome outcome in sorted {
        string statusColour = outcome.status == database:SCHEDULED_CHANGE_APPLIED
            ? "#2e7d32"
            : (outcome.status == database:SCHEDULED_CHANGE_SUPERSEDED ? "#a06000" : "#c62828");
        string detail = outcome.failureReason ?: string:'join(", ", ...outcome.fields);

        rows += string `<tr>` +
            string `<td style="${cellBase} font-size:13px; color:#2b3844;">${escapeHtml(outcome.employeeId)}</td>` +
            string `<td style="${cellBase} font-size:13px; color:#2b3844;">${escapeHtml(outcome.employeeName)}</td>` +
            string `<td style="${cellBase} font-size:13px; color:#2b3844;">` +
            string `${escapeHtml(database:locationLabel(outcome.workLocation, outcome.timeZone))}</td>` +
            string `<td style="${cellBase} font-size:13px; color:#5a6b7b; white-space:nowrap;">${escapeHtml(outcome.effectiveDate)}</td>` +
            string `<td style="${cellBase} font-size:13px;">` +
            string `<span style="color:${statusColour}; font-weight:bold;">${outcome.status}</span>` +
            string `<div style="color:#7a8899; font-size:12px; margin-top:2px;">${escapeHtml(detail)}</div>` +
            string `</td></tr>`;
    }

    return rows;
}

# Make a value safe to place inside the summary's HTML.
#
# The detail column carries raw failure text — a database message, not something written
# for display — and a stray angle bracket in it would be read as markup and swallow the
# rest of the table. That would take out the one place a superseded or failed change is
# reported, which is the reason the email exists.
#
# Ampersand first: escaping it after the others would re-escape the entities they wrote.
#
# + value - The value to place in the HTML
# + return - The value with HTML's special characters replaced by entities
isolated function escapeHtml(string value) returns string {
    string escaped = re `&`.replaceAll(value, "&amp;");
    escaped = re `<`.replaceAll(escaped, "&lt;");
    escaped = re `>`.replaceAll(escaped, "&gt;");
    escaped = re `"`.replaceAll(escaped, "&quot;");
    return escaped;
}
