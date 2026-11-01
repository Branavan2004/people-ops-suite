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

import people.authorization;
import people.database;
import people.promotion;
import people.qr;
import people.wso2_coin;

// Temporarily disabled together with the Asgardeo/SCIM provisioning blocks in the onboarding
// handlers below (see the NOTE there). Re-enable these imports when provisioning is restored.
// import people.email;
// import people.scim;

import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

@display {
    label: "People Service",
    id: "people-ops-suite/people-service"
}
configurable boolean isMaintenanceMode = false;

service class ErrorInterceptor {
    *http:ResponseErrorInterceptor;

    remote function interceptResponseError(error err, http:RequestContext ctx) returns http:BadRequest|error {

        // Handle data-binding errors.
        if err is http:PayloadBindingError {
            string customErr = string `Payload binding failed!`;
            log:printError(customErr, err);
            return {
                body: {
                    message: customErr
                }
            };
        }
        return err;
    }
}

# Whether the caller may use the QR code report.
#
# The QR export role reaches this and nothing else: it grants no visibility of an
# employee profile, so it is checked separately from canReadAnyEmployee rather than
# folded into it.
#
# + userInfo - Invoker's JWT payload
# + return - true when the caller may search for and download QR codes
isolated function canExportQrCodes(authorization:CustomJwtPayload userInfo) returns boolean =>
    authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups)
    || authorization:checkPermissions([authorization:authorizedRoles.SERVICE_DESK_ROLE], userInfo.groups)
    || authorization:checkPermissions([authorization:authorizedRoles.QR_EXPORT_ROLE], userInfo.groups);

# Whether the caller may read any employee's record.
#
# Admins have always been able to; the employee-view role grants the same visibility
# without any ability to change a record. Both are IAM-group-backed, so this is a pure
# group check with no database lookup.
#
# + userInfo - Invoker's JWT payload
# + return - true when the caller may read any employee
isolated function canReadAnyEmployee(authorization:CustomJwtPayload userInfo) returns boolean =>
    authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups)
    || authorization:checkPermissions([authorization:authorizedRoles.EMPLOYEE_VIEW_ROLE], userInfo.groups)
    || authorization:checkPermissions([authorization:authorizedRoles.RESIGNATION_ROLE], userInfo.groups);

service http:InterceptableService / on new http:Listener(9090) {

    # Service initialization.
    function init() {
        log:printInfo("People App backend started...");
    }

    # Request interceptor.
    #
    # + return - authorization:JwtInterceptor, ErrorInterceptor
    public function createInterceptors() returns http:Interceptor[] =>
        [new authorization:JwtInterceptor(), new ErrorInterceptor()];

    # Get global app config.
    #
    # + return - App config
    resource function get configs() returns AppConfig {
        return {isMaintenanceMode};
    }

    # Get user information.
    #
    # + return - User information or http errors
    resource function get user\-info(http:RequestContext ctx)
        returns database:UserInfo|http:InternalServerError|http:NotFound {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        database:EmployeeBasicInfo|error? employeeBasicInfo = database:getEmployeeBasicInfo(userInfo.email);
        if employeeBasicInfo is error {
            string customErr = string `Error occurred while fetching employee basic information`;
            log:printError(customErr, employeeBasicInfo, email = userInfo.email);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        if employeeBasicInfo is () {
            string customErr = "Employee basic information not found";
            log:printWarn(customErr, user = userInfo.email);
            return <http:NotFound>{
                body: {
                    message: customErr
                }
            };
        }

        int[] privileges = [];
        if authorization:checkPermissions([authorization:authorizedRoles.EMPLOYEE_ROLE], userInfo.groups) {
            privileges.push(authorization:EMPLOYEE_PRIVILEGE);
        }
        if authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            privileges.push(authorization:ADMIN_PRIVILEGE);
        }
        if authorization:checkPermissions([authorization:authorizedRoles.SERVICE_DESK_ROLE], userInfo.groups) {
            privileges.push(authorization:SERVICE_DESK_PRIVILEGE);
        }
        if authorization:checkPermissions([authorization:authorizedRoles.EMPLOYEE_VIEW_ROLE], userInfo.groups) {
            privileges.push(authorization:EMPLOYEE_VIEW_PRIVILEGE);
        }
        if authorization:checkPermissions([authorization:authorizedRoles.RESIGNATION_ROLE], userInfo.groups) {
            privileges.push(authorization:RESIGNATION_PRIVILEGE);
        }
        if authorization:checkPermissions([authorization:authorizedRoles.QR_EXPORT_ROLE], userInfo.groups) {
            privileges.push(authorization:QR_EXPORT_PRIVILEGE);
        }
        boolean|error isLeadUser = database:isLead(userInfo.email);
        if isLeadUser is error {
            string customErr = "Error occurred while checking lead status";
            log:printError(customErr, isLeadUser, email = userInfo.email);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        if isLeadUser {
            privileges.push(authorization:LEAD_PRIVILEGE);
        }
        return {...employeeBasicInfo, privileges};
    }

    # Validate EPF uniqueness.
    #
    # + payload - EPF validation payload
    # + return - Whether the EPF already exists, or HTTP errors
    resource function post employees/validate\-epf(http:RequestContext ctx, database:EpfValidationPayload payload)
        returns database:EpfValidationResponse|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("User is not authorized to validate EPF", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {
                    message: "You are not authorized to validate EPF"
                }
            };
        }

        string trimmedEpf = payload.epf.trim();
        if trimmedEpf == "" {
            string customErr = "EPF validation failed: EPF cannot be empty";
            log:printWarn(customErr);
            return <http:BadRequest>{
                body: {
                    message: customErr
                }
            };
        }

        string|error? employeeId = database:getEmployeeIdByEpf(trimmedEpf);
        if employeeId is error {
            string customErr = "Error occurred while validating EPF uniqueness";
            log:printError(customErr, employeeId, epf = trimmedEpf);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }

        return {epfExists: employeeId is string};
    }

    # Recognise a returning employee from the NIC/Passport on the onboarding form, so the form
    # can say who they are and fill in the work email a rehire has to use. Creating the employee
    # applies the same rules again; this only lets the form show them before submitting.
    #
    # + payload - NIC/Passport to look up
    # + return - The person's latest employment and former work email, or HTTP errors
    resource function post employees/returning\-employee(http:RequestContext ctx,
            database:ReturningEmployeeLookupPayload payload)
        returns database:ReturningEmployeeLookupResponse|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("User is not authorized to look up returning employees", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {
                    message: "You are not authorized to look up returning employees"
                }
            };
        }

        string nicOrPassport = payload.nicOrPassport.trim();
        if nicOrPassport == "" {
            string customErr = "NIC/Passport cannot be empty";
            log:printWarn(customErr);
            return <http:BadRequest>{
                body: {
                    message: customErr
                }
            };
        }

        database:EmploymentMatch[]|error employments = database:getEmploymentsByNic(nicOrPassport);
        if employments is error {
            string customErr = "Error occurred while looking up the returning employee";
            log:printError(customErr, employments);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }

        database:EmploymentMatch[] withRealEmail =
            employments.filter(e => !database:isPlaceholderWorkEmail(e.workEmail));
        return {
            latestEmployment: employments.length() > 0 ? employments[0] : (),
            isCurrentEmployee: employments.some(e => database:isCurrentEmploymentStatus(e.employeeStatus)),
            formerWorkEmail: withRealEmail.length() > 0 ? withRealEmail[0].workEmail : ()
        };
    }

    # Fetch employee detailed information.
    #
    # + employeeId - Employee ID
    # + return - Employee detailed information
    resource function get employees/[string employeeId](http:RequestContext ctx)
        returns database:Employee|http:InternalServerError|http:NotFound|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        database:Employee|error? employeeInfo = database:getEmployeeInfo(employeeId);
        if employeeInfo is error {
            string customErr = string `Error occurred while fetching employee information for ID: ${employeeId}`;
            log:printError(customErr, employeeInfo, employeeId = employeeId);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }

        boolean hasAdminAccess = canReadAnyEmployee(userInfo);
        boolean isSelf = employeeInfo != () && employeeInfo.workEmail == userInfo.email;
        if !hasAdminAccess && !isSelf {
            boolean|error isSubordinate = database:isSubordinateOfLead(userInfo.email, employeeId);
            if isSubordinate is error {
                string customErr = string `Error occurred while checking lead authorization for ID: ${employeeId}`;
                log:printError(customErr, isSubordinate, employeeId = employeeId);
                return <http:InternalServerError>{body: {message: customErr}};
            }
            if !isSubordinate {
                log:printWarn("User is not authorized to view this employee's information", invokerEmail = userInfo.email);
                return <http:Forbidden>{body: {message: "You are not authorized to view this employee's information"}};
            }
        }

        if employeeInfo is () {
            string customErr = "Employee information not found";
            log:printWarn(customErr, employeeId = employeeId);
            return <http:NotFound>{body: {message: customErr}};
        }

        int[]|error heldGroups = database:getEmployeeLeadershipIds(employeeId);
        if heldGroups is error {
            log:printError("Error fetching leadership attributes", heldGroups);
            return <http:InternalServerError>{body: {message: "Error fetching employee"}};
        }
        employeeInfo.leadershipGroupIds = heldGroups;

        return employeeInfo;
    }

    # Fetch how a member of the caller's team is linked to them.
    #
    # + employeeId - Employee ID of the team member
    # + return - Reporting line, or Forbidden when the employee is not in the caller's chain
    resource function get employees/[string employeeId]/reporting\-line(http:RequestContext ctx)
        returns database:ReportingLine|http:InternalServerError|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        database:ReportingLine|error? reportingLine = database:getReportingLine(userInfo.email, employeeId);
        if reportingLine is error {
            string customErr = string `Error occurred while fetching the reporting line for ID: ${employeeId}`;
            log:printError(customErr, reportingLine, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        if reportingLine is () {
            log:printWarn("Employee is not in the caller's team", invokerEmail = userInfo.email,
                    employeeId = employeeId);
            return <http:Forbidden>{body: {message: "This employee is not in your team"}};
        }
        return reportingLine;
    }

    # Fetch employee personal information.
    #
    # + employeeId - Employee ID
    # + return - Employee personal information
    resource function get employees/[string employeeId]/personal\-info(http:RequestContext ctx)
        returns database:EmployeePersonalInfo|http:InternalServerError|http:NotFound|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        database:Employee|error? employeeInfo = database:getEmployeeInfo(employeeId);
        if employeeInfo is error {
            string customErr = string `Error occurred while fetching employee information for ID: ${employeeId}`;
            log:printError(customErr, employeeInfo, employeeId = employeeId);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }

        // Personal information is admin-or-self only. A lead legitimately sees a subordinate's
        // work details through the sibling employee endpoint, but personal_info carries
        // NIC/passport, date of birth, gender, home address, personal contact details and
        // emergency contacts — none of which a lead needs in order to manage someone. Unlike the
        // history endpoint there is no lead projection here: the whole record is withheld.
        boolean hasAdminAccess = canReadAnyEmployee(userInfo);
        boolean isSelf = employeeInfo != () && employeeInfo.workEmail == userInfo.email;
        if !hasAdminAccess && !isSelf {
            log:printWarn("User is not authorized to view this employee's personal information",
                    invokerEmail = userInfo.email, employeeId = employeeId);
            return <http:Forbidden>{body: {message: "You are not authorized to view this employee's information"}};
        }

        if employeeInfo is () {
            string customErr = "Employee information not found";
            log:printWarn(customErr, employeeId = employeeId);
            return <http:NotFound>{body: {message: customErr}};
        }

        database:EmployeePersonalInfo|error? employeePersonalInfo = database:getEmployeePersonalInfo(employeeId);
        if employeePersonalInfo is error {
            string customErr = string `Error occurred while fetching employee personal information for ID: ${employeeId}`;
            log:printError(customErr, employeePersonalInfo, employeeId = employeeId);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        if employeePersonalInfo is () {
            string customErr = "Employee personal information not found";
            log:printWarn(customErr, employeeId = employeeId);
            return <http:NotFound>{
                body: {
                    message: customErr
                }
            };
        }
        return employeePersonalInfo;
    }

    # Generate a QR code PNG for a single employee.
    # Non-admins may only request their own QR code or that of a subordinate.
    #
    # + employeeId - Employee ID to generate QR for
    # + return - PNG binary, or HTTP errors
    resource function get employees/[string employeeId]/qr\-code(http:RequestContext ctx)
            returns byte[]|http:Forbidden|http:BadRequest|http:NotFound|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        boolean hasQrExportAccess = canExportQrCodes(userInfo);

        database:Employee|error? employee = database:getEmployeeInfo(employeeId);
        if employee is error {
            string customErr = string `Error fetching employee: ${employeeId}`;
            log:printError(customErr, employee, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        if employee is () {
            return <http:NotFound>{body: {message: string `Employee not found: ${employeeId}`}};
        }

        if !hasQrExportAccess {
            boolean isSelf = employee.workEmail == userInfo.email;
            if !isSelf {
                boolean|error isSubordinate = database:isSubordinateOfLead(userInfo.email, employeeId);
                if isSubordinate is error {
                    string customErr = string `Error checking authorization for employee: ${employeeId}`;
                    log:printError(customErr, isSubordinate, employeeId = employeeId);
                    return <http:InternalServerError>{body: {message: customErr}};
                }
                if !isSubordinate {
                    log:printWarn("User is not authorized to generate QR for this employee",
                            invokerEmail = userInfo.email);
                    return <http:Forbidden>{
                        body: {message: "You are not authorized to generate a QR code for this employee"}
                    };
                }
            }
        }

        string? house = employee.house;
        if house is () {
            return <http:BadRequest>{
                body: {
                    message: string `Employee ${employeeId} has no house assigned`
                }
            };
        }

        byte[]|error imageBytes = qr:generateEmployeeQrCode({
                                                                employeeNumber: employee.employeeId,
                                                                firstName: employee.firstName,
                                                                lastName: employee.lastName,
                                                                house
                                                            });
        if imageBytes is error {
            string customErr = "Error occurred while generating QR code";
            log:printError(customErr, imageBytes);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return imageBytes;
    }

    # Fetch managers.
    #
    # + return - List of managers or error response
    resource function get employees/managers(http:RequestContext ctx)
        returns database:Manager[]|http:InternalServerError|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        boolean hasAdminAccess = canReadAnyEmployee(userInfo);

        if !hasAdminAccess {
            boolean|error isLeadUser = database:isLead(userInfo.email);
            if isLeadUser is error {
                string customErr = "Error occurred while checking lead status";
                log:printError(customErr, isLeadUser, email = userInfo.email);
                return <http:InternalServerError>{body: {message: customErr}};
            }
            if !isLeadUser {
                log:printWarn("User is not authorized to view managers", invokerEmail = userInfo.email);
                return <http:Forbidden>{body: {message: "You are not authorized to view managers"}};
            }
        }

        database:Manager[]|error managers = database:getManagers();
        if managers is error {
            string customErr = "Error occurred while fetching managers";
            log:printError(customErr, managers);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return managers;
    }

    # Fetch employees based on filters.
    #
    # + payload - Get employees filter payload
    # + return - List of employees or error response
    resource function post employees/search(http:RequestContext ctx, database:EmployeeSearchPayload payload)
        returns http:Ok|http:InternalServerError|http:BadRequest|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        boolean hasAdminAccess = canReadAnyEmployee(userInfo);

        string sortField = payload.sort.sortField;
        if !database:EmployeeSortField.hasKey(sortField) {
            string customErr = string `Invalid sort field ${sortField}`;
            log:printWarn(customErr, sortField = sortField);
            return <http:BadRequest>{
                body: {
                    message: customErr
                }
            };
        }

        string sortOrder = payload.sort.sortOrder;
        if !database:SortOrder.hasKey(sortOrder) {
            string customErr = string `Invalid sort order ${sortOrder}`;
            log:printWarn(customErr, sortOrder = sortOrder);
            return <http:BadRequest>{
                body: {
                    message: customErr
                }
            };
        }

        if hasAdminAccess && !payload.leadOnly {
            database:EmployeesResponse|error employees = database:getEmployees(payload, includePersonalInfo = true);
            if employees is error {
                string customErr = "Error occurred while fetching employees";
                log:printError(customErr, employees);
                return <http:InternalServerError>{
                    body: {
                        message: customErr
                    }
                };
            }
            return <http:Ok>{body: employees};
        }

        // Lead path: verify the caller manages at least one employee.
        boolean|error isLeadUser = database:isLead(userInfo.email);
        if isLeadUser is error {
            string customErr = "Error occurred while fetching employees";
            log:printError(customErr, isLeadUser);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        if !isLeadUser {
            log:printWarn("User is not authorized to view employee list", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {
                    message: "You are not authorized to view employee list"
                }
            };
        }

        // Lead: results restricted to their subordinates, and without personal information.
        // A lead sees a subordinate's work details but not their NIC, date of birth, home
        // address or emergency contacts — the same rule the personal-info endpoint states,
        // where the whole record is withheld from a lead rather than projected.
        database:EmployeesResponse|error employees =
            database:getEmployees(payload, userInfo.email);
        if employees is error {
            string customErr = "Error occurred while fetching employees";
            log:printError(customErr, employees);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return <http:Ok>{body: employees};
    }

    # Search employees for QR code export.
    #
    # + payload - QR code search payload
    # + return - Lean employee list for QR export, or HTTP errors
    resource function post reports/qr\-codes/search(http:RequestContext ctx, database:QrCodeSearchPayload payload)
            returns http:Ok|http:InternalServerError|http:BadRequest|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        boolean hasQrSearchAccess = canExportQrCodes(userInfo);

        if !hasQrSearchAccess {
            log:printWarn("User is not authorized to search employees for QR export",
                    invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {message: "You are not authorized to search employees for QR export"}
            };
        }

        if !database:EmployeeSortField.hasKey(payload.sort.sortField) {
            string customErr = "Invalid sort field: " + payload.sort.sortField;
            log:printWarn(customErr, sortField = payload.sort.sortField);
            return <http:BadRequest>{
                body: {message: customErr}
            };
        }

        if !database:SortOrder.hasKey(payload.sort.sortOrder) {
            string customErr = "Invalid sort order: " + payload.sort.sortOrder;
            log:printWarn(customErr, sortOrder = payload.sort.sortOrder);
            return <http:BadRequest>{
                body: {message: customErr}
            };
        }

        database:EmployeesResponse|error result = database:getEmployees({
                                                                            searchString: payload.searchString,
                                                                            filters: {
                                                                                employeeStatus: payload.filters.employeeStatus,
                                                                                startDate: payload.filters.startDate
                                                                            },
                                                                            pagination: payload.pagination,
                                                                            sort: payload.sort
                                                                        });
        if result is error {
            string customErr = "Error occurred while fetching employees for QR export";
            log:printError(customErr, result);
            return <http:InternalServerError>{
                body: {message: customErr}
            };
        }
        database:EmployeeQrInfo[] qrInfoList = from database:Employee e in result.employees
            select {
                employeeId: e.employeeId,
                firstName: e.firstName,
                lastName: e.lastName,
                workEmail: e.workEmail,
                employeeThumbnail: e.employeeThumbnail,
                house: e.house,
                houseId: e.houseId,
                employeeStatus: e.employeeStatus
            };
        return <http:Ok>{
            body: {
                employees: qrInfoList,
                totalCount: result.totalCount
            }
        };
    }

    # Fetch continuous service record by work email.
    #
    # + workEmail - Work email of the employee
    # + return - Employee ID and continuous service record or error response
    resource function get continuous\-service\-records(http:RequestContext ctx, string workEmail)
        returns database:ContinuousServiceRecordInfo[]|http:InternalServerError|http:BadRequest|http:Forbidden {

        if workEmail.trim().length() == 0 {
            string customErr = "Work email is a mandatory query parameter";
            log:printWarn(customErr);
            return <http:BadRequest>{
                body: {
                    message: customErr
                }
            };
        }

        if !database:EMAIL_PATTERN.isFullMatch(workEmail) {
            string customErr = "Invalid work email format";
            log:printWarn(customErr, workEmail = workEmail);
            return <http:BadRequest>{
                body: {
                    message: customErr
                }
            };
        }

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        boolean hasAdminAccess = authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups);
        if !hasAdminAccess {
            log:printWarn("User is not authorized to view continuous service records", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {
                    message: "You are not authorized to view continuous service records"
                }
            };
        }

        database:ContinuousServiceRecordInfo[]|error serviceRecords = database:getContinuousServiceRecordsByEmail(workEmail);
        if serviceRecords is error {
            string customErr = "Error occurred while fetching continuous service records";
            log:printError(customErr, serviceRecords, workEmail = workEmail);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return serviceRecords;
    }

    # Fetch directory information for all currently employed staff (Active and Marked leaver).
    # Available to every authenticated user.
    #
    # + return - Directory information for Active and Marked leaver employees
    resource function get employees/basic\-info(http:RequestContext ctx)
        returns database:EmployeeDirectoryInfo[]|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        database:EmployeeDirectoryInfo[]|error employeesBasicInfos = database:getAllEmployeesBasicInfo();
        if employeesBasicInfos is error {
            string customErr = "Error occurred while fetching employees' basic information";
            log:printError(customErr, employeesBasicInfos);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return employeesBasicInfos;
    }

    # Get business units.
    #
    # + ctx - Request context (used only when `includeInactive=true` to gate admin access)
    # + includeInactive - If true return all including inactive (ADMIN-only)
    # + return - Business units
    resource function get business\-units(http:RequestContext ctx, boolean includeInactive = false)
            returns database:BusinessUnit[]|http:Forbidden|http:InternalServerError {

        if includeInactive {
            authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
            if userInfo is error {
                log:printError(ERROR_USER_INFORMATION_HEADER_NOT_FOUND, userInfo);
                return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
            }
            if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
                log:printWarn("Unauthorized attempt to fetch inactive business units",
                        invokerEmail = userInfo.email);
                return <http:Forbidden>{
                    body: {message: "You are not authorized to view inactive business units"}
                };
            }
        }

        database:BusinessUnit[]|error businessUnits = database:getBusinessUnits(includeInactive);
        if businessUnits is error {
            string customErr = "Error while fetching Business Units";
            log:printError(customErr, businessUnits);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return businessUnits;
    }

    # Get teams.
    #
    # + ctx - Request context (used only when `includeInactive=true` to gate admin access)
    # + buId - Business unit ID (optional)
    # + includeInactive - If true return all including inactive (ADMIN-only)
    # + return - Teams
    resource function get teams(http:RequestContext ctx, int? buId = (), boolean includeInactive = false)
            returns database:Team[]|http:Forbidden|http:InternalServerError {

        if includeInactive {
            authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
            if userInfo is error {
                log:printError(ERROR_USER_INFORMATION_HEADER_NOT_FOUND, userInfo);
                return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
            }
            if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
                log:printWarn("Unauthorized attempt to fetch inactive teams",
                        invokerEmail = userInfo.email);
                return <http:Forbidden>{
                    body: {message: "You are not authorized to view inactive teams"}
                };
            }
        }

        database:Team[]|error teams = database:getTeams(buId, includeInactive);
        if teams is error {
            string customErr = "Error while fetching Teams";
            log:printError(customErr, teams);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return teams;
    }

    # Get sub teams.
    #
    # + ctx - Request context (used only when `includeInactive=true` to gate admin access)
    # + teamId - Team ID (optional)
    # + includeInactive - If true return all including inactive (ADMIN-only)
    # + return - Sub teams
    resource function get sub\-teams(http:RequestContext ctx, int? teamId = (), boolean includeInactive = false)
            returns database:SubTeam[]|http:Forbidden|http:InternalServerError {

        if includeInactive {
            authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
            if userInfo is error {
                log:printError(ERROR_USER_INFORMATION_HEADER_NOT_FOUND, userInfo);
                return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
            }
            if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
                log:printWarn("Unauthorized attempt to fetch inactive sub-teams",
                        invokerEmail = userInfo.email);
                return <http:Forbidden>{
                    body: {message: "You are not authorized to view inactive sub-teams"}
                };
            }
        }

        database:SubTeam[]|error subTeams = database:getSubTeams(teamId, includeInactive);
        if subTeams is error {
            string customErr = "Error while fetching Sub Teams";
            log:printError(customErr, subTeams);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return subTeams;
    }

    # Get units.
    #
    # + ctx - Request context (used only when `includeInactive=true` to gate admin access)
    # + subTeamId - Sub team ID (optional)
    # + includeInactive - If true return all including inactive (ADMIN-only)
    # + return - Units
    resource function get units(http:RequestContext ctx, int? subTeamId = (), boolean includeInactive = false)
            returns database:Unit[]|http:Forbidden|http:InternalServerError {

        if includeInactive {
            authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
            if userInfo is error {
                log:printError(ERROR_USER_INFORMATION_HEADER_NOT_FOUND, userInfo);
                return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
            }
            if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
                log:printWarn("Unauthorized attempt to fetch inactive units",
                        invokerEmail = userInfo.email);
                return <http:Forbidden>{
                    body: {message: "You are not authorized to view inactive units"}
                };
            }
        }

        database:Unit[]|error units = database:getUnits(subTeamId, includeInactive);
        if units is error {
            string customErr = "Error while fetching Units";
            log:printError(customErr, units);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return units;
    }

    # Get full organization structure.
    #
    # + return - Full organization structure
    resource function get organization\-structure() returns database:OrgStructureBusinessUnit[]|http:InternalServerError {
        database:OrgStructureBusinessUnit[]|error orgStructure = database:getFullOrganizationStructure();
        if orgStructure is error {
            string customErr = "Error while fetching organization structure";
            log:printError(customErr, orgStructure);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return orgStructure;
    }

    # Get career functions.
    #
    # + ctx - Request context (used only when `includeInactive=true` to gate admin access)
    # + includeInactive - If true return all including inactive (ADMIN-only)
    # + return - Career functions or HTTP errors
    resource function get career\-functions(http:RequestContext ctx, boolean includeInactive = false)
            returns database:CareerFunction[]|http:Forbidden|http:InternalServerError {

        if includeInactive {
            authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
            if userInfo is error {
                log:printError(ERROR_USER_INFORMATION_HEADER_NOT_FOUND, userInfo);
                return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
            }
            if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
                log:printWarn("Unauthorized attempt to fetch inactive career functions",
                        invokerEmail = userInfo.email);
                return <http:Forbidden>{
                    body: {message: "You are not authorized to view inactive career functions"}
                };
            }
        }

        database:CareerFunction[]|error careerFunctions = database:getCareerFunctions(includeInactive);
        if careerFunctions is error {
            string customErr = "Error while fetching Career Functions";
            log:printError(customErr, careerFunctions);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return careerFunctions;
    }

    # Get designations.
    #
    # + ctx - Request context (used only when `includeInactive=true` to gate admin access)
    # + careerFunctionId - Career function ID (optional)
    # + includeInactive - If true return all including inactive (ADMIN-only)
    # + return - Designations or HTTP errors
    resource function get designations(http:RequestContext ctx, int? careerFunctionId = (),
            boolean includeInactive = false)
            returns database:Designation[]|http:Forbidden|http:InternalServerError {

        if includeInactive {
            authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
            if userInfo is error {
                log:printError(ERROR_USER_INFORMATION_HEADER_NOT_FOUND, userInfo);
                return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
            }
            if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
                log:printWarn("Unauthorized attempt to fetch inactive designations",
                        invokerEmail = userInfo.email);
                return <http:Forbidden>{
                    body: {message: "You are not authorized to view inactive designations"}
                };
            }
        }

        database:Designation[]|error designations = database:getDesignations(careerFunctionId, includeInactive);
        if designations is error {
            string customErr = "Error while fetching Designations";
            log:printError(customErr, designations);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return designations;
    }

    # Get companies.
    #
    # + return - Companies
    resource function get companies() returns database:CompanyResponse[]|http:InternalServerError {
        database:CompanyResponse[]|error companies = database:getCompanies();
        if companies is error {
            string customErr = "Error while fetching Companies";
            log:printError(customErr, companies);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return companies;
    }

    # Get offices.
    #
    # + companyId - Company ID (optional)
    # + return - Offices
    resource function get offices(int? companyId = ()) returns database:Office[]|http:InternalServerError {
        database:Office[]|error offices = database:getOffices(companyId);
        if offices is error {
            string customErr = "Error while fetching Offices";
            log:printError(customErr, offices);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return offices;
    }

    # Get employment types.
    #
    # + return - Employment types
    resource function get employment\-types() returns database:EmploymentType[]|http:InternalServerError {
        database:EmploymentType[]|error employmentTypes = database:getEmploymentTypes();
        if employmentTypes is error {
            string customErr = "Error while fetching Employment Types";
            log:printError(customErr, employmentTypes);
            return <http:InternalServerError>{
                body: {
                    message: customErr
                }
            };
        }
        return employmentTypes;
    }

    # Fetch the assignable leadership attributes.
    #
    # Every caller gets the active attributes. `includeInactive` is the master data view:
    # retired attributes too, each with its current holder count, and admin only.
    #
    # + ctx - Request context
    # + includeInactive - Include retired attributes and holder counts (admin only)
    # + return - Leadership attributes or an error
    resource function get leadership\-groups(http:RequestContext ctx, boolean includeInactive = false)
            returns database:LeadershipGroup[]|database:LeadershipGroupWithUsage[]|http:Forbidden
                |http:InternalServerError {

        if includeInactive {
            authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
            if userInfo is error {
                return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
            }
            if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
                log:printWarn("Unauthorized attempt to list all leadership attributes",
                        invokerEmail = userInfo.email);
                return <http:Forbidden>{body: {message: "You are not authorized to manage leadership attributes"}};
            }
            database:LeadershipGroupWithUsage[]|error withUsage = database:getLeadershipGroupsWithUsage();
            if withUsage is error {
                log:printError("Error fetching leadership groups with usage", withUsage);
                return <http:InternalServerError>{
                    body: {message: "Error fetching leadership attributes"}
                };
            }
            return withUsage;
        }

        database:LeadershipGroup[]|error groups = database:getLeadershipGroups();
        if groups is error {
            log:printError("Error fetching leadership groups", groups);
            return <http:InternalServerError>{
                body: {message: "Error fetching leadership attributes"}
            };
        }
        return groups;
    }

    # Get houses.
    #
    # + ctx - Request context
    # + return - Houses
    resource function get houses(http:RequestContext ctx)
        returns database:House[]|http:Forbidden|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }
        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("User is not authorized to view houses", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to view houses"}};
        }
        database:House[]|error houses = database:getHouses();
        if houses is error {
            string customError = "Error while fetching Houses";
            log:printError(customError, houses);
            return <http:InternalServerError>{body: {message: customError}};
        }
        return houses;
    }

    # Bulk-creates employees from an uploaded CSV file.
    #
    # Processes the request in two passes:
    # - First pass: validates all rows, checks for within-CSV and DB-level
    # duplicates. Returns 400 with per-row errors if any row fails.
    # - Second pass: builds payloads, generates employee IDs, and inserts
    # all records in a single DB transaction.
    #
    # + return - Bulk upload result with created/skipped counts, or an HTTP error
    resource function post employees/bulk(http:RequestContext ctx, http:Request req)
            returns database:BulkUploadResponse|http:BadRequest|http:Forbidden|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }
        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("User is not authorized to bulk create employees", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {
                    message: "You are not authorized to bulk create employees"
                }
            };
        }

        byte[]|http:BadRequest fileBytes = extractCsvFileBytes(req);
        if fileBytes is http:BadRequest {
            log:printWarn("Failed to extract CSV file bytes from request");
            return fileBytes;
        }

        BulkEmployeeCsvRow[]|error rows = parseCsvBytes(fileBytes);
        if rows is error {
            log:printError("Error parsing bulk upload CSV", rows);
            return <http:BadRequest>{
                body: {
                    message: "Invalid CSV file"
                }
            };
        }

        if rows.length() > MAX_BULK_ROWS {
            log:printWarn("CSV file exceeds maximum row limit", rowCount = rows.length(), maxLimit = MAX_BULK_ROWS);
            return <http:BadRequest>{
                body: {
                    message: string `CSV exceeds ${MAX_BULK_ROWS}-row limit`
                }
            };
        }

        BulkRefData|error refData = loadBulkReferenceData();
        if refData is error {
            log:printError("Error loading reference data for bulk upload", refData);
            return <http:InternalServerError>{
                body: {
                    message: "Error validating bulk upload"
                }
            };
        }

        BulkFirstPassResult firstPass = processBulkCsvRows(rows, refData);

        database:BulkEmployeeError[]|error dbErrors = detectDbDuplicates(
                firstPass.rowByEmail, firstPass.rowByNic, firstPass.rowByEpf,
                firstPass.candidateEmails, firstPass.candidateNics, firstPass.candidateEpfs);
        if dbErrors is error {
            log:printError("Error checking duplicates during bulk upload", dbErrors);
            return <http:InternalServerError>{
                body: {
                    message: "Error validating bulk upload"
                }
            };
        }

        database:BulkEmployeeError[] allErrors = [...firstPass.errors, ...dbErrors];
        if allErrors.length() > 0 {
            return <http:BadRequest>{
                body: allErrors
            };
        }

        BulkPayloadResult payloadResult = buildBulkPayloads(firstPass.rowInfos, refData);

        [string, int][] bulkResults = database:addEmployeesBulk(
                payloadResult.employees.map(e => e.payload),
                userInfo.email);

        int batchStatus = bulkResults.length() > 0 ? bulkResults[0][1] : database:BULK_INSERT_FAILED;

        if batchStatus != database:BULK_INSERT_SUCCESS {
            string errorMessage = batchStatus == database:BULK_INSERT_DUPLICATE
                ? "Concurrent upload conflict — please retry"
                : ERROR_EMPLOYEE_CREATION_FAILED;

            return <http:InternalServerError>{
                body: {
                    message: errorMessage
                }
            };
        }

        foreach int i in 0 ..< bulkResults.length() {
            payloadResult.employees[i].employeeId = bulkResults[i][0];
        }
        int created = payloadResult.employees.length();

        database:BulkProvisioningError[] provisioningErrors = [];
        database:BulkGroupAssignmentWarning[] groupAssignmentWarnings = [];
        database:OrphanedScimUser[] orphanedScimUsers = [];

        // NOTE: Asgardeo/SCIM provisioning is intentionally disabled for now and will be re-enabled
        // shortly (tracked in PR #294). The block below is kept rather than deleted so re-enabling is
        // a straightforward uncomment. While disabled, employees are created in the DB only; the
        // provisioning arrays above stay empty, so the response reflects DB creation without
        // provisioning (no SCIM user/group assignment is attempted).
        // foreach ResolvedEmployee emp in payloadResult.employees {
        //     error? scimResult = scim:createUser(
        //             emp.payload.workEmail,
        //             emp.payload.firstName,
        //             emp.payload.lastName
        //     );
        //
        //     if scimResult is error {
        //         log:printError("Failed to provision user in Asgardeo during bulk onboarding; rolling back employee record",
        //                 scimResult, workEmail = emp.payload.workEmail, employeeId = emp.employeeId);
        //         rollbackEmployeeCreation(emp.employeeId, emp.payload.workEmail);
        //         provisioningErrors.push({
        //             employeeId: emp.employeeId,
        //             workEmail: emp.payload.workEmail,
        //             reason: scimResult.message()
        //         });
        //         continue;
        //     }
        //
        //     string[]|error groupNames = database:getAsgardeoGroupsByEmploymentType(emp.payload.employmentTypeId);
        //     if groupNames is error {
        //         log:printError("Failed to fetch Asgardeo groups during bulk onboarding; rolling back employee record. " +
        //                 "Asgardeo user was already created and requires manual cleanup",
        //                 groupNames, workEmail = emp.payload.workEmail, employeeId = emp.employeeId,
        //                 employmentTypeId = emp.payload.employmentTypeId);
        //         rollbackEmployeeCreation(emp.employeeId, emp.payload.workEmail);
        //         provisioningErrors.push({
        //             employeeId: emp.employeeId,
        //             workEmail: emp.payload.workEmail,
        //             reason: groupNames.message()
        //         });
        //         orphanedScimUsers.push({
        //             employeeId: emp.employeeId,
        //             workEmail: emp.payload.workEmail,
        //             reason: groupNames.message()
        //         });
        //         continue;
        //     }
        //
        //     string[] allGroups = [...groupNames];
        //     string[]|error teamGroupNames = database:getAsgardeoGroupsByTeam(emp.payload.teamId, emp.payload.employmentTypeId);
        //     if teamGroupNames is string[] {
        //         allGroups.push(...teamGroupNames);
        //     } else {
        //         log:printError("Failed to fetch Asgardeo groups for team during bulk onboarding; skipping team group assignment",
        //                 teamGroupNames, workEmail = emp.payload.workEmail, employeeId = emp.employeeId, teamId = emp.payload.teamId);
        //     }
        //
        //     string[] uniqueGroups = from var groupName in allGroups
        //         group by groupName
        //         select groupName;
        //
        //     string[] failedGroups = [];
        //     foreach string groupName in uniqueGroups {
        //         scim:AddUsersToGroupResponse|error addResult =
        //                 scim:addUserToGroup(groupName, emp.payload.workEmail);
        //         if addResult is error || addResult.failedUsers.length() > 0 {
        //             log:printError("Failed to add user to Asgardeo group during bulk onboarding. " +
        //                     "Asgardeo user was already created and requires manual cleanup",
        //                         addResult is error ? addResult : (),
        //                     workEmail = emp.payload.workEmail, group = groupName, employeeId = emp.employeeId,
        //                     failedUsers = addResult is scim:AddUsersToGroupResponse ? addResult.failedUsers : ());
        //             failedGroups.push(groupName);
        //         }
        //     }
        //
        //     if failedGroups.length() > 0 {
        //         error? notificationResult = email:notifyGroupAssignmentFailure(emp.employeeId, emp.payload.firstName,
        //                 emp.payload.lastName, emp.payload.workEmail, failedGroups);
        //         if notificationResult is error {
        //             log:printError("Failed to send group assignment failure notification during bulk onboarding",
        //                     notificationResult, employeeId = emp.employeeId, workEmail = emp.payload.workEmail);
        //         }
        //         groupAssignmentWarnings.push({
        //             employeeId: emp.employeeId,
        //             workEmail: emp.payload.workEmail,
        //             failedGroups
        //         });
        //     }
        //
        //     created += 1;
        // }

        return {
            created,
            skipped: firstPass.skipped,
            errors: [],
            provisioningErrors,
            orphanedScimUsers,
            groupAssignmentWarnings
        };
    }

    # Create a new employee.
    #
    # + payload - Employee creation payload
    # + return - HTTP OK with created employee ID and status, or HTTP errors
    resource function post employees(http:RequestContext ctx, database:CreateEmployeePayload payload)
        returns EmployeeCreatedResponse|http:InternalServerError|http:BadRequest|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        boolean hasAdminAccess = authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups);
        if !hasAdminAccess {
            log:printWarn("User is not authorized to create new employees", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {
                    message: "You are not authorized to create new employees"
                }
            };
        }

        // An empty work email means the joiner's account does not exist yet; FUTURE_JOINER_EMAIL
        // is stored in its place below. Typing a placeholder in is refused rather than treated
        // the same, so every placeholder joiner is one the backend knows has no email.
        string? requestedEmail = payload.workEmail;
        if requestedEmail is string && database:isPlaceholderWorkEmail(requestedEmail) {
            string customErr = "Leave the work email empty when the employee's account is not created yet";
            log:printWarn(customErr, workEmail = requestedEmail);
            return <http:BadRequest>{
                body: {
                    message: customErr
                }
            };
        }

        http:BadRequest|http:InternalServerError? rejectedIdentity =
            validateOnboardingIdentity(payload.personalInfo.nicOrPassport, requestedEmail);
        if rejectedIdentity is http:BadRequest|http:InternalServerError {
            return rejectedIdentity;
        }

        string? epfOpt = payload.epf;
        if epfOpt is string && epfOpt.trim() != "" {
            string|error? existingEmp = database:getEmployeeIdByEpf(epfOpt);
            if existingEmp is error {
                string customErr = "Error occurred while validating EPF uniqueness";
                log:printError(customErr, existingEmp, epf = epfOpt);
                return <http:InternalServerError>{
                    body: {
                        message: ERROR_EMPLOYEE_CREATION_FAILED
                    }
                };
            }
            if existingEmp is string {
                string customErr = "EPF already exists";
                log:printWarn(customErr, epf = epfOpt);
                return <http:BadRequest>{
                    body: {
                        message: customErr
                    }
                };
            }
        }

        int? continuousServiceRecord = payload.continuousServiceRecord;
        if continuousServiceRecord is int {
            // Earlier employments are found by work email, so without one there is nothing
            // the link could be checked against.
            if requestedEmail is () {
                string customErr = "A continuous service record can only be linked when a work email is given";
                log:printWarn(customErr, linkedId = continuousServiceRecord);
                return <http:BadRequest>{
                    body: {
                        message: customErr
                    }
                };
            }
            http:BadRequest|http:InternalServerError? invalidLink =
                validateContinuousServiceRecord(continuousServiceRecord, requestedEmail, payload.startDate);
            if invalidLink is http:BadRequest|http:InternalServerError {
                return invalidLink;
            }
        }

        string workEmail = requestedEmail ?: database:FUTURE_JOINER_EMAIL;
        payload.workEmail = workEmail;
        // Set here rather than taken from the request: whether someone has started is decided
        // by their start date where they work, and the scheduler moves a New joiner to Active
        // once that date begins there.
        string|error today = todayAt(payload.companyId, payload.workLocation);
        if today is error {
            log:printError("Error occurred while reading the work location's timezone", today,
                    companyId = payload.companyId, workLocation = payload.workLocation);
            return <http:InternalServerError>{
                body: {
                    message: ERROR_EMPLOYEE_CREATION_FAILED
                }
            };
        }
        payload.employeeStatus = database:initialEmployeeStatus(payload.startDate, today);

        string|http:BadRequest|http:InternalServerError generatedEmployeeId = generateEmployeeId(payload);
        if generatedEmployeeId is http:BadRequest|http:InternalServerError {
            return generatedEmployeeId;
        }
        string employeeId = generatedEmployeeId;

        // House is assigned automatically — a returning employee keeps the one they had,
        // everyone else gets it from the employee ID's numeric part. Not a user-editable
        // choice, and not known until the ID above is resolved.
        int|error autoHouseId = database:resolveHouseIdForNewEmployee(payload.personalInfo.nicOrPassport,
                workEmail, employeeId);
        if autoHouseId is error {
            log:printError("Error occurred while computing automatic house assignment",
                    autoHouseId, employeeId = employeeId);
            return <http:InternalServerError>{
                body: {
                    message: ERROR_EMPLOYEE_CREATION_FAILED
                }
            };
        }
        payload.houseId = autoHouseId;

        int|error newEmployeeId = database:addEmployee(payload, userInfo.email, employeeId);
        if newEmployeeId is error {
            log:printError(ERROR_EMPLOYEE_CREATION_FAILED, newEmployeeId);
            return <http:InternalServerError>{
                body: {
                    message: ERROR_EMPLOYEE_CREATION_FAILED
                }
            };
        }

        // NOTE: Asgardeo/SCIM provisioning is intentionally disabled for now and will be re-enabled
        // shortly (tracked in PR #294). The block below is kept rather than deleted so re-enabling is
        // a straightforward uncomment. While disabled, the employee is created in the DB only and the
        // response returns hasGroupAssignmentWarning: false (no SCIM user/group assignment attempted).
        // error? scimUserResult = scim:createUser(
        //         payload.workEmail,
        //         payload.firstName,
        //         payload.lastName
        // );
        // if scimUserResult is error {
        //     log:printError("Failed to provision user in Asgardeo; rolling back employee record",
        //             scimUserResult, workEmail = payload.workEmail, employeeId = employeeId);
        //     rollbackEmployeeCreation(employeeId, payload.workEmail);
        //     return <http:InternalServerError>{
        //         body: {
        //             message: ERROR_EMPLOYEE_CREATION_FAILED
        //         }
        //     };
        // }

        // string[]|error groupNames = database:getAsgardeoGroupsByEmploymentType(payload.employmentTypeId);
        // if groupNames is error {
        //     log:printError("Failed to fetch Asgardeo groups for employment type; rolling back employee record. " +
        //             "Asgardeo user was already created and requires manual cleanup",
        //             groupNames, workEmail = payload.workEmail, employeeId = employeeId,
        //             employmentTypeId = payload.employmentTypeId);
        //     rollbackEmployeeCreation(employeeId, payload.workEmail);
        //     return <http:InternalServerError>{
        //         body: {
        //             message: ERROR_EMPLOYEE_CREATION_FAILED,
        //             orphanedScimUsers: [
        //                 {
        //                     employeeId,
        //                     workEmail: payload.workEmail,
        //                     reason: groupNames.message()
        //                 }
        //             ]
        //         }
        //     };
        // }

        // string[] allGroups = [...groupNames];
        // string[]|error teamGroupNames = database:getAsgardeoGroupsByTeam(payload.teamId, payload.employmentTypeId);
        // if teamGroupNames is string[] {
        //     allGroups.push(...teamGroupNames);
        // } else {
        //     log:printError("Failed to fetch Asgardeo groups for team; skipping team group assignment",
        //             teamGroupNames, workEmail = payload.workEmail, employeeId = employeeId, teamId = payload.teamId);
        // }

        // string[] uniqueGroups = from var groupName in allGroups
        //     group by groupName
        //     select groupName;

        // string[] failedGroups = [];
        // foreach string groupName in uniqueGroups {
        //     scim:AddUsersToGroupResponse|error addResult =
        //             scim:addUserToGroup(groupName, payload.workEmail);
        //     if addResult is error || addResult.failedUsers.length() > 0 {
        //         log:printError("Failed to add user to Asgardeo group. " +
        //                 "Asgardeo user was already created and requires manual cleanup",
        //                     addResult is error ? addResult : (),
        //                 workEmail = payload.workEmail, group = groupName, employeeId = employeeId,
        //                 failedUsers = addResult is scim:AddUsersToGroupResponse ? addResult.failedUsers : ());
        //         failedGroups.push(groupName);
        //     }
        // }

        // if failedGroups.length() > 0 {
        //     error? notificationResult = email:notifyGroupAssignmentFailure(employeeId, payload.firstName,
        //             payload.lastName, payload.workEmail, failedGroups);
        //     if notificationResult is error {
        //         log:printError("Failed to send group assignment failure notification",
        //                 notificationResult, employeeId = employeeId, workEmail = payload.workEmail);
        //     }

        //     return {
        //         employeeId: newEmployeeId,
        //         message: WARNING_GROUP_ASSIGNMENT_FAILED,
        //         hasGroupAssignmentWarning: true
        //     };
        // }
        return {
            employeeId: newEmployeeId,
            message: "Employee created successfully!",
            hasGroupAssignmentWarning: false
        };
    }

    # Update employee personal information.
    #
    # + employeeId - Employee ID
    # + payload - Employee personal information update payload
    # + return - HTTP OK or HTTP errors
    resource function patch employees/[string employeeId]/personal\-info(http:RequestContext ctx,
            database:UpdateEmployeePersonalInfoPayload payload)
        returns http:Ok|http:NotFound|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        boolean hasAdminAccess = authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups);

        string? firstName = payload.firstName;
        string? lastName = payload.lastName;
        if firstName is string {
            if firstName.trim().length() == 0 {
                return <http:BadRequest>{
                    body: {
                        message: "First name and last name must not be blank"
                    }
                };
            }
        }
        if lastName is string {
            if lastName.trim().length() == 0 {
                return <http:BadRequest>{
                    body: {
                        message: "First name and last name must not be blank"
                    }
                };
            }
        }

        database:Employee|error? employeeInfo = database:getEmployeeInfo(employeeId);
        if employeeInfo is error {
            log:printError(string `Error occurred while fetching employee information for ID: ${employeeId}`,
                    employeeInfo, employeeId = employeeId);
            return <http:InternalServerError>{
                body: {
                    message: ERROR_PERSONAL_INFO_UPDATE_FAILED
                }
            };
        }
        if employeeInfo is () {
            log:printWarn("Employee information not found", employeeId = employeeId);
            return <http:NotFound>{
                body: {
                    message: ERROR_PERSONAL_INFO_UPDATE_FAILED
                }
            };
        }

        if !hasAdminAccess {
            if employeeInfo.workEmail != userInfo.email {
                string customErr = "You are not allowed to update personal information of another employee";
                log:printWarn(customErr, employeeId = employeeId, invokerEmail = userInfo.email, targetEmail = employeeInfo.workEmail);
                return <http:Forbidden>{
                    body: {
                        message: customErr
                    }
                };
            }

            boolean hasRestrictedFields =
                payload.nicOrPassport is string ||
                payload.firstName is string ||
                payload.lastName is string ||
                payload.fullName is string ||
                payload.title is string ||
                payload.dob is string ||
                payload.gender is string ||
                payload.nationality is string;

            if hasRestrictedFields {
                string customErr = "You are not allowed to update one or more of the provided fields";
                log:printWarn(customErr, employeeId = employeeId, invokerEmail = userInfo.email);
                return <http:Forbidden>{
                    body: {
                        message: customErr
                    }
                };
            }
        }

        database:EmployeePersonalInfo|error? employeePersonalInfo = database:getEmployeePersonalInfo(employeeId);
        if employeePersonalInfo is error {
            string customErr = string `Error occurred while fetching employee personal information for ID: ${employeeId}`;
            log:printError(customErr, employeePersonalInfo, employeeId = employeeId);
            return <http:InternalServerError>{
                body: {
                    message: ERROR_PERSONAL_INFO_UPDATE_FAILED
                }
            };
        }
        if employeePersonalInfo is () {
            string customErr = "Employee personal information not found";
            log:printWarn(customErr, employeeId = employeeId);
            return <http:NotFound>{
                body: {
                    message: customErr
                }
            };
        }

        error? updateResult = database:updateEmployeePersonalInfo(employeeId, payload, userInfo.email);
        if updateResult is error {
            string customErr = string `Error occurred while updating employee personal information for ID: ${employeeId}`;
            log:printError(customErr, updateResult, employeeId = employeeId);
            return <http:InternalServerError>{
                body: {
                    message: ERROR_PERSONAL_INFO_UPDATE_FAILED
                }
            };
        }

        return http:OK;
    }

    # Record an employee's resignation.
    #
    # A dedicated route rather than a rule inside the job-info handler: the permission is
    # then structural — this role may call this endpoint, and this endpoint can only write
    # these three fields. A field-level check on the 25-field job-info payload would be a
    # negative rule that has to stay correct about every other field, and would silently
    # widen the moment a new one is added.
    #
    # Employment status is not accepted from the caller; recording a departure is what
    # makes someone a leaver, so it is set to "Marked leaver" here.
    #
    # + employeeId - Employee ID
    # + payload - Resignation details
    # + return - HTTP OK or HTTP errors
    resource function patch employees/[string employeeId]/resignation(http:RequestContext ctx,
            @http:Payload database:UpdateResignationPayload payload)
        returns http:Ok|http:NotFound|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        boolean isAuthorized =
            authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups)
            || authorization:checkPermissions([authorization:authorizedRoles.RESIGNATION_ROLE], userInfo.groups);
        if !isAuthorized {
            log:printWarn("User is not authorized to record a resignation", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {message: "You are not authorized to record a resignation"}
            };
        }

        database:Employee|error? employeeInfo = database:getEmployeeInfo(employeeId);
        if employeeInfo is error {
            string customErr = string `Error occurred while fetching employee information for ID: ${employeeId}`;
            log:printError(customErr, employeeInfo, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        if employeeInfo is () {
            string customErr = "Employee information not found";
            log:printWarn(customErr, employeeId = employeeId);
            return <http:NotFound>{body: {message: customErr}};
        }

        error? updateResult = database:updateResignation(employeeId, payload, userInfo.email);
        if updateResult is error {
            // An impossible date pair is the caller's mistake, not a server fault, so it
            // is reported as such with the reason rather than a generic failure. Matched
            // on the error type rather than its message: the wording is a user-facing
            // string and rewording it should not turn somebody's bad input into a 500.
            if updateResult is database:InvalidResignationDatesError {
                log:printWarn(updateResult.message(), employeeId = employeeId);
                return <http:BadRequest>{body: {message: updateResult.message()}};
            }
            string customErr = string `Error occurred while recording the resignation for ID: ${employeeId}`;
            log:printError(customErr, updateResult, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }

        return http:OK;
    }

    # Update employee job information.
    #
    # + employeeId - Employee ID
    # + payload - Employee job info update payload
    # + return - HTTP OK or HTTP errors
    resource function patch employees/[string employeeId]/job\-info(http:RequestContext ctx,
            database:UpdateEmployeeJobInfoPayload payload)
        returns http:Ok|http:NotFound|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        boolean hasAdminAccess = authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups);
        if !hasAdminAccess {
            log:printWarn("User is not authorized to update an employee", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {
                    message: "You are not authorized to update an employee"
                }
            };
        }

        database:Employee|error? employeeInfo = database:getEmployeeInfo(employeeId);
        if employeeInfo is error {
            log:printError(string `Error occurred while fetching employee information for ID: ${employeeId}`,
                    employeeInfo, employeeId = employeeId);

            return <http:InternalServerError>{
                body: {
                    message: ERROR_EMPLOYEE_INFO_UPDATE_FAILED
                }
            };
        }
        if employeeInfo is () {
            log:printWarn("Employee information not found", employeeId = employeeId);
            return <http:NotFound>{
                body: {
                    message: "Employee information not found"
                }
            };
        }

        if (payload.officeId is int && payload.officeId <= 0
                && payload.officeId != database:OFFICE_CLEAR_SENTINEL)
                || (payload.unitId is int && payload.unitId <= 0
                && payload.unitId != database:UNIT_CLEAR_SENTINEL) {
            return <http:BadRequest>{
                body: {
                    message: "Office and unit IDs must be positive IDs or the clear sentinel"
                }
            };
        }

        http:BadRequest|http:InternalServerError? identityError =
            validateEditIdentity(employeeInfo, payload.employeeStatus, payload.workEmail);
        if identityError !is () {
            return identityError;
        }

        // A link sent in the request is checked against the email and start date the
        // employment will hold afterwards. A stored link the request leaves alone is checked
        // too when either of those changes, so an edit cannot turn it into a forward link.
        int? continuousServiceRecord = payload.continuousServiceRecord;
        boolean keepsStoredLink = continuousServiceRecord is ()
            && (payload.workEmail is string || payload.startDate is string);
        int? linkToCheck = keepsStoredLink ? employeeInfo.continuousServiceRecord : continuousServiceRecord;
        if linkToCheck is int && linkToCheck != database:CONTINUOUS_SERVICE_RECORD_CLEAR_SENTINEL {
            http:BadRequest|http:InternalServerError? invalidLink = validateContinuousServiceRecord(
                    linkToCheck, payload.workEmail ?: employeeInfo.workEmail,
                    payload.startDate ?: employeeInfo.startDate, employeeId);
            if invalidLink is http:BadRequest {
                return keepsStoredLink
                    ? <http:BadRequest>{
                        body: {
                            message: "This change makes the existing continuous service record invalid: it must be an "
                                + "earlier employment under the same work email that has ended or is ending "
                                + "(status Left or Marked leaver). "
                                + "Remove the link in the same update."
                        }
                    }
                    : invalidLink;
            }
            if invalidLink is http:InternalServerError {
                return invalidLink;
            }
        }

        string? epfOpt = payload.epf;
        if epfOpt is string && epfOpt.trim() != "" {
            string|error? existingEmp = database:getEmployeeIdByEpf(epfOpt);
            if existingEmp is error {
                string customErr = "Error occurred while validating EPF uniqueness for update";
                log:printError(customErr, existingEmp, epf = epfOpt);
                return <http:InternalServerError>{
                    body: {
                        message: ERROR_EMPLOYEE_INFO_UPDATE_FAILED
                    }
                };
            }
            if existingEmp is string && existingEmp != employeeId {
                string customErr = "EPF already exists for another employee";
                log:printWarn(customErr, epf = epfOpt, employeeId = employeeId);
                return <http:BadRequest>{
                    body: {
                        message: customErr
                    }
                };
            }
        }

        boolean isLeaverStatus = payload.employeeStatus is ()
            ? employeeInfo.employeeStatus == database:EMPLOYEE_LEFT
                || employeeInfo.employeeStatus == database:EMPLOYEE_MARKED_LEAVER
            : payload.employeeStatus == database:EMPLOYEE_LEFT
                || payload.employeeStatus == database:EMPLOYEE_MARKED_LEAVER;
        if database:hasLeaverFields(payload) && !isLeaverStatus {
            log:printWarn("Attempt to set resignation fields on an employee who is not a leaver",
                    employeeId = employeeId);
            return <http:BadRequest>{
                body: {
                    message: "Resignation details can only be set when employee status is 'Left' or 'Marked leaver'"
                }
            };
        }

        // Keyed on the status this request sets, not on the status the employee already
        // holds. The rule is "recording a departure has to say when and why", which is
        // about the moment somebody becomes a leaver. Reading isLeaverStatus here instead
        // asked "is this person a leaver", which is true forever once they have left — so
        // every later edit of their record, a job role or a team on its own, was refused
        // unless it resent all three resignation fields.
        boolean isBecomingLeaver = payload.employeeStatus == database:EMPLOYEE_LEFT
            || payload.employeeStatus == database:EMPLOYEE_MARKED_LEAVER;
        if isBecomingLeaver {
            string? payloadFinalDayInOffice = payload.finalDayInOffice;
            string? payloadFinalDayOfEmployment = payload.finalDayOfEmployment;
            string? payloadResignationReason = payload.resignationReason;

            if payloadFinalDayInOffice is () || payloadFinalDayOfEmployment is ()
                || payloadResignationReason is () || payloadResignationReason.trim().length() == 0 {
                log:printWarn("Attempt to set status to Marked leaver/Left without all resignation details in the request",
                        employeeId = employeeId);
                return <http:BadRequest>{
                    body: {
                        message: "Final day in office, final day of employment, and resignation reason must all be provided in the request when status is 'Marked leaver' or 'Left'"
                    }
                };
            }
        }

        // Validated up front so an unknown or inactive id rejects the whole request before
        // anything is written. The de-duplicated set is then written inside
        // updateEmployeeJobInfo's transaction, together with the rest of the update.
        int[]? requestedGroups = payload.leadershipGroupIds;
        if requestedGroups is int[] {
            int[]|http:BadRequest|http:InternalServerError validGroups =
                validateLeadershipGroupIds(requestedGroups, employeeId);
            if validGroups is http:BadRequest|http:InternalServerError {
                return validGroups;
            }
            payload.leadershipGroupIds = validGroups;
        }

        error? updateResult = database:updateEmployeeJobInfo(employeeId, payload, userInfo.email);
        if updateResult is error {
            string customErr = string `Error occurred while updating employee job information for ID: ${employeeId}`;
            log:printError(customErr, updateResult, employeeId = employeeId);
            return <http:InternalServerError>{
                body: {
                    message: ERROR_EMPLOYEE_INFO_UPDATE_FAILED
                }
            };
        }

        return http:OK;
    }

    # Fetch vehicles of a specific employee.
    #
    # + employeeEmail - The email of the employee  
    # + vehicleStatus - filter :  status of the vehicle
    # + offset - offset of the response  
    # + 'limit - limit of the response
    # + return - List  of vehicles | Error
    resource function get employees/[string employeeEmail]/vehicles(http:RequestContext ctx,
            database:VehicleStatus? vehicleStatus, database:VehicleTypes? vehicleType, int? offset, int? 'limit)
        returns database:Vehicles|http:InternalServerError|http:NotFound|http:Forbidden {

        // User information header.
        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        if employeeEmail !== userInfo.email {
            return <http:Forbidden>{
                body: {
                    message: "You are not allowed to view vehicles of other employees!"
                }
            };
        }

        database:Vehicles|error vehicles = database:fetchVehicles(
                owner = employeeEmail,
                vehicleStatus = vehicleStatus,
                vehicleType = vehicleType,
                'limit = 'limit,
                offset = offset
            );

        if vehicles is error {
            string customError = string `An error occurred while fetching vehicles of ${employeeEmail}`;
            log:printError(customError, vehicles);
            return <http:InternalServerError>{
                body: {
                    message: customError
                }
            };
        }

        return vehicles;
    }

    # Persist new vehicle.
    #
    # + employeeEmail - The email of the employee
    # + vehicle - The vehicle details
    # + return - success | Error
    resource function post employees/[string employeeEmail]/vehicles(http:RequestContext ctx, NewVehicle vehicle)
        returns http:Created|http:Forbidden|http:InternalServerError {

        // User information header.
        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        if employeeEmail !== userInfo.email {
            return <http:Forbidden>{
                body: {
                    message: "You are not allowed to add vehicles for other employees!"
                }
            };
        }

        int|error vehicleResult = database:addVehicle({
                                                          owner: userInfo.email,
                                                          vehicleRegistrationNumber: vehicle.vehicleRegistrationNumber,
                                                          vehicleType: vehicle.vehicleType,
                                                          vehicleStatus: database:ACTIVE,
                                                          createdBy: userInfo.email
                                                      });
        if vehicleResult is error {
            string customError = string `Error occurred while adding vehicle!`;
            log:printError(customError, vehicleResult);
            return <http:InternalServerError>{
                body: {
                    message: customError
                }
            };
        }

        return http:CREATED;

    }

    resource function delete employees/[string employeeEmail]/vehicles/[int vehicleId](http:RequestContext ctx)
        returns http:Ok|http:Forbidden|http:InternalServerError|http:BadRequest {

        // User information header.
        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        if employeeEmail !== userInfo.email {
            return <http:Forbidden>{
                body: {
                    message: "You are not allowed to remove vehicles for other employees!"
                }
            };
        }

        boolean|error updateResult = database:updateVehicle({
                                                                vehicleId,
                                                                vehicleStatus: database:INACTIVE,
                                                                updatedBy: userInfo.email
                                                            });

        if updateResult is error {
            string customError = string `Error occurred while updating vehicle!`;
            log:printError(customError, updateResult);
            return <http:InternalServerError>{
                body: {
                    message: customError
                }
            };
        }

        if updateResult == false {
            string customError = string `No vehicle found with ID ${vehicleId} to update!`;
            log:printError(customError);
            return <http:BadRequest>{
                body: {
                    message: customError
                }
            };
        }

        return http:OK;
    }

    # Get car park configs.
    #
    # + return - Car park configs or error response
    resource function get parkings/configs(http:RequestContext ctx)
        returns CarParkConfigResponse|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }
        return {
            reservationWindowStartHour: wso2_coin:reservationWindowStartHour,
            reservationWindowEndHour: wso2_coin:reservationWindowEndHour
        };
    }

    # List the current user's wallets available for car park payments.
    #
    # + return - The caller's wallets with balances, or error response
    resource function get parkings/wallets(http:RequestContext ctx, http:Request request)
        returns wso2_coin:WalletDetails[]|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        string|error userAssertion = request.getHeader(authorization:JWT_ASSERTION_HEADER);
        if userAssertion is error {
            log:printError("Missing user assertion header while listing wallets", userAssertion,
                    invokerEmail = userInfo.email);
            return <http:InternalServerError>{
                body: {message: "Error occurred while fetching wallets."}
            };
        }

        wso2_coin:WalletDetails[]|error wallets = wso2_coin:getUserWallets(userAssertion);
        if wallets is error {
            log:printError("Error fetching user wallets", wallets, invokerEmail = userInfo.email);
            return <http:InternalServerError>{
                body: {message: "Error occurred while fetching wallets."}
            };
        }
        return wallets;
    }

    # List parking floors.
    #
    # + return - List of parking floors or error response
    resource function get parkings/floors(http:RequestContext ctx)
        returns database:ParkingFloor[]|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        database:ParkingFloor[]|error floors = database:getParkingFloors();
        if floors is error {
            log:printError("Error fetching parking floors", floors);
            return <http:InternalServerError>{
                body: {message: "Error occurred while fetching parking floors."}
            };
        }
        return floors;
    }

    # List parking slots for a floor with availability for a given date.
    #
    # + id - Floor identifier
    # + date - Booking date
    # + return - List of parking slots with availability status or error response
    resource function get parkings/floors/[int id]/slots(http:RequestContext ctx, string date)
        returns database:ParkingSlot[]|http:InternalServerError|http:BadRequest {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        if !database:DATE_PATTERN.isFullMatch(date) {
            return <http:BadRequest>{
                body: {message: "Query parameter 'date' must be in YYYY-MM-DD format."}
            };
        }

        database:ParkingSlot[]|error slots = database:getParkingSlotsByFloor(id, date,
                wso2_coin:pendingReservationExpiryMinutes);
        if slots is error {
            log:printError("Error fetching parking slots", slots);
            return <http:InternalServerError>{
                body: {message: "Error occurred while fetching parking slots."}
            };
        }
        return slots;
    }

    # Create a parking reservation.
    #
    # + body - Reservation creation details
    # + return - Reservation ID and amount to be paid in coins, or error response
    resource function post parkings/reservations(http:RequestContext ctx, CreateParkingReservationRequest body)
        returns CreateParkingReservationResponse|http:InternalServerError|http:BadRequest|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        time:Utc nowUtc = time:utcNow();
        string today;
        int hour;
        time:Zone? sriLankaZone = time:getZone("Asia/Colombo");
        if sriLankaZone is time:Zone {
            time:Civil civil = sriLankaZone.utcToCivil(nowUtc);
            string|error civilStr = time:civilToString(civil);
            today = civilStr is string ? civilStr.substring(0, 10) : time:utcToString(time:utcAddSeconds(nowUtc, 19800)).substring(0, 10);
            hour = civil.hour;
        } else {
            time:Utc slTime = time:utcAddSeconds(nowUtc, 19800);
            today = time:utcToString(slTime).substring(0, 10);
            string hourStr = time:utcToString(slTime).substring(11, 13);
            int|error parsedHour = int:fromString(hourStr);
            hour = parsedHour is int ? parsedHour : 0;
        }
        if hour < wso2_coin:reservationWindowStartHour || hour >= wso2_coin:reservationWindowEndHour {
            return <http:BadRequest>{
                body: {
                    message: string `Reservations are only allowed from ${wso2_coin:reservationWindowStartHour}:00 to ${wso2_coin:reservationWindowEndHour}:00.`
                }
            };
        }
        if body.bookingDate != today {
            return <http:BadRequest>{
                body: {message: "Reservations are only allowed for the same day. Use date " + today + "."}
            };
        }

        string|error? vehicleOwner = database:getVehicleOwner(body.vehicleId);
        if vehicleOwner is error {
            log:printError("Error fetching vehicle owner", vehicleOwner);
            return <http:InternalServerError>{
                body: {message: "Error occurred while validating vehicle."}
            };
        }
        if vehicleOwner is () || vehicleOwner != userInfo.email {
            return <http:Forbidden>{
                body: {message: "Vehicle not found or you are not the owner. Use one of your registered (active) vehicles."}
            };
        }

        database:ParkingSlot|error? slot = database:getParkingSlotById(body.slotId);
        if slot is error {
            log:printError("Error fetching slot for reservation", slot);
            return <http:InternalServerError>{
                body: {message: "Error occurred while validating slot."}
            };
        }
        if slot is () {
            return <http:BadRequest>{
                body: {message: string `Parking slot '${body.slotId}' not found.`}
            };
        }

        // Expire the caller's own stale pending reservations for the date (any slot), so an
        // abandoned attempt does not block a fresh booking.
        boolean|error clearedForEmployee = database:expireStalePendingParkingReservationsForEmployeeDate(
                userInfo.email, body.bookingDate, wso2_coin:pendingReservationExpiryMinutes);
        if clearedForEmployee is error {
            log:printError("Error expiring stale pending reservations for employee", clearedForEmployee);
            return <http:InternalServerError>{
                body: {message: "Error occurred while validating booking eligibility."}
            };
        }

        // Enforce one active (PENDING/CONFIRMED) reservation per employee per day.
        database:ActiveParkingReservationRow|error? activeReservation =
            database:getActiveParkingReservationForEmployeeDate(userInfo.email, body.bookingDate,
                wso2_coin:pendingReservationExpiryMinutes);
        if activeReservation is error {
            log:printError("Error checking existing reservations for employee", activeReservation);
            return <http:InternalServerError>{
                body: {message: "Error occurred while validating booking eligibility."}
            };
        }
        if activeReservation is database:ActiveParkingReservationRow {
            // Same-slot PENDING: reuse it so a retry does not create (or pay for) a second booking.
            if activeReservation.status == database:PENDING && activeReservation.slotId == body.slotId {
                // Keep the reused reservation aligned with the vehicle chosen on this attempt.
                if activeReservation.vehicleId != body.vehicleId {
                    boolean|error vehicleUpdated = database:updateParkingReservationVehicle(
                            activeReservation.id, body.vehicleId, userInfo.email);
                    if vehicleUpdated is error {
                        log:printError("Error updating vehicle on reused reservation", vehicleUpdated);
                        return <http:InternalServerError>{
                            body: {message: "Error occurred while updating reservation."}
                        };
                    }
                }
                return {
                    reservationId: activeReservation.id,
                    coinsAmount: activeReservation.coinsAmount
                };
            }
            log:printWarn("Employee already has an active parking reservation for the date",
                    invokerEmail = userInfo.email, bookingDate = body.bookingDate,
                    existingSlot = activeReservation.slotId);
            string activeMsg = activeReservation.status == database:CONFIRMED
                ? string `You already have a confirmed parking booking for ${body.bookingDate}`
                    + string ` (slot ${activeReservation.slotId}).`
                : string `You already have a pending parking booking for ${body.bookingDate}`
                    + string ` (slot ${activeReservation.slotId}). Complete or cancel it before booking another.`;
            return <http:BadRequest>{
                body: {message: activeMsg}
            };
        }

        // Expire stale pending reservations so the slot/date becomes reusable.
        boolean|error cleared = database:expireStalePendingParkingReservationForSlotDate(body.slotId, body.bookingDate,
                wso2_coin:pendingReservationExpiryMinutes);
        if cleared is error {
            log:printError("Error expiring stale pending reservations", cleared);
            return <http:InternalServerError>{
                body: {message: "Error occurred while validating slot availability."}
            };
        }

        boolean|error booked = database:isParkingSlotBookedForDate(body.slotId, body.bookingDate,
                wso2_coin:pendingReservationExpiryMinutes);
        if booked is error {
            log:printError("Error checking slot availability", booked);
            return <http:InternalServerError>{
                body: {message: "Error occurred while checking slot availability."}
            };
        }
        if booked {
            return <http:BadRequest>{
                body: {
                    message: string `Slot ${body.slotId} is unavailable for ${body.bookingDate}. `
                        + "It may be temporarily reserved or already booked."
                }
            };
        }

        // Mint the transaction hash up front (0x + 64 hex); it is reused as the payment
        // idempotency key on confirm, so retries never double-charge.
        string transactionHash = "0x" + (re `-`).replaceAll(uuid:createType4AsString(), "")
            + (re `-`).replaceAll(uuid:createType4AsString(), "");

        // Insert a new PENDING row
        int|error reservationId = database:addParkingReservation({
                                                                     slotId: body.slotId,
                                                                     bookingDate: body.bookingDate,
                                                                     employeeEmail: userInfo.email,
                                                                     vehicleId: body.vehicleId,
                                                                     coinsAmount: slot.coinsPerSlot,
                                                                     transactionHash,
                                                                     createdBy: userInfo.email
                                                                 });
        if reservationId is database:DuplicateActiveReservationError {
            log:printWarn("Duplicate active parking reservation blocked by unique index",
                    invokerEmail = userInfo.email, bookingDate = body.bookingDate, slotId = body.slotId);
            return <http:BadRequest>{
                body: {
                    message: "You already have an active booking for this date, or the slot was just taken. "
                        + "Please refresh and try again."
                }
            };
        }
        if reservationId is error {
            log:printError("Error creating parking reservation", reservationId);
            return <http:InternalServerError>{
                body: {message: "Error occurred while creating reservation."}
            };
        }

        return {
            reservationId,
            coinsAmount: slot.coinsPerSlot
        };
    }

    # Get current user's parking reservations.
    #
    # + fromDate - Filter reservations from this date
    # + toDate - Filter reservations up to this date
    # + return - List of parking reservations or error response
    resource function get parkings/reservations(http:RequestContext ctx, string? fromDate, string? toDate)
        returns database:ParkingReservationDetails[]|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        database:ParkingReservationDetails[]|error list = database:getParkingReservationsByEmployee(
                userInfo.email, fromDate, toDate);
        if list is error {
            log:printError("Error fetching parking reservations", list);
            return <http:InternalServerError>{
                body: {message: "Error occurred while fetching reservations."}
            };
        }
        return list;
    }

    # Get a single reservation.
    #
    # + id - Reservation identifier
    # + return - Parking reservation details or error response
    resource function get parkings/reservations/[int id](http:RequestContext ctx)
        returns database:ParkingReservationDetails|http:InternalServerError|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        database:ParkingReservationDetails|error? reservation = database:getParkingReservationById(id);
        if reservation is error {
            log:printError("Error fetching parking reservation", reservation);
            return <http:InternalServerError>{
                body: {message: "Error occurred while fetching reservation."}
            };
        }
        if reservation is () || reservation.employeeEmail != userInfo.email {
            return <http:Forbidden>{
                body: {message: "You are not allowed to view this reservation."}
            };
        }
        return reservation;
    }

    # Export employees as a CSV file, optionally filtered by status.
    #
    # + payload - Report generation options (status filter, future-joiner exclusion, marked-leaver inclusion)
    # + return - CSV file response or HTTP errors
    resource function post reports/employees/generate(http:RequestContext ctx,
            @http:Payload database:EmployeeReportPayload payload)
        returns http:Response|http:Forbidden|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }
        // Employee reports only. QR code generation stays with admin and service desk,
        // which is checked on its own endpoint.
        if !canReadAnyEmployee(userInfo) {
            log:printWarn("User is not authorized to access reports", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {message: "You are not authorized to access reports"}
            };
        }

        database:Employee[] allEmployees = [];
        boolean fetchMore = true;
        int offset = 0;

        while fetchMore {
            database:EmployeesResponse|error pageResult = database:getEmployees(includePersonalInfo = true, payload = {
                                                                                    searchString: (),
                                                                                    filters: payload.filters,
                                                                                    pagination: {'limit: database:DEFAULT_LIMIT, offset: offset},
                                                                                    sort: {sortField: "employeeId", sortOrder: "ASC"}
                                                                                });
            if pageResult is error {
                log:printError("Error fetching employees for report", pageResult);
                return <http:InternalServerError>{
                    body: {message: "Error generating report"}
                };
            }
            allEmployees.push(...pageResult.employees);
            if pageResult.employees.length() < database:DEFAULT_LIMIT {
                fetchMore = false;
            }
            offset += database:DEFAULT_LIMIT;
        }

        map<string>|error nameMap = database:getEmployeeEmailToNameMap();
        if nameMap is error {
            log:printError("Error fetching employee name map for report", nameMap);
            return <http:InternalServerError>{
                body: {message: "Error generating report"}
            };
        }

        database:LeadershipGroup[]|error leadershipGroups = database:getLeadershipGroups();
        if leadershipGroups is error {
            log:printError("Error fetching leadership groups for report", leadershipGroups);
            return <http:InternalServerError>{body: {message: "Error generating report"}};
        }

        string csvContent = payload.filters.employeeStatus == database:EMPLOYEE_LEFT
            ? database:buildResignationCsv(allEmployees, nameMap, payload.columns, leadershipGroups)
            : database:buildEmployeeCsv(allEmployees, nameMap, payload.columns, leadershipGroups);
        string? filterStatus = payload.filters.employeeStatus;
        string statusLabel = filterStatus is () ? "all" : re ` `.replaceAll(filterStatus.toLowerAscii(), "_");
        string filename = statusLabel + "_employees_report_" + time:utcToString(time:utcNow()).substring(0, 10) + ".csv";

        http:Response response = new;
        response.setHeader("Content-Type", "text/csv");
        response.setHeader("Content-Disposition", string `attachment; filename="${filename}"`);
        response.setTextPayload(csvContent);
        return response;
    }

    # Confirm a parking reservation by collecting payment from the selected wallet.
    #
    # + body - Request containing the reservation ID and the payer wallet address
    # + return - Reservation details with CONFIRMED status or error response
    resource function post parkings/reservations/confirm(http:RequestContext ctx, http:Request request,
            ConfirmParkingReservationRequest body)
        returns database:ParkingReservationDetails|http:BadRequest|http:InternalServerError|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        string|error userAssertion = request.getHeader(authorization:JWT_ASSERTION_HEADER);
        if userAssertion is error {
            log:printError("Missing user assertion header while confirming reservation", userAssertion,
                    invokerEmail = userInfo.email);
            return <http:InternalServerError>{
                body: {message: "Error occurred while confirming reservation."}
            };
        }

        string fromAddress = body.fromAddress.trim();
        if fromAddress.length() == 0 {
            log:printWarn("Parking reservation confirmation missing payer wallet address",
                    invokerEmail = userInfo.email, reservationId = body.reservationId);
            return <http:BadRequest>{
                body: {message: "A payer wallet address is required."}
            };
        }

        database:ParkingReservationDetails|error? reservation = database:getParkingReservationById(body.reservationId);

        if reservation is error {
            log:printError("Error fetching reservation", reservation);
            return <http:InternalServerError>{
                body: {message: "Error occurred while confirming reservation."}
            };
        }
        if reservation is () || reservation.employeeEmail != userInfo.email {
            log:printWarn("Unauthorized parking reservation confirmation attempt", invokerEmail = userInfo.email,
                    reservationId = body.reservationId);
            return <http:Forbidden>{
                body: {message: "You are not allowed to confirm this reservation."}
            };
        }

        if reservation.status != database:PENDING {
            log:printWarn("Attempt to confirm a non-pending parking reservation", invokerEmail = userInfo.email,
                    reservationId = reservation.id, status = reservation.status);
            return <http:BadRequest>{
                body: {message: string `Reservation is already ${reservation.status.toString()}. Cannot confirm.`}
            };
        }

        // Reuse the transaction hash minted at create as the idempotency key; fall back to the
        // reservation-derived reference for any row created before this field was populated.
        string paymentReference = reservation.paymentReference
            ?: (wso2_coin:PARKING_PAYMENT_REFERENCE_PREFIX + reservation.id.toString());
        wso2_coin:CollectPaymentResponse|error payment = wso2_coin:collectPayment(userAssertion, fromAddress,
                reservation.coinsAmount, paymentReference);
        if payment is wso2_coin:PaymentError {
            wso2_coin:PaymentErrorDetail detail = payment.detail();
            log:printWarn("Parking payment rejected by the payment service", invokerEmail = userInfo.email,
                    reservationId = reservation.id, statusCode = detail.statusCode);
            match detail.statusCode {
                http:STATUS_FORBIDDEN => {
                    return <http:Forbidden>{
                        body: {message: "The selected wallet does not belong to you."}
                    };
                }
                http:STATUS_BAD_REQUEST|http:STATUS_CONFLICT => {
                    return <http:BadRequest>{
                        body: {message: detail.reason}
                    };
                }
            }
            return <http:InternalServerError>{
                body: {message: "Error occurred while confirming reservation."}
            };
        }
        if payment is error {
            log:printError("Error collecting parking payment", payment, invokerEmail = userInfo.email,
                    reservationId = reservation.id);
            return <http:InternalServerError>{
                body: {message: "Error occurred while confirming reservation."}
            };
        }

        // Transition PENDING -> CONFIRMED atomically so two concurrent confirms cannot both proceed.
        boolean|error confirmed = database:confirmParkingReservation(reservation.id, payment.reference,
                userInfo.email);
        if confirmed is error {
            log:printError("Error confirming reservation", confirmed, invokerEmail = userInfo.email,
                    reservationId = reservation.id);
            return <http:InternalServerError>{
                body: {message: "Error occurred while confirming reservation."}
            };
        }

        database:ParkingReservationDetails|error? confirmedReservation = database:getParkingReservationById(reservation.id);
        if confirmedReservation is error || confirmedReservation is () {
            log:printError("Error fetching confirmed reservation", confirmedReservation);
            return <http:InternalServerError>{
                body: {message: "Reservation confirmed but failed to fetch updated details."}
            };
        }

        if !confirmed {
            // A concurrent request already transitioned this reservation. The payment used the
            // deterministic parking-<id> reference, so it was charged at most once.
            if confirmedReservation.status == database:CONFIRMED {
                return confirmedReservation;
            }
            log:printWarn("Parking reservation confirmation lost a concurrent transition",
                    invokerEmail = userInfo.email, reservationId = reservation.id,
                    status = confirmedReservation.status);
            return <http:BadRequest>{
                body: {message: string `Reservation is ${confirmedReservation.status.toString()}. Cannot confirm.`}
            };
        }

        // This request performed the transition — append to Google Sheet.
        error? sheetErr = wso2_coin:appendParkingReservation(confirmedReservation);
        if sheetErr is error {
            log:printError("Failed to append parking reservation to Google Sheet", sheetErr,
                    reservationId = confirmedReservation.id);
        }

        return confirmedReservation;
    }

    # Create a business unit.
    #
    # + ctx - Request context
    # + payload - Business unit creation payload
    # + return - ID of the new business unit, or HTTP errors
    resource function post business\-units(http:RequestContext ctx, database:CreateCompanyOrgChartEntityPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create business unit", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        int|error newId = database:createBusinessUnit(payload, userInfo.email);
        if newId is error {
            string customErr = "Error occurred while creating business unit";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Update a business unit.
    #
    # + ctx - Request context
    # + id - Business unit ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch business\-units/[int id](http:RequestContext ctx,
            database:UpdateCompanyOrgChartEntityPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update business unit", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if payload.isActive == false {
            boolean|error hasEmployees = database:hasActiveEmployeesInBusinessUnit(id);
            if hasEmployees is error {
                log:printError("Error checking active employees in business unit", hasEmployees, id = id);
                return <http:InternalServerError>{body: {message: "Error occurred while updating business unit"}};
            }
            if hasEmployees {
                return <http:BadRequest>{
                    body: {message: "Cannot deactivate: there are active employees or new joiners assigned to this business unit"}
                };
            }
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        error? updateResult = database:updateBusinessUnit(id, payload, userInfo.email);
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating business unit", updateResult, id = id);
            return <http:InternalServerError>{body: {message: "Error occurred while updating business unit"}};
        }
        return http:OK;
    }

    # Create a team.
    #
    # + ctx - Request context
    # + payload - Team creation payload
    # + return - ID of the new team, or HTTP errors
    resource function post teams(http:RequestContext ctx, database:CreateCompanyOrgChartEntityPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create team", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        int|error newId = database:createTeam(payload, userInfo.email);
        if newId is error {
            string customErr = "Error occurred while creating team";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Update a team.
    #
    # + ctx - Request context
    # + id - Team ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch teams/[int id](http:RequestContext ctx,
            database:UpdateCompanyOrgChartEntityPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update team", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if payload.isActive == false {
            boolean|error hasEmployees = database:hasActiveEmployeesInTeam(id);
            if hasEmployees is error {
                log:printError("Error checking active employees in team", hasEmployees, id = id);
                return <http:InternalServerError>{body: {message: "Error occurred while updating team"}};
            }
            if hasEmployees {
                return <http:BadRequest>{
                    body: {message: "Cannot deactivate: there are active employees or new joiners assigned to this team"}
                };
            }
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        error? updateResult = database:updateTeam(id, payload, userInfo.email);
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating team", updateResult, id = id);
            return <http:InternalServerError>{body: {message: "Error occurred while updating team"}};
        }
        return http:OK;
    }

    # Create a sub-team.
    #
    # + ctx - Request context
    # + payload - Sub-team creation payload
    # + return - ID of the new sub-team, or HTTP errors
    resource function post sub\-teams(http:RequestContext ctx, database:CreateCompanyOrgChartEntityPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create sub-team", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        int|error newId = database:createSubTeam(payload, userInfo.email);
        if newId is error {
            string customErr = "Error occurred while creating sub-team";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Update a sub-team.
    #
    # + ctx - Request context
    # + id - Sub-team ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch sub\-teams/[int id](http:RequestContext ctx,
            database:UpdateCompanyOrgChartEntityPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update sub-team", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if payload.isActive == false {
            boolean|error hasEmployees = database:hasActiveEmployeesInSubTeam(id);
            if hasEmployees is error {
                log:printError("Error checking active employees in sub-team", hasEmployees, id = id);
                return <http:InternalServerError>{body: {message: "Error occurred while updating sub-team"}};
            }
            if hasEmployees {
                return <http:BadRequest>{
                    body: {message: "Cannot deactivate: there are active employees or new joiners assigned to this sub-team"}
                };
            }
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        error? updateResult = database:updateSubTeam(id, payload, userInfo.email);
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating sub-team", updateResult, id = id);
            return <http:InternalServerError>{body: {message: "Error occurred while updating sub-team"}};
        }
        return http:OK;
    }

    # Create a unit.
    #
    # + ctx - Request context
    # + payload - Unit creation payload
    # + return - ID of the new unit, or HTTP errors
    resource function post units(http:RequestContext ctx, database:CreateCompanyOrgChartEntityPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create unit", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        int|error newId = database:createUnit(payload, userInfo.email);
        if newId is error {
            string customErr = "Error occurred while creating unit";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Update a unit.
    #
    # + ctx - Request context
    # + id - Unit ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch units/[int id](http:RequestContext ctx,
            database:UpdateCompanyOrgChartEntityPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update unit", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if payload.isActive == false {
            boolean|error hasEmployees = database:hasActiveEmployeesInUnit(id);
            if hasEmployees is error {
                log:printError("Error checking active employees in unit", hasEmployees, id = id);
                return <http:InternalServerError>{body: {message: "Error occurred while updating unit"}};
            }
            if hasEmployees {
                return <http:BadRequest>{
                    body: {message: "Cannot deactivate: there are active employees or new joiners assigned to this unit"}
                };
            }
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        error? updateResult = database:updateUnit(id, payload, userInfo.email);
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating unit", updateResult, id = id);
            return <http:InternalServerError>{body: {message: "Error occurred while updating unit"}};
        }
        return http:OK;
    }

    # Create a career function.
    #
    # + ctx - Request context
    # + payload - Career function creation payload
    # + return - ID of the new career function, or HTTP errors
    resource function post career\-functions(http:RequestContext ctx,
            database:CreateCareerFunctionPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create career function", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage career functions"}};
        }

        int|error newId = database:createCareerFunction(payload, userInfo.email);
        if newId is database:DuplicateCareerFunctionError {
            return <http:BadRequest>{body: {message: newId.message()}};
        }
        if newId is error {
            string customErr = "Error occurred while creating career function";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Update a career function.
    #
    # + ctx - Request context
    # + id - Career function ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch career\-functions/[int id](http:RequestContext ctx,
            database:UpdateCareerFunctionPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update career function", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage career functions"}};
        }

        if payload.isActive == false {
            // Only the active-employee check gates deactivation. A career function with
            // active-but-unstaffed designations may be deactivated: the onboarding form
            // fetches designations scoped to a chosen career function
            // (fetchDesignations({ careerFunctionId })) and the career function dropdown
            // comes from GET /career-functions, which is active-only by default — so a
            // deactivated function's designations are already unreachable for new hires.
            boolean|error hasEmployees = database:hasActiveEmployeesInCareerFunction(id);
            if hasEmployees is error {
                log:printError("Error checking active employees in career function", hasEmployees, id = id);
                return <http:InternalServerError>{
                    body: {message: "Error occurred while updating career function"}
                };
            }
            if hasEmployees {
                return <http:BadRequest>{
                    body: {message: "Cannot deactivate: there are active employees or new joiners in this career function"}
                };
            }
        }

        error? updateResult = database:updateCareerFunction(id, payload, userInfo.email);
        if updateResult is database:DuplicateCareerFunctionError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating career function", updateResult, id = id);
            return <http:InternalServerError>{body: {message: "Error occurred while updating career function"}};
        }
        return http:OK;
    }

    # Create a leadership attribute.
    #
    # + ctx - Request context
    # + payload - Leadership attribute creation payload
    # + return - New attribute ID or HTTP errors
    resource function post leadership\-groups(http:RequestContext ctx,
            database:CreateLeadershipGroupPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create leadership attribute", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage leadership attributes"}};
        }

        int|error newId = database:createLeadershipGroup(payload, userInfo.email);
        if newId is database:DuplicateLeadershipGroupError {
            return <http:BadRequest>{body: {message: newId.message()}};
        }
        if newId is error {
            string customErr = "Error occurred while creating leadership attribute";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Rename, retire or reactivate a leadership attribute.
    #
    # Retiring is refused while current employees hold the attribute.
    #
    # + ctx - Request context
    # + id - Leadership attribute ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch leadership\-groups/[int id](http:RequestContext ctx,
            database:UpdateLeadershipGroupPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update leadership attribute", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage leadership attributes"}};
        }

        error? updateResult = database:updateLeadershipGroup(id, payload, userInfo.email);
        if updateResult is database:DuplicateLeadershipGroupError|database:LeadershipGroupInUseError
                |database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating leadership attribute", updateResult, id = id);
            return <http:InternalServerError>{body: {message: "Error occurred while updating leadership attribute"}};
        }
        return http:OK;
    }

    # Create a designation.
    #
    # + ctx - Request context
    # + payload - Designation creation payload
    # + return - ID of the new designation, or HTTP errors
    resource function post designations(http:RequestContext ctx, database:CreateDesignationPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create designation", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage designations"}};
        }

        int|error newId = database:createDesignation(payload, userInfo.email);
        if newId is database:DuplicateDesignationError || newId is database:UnknownCareerFunctionError {
            return <http:BadRequest>{body: {message: newId.message()}};
        }
        if newId is error {
            string customErr = "Error occurred while creating designation";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Update a designation.
    #
    # + ctx - Request context
    # + id - Designation ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch designations/[int id](http:RequestContext ctx,
            database:UpdateDesignationPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update designation", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage designations"}};
        }

        if payload.isActive == false {
            boolean|error hasEmployees = database:hasActiveEmployeesInDesignation(id);
            if hasEmployees is error {
                log:printError("Error checking active employees in designation", hasEmployees, id = id);
                return <http:InternalServerError>{body: {message: "Error occurred while updating designation"}};
            }
            if hasEmployees {
                return <http:BadRequest>{
                    body: {message: "Cannot deactivate: there are active employees or new joiners with this designation"}
                };
            }
        }

        error? updateResult = database:updateDesignation(id, payload, userInfo.email);
        if updateResult is database:DuplicateDesignationError
                || updateResult is database:UnknownCareerFunctionError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating designation", updateResult, id = id);
            return <http:InternalServerError>{body: {message: "Error occurred while updating designation"}};
        }
        return http:OK;
    }

    # Create a business-unit → team mapping.
    #
    # + ctx - Request context
    # + payload - Mapping creation payload
    # + return - ID of the new mapping, or HTTP errors
    resource function post business\-unit\-teams(http:RequestContext ctx,
            database:CreateBusinessUnitTeamPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create business unit team mapping", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        int|error newId = database:createBusinessUnitTeam(payload, userInfo.email);
        if newId is error {
            string customErr = "Error occurred while creating business unit team mapping";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Update a business-unit → team mapping.
    #
    # + ctx - Request context
    # + id - Mapping ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch business\-unit\-teams/[int id](http:RequestContext ctx,
            database:UpdateMappingPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update business unit team mapping", invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if payload.isActive == false {
            boolean|error hasEmployees = database:hasActiveEmployeesInBUTeamMapping(id);
            if hasEmployees is error {
                log:printError("Error checking active employees in business unit team mapping",
                        hasEmployees, id = id);
                return <http:InternalServerError>{
                    body: {message: "Error occurred while updating business unit team mapping"}
                };
            }
            if hasEmployees {
                return <http:BadRequest>{
                    body: {message: "Cannot deactivate: there are active employees or new joiners assigned to this mapping"}
                };
            }
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        error? updateResult = database:updateBusinessUnitTeam(id, payload, userInfo.email);
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating business unit team mapping", updateResult, id = id);
            return <http:InternalServerError>{
                body: {message: "Error occurred while updating business unit team mapping"}
            };
        }
        return http:OK;
    }

    # Create a business-unit-team → sub-team mapping.
    #
    # + ctx - Request context
    # + payload - Mapping creation payload
    # + return - ID of the new mapping, or HTTP errors
    resource function post business\-unit\-team\-sub\-teams(http:RequestContext ctx,
            database:CreateBusinessUnitTeamSubTeamPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create business unit team sub-team mapping",
                    invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        int|error newId = database:createBusinessUnitTeamSubTeam(payload, userInfo.email);
        if newId is error {
            string customErr = "Error occurred while creating business unit team sub-team mapping";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Update a business-unit-team → sub-team mapping.
    #
    # + ctx - Request context
    # + id - Mapping ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch business\-unit\-team\-sub\-teams/[int id](http:RequestContext ctx,
            database:UpdateMappingPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update business unit team sub-team mapping",
                    invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if payload.isActive == false {
            boolean|error hasEmployees = database:hasActiveEmployeesInBUTeamSubTeamMapping(id);
            if hasEmployees is error {
                log:printError("Error checking active employees in business unit team sub-team mapping",
                        hasEmployees, id = id);
                return <http:InternalServerError>{
                    body: {message: "Error occurred while updating business unit team sub-team mapping"}
                };
            }
            if hasEmployees {
                return <http:BadRequest>{
                    body: {message: "Cannot deactivate: there are active employees or new joiners assigned to this mapping"}
                };
            }
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        error? updateResult = database:updateBusinessUnitTeamSubTeam(id, payload, userInfo.email);
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating business unit team sub-team mapping",
                    updateResult, id = id);
            return <http:InternalServerError>{
                body: {message: "Error occurred while updating business unit team sub-team mapping"}
            };
        }
        return http:OK;
    }

    # Create a business-unit-team-sub-team → unit mapping.
    #
    # + ctx - Request context
    # + payload - Mapping creation payload
    # + return - ID of the new mapping, or HTTP errors
    resource function post business\-unit\-team\-sub\-team\-units(http:RequestContext ctx,
            database:CreateBusinessUnitTeamSubTeamUnitPayload payload)
            returns int|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to create business unit team sub-team unit mapping",
                    invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        int|error newId = database:createBusinessUnitTeamSubTeamUnit(payload, userInfo.email);
        if newId is error {
            string customErr = "Error occurred while creating business unit team sub-team unit mapping";
            log:printError(customErr, newId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return newId;
    }

    # Update a business-unit-team-sub-team → unit mapping.
    #
    # + ctx - Request context
    # + id - Mapping ID
    # + payload - Update payload
    # + return - HTTP OK or HTTP errors
    resource function patch business\-unit\-team\-sub\-team\-units/[int id](http:RequestContext ctx,
            database:UpdateMappingPayload payload)
            returns http:Ok|http:Forbidden|http:NotFound|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to update business unit team sub-team unit mapping",
                    invokerEmail = userInfo.email);
            return <http:Forbidden>{body: {message: "You are not authorized to manage the company org chart"}};
        }

        if payload.isActive == false {
            boolean|error hasEmployees = database:hasActiveEmployeesInBUTeamSubTeamUnitMapping(id);
            if hasEmployees is error {
                log:printError("Error checking active employees in business unit team sub-team unit mapping",
                        hasEmployees, id = id);
                return <http:InternalServerError>{
                    body: {message: "Error occurred while updating business unit team sub-team unit mapping"}
                };
            }
            if hasEmployees {
                return <http:BadRequest>{
                    body: {message: "Cannot deactivate: there are active employees or new joiners assigned to this mapping"}
                };
            }
        }

        if !database:isValidOptionalPatternString(payload.headEmail, database:EMAIL_PATTERN) {
            string customErr = "Invalid head email format";
            log:printWarn(customErr, headEmail = payload.headEmail);
            return <http:BadRequest>{body: {message: customErr}};
        }

        error? updateResult = database:updateBusinessUnitTeamSubTeamUnit(id, payload, userInfo.email);
        if updateResult is database:EntityNotFoundError {
            return <http:NotFound>{body: {message: updateResult.message()}};
        }
        if updateResult is database:NoFieldsToUpdateError {
            return <http:BadRequest>{body: {message: updateResult.message()}};
        }
        if updateResult is error {
            log:printError("Error occurred while updating business unit team sub-team unit mapping",
                    updateResult, id = id);
            return <http:InternalServerError>{
                body: {message: "Error occurred while updating business unit team sub-team unit mapping"}
            };
        }
        return http:OK;
    }

    # Get the company org chart structure (ADMIN only).
    #
    # + ctx - Request context
    # + return - Company org chart structure with full mapping metadata, or HTTP errors
    resource function get company\-org\-structure(http:RequestContext ctx)
            returns database:CompanyOrgChartBusinessUnit[]|http:Forbidden|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}};
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to access company org chart structure",
                    invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {message: "You are not authorized to access the company org chart structure"}
            };
        }

        database:CompanyOrgChartBusinessUnit[]|error orgStructure = database:getCompanyOrgChartStructure();
        if orgStructure is error {
            string customErr = "Error occurred while fetching the company org chart structure";
            log:printError(customErr, orgStructure);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return orgStructure;
    }

    # Fetch the employment history timeline for an employee.
    #
    # Returns every employment period held by the *person* behind the given employee ID
    # (a rehire has more than one), the field-level changes derived from the audit trail,
    # and the approved promotions from HRIS attached to the period they fall in.
    #
    # + employeeId - Employee ID
    # + return - History timeline, or an error response
    resource function get employees/[string employeeId]/history(http:RequestContext ctx)
        returns EmployeeHistoryResponse|http:InternalServerError|http:NotFound|http:Forbidden {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {
                    message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND
                }
            };
        }

        // Access and projection are one decision, carried by one variable, so a caller can never
        // be granted access under one tier and then filtered under another.
        //
        // - ADMIN, and a LEAD viewing their own subordinate, get the full projection:
        //   attribution and system rows included. A lead can already see a subordinate's
        //   designation, manager, status and dates through the sibling employee endpoint;
        //   history adds only *when* those changed, so withholding it would be inconsistent.
        // - Self gets the employee projection: no actionBy, no system rows.
        // The employee-view role reads any employee's record, so it gets the same
        // projection an admin does: the fallback below is self-only, which would
        // otherwise deny it a history it is allowed to see.
        boolean hasFullProjection = canReadAnyEmployee(userInfo);

        if !hasFullProjection {
            // Two conditions, and both are required.
            //
            // `manager_email` is never cleared when an employment ends, so an old row names its
            // former manager forever. The subordinate check alone would therefore let a former
            // lead pass by quoting a stale employee ID — and because the response fans out to
            // every period for that person, they would receive the current employment too.
            // Requiring the requested row to be the person's current employment closes that:
            // the lead projection is granted only for someone they still manage today.
            boolean|error isSubordinate = database:isSubordinateOfLead(userInfo.email, employeeId);
            if isSubordinate is error {
                string customErr = string `Error occurred while checking lead authorization for ID: ${employeeId}`;
                log:printError(customErr, isSubordinate, employeeId = employeeId);
                return <http:InternalServerError>{body: {message: customErr}};
            }

            if isSubordinate {
                boolean|error isCurrent = database:isCurrentEmployment(employeeId);
                if isCurrent is error {
                    string customErr = string `Error occurred while checking employment currency for ID: ${employeeId}`;
                    log:printError(customErr, isCurrent, employeeId = employeeId);
                    return <http:InternalServerError>{body: {message: customErr}};
                }
                if !isCurrent {
                    log:printWarn("Lead access denied: requested employment is not the person's current one",
                            invokerEmail = userInfo.email, employeeId = employeeId);
                }
                hasFullProjection = isCurrent;
            }
        }

        // Authorization compares *people*, not employee IDs. A rehired person holds several
        // employee IDs against one personal_info row (e.g. intern "IN 0456" then permanent
        // "EP 10006"), so comparing the caller's employee ID against the requested one would
        // deny them their own earlier employment. Admins and leads-of-this-report skip this.
        if !hasFullProjection {
            int?|error callerPersonalInfoId = database:getPersonalInfoIdByWorkEmail(userInfo.email);
            if callerPersonalInfoId is error {
                string customErr = "Error occurred while resolving the invoker's employee record";
                log:printError(customErr, callerPersonalInfoId, invokerEmail = userInfo.email);
                return <http:InternalServerError>{body: {message: customErr}};
            }

            int?|error requestedPersonalInfoId = database:getPersonalInfoIdByEmployeeId(employeeId);
            if requestedPersonalInfoId is error {
                string customErr = string `Error occurred while resolving employee record for ID: ${employeeId}`;
                log:printError(customErr, requestedPersonalInfoId, employeeId = employeeId);
                return <http:InternalServerError>{body: {message: customErr}};
            }

            if requestedPersonalInfoId is () {
                string customErr = "Employee information not found";
                log:printWarn(customErr, employeeId = employeeId);
                return <http:NotFound>{body: {message: customErr}};
            }

            if callerPersonalInfoId is () || callerPersonalInfoId != requestedPersonalInfoId {
                log:printWarn("User is not authorized to view this employee's history",
                        invokerEmail = userInfo.email, employeeId = employeeId);
                return <http:Forbidden>{
                    body: {message: "You are not authorized to view this employee's history"}
                };
            }
        }

        database:EmploymentPeriod[]|error periods = database:getEmploymentPeriods(employeeId);
        if periods is error {
            string customErr = string `Error occurred while fetching employment periods for ID: ${employeeId}`;
            log:printError(customErr, periods, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }

        if periods.length() == 0 {
            string customErr = "Employee information not found";
            log:printWarn(customErr, employeeId = employeeId);
            return <http:NotFound>{body: {message: customErr}};
        }

        int[] employeePkIds = from database:EmploymentPeriod period in periods
            select period.id;

        database:AuditSnapshot[]|error snapshots = database:getAuditSnapshots(employeePkIds);
        if snapshots is error {
            string customErr = string `Error occurred while fetching audit history for ID: ${employeeId}`;
            log:printError(customErr, snapshots, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }

        database:HistoryEvent[] events = database:buildHistoryEvents(snapshots);

        // Audit snapshots store foreign keys, so an event reads "87" until its id is
        // resolved. A lookup failure degrades to raw ids rather than failing the request —
        // an unhelpful timeline is better than none.
        map<map<string>>|error lookupNames = database:getHistoryLookupNames();
        if lookupNames is map<map<string>> {
            events = database:resolveHistoryEventNames(events, lookupNames);
        } else {
            log:printError("Error resolving history lookup names; returning raw ids",
                    lookupNames, employeeId = employeeId);
        }

        // The HRIS promotion database is a second database. An outage there must degrade the
        // timeline rather than break the employee's own profile page, so the failure is
        // reported as a flag alongside an otherwise complete response.
        boolean promotionsUnavailable = false;
        promotion:PromotionRecord[] promotions = [];

        // work_email lives on the employment row, and a chain is walked by
        // continuous_service_record rather than by email, so periods can legitimately carry
        // different emails. Querying only the newest one would silently omit promotions
        // raised under a former address.
        string[] workEmails = [];
        foreach database:EmploymentPeriod period in periods {
            if period.workEmail.trim() != "" && workEmails.indexOf(period.workEmail) is () {
                workEmails.push(period.workEmail);
            }
        }

        foreach string workEmail in workEmails {
            promotion:PromotionRecord[]|error fetched = promotion:getApprovedPromotions(workEmail);
            if fetched is error {
                promotionsUnavailable = true;
                log:printError("Error occurred while fetching promotions from HRIS; returning history without them",
                        fetched, employeeId = employeeId, workEmail = workEmail);
            } else {
                promotions.push(...fetched);
            }
        }

        EmploymentPeriodResponse[] periodResponses = assignPromotionsToPeriods(periods, promotions);

        return {
            periods: periodResponses,
            events: projectHistoryEvents(events, hasFullProjection),
            promotionsUnavailable: promotionsUnavailable
        };
    }

    # Schedule a change to an employee's general information for a future date.
    #
    # The same edit an admin can apply immediately, held until the date it should take
    # effect: a promotion effective the first of the month, a transfer effective when the
    # quarter starts. The scheduler applies it on the day through a plain update, so the
    # audit trail and the profile history read exactly as they would for a change made by
    # hand.
    #
    # The caller sends what the targeted fields hold now alongside the change. The sweep
    # compares against it on the day, so a change overtaken by a direct edit to the same
    # field is reported rather than quietly undoing the more recent decision.
    #
    # + employeeId - Employee ID
    # + payload - Effective date and the fields to change
    # + return - HTTP Created with the scheduled change id, or HTTP errors
    resource function post employees/[string employeeId]/scheduled\-changes(http:RequestContext ctx,
            @http:Payload database:ScheduleChangePayload payload)
        returns http:Created|http:NotFound|http:Forbidden|http:BadRequest|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        // Scheduling is the same act as editing, deferred, so it is gated the same way the
        // inline section editor is.
        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("User is not authorized to schedule an employee change",
                    invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {message: "You are not authorized to schedule a change"}
            };
        }

        database:Employee|error? employeeInfo = database:getEmployeeInfo(employeeId);
        if employeeInfo is error {
            string customErr = string `Error occurred while fetching employee information for ID: ${employeeId}`;
            log:printError(customErr, employeeInfo, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        if employeeInfo is () {
            string customErr = "Employee information not found";
            log:printWarn(customErr, employeeId = employeeId);
            return <http:NotFound>{body: {message: customErr}};
        }

        // Judged against today where the employee works, the day the sweep will act on.
        // Today is refused along with the past: the sweep would apply it at its next run,
        // and an edit meant to take effect now should be applied now.
        string|error today = todayAt(employeeInfo.companyId, employeeInfo.workLocation);
        if today is error {
            string customErr = string `Error occurred while reading the work location's timezone for ID: ${employeeId}`;
            log:printError(customErr, today, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        if !isFutureDate(payload.effectiveDate, today) {
            log:printWarn("Scheduled change rejected: effective date is not in the future",
                    employeeId = employeeId, effectiveDate = payload.effectiveDate, today = today);
            return <http:BadRequest>{
                body: {message: "The effective date must be a future date"}
            };
        }

        // Refused while somebody is present to be told. A field the sweep cannot write
        // would otherwise sit pending until its date and fail there, long after the person
        // who scheduled it has moved on.
        map<json>|error columnChanges = toSchedulableColumns(payload.changes);
        if columnChanges is error {
            log:printWarn("Scheduled change rejected: a field cannot be scheduled",
                    employeeId = employeeId, reason = columnChanges.message());
            return <http:BadRequest>{body: {message: columnChanges.message()}};
        }

        // Refused rather than scheduled without it: the sweep compares against these on
        // the day, and a change carrying none would be applied without that check.
        map<json>|error expected = expectedValuesFor(employeeInfo, columnChanges);
        if expected is error {
            string customErr = string `Error occurred while recording the current values for ID: ${employeeId}`;
            log:printError(customErr, expected, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }

        int|error scheduled = database:scheduleEmployeeChange(employeeId, payload.effectiveDate,
                columnChanges.toJsonString(), expected.toJsonString(), userInfo.email);
        if scheduled is error {
            string customErr = string `Error occurred while scheduling a change for ID: ${employeeId}`;
            log:printError(customErr, scheduled, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }

        return <http:Created>{body: {id: scheduled}};
    }

    # Fetch an employee's scheduled changes.
    #
    # + employeeId - Employee ID
    # + pendingOnly - Limit to changes still waiting for their date
    # + return - The scheduled changes, or HTTP errors
    resource function get employees/[string employeeId]/scheduled\-changes(http:RequestContext ctx,
            boolean pendingOnly = true)
        returns database:ScheduledChange[]|http:NotFound|http:Forbidden|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        // Read access matches the profile: anyone who may read the record may see what is
        // queued against it, so the record is never shown as settled when it is not.
        if !canReadAnyEmployee(userInfo) {
            log:printWarn("User is not authorized to view scheduled changes",
                    invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {message: "You are not authorized to view scheduled changes"}
            };
        }

        database:ScheduledChange[]|error changes = database:getScheduledChanges(employeeId, pendingOnly);
        if changes is error {
            string customErr = string `Error occurred while fetching scheduled changes for ID: ${employeeId}`;
            log:printError(customErr, changes, employeeId = employeeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        return changes;
    }

    # Withdraw a scheduled change before its date arrives.
    #
    # + employeeId - Employee ID
    # + changeId - Scheduled change id
    # + return - HTTP OK, or HTTP errors
    resource function delete employees/[string employeeId]/scheduled\-changes/[int changeId](
            http:RequestContext ctx)
        returns http:Ok|http:NotFound|http:Forbidden|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }

        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("User is not authorized to cancel a scheduled change",
                    invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {message: "You are not authorized to cancel a scheduled change"}
            };
        }

        database:ScheduledChange|error? existing = database:getScheduledChangeById(changeId);
        if existing is error {
            string customErr = string `Error occurred while fetching scheduled change: ${changeId}`;
            log:printError(customErr, existing, changeId = changeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        // The id is checked against the employee in the path as well as existing at all,
        // so a change cannot be cancelled through another employee's URL.
        if existing is () || existing.employeeIdentifier != employeeId {
            return <http:NotFound>{body: {message: "Scheduled change not found"}};
        }

        boolean|error cancelled = database:cancelScheduledChange(changeId, userInfo.email);
        if cancelled is error {
            string customErr = string `Error occurred while cancelling scheduled change: ${changeId}`;
            log:printError(customErr, cancelled, changeId = changeId);
            return <http:InternalServerError>{body: {message: customErr}};
        }
        if !cancelled {
            // Already applied or already cancelled: there is no pending change to withdraw.
            return <http:NotFound>{body: {message: "No pending scheduled change to cancel"}};
        }

        return http:OK;
    }

    # Get Employee Hub dashboard data: current employees and non-intern leavers.
    #
    # + return - Employee Hub data or error response
    resource function get employee\-hub/employees(http:RequestContext ctx)
        returns database:EmployeeHubData|http:Forbidden|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }
        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to fetch Employee Hub data", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {message: "You are not authorized to view Employee Hub data"}
            };
        }

        database:EmployeeHubEmployee[]|error employees = database:getEmployeeHubEmployees(false);
        if employees is error {
            log:printError("Error fetching Employee Hub employees", employees);
            return <http:InternalServerError>{
                body: {message: "Error occurred while fetching employee data."}
            };
        }
        database:EmployeeHubEmployee[]|error leavers = database:getEmployeeHubEmployees(true);
        if leavers is error {
            log:printError("Error fetching Employee Hub leavers", leavers);
            return <http:InternalServerError>{
                body: {message: "Error occurred while fetching employee data."}
            };
        }
        return {employees, leavers};
    }

    # List intern profiles.
    #
    # + return - List of intern profiles or error response
    resource function get intern\-profiles(http:RequestContext ctx)
        returns database:InternProfile[]|http:Forbidden|http:InternalServerError {

        authorization:CustomJwtPayload|error userInfo = ctx.getWithType(authorization:HEADER_USER_INFO);
        if userInfo is error {
            return <http:InternalServerError>{
                body: {message: ERROR_USER_INFORMATION_HEADER_NOT_FOUND}
            };
        }
        if !authorization:checkPermissions([authorization:authorizedRoles.ADMIN_ROLE], userInfo.groups) {
            log:printWarn("Unauthorized attempt to fetch intern profiles", invokerEmail = userInfo.email);
            return <http:Forbidden>{
                body: {message: "You are not authorized to view intern profiles"}
            };
        }
        database:InternProfile[]|error internProfiles = database:getInternProfiles();
        if internProfiles is error {
            log:printError("Error fetching intern profiles", internProfiles);
            return <http:InternalServerError>{
                body: {message: "Error occurred while fetching intern profiles."}
            };
        }
        return internProfiles;
    }
}
