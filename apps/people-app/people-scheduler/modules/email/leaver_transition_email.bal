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

# Send a summary email listing employees auto-transitioned from Marked leaver to Left.
#
# + transitions - Employees that were transitioned during this sweep (must be non-empty)
# + return - Error if the email notification fails to send
public isolated function notifyLeaverAutoTransition(database:LeaverTransition[] transitions) returns error? {
    string employeeListHtml = buildTransitionRows(transitions);

    [string, string] [summaryDate, heading] = summaryDateAndHeading(
            from database:LeaverTransition t in transitions select t.finalDayOfEmployment,
            from database:LeaverTransition t in transitions select t.workLocation);

    map<string> keyValues = {
        APP_NAME: appName,
        SUMMARY_DATE: summaryDate,
        COUNT: transitions.length().toString(),
        EMPLOYEE_LIST: employeeListHtml,
        YEAR: time:utcToCivil(time:utcNow()).year.toString()
    };

    string|error boundTemplate = bindKeyValues(leaverAutoTransitionSummaryTemplate, keyValues);
    if boundTemplate is error {
        log:printError("Failed to bind email template for leaver auto-transition summary notification",
                boundTemplate);
        return boundTemplate;
    }

    string[] recipients = emailServiceConfig.leaverTransitionRecipients;

    EmailPayload emailPayload = {
        to: recipients,
        'from: emailServiceConfig.'from,
        subject: string `Employee Offboarding Alert (${heading}): ` +
            string `${transitions.length()} employee(s) transitioned to Left`,
        template: boundTemplate
    };

    log:printInfo("Sending leaver auto-transition summary email", count = transitions.length(),
            recipientCount = recipients.length());

    http:Response|http:ClientError response = emailClient->/send\-email.post(emailPayload);
    if response is http:ClientError {
        string customError = "Client Error occurred while sending the leaver auto-transition summary email!";
        log:printError(customError, response);
        return error(customError);
    }
    if response.statusCode != http:STATUS_OK {
        string customError = string `Error occurred while sending the leaver auto-transition summary email! - HTTP ${response.statusCode}`;
        json|error responseBody = response.getJsonPayload();
        log:printError(customError, responseBody = responseBody is json ? responseBody.toJsonString() : responseBody.message());
        return error(customError);
    }
    log:printInfo(string `Leaver auto-transition summary email sent for ${summaryDate}` +
            string ` with ${transitions.length()} leaver(s)`);
}

# Build the `<tbody>` rows for the transitioned-employees table, latest final day of employment
# first and tie-broken by employee ID so the listing is stable across runs (the underlying query
# applies no ordering of its own). Same-date employees are grouped under a date band.
#
# + transitions - Employees that were transitioned during this sweep
# + return - HTML table rows, safe to inject into the template
isolated function buildTransitionRows(database:LeaverTransition[] transitions) returns string {
    database:LeaverTransition[] sorted = from database:LeaverTransition t in transitions
        order by t.finalDayOfEmployment descending, t.employeeId ascending
        select t;

    // Count per final day up front so each date band can state its own total.
    map<int> countsByDate = {};
    foreach database:LeaverTransition t in sorted {
        countsByDate[t.finalDayOfEmployment] = (countsByDate[t.finalDayOfEmployment] ?: 0) + 1;
    }

    string cellBase = "padding:10px 12px; border-bottom:1px solid #eef1f4; vertical-align:top;";
    string rows = "";
    string currentDate = "";

    foreach database:LeaverTransition t in sorted {
        if t.finalDayOfEmployment != currentDate {
            currentDate = t.finalDayOfEmployment;
            int dateCount = countsByDate[currentDate] ?: 0;
            rows += string `<tr><td colspan="5" style="padding:9px 16px; background-color:#eef2f6;` +
                string ` border-top:1px solid #d8dfe6; border-bottom:1px solid #d8dfe6; font-size:13px;` +
                string ` font-weight:bold; color:#33455c;">` +
                string `${htmlEscape(formatDisplayDate(currentDate))} <span style="font-weight:normal; color:#6b7a8c;">` +
                string `(${dateCount})</span></td></tr>`;
        }
        rows += string `<tr>` +
            string `<td style="${cellBase} padding-left:16px; white-space:nowrap;">${htmlEscape(t.employeeId)}</td>` +
            string `<td style="${cellBase}">${htmlEscape(t.firstName)} ${htmlEscape(t.lastName)}</td>` +
            string `<td style="${cellBase}">${htmlEscape(t.workEmail)}</td>` +
            string `<td style="${cellBase}">${htmlEscape(database:locationLabel(t.workLocation, t.timeZone))}</td>` +
            string `<td align="right" style="${cellBase} padding-right:16px; white-space:nowrap;` +
            string ` color:#7a8899;">${htmlEscape(formatDisplayDate(t.finalDayOfEmployment))}</td>` +
            string `</tr>`;
    }
    return rows;
}
