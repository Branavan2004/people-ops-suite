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

# Work email the backend stores for a joiner whose account does not exist yet. Kept in step with
# the backend's FUTURE_JOINER_EMAIL; this package cannot import it.
const string FUTURE_JOINER_EMAIL = "future-joiner@wso2.com";

# Send a summary email listing employees auto-transitioned from New joiner to Active, calling out
# the ones still on the placeholder work email so HR can add their real one.
#
# + activations - Employees that were activated during this sweep (must be non-empty)
# + return - Error if the email notification fails to send
public isolated function notifyJoinerActivation(database:JoinerActivation[] activations) returns error? {
    [string, string] [summaryDate, heading] = summaryDateAndHeading(
            from database:JoinerActivation a in activations select a.startDate,
            from database:JoinerActivation a in activations select a.workLocation);

    map<string> keyValues = {
        APP_NAME: appName,
        SUMMARY_DATE: summaryDate,
        COUNT: activations.length().toString(),
        PENDING_EMAIL_NOTE: buildPendingEmailNote(activations),
        EMPLOYEE_LIST: buildActivationRows(activations),
        YEAR: time:utcToCivil(time:utcNow()).year.toString()
    };

    string|error boundTemplate = bindKeyValues(joinerActivationSummaryTemplate, keyValues);
    if boundTemplate is error {
        log:printError("Failed to bind email template for joiner activation summary notification",
                boundTemplate);
        return boundTemplate;
    }

    string[] recipients = emailServiceConfig.joinerActivationRecipients;

    EmailPayload emailPayload = {
        to: recipients,
        'from: emailServiceConfig.'from,
        subject: string `Employee Onboarding Alert (${heading}): ` +
            string `${activations.length()} employee(s) transitioned to Active`,
        template: boundTemplate
    };

    log:printInfo("Sending joiner activation summary email", count = activations.length(),
            recipientCount = recipients.length());

    http:Response|http:ClientError response = emailClient->/send\-email.post(emailPayload);
    if response is http:ClientError {
        string customError = "Client Error occurred while sending the joiner activation summary email!";
        log:printError(customError, response);
        return error(customError);
    }
    if response.statusCode != http:STATUS_OK {
        string customError = string `Error occurred while sending the joiner activation summary email! - HTTP ${response.statusCode}`;
        json|error responseBody = response.getJsonPayload();
        log:printError(customError, responseBody = responseBody is json ? responseBody.toJsonString() : responseBody.message());
        return error(customError);
    }
    log:printInfo(string `Joiner activation summary email sent for ${summaryDate}` +
            string ` with ${activations.length()} joiner(s)`);
}

# Whether an activated employee is still on the placeholder work email.
#
# + activation - Activated employee
# + return - true when their work email is the future-joiner placeholder
isolated function isPendingWorkEmail(database:JoinerActivation activation) returns boolean =>
    activation.workEmail.trim().toLowerAscii() == FUTURE_JOINER_EMAIL;

# Build the banner naming the activated employees still on the placeholder work email, or an
# empty string when every one of them has a real email.
#
# + activations - Employees that were activated during this sweep
# + return - HTML banner, safe to inject into the template
isolated function buildPendingEmailNote(database:JoinerActivation[] activations) returns string {
    string[] pendingIds = from database:JoinerActivation a in activations
        where isPendingWorkEmail(a)
        order by a.employeeId ascending
        select htmlEscape(a.employeeId);
    if pendingIds.length() == 0 {
        return "";
    }
    return string `<table width="100%" cellpadding="0" cellspacing="0" style="margin-top:16px;"><tbody><tr>` +
        string `<td style="background-color:#fff4e5; border-left:4px solid #ff9800; padding:14px 16px;` +
        string ` border-radius:4px;"><p style="margin:0; font-family:'Roboto', Helvetica, sans-serif;` +
        string ` font-size:14px; color:#6b4500;"><strong>Action needed</strong> &mdash; ` +
        string `${pendingIds.length()} employee(s) are still on the placeholder work email ` +
        string `<em>${FUTURE_JOINER_EMAIL}</em>. Please update their work email in the ` +
        string `${htmlEscape(appName)}: <strong>${string:'join(", ", ...pendingIds)}</strong></p>` +
        string `</td></tr></tbody></table>`;
}

# Build the `<tbody>` rows for the activated-employees table, latest start date first and
# tie-broken by employee ID so the listing is stable across runs (the underlying query applies
# no ordering of its own). Same-date employees are grouped under a date band.
#
# + activations - Employees that were activated during this sweep
# + return - HTML table rows, safe to inject into the template
isolated function buildActivationRows(database:JoinerActivation[] activations) returns string {
    database:JoinerActivation[] sorted = from database:JoinerActivation a in activations
        order by a.startDate descending, a.employeeId ascending
        select a;

    // Count per start date up front so each date band can state its own total.
    map<int> countsByDate = {};
    foreach database:JoinerActivation a in sorted {
        countsByDate[a.startDate] = (countsByDate[a.startDate] ?: 0) + 1;
    }

    string cellBase = "padding:10px 12px; border-bottom:1px solid #eef1f4; vertical-align:top;";
    string rows = "";
    string currentDate = "";

    foreach database:JoinerActivation a in sorted {
        if a.startDate != currentDate {
            currentDate = a.startDate;
            int dateCount = countsByDate[currentDate] ?: 0;
            rows += string `<tr><td colspan="5" style="padding:9px 16px; background-color:#eef2f6;` +
                string ` border-top:1px solid #d8dfe6; border-bottom:1px solid #d8dfe6; font-size:13px;` +
                string ` font-weight:bold; color:#33455c;">` +
                string `${htmlEscape(formatDisplayDate(currentDate))} <span style="font-weight:normal; color:#6b7a8c;">` +
                string `(${dateCount})</span></td></tr>`;
        }
        string emailCell = isPendingWorkEmail(a)
            ? string `<span style="color:#b26a00; font-weight:bold;">Work email pending</span>`
            : htmlEscape(a.workEmail);
        rows += string `<tr>` +
            string `<td style="${cellBase} padding-left:16px; white-space:nowrap;">${htmlEscape(a.employeeId)}</td>` +
            string `<td style="${cellBase}">${htmlEscape(a.firstName)} ${htmlEscape(a.lastName)}</td>` +
            string `<td style="${cellBase}">${emailCell}</td>` +
            string `<td style="${cellBase}">${htmlEscape(database:locationLabel(a.workLocation, a.timeZone))}</td>` +
            string `<td align="right" style="${cellBase} padding-right:16px; white-space:nowrap;` +
            string ` color:#7a8899;">${htmlEscape(formatDisplayDate(a.startDate))}</td>` +
            string `</tr>`;
    }
    return rows;
}
