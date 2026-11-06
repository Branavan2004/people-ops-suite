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

# Leave type value for Compassionate Leave.
public const COMPASSIONATE = "compassionate";

# Leave type value for Other Authorized Leave.
public const OTHER_AUTHORIZED = "other_authorized";

# Leave type value for Sick Leave.
public const SICK = "sick";

# Leave type value for Sabbatical Leave.
const SABBATICAL = "sabbatical";

# Employee location for which the France-only rules apply.
public const FRANCE = "France";

# Maximum length of a rejection reason, in characters.
public const MAX_REJECTION_REASON_LENGTH = 500;

# Status of a request that is awaiting a decision.
const STATUS_PENDING = "PENDING";

# Status of a request that has been approved.
const STATUS_APPROVED = "APPROVED";

# Check whether an employee may apply for the given leave type at their location.
#
# + leaveType - Leave type value
# + location - Employee location, if known
# + return - An error if the leave type is France-only and the employee is not in France
public isolated function checkLeaveTypeAllowed(string leaveType, string? location) returns error? {
    if (leaveType == COMPASSIONATE || leaveType == OTHER_AUTHORIZED) && location != FRANCE {
        return error("Compassionate Leave and Other Authorized Leave are only available to employees in France.");
    }
}

# Check whether a leave type needs the lead's approval.
#
# + leaveType - Leave type value
# + return - True only for Other Authorized Leave
public isolated function needsLeadApproval(string leaveType) returns boolean {
    return leaveType == OTHER_AUTHORIZED;
}

# Check that a leave request carries the reason its type requires. The lead decides Other Authorized Leave on this
# reason, so it must not be blank.
#
# + leaveType - Leave type value
# + comment - Comment entered by the employee
# + return - An error if the leave type is Other Authorized Leave and the comment is blank
public isolated function checkCommentGiven(string leaveType, string? comment) returns error? {
    if leaveType == OTHER_AUTHORIZED && (comment ?: "").trim().length() == 0 {
        return error("A reason is required for Other Authorized Leave.");
    }
}

# Check whether a leave type requires a sick note at the given location.
#
# + leaveType - Leave type value
# + location - Employee location, if known
# + return - True only for Sick Leave taken by an employee in France
public isolated function requiresSickNote(string leaveType, string? location) returns boolean {
    return leaveType == SICK && location == FRANCE;
}

# Check whether a leave request blocks other leave from overlapping its dates.
#
# + leaveType - Leave type value
# + status - Leave request status
# + return - True for approved requests and for pending requests other than Sabbatical Leave
public isolated function isBlockingLeave(string leaveType, string status) returns boolean {
    if status == STATUS_APPROVED {
        return true;
    }
    return status == STATUS_PENDING && leaveType != SABBATICAL;
}

# Check whether a leave request can still be approved or rejected.
#
# + status - Leave request status
# + return - An error if the request is not pending
public isolated function checkDecidable(string status) returns error? {
    if status != STATUS_PENDING {
        return error("This request is no longer pending.");
    }
}

# Trim and validate a rejection reason.
#
# + reason - Reason supplied by the approver
# + return - The trimmed reason, or an error if it is blank or longer than the maximum length
public isolated function normaliseRejectionReason(string? reason) returns string|error {
    string trimmed = (reason ?: "").trim();
    if trimmed.length() == 0 {
        return error("A reason is required to reject this request.");
    }
    if trimmed.length() > MAX_REJECTION_REASON_LENGTH {
        return error(string `The reason can be at most ${MAX_REJECTION_REASON_LENGTH} characters.`);
    }
    return trimmed;
}
