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
import leave_service.employee;
import leave_service.policy;

import ballerina/log;
import ballerina/time;
import ballerina/uuid;

configurable decimal allowedDaysToCancelLeave = 30;
public configurable boolean isDebug = false;

# Calculates and returns the leave details for a given leave request.
#
# + input - Leave creation input
# + token - JWT token
# + return - Returns calculated leave details or error for validation failure
public isolated function calculateLeaveDetails(LeaveInput input, string token)
    returns LeaveDetails[]|error? {

    final LeaveInput {email, startDate, endDate, periodType, isMorningLeave} = input;
    string|error employeeLocation = employee:getEmployeeLocation(email, token);
    if employeeLocation is error {
        return error(employeeLocation.message(), employeeLocation);
    }
    future<database:Holiday[]|error> futureHolidaysInRange = start calendar_events:getHolidaysForCountry(
            employeeLocation, startDate, endDate);
    float workingDays = 0.0;
    [time:Utc, time:Utc] [startDateUtc, endDateUtc] = check validateDateRange(startDate, endDate);
    database:Day[] weekdaysFromRange = getWeekdaysFromRange(startDateUtc, endDateUtc);
    workingDays = <float>weekdaysFromRange.length();

    if workingDays == 0.0 {
        return error(ERR_MSG_LEAVE_SHOULD_BE_AT_LEAST_ONE_WEEKDAY,
                externalMessage = ERR_MSG_LEAVE_SHOULD_BE_AT_LEAST_ONE_WEEKDAY, workingDays = 0.0);
    }

    database:Holiday[]|error holidaysInRange = wait futureHolidaysInRange;
    if holidaysInRange is error {
        return error(ERR_MSG_HOLIDAYS_RETRIEVAL_FAILED, holidaysInRange, workingDays = 0.0);
    }

    // Assumes all holidays are full day holidays
    database:Day[] workingDaysAfterHolidays = getWorkingDaysAfterHolidays(weekdaysFromRange, holidaysInRange);
    if workingDaysAfterHolidays.length() == 0 {
        return error(
                ERR_MSG_LEAVE_SHOULD_BE_AT_LEAST_ONE_WORKING_DAY,
                workingDays = <float>workingDaysAfterHolidays.length()
            );
    }

    database:Leave[]|error overlappingDbLeaves = database:getLeaves(
                filter = {emails: [email], startDate, endDate, statuses: [APPROVED, PENDING]}
        );
    if overlappingDbLeaves is error {
        return error(overlappingDbLeaves.message(), overlappingDbLeaves);
    }
    // Pending leaves block too, except those the policy exempts (e.g. sabbatical).
    database:Leave[] blockingDbLeaves = from database:Leave leave in overlappingDbLeaves
        where policy:isBlockingLeave(leave.leaveType ?: "", (leave.status ?: "").toString())
        select leave;

    LeaveDetails[]|error overlappingLeaves = getLeaveEntitiesFromDbRecords(blockingDbLeaves, token);
    if overlappingLeaves is error {
        return overlappingLeaves;
    }
    if overlappingLeaves.length() > 0 {
        if periodType == database:HALF_DAY_LEAVE && isMorningLeave is boolean {
            if overlappingLeaves.length() > 2 {
                return error(ERR_MSG_LEAVE_IN_INVALID_STATE);
            }
            // Assumes all leaves in system are in a valid state.
            if overlappingLeaves.length() == 2 || overlappingLeaves[0].isMorningLeave == isMorningLeave {
                return error(ERR_MSG_LEAVE_OVERLAPS_WITH_EXISTING_LEAVE, workingDays = 0.5);
            }
        } else {
            return error(
                    ERR_MSG_LEAVE_OVERLAPS_WITH_EXISTING_LEAVE,
                    workingDays = <float>workingDaysAfterHolidays.length()
                );
        }
        return overlappingLeaves;
    }
    return;
}

# Checks if a leave is allowed to be cancelled.
#
# + leave - Leave to be checked
# + return - Whether the leave is allowed to be cancelled or error
isolated function checkIfLeaveAllowedToCancel(LeaveResponse leave) returns boolean {

    final LeaveResponse {startDate} = leave;
    time:Utc|error startUtc = getUtcDateFromString(getDateStringFromTimestamp(startDate));
    if startUtc is error {
        log:printError(string `Error occurred while getting UTC date from start date: ${startDate}.`, startUtc);
        return false;
    }

    time:Utc currentUtc = time:utcNow();
    decimal diff = time:utcDiffSeconds(currentUtc, startUtc) / DAY_IN_SECONDS;
    return diff <= allowedDaysToCancelLeave;
}

# Creates a event for an employee's leave in their calendar.
#
# + email - Employee email
# + leave - Created leave
# + calendarEventId - UUID to be used for event
isolated function createLeaveEventInCalendar(string email, LeaveResponse leave, string calendarEventId) {

    final LeaveResponse {id, periodType, isMorningLeave, startDate, endDate, location} = leave;
    string startDateString = getDateStringFromTimestamp(startDate);
    string endDateString = getDateStringFromTimestamp(endDate);

    string timeZoneOffset = "+00:00";
    if location is string && TIMEZONE_OFFSET_MAP.hasKey(location) {
        timeZoneOffset = TIMEZONE_OFFSET_MAP.get(location);
    }

    calendar_events:Time startTime = {
        dateTime: string `${startDateString}T00:00:00.000`,
        timeZone: string `GMT${timeZoneOffset}`
    };
    calendar_events:Time endTime = {
        dateTime: string `${endDateString}T23:59:00.000`,
        timeZone: string `GMT${timeZoneOffset}`
    };

    if periodType is database:HALF_DAY_LEAVE && isMorningLeave == false {
        startTime.dateTime = string `${startDateString}T13:00:00.000`;
    } else if periodType is database:HALF_DAY_LEAVE && isMorningLeave == true {
        endTime.dateTime = string `${startDateString}T13:00:00.000`;
    }

    string summary = isDebug ? "Test Leave" : "On Leave";
    log:printInfo(string `Creating event for leave id: ${id} email: ${email}.`);
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
        log:printInfo(string `Event created successfully with event id: ${eventId}. Leave id: ${id}.`);
    } else if eventId is error {
        log:printError(
                string `Error occurred while creating event for leave id: ${id} with ID: ${calendarEventId}.`,
                eventId
        );
    } else {
        log:printError(
                string `Error occurred while creating event for leave id: ${id} with ID: ${calendarEventId}. No ID returned.`
        );
    }
}

# Generates a UUID to be used for the calendar event creation.
#
# + return - UUID for calendar event
isolated function createUuidForCalendarEvent() returns string {

    string calendarId = re `-`.replaceAll(uuid:createType4AsString(), "");
    return calendarId.toLowerAscii();
}

# Delete an event from an employee's calendar.
#
# + email - Employee email
# + eventId - Calendar event ID
# + return - Nil or error
isolated function deleteLeaveEventFromCalendar(string email, string eventId) returns error? {

    log:printInfo(string `Deleting with event ID: ${eventId} email: ${email}.`);
    error? deleteEventResult = calendar_events:deleteEvent(email, eventId);
    if deleteEventResult is error {
        log:printError(string `Error occurred while deleting event with event ID: ${eventId}.`, deleteEventResult);
        return deleteEventResult;
    }
    log:printInfo(string `Event deleted successfully with event ID: ${eventId}.`);
}

# Get leave entitlement for an employee.
#
# + employee - Employee record
# + token - JWT token
# + years - Years to get leave entitlement for
# + return - Leave entitlements or error
isolated function getLeaveEntitlement(readonly & Employee employee, string token, int[] years)
    returns LeaveEntitlement[]|error {

    LeavePolicy leavePolicy = check getLegallyEntitledLeave(employee);
    int[] yearsOfLeave = years.length() == 0 ? [time:utcToCivil(time:utcNow()).year] : years;
    return from int year in yearsOfLeave
        let LeavePolicy policyAdjustedLeave = check getPolicyAdjustedLeaveCounts(employee, token, year)
        select {
            year,
            location: employee.location,
            leavePolicy,
            policyAdjustedLeave,
            periodStart: getLeavePeriodStart(employee.location, year),
            periodEnd: getLeavePeriodEnd(employee.location, year)
        };
}

# Get legally entitled leave for an employee based on location.
#
# + employee - Employee record
# + return - Location based leave policy or error
isolated function getLegallyEntitledLeave(readonly & Employee employee) returns LeavePolicy|error {

    match employee.location {
        LK => {
            string? employmentStartDate = employee.startDate;
            string? employmentEndDate = employee.finalDayOfEmployment;
            if employmentStartDate is () || employmentStartDate.length() == 0 {
                return error("Employee start date is not set!");
            }
            time:Civil civilEndDate = employmentEndDate is string ?
                check getCivilDateFromString(employmentEndDate) : time:utcToCivil(time:utcNow());
            time:Civil civilEmploymentStartDate = check getCivilDateFromString(employmentStartDate);

            int yearsOfEmployment = civilEndDate.year - civilEmploymentStartDate.year;
            float lkAnnualLeave = 14.0;
            float lkCasualLeave = 7.0;

            if yearsOfEmployment == 0 {
                // First year of employment
                lkAnnualLeave = 0.0;
                // One day of Casual leave for every two months of employment. This value will change throughout the year
                int monthsOfEmployment = civilEndDate.month - civilEmploymentStartDate.month;
                lkCasualLeave = <float>(monthsOfEmployment / 2);
            } else if yearsOfEmployment == 1 {
                // Second year of employment
                if civilEmploymentStartDate.month >= 10 {
                    // If employment start date is on or after October
                    lkAnnualLeave = 4.0;
                } else if civilEmploymentStartDate.month >= 7 {
                    // If employment start date is on or after July and before October
                    lkAnnualLeave = 7.0;
                } else if civilEmploymentStartDate.month >= 4 {
                    // If employment start date is on or after April and before July
                    lkAnnualLeave = 10.0;
                }
                // If employment start date is on or after January and before April
            }

            return {
                annual: lkAnnualLeave,
                casual: lkCasualLeave
            };
        }
        FR => {
            // France: 25 days Congés Payés (June–May period) + RTT days (calendar year) + open sick leave
            return {
                congesPayes: 25.0,
                rtt: 9.0
            };
        }
        ES => {
            // Spain: 23 working days annual leave (calendar year) + open sick + open casual
            return {
                annual: 23.0
            };
        }
        _ => {
            return {};
        }
    }
}

# Get leave report content for a given leaves.
#
# + leaves - Leaves to be used to generate report content
# + return - Report content
isolated function getLeaveReportContent(database:Leave[] leaves) returns ReportContent {

    ReportContent reportContent = {};
    foreach database:Leave leave in leaves {
        string? leaveType = leave.leaveType;
        float? numberOfDays = leave.numberOfDays;
        string email = leave.email;
        // Skip if essential data is missing
        if leaveType is () || numberOfDays is () {
            continue;
        }
        string processedLeaveType = leaveType;
        if processedLeaveType == TOTAL_LEAVE_TYPE {
            continue;
        }
        if processedLeaveType is database:SICK_LEAVE {
            // For France and Spain, sick leave is tracked separately; for others merge into casual
            string? leaveLocation = leave.location;
            if leaveLocation !is FR && leaveLocation !is ES {
                processedLeaveType = database:CASUAL_LEAVE;
            }
        }
        // France/Spain leave types are tracked as-is (conges_payes, rtt, annual, casual)
        map<float>? employeeLeaveMap = reportContent[email];
        if employeeLeaveMap is map<float> {
            float? leaveTypeCount = employeeLeaveMap[processedLeaveType];
            if leaveTypeCount is float {
                employeeLeaveMap[processedLeaveType] = leaveTypeCount + numberOfDays;
            } else {
                employeeLeaveMap[processedLeaveType] = numberOfDays;
            }

            employeeLeaveMap[TOTAL_LEAVE_TYPE] = numberOfDays + employeeLeaveMap.get(TOTAL_LEAVE_TYPE);
            if processedLeaveType !is database:LIEU_LEAVE {
                employeeLeaveMap[TOTAL_EXCLUDING_LIEU_LEAVE_TYPE] = numberOfDays +
                    employeeLeaveMap.get(TOTAL_EXCLUDING_LIEU_LEAVE_TYPE);
            }
        } else {
            reportContent[email] = {
                [processedLeaveType]: numberOfDays,
                [TOTAL_LEAVE_TYPE]: numberOfDays,
                [TOTAL_EXCLUDING_LIEU_LEAVE_TYPE]: processedLeaveType is database:LIEU_LEAVE ? 0 : numberOfDays
            };
        }
    }

    return reportContent;
}

# Fetch employee leaves and holidays for a given date range to generate user calendar information.
#
# + email - Employee email
# + startDate - Start date of the range
# + endDate - End date of the range
# + token - JWT token
# + return - User calendar information or error
isolated function getUserCalendarInformation(string email, string startDate, string endDate, string token)
    returns UserCalendarInformation|error {

    readonly & Employee|error employeeEntityResponse = employee:getEmployee(email);
    if employeeEntityResponse is error {
        return error(employee:ERR_MSG_EMPLOYEE_RETRIEVAL_FAILED, employeeEntityResponse);
    }
    final readonly & Employee employee = employeeEntityResponse;
    worker LeavesWorker returns Leave[]|error {
        string[] emails = [email];
        database:Leave[]|error leaves = database:getLeaves(
                {
                    emails,
                    statuses: [APPROVED],
                    startDate,
                    endDate,
                    orderBy: database:DESC
                }
        );
        if leaves is error {
            return error(ERR_MSG_LEAVES_RETRIEVAL_FAILED, leaves);
        }
        LeaveResponse[] leavesResponse = from database:Leave leave in leaves
            select check toLeaveEntity(leave, token);

        return from LeaveResponse leaveResponse in leavesResponse
            select {
                id: leaveResponse.id,
                startDate: leaveResponse.startDate,
                endDate: leaveResponse.endDate,
                leaveType: leaveResponse.leaveType,
                isMorningLeave: leaveResponse.isMorningLeave,
                numberOfDays: leaveResponse.numberOfDays,
                status: <Status>leaveResponse.status,
                periodType: leaveResponse.periodType,
                email: leaveResponse.email,
                isCancelAllowed: checkIfLeaveAllowedToCancel(leaveResponse),
                createdDate: leaveResponse.createdDate
            };
    }

    worker HolidaysWorker returns Holiday[]|error {
        string? country = employee.location;
        if country is () {
            return error(ERR_MSG_EMPLOYEE_LOCATION_RETRIEVAL_FAILED, country);
        }

        calendar_events:Holiday[]|error holidays = calendar_events:getHolidaysForCountry(country, startDate, endDate);
        if holidays is error {
            return error(ERR_MSG_HOLIDAYS_RETRIEVAL_FAILED, holidays);
        }

        return from calendar_events:Holiday holiday in holidays
            select {
                date: holiday.date,
                title: holiday.title
            };
    }

    Leave[] leaves = check wait LeavesWorker;
    Holiday[] holidays = check wait HolidaysWorker;
    return {
        leaves,
        holidays
    };
}

# Get policy adjusted leave counts for an employee.
#
# + employee - Employee record
# + token - JWT token
# + year - Year to get leave counts for
# + return - Policy adjusted leave counts or error
isolated function getPolicyAdjustedLeaveCounts(readonly & Employee employee, string token, int? year = ())
    returns LeavePolicy|error {

    LeavePolicy leavePolicy = check getLegallyEntitledLeave(employee);
    string email = employee.workEmail;
    string? location = employee.location;
    int effectiveYear = year ?: time:utcToCivil(time:utcNow()).year;

    // France: track Congés Payés and RTT independently
    if location is FR {
        float congesPayesTaken = 0.0;
        float rttTaken = 0.0;
        float sickTaken = 0.0;

        // Congés Payés: June 1 (prev year) to May 31 (current year)
        [string, string] [cpStart, cpEnd] = getLeavePeriodBounds(location, database:CONGES_PAYES_LEAVE, effectiveYear);
        database:Leave[]|error cpLeaves = database:getLeaves({emails: [email], statuses: [APPROVED], startDate: cpStart, endDate: cpEnd});
        if cpLeaves is error {
            return error(ERR_MSG_LEAVES_RETRIEVAL_FAILED, cpLeaves);
        }
        foreach database:Leave leave in cpLeaves {
            if leave.leaveType is database:CONGES_PAYES_LEAVE && leave.numberOfDays is float {
                congesPayesTaken += <float>leave.numberOfDays;
            }
        }

        // RTT + Sick: calendar year
        [string, string] [rttStart, rttEnd] = getLeavePeriodBounds(location, database:RTT_LEAVE, effectiveYear);
        database:Leave[]|error rttLeaves = database:getLeaves({emails: [email], statuses: [APPROVED], startDate: rttStart, endDate: rttEnd});
        if rttLeaves is error {
            return error(ERR_MSG_LEAVES_RETRIEVAL_FAILED, rttLeaves);
        }
        foreach database:Leave leave in rttLeaves {
            if leave.leaveType is database:RTT_LEAVE && leave.numberOfDays is float {
                rttTaken += <float>leave.numberOfDays;
            } else if leave.leaveType is database:SICK_LEAVE && leave.numberOfDays is float {
                sickTaken += <float>leave.numberOfDays;
            }
        }

        return {
            congesPayes: congesPayesTaken,
            rtt: rttTaken,
            sick: sickTaken
        };
    }

    // Spain: track annual, casual, and sick independently
    if location is ES {
        float annualTaken = 0.0;
        float casualTaken = 0.0;
        float sickTaken = 0.0;

        [string, string] [esStart, esEnd] = getLeavePeriodBounds(location, database:ANNUAL_LEAVE, effectiveYear);
        database:Leave[]|error esLeaves = database:getLeaves({emails: [email], statuses: [APPROVED], startDate: esStart, endDate: esEnd});
        if esLeaves is error {
            return error(ERR_MSG_LEAVES_RETRIEVAL_FAILED, esLeaves);
        }
        foreach database:Leave leave in esLeaves {
            if leave.leaveType is database:ANNUAL_LEAVE && leave.numberOfDays is float {
                annualTaken += <float>leave.numberOfDays;
            } else if leave.leaveType is database:CASUAL_LEAVE && leave.numberOfDays is float {
                casualTaken += <float>leave.numberOfDays;
            } else if leave.leaveType is database:SICK_LEAVE && leave.numberOfDays is float {
                sickTaken += <float>leave.numberOfDays;
            }
        }

        return {
            annual: annualTaken,
            casual: casualTaken,
            sick: sickTaken
        };
    }

    // Sri Lanka and other locations: existing logic
    float? entitledCasualLeave = leavePolicy?.casual;
    float? entitledAnnualLeave = leavePolicy?.annual;
    if entitledCasualLeave !is float || entitledAnnualLeave !is float {
        return {};
    }

    string startDate = getStartDateOfYear(year = year);
    string endDate = getEndDateOfYear(year = year);

    database:Leave[]|error leaves = database:getLeaves({emails: [email], statuses: [APPROVED], startDate, endDate});
    if leaves is error {
        return error(ERR_MSG_LEAVES_RETRIEVAL_FAILED, leaves);
    }

    LeaveResponse[] leavesResponse = from database:Leave leave in leaves
        select check toLeaveEntity(leave, token);
    float totalAnnualAndCasualLeaveTaken = 0.0;
    foreach LeaveResponse leaveResponse in leavesResponse {
        if leaveResponse.leaveType is database:CASUAL_LEAVE || leaveResponse.leaveType is database:ANNUAL_LEAVE {
            totalAnnualAndCasualLeaveTaken += leaveResponse.numberOfDays;
        }
    }

    float adjustedCasualLeave = 0.0;
    float adjustedAnnualLeave = 0.0;
    float totalLeavesAfterCasualLeaveEntitlement = totalAnnualAndCasualLeaveTaken - entitledCasualLeave;
    // If casual leave entitlement is exceeded
    if totalLeavesAfterCasualLeaveEntitlement > 0.0 {
        adjustedCasualLeave = entitledCasualLeave;
        float totalLeavesAfterAnnualLeaveEntitlement = totalLeavesAfterCasualLeaveEntitlement - entitledAnnualLeave;
        // If annual leave entitlement is exceeded
        if totalLeavesAfterAnnualLeaveEntitlement > 0.0 {
            adjustedAnnualLeave = entitledAnnualLeave;
            // Add the remaining leaves to casual leave
            adjustedCasualLeave += totalLeavesAfterAnnualLeaveEntitlement;
        } else {
            // If annual leave entitlement is not exceeded
            adjustedAnnualLeave = totalLeavesAfterCasualLeaveEntitlement;
        }
    } else {
        // If casual leave entitlement is not exceeded
        adjustedCasualLeave = totalAnnualAndCasualLeaveTaken;
    }

    return {
        casual: adjustedCasualLeave,
        annual: adjustedAnnualLeave
    };
}
