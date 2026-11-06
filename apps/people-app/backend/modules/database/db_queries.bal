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

# Fetch employee basic information.
#
# A person may hold several employee rows under one work email (a rehire issues a new employee
# ID while reusing the same work email), so this orders by start date to return their latest
# employment rather than an arbitrary row. `id` is only a deterministic tiebreaker: it does not
# track chronology, because historical stints were migrated in after the current records.
#
# + email - Employee's work email address
# + return - Query to get employee basic information
isolated function getEmployeeBasicInfoQuery(string email) returns sql:ParameterizedQuery =>
    `SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.work_email,
        e.employee_thumbnail,
        e.work_location,
        CONCAT(
            d.designation,
            CASE WHEN NULLIF(TRIM(e.secondary_job_title), '') IS NOT NULL
                THEN CONCAT(' ', TRIM(e.secondary_job_title)) ELSE '' END,
            CASE WHEN NULLIF(TRIM(e.job_role), '') IS NOT NULL
                THEN CONCAT(' & ', TRIM(e.job_role)) ELSE '' END
        ) AS designation,
        e.external_designation AS externalDesignation
    FROM employee e
        INNER JOIN designation d ON e.designation_id = d.id
    WHERE e.work_email = ${email}
    ORDER BY e.start_date DESC, e.id DESC
    LIMIT 1;`;

# Fetch all employees' basic information.
#
# + return - Query to get all employees basic information
isolated function getAllEmployeesBasicInfoQuery() returns sql:ParameterizedQuery =>
    `SELECT
        e.employee_id AS employeeId,
        e.first_name AS firstName,
        e.last_name AS lastName,
        e.work_email AS workEmail,
        e.employee_thumbnail AS employeeThumbnail,
        CONCAT(
            d.designation,
            CASE WHEN NULLIF(TRIM(e.secondary_job_title), '') IS NOT NULL
                THEN CONCAT(' ', TRIM(e.secondary_job_title)) ELSE '' END,
            CASE WHEN NULLIF(TRIM(e.job_role), '') IS NOT NULL
                THEN CONCAT(' & ', TRIM(e.job_role)) ELSE '' END
        ) AS designation,
        d.job_band AS jobBand,
        e.start_date AS startDate,
        e.manager_email AS managerEmail,
        bu.name AS businessUnit,
        t.name AS team,
        st.name AS subTeam,
        u.name AS unit,
        et.name AS employmentType,
        c.name AS company,
        e.work_location AS workLocation,
        e.employee_status AS employeeStatus
    FROM employee e
        INNER JOIN designation d ON e.designation_id = d.id
        INNER JOIN business_unit bu ON e.business_unit_id = bu.id
        INNER JOIN team t ON e.team_id = t.id
        INNER JOIN employment_type et ON e.employment_type_id = et.id
        INNER JOIN company c ON c.id = e.company_id
        LEFT JOIN sub_team st ON e.sub_team_id = st.id
        LEFT JOIN unit u ON e.unit_id = u.id
    WHERE e.employee_status IN ('Active', 'Marked leaver');`;

# Fetch employee ID by primary key ID.
#
# + id - Primary key ID of the employee record
# + return - Query to get employee ID
isolated function getEmployeeIdQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT employee_id FROM employee WHERE id = ${id};`;

# Fetch employee ID by EPF.
#
# + epf - Employee Provident Fund number
# + return - Query to get employee ID by EPF number
isolated function getEmployeeIdByEpfQuery(string epf) returns sql:ParameterizedQuery =>
    `SELECT employee_id FROM employee WHERE epf = ${epf} LIMIT 1;`;

# Every employment of the person behind a NIC/Passport, newest first.
#
# Used to recognise a returning employee at onboarding: whether they are still employed, and
# which work email they held. Ordered by start date, then id for two starting the same day,
# so the first row is their latest employment.
#
# + nicOrPassport - NIC/Passport from the onboarding submission
# + return - Query returning the person's employment rows
isolated function getEmploymentsByNicQuery(string nicOrPassport) returns sql:ParameterizedQuery =>
    `SELECT
        e.employee_id AS employeeId,
        e.first_name AS firstName,
        e.last_name AS lastName,
        e.work_email AS workEmail,
        e.employee_status AS employeeStatus
     FROM employee e
        INNER JOIN personal_info p ON p.id = e.personal_info_id
     WHERE p.nic_or_passport = ${nicOrPassport}
     ORDER BY e.start_date DESC, e.id DESC;`;

# Find an Active or New joiner employee holding a work email.
#
# A Marked leaver does not hold on to their email here: an employee who relocates keeps it,
# and their new employment is onboarded while the old one is Marked leaver.
#
# + workEmail - Work email to look for
# + excludeEmployeeId - Employee ID to leave out (the employee being edited), nil for none
# + return - Query returning at most one matching employee
isolated function getCurrentEmployeeByWorkEmailQuery(string workEmail, string? excludeEmployeeId = ())
        returns sql:ParameterizedQuery =>
    `SELECT
        e.employee_id AS employeeId,
        e.first_name AS firstName,
        e.last_name AS lastName,
        e.work_email AS workEmail,
        e.employee_status AS employeeStatus
     FROM employee e
     WHERE LOWER(e.work_email) = LOWER(${workEmail})
       AND e.employee_status IN (${EMPLOYEE_ACTIVE}, ${EMPLOYEE_NEW_JOINER})
       AND (${excludeEmployeeId} IS NULL OR e.employee_id <> ${excludeEmployeeId})
     ORDER BY e.start_date DESC, e.id DESC
     LIMIT 1;`;

# Fetch employee work email by employee ID.
#
# + employeeId - Employee ID
# + return - Query to get employee work email
isolated function getEmployeeWorkEmailQuery(string employeeId) returns sql:ParameterizedQuery =>
    `SELECT work_email FROM employee WHERE employee_id = ${employeeId};`;

# Fetch employee detailed information.
#
# + employeeId - Employee ID
# + return - Query to get employee detailed information
isolated function getEmployeeInfoQuery(string employeeId) returns sql:ParameterizedQuery =>
    `SELECT 
        e.employee_id AS employeeId,
        e.first_name AS firstName,
        e.last_name AS lastName,
        e.work_email AS workEmail,
        e.employee_thumbnail AS employeeThumbnail,
        e.epf AS epf,
        c.name AS company,
        e.company_id AS companyId,
        e.work_location AS workLocation,
        e.start_date AS startDate,
        e.manager_email AS managerEmail,
        COALESCE((
            SELECT CONCAT(m.first_name, ' ', m.last_name)
            FROM employee m
            WHERE LOWER(m.work_email) = LOWER(e.manager_email)
            ORDER BY m.id DESC
            LIMIT 1
        ), '') AS managerName,
        COALESCE(eam.additionalManagerEmails, '') AS additionalManagerEmails,
        elg.leadershipGroups AS leadershipGroups,
        pi.gender AS gender,
        (
            SELECT COUNT(1)
            FROM employee e2
            WHERE e2.id <> e.id
              AND e2.manager_email = e.work_email
        ) AS subordinateCount,
        e.employee_status AS employeeStatus,
        e.continuous_service_record AS continuousServiceRecord,
        -- Walks the whole continuous-service chain, not one hop. An employee with three
        -- linked employments (A -> B -> C) would otherwise report B's start date and
        -- understate their service.
        (
            WITH RECURSIVE chain AS (
                SELECT csr0.id, csr0.continuous_service_record, csr0.start_date
                FROM employee csr0 WHERE csr0.id = e.continuous_service_record
                UNION
                SELECT csr1.id, csr1.continuous_service_record, csr1.start_date
                FROM employee csr1 JOIN chain ON csr1.id = chain.continuous_service_record
            )
            SELECT MIN(chain.start_date) FROM chain
        ) AS continuousServiceDate,
        e.probation_end_date AS probationEndDate,
        e.agreement_end_date AS agreementEndDate,
        r.date AS resignationDate,
        r.final_day_in_office AS finalDayInOffice,
        r.final_day_of_employment AS finalDayOfEmployment,
        r.reason AS resignationReason,
        et.name AS employmentType,
        e.employment_type_id AS employmentTypeId,
        d.career_function_id AS careerFunctionId,
        CONCAT(
            d.designation,
            CASE WHEN NULLIF(TRIM(e.secondary_job_title), '') IS NOT NULL
                THEN CONCAT(' ', TRIM(e.secondary_job_title)) ELSE '' END,
            CASE WHEN NULLIF(TRIM(e.job_role), '') IS NOT NULL
                THEN CONCAT(' & ', TRIM(e.job_role)) ELSE '' END
        ) AS designation,
        e.designation_id AS designationId,
        d.job_band AS jobBand,
        e.secondary_job_title AS secondaryJobTitle,
        e.job_role AS jobRole,
        e.external_designation AS externalDesignation,
        o.name AS office,
        e.office_id AS officeId,
        bu.name AS businessUnit,
        e.business_unit_id AS businessUnitId,
        t.name AS team,
        e.team_id AS teamId,
        st.name AS subTeam,
        e.sub_team_id AS subTeamId,
        u.name AS unit,
        e.unit_id AS unitId,
        h.name AS house,
        e.house_id AS houseId
    FROM
        employee e
        LEFT JOIN (
            SELECT
                employee_pk_id,
                GROUP_CONCAT(additional_manager_email ORDER BY additional_manager_email SEPARATOR ',')
                AS additionalManagerEmails
            FROM employee_additional_managers
            WHERE is_active = 1
            GROUP BY employee_pk_id
        ) eam ON eam.employee_pk_id = e.id
        LEFT JOIN (
            SELECT
                el.employee_pk_id,
                GROUP_CONCAT(lg.name ORDER BY lg.name SEPARATOR ',') AS leadershipGroups
            FROM employee_leadership el
            JOIN leadership_group lg ON lg.id = el.leadership_group_id
            -- A retired attribute is hidden from its holders' records; the assignment row
            -- is kept, so reactivating the attribute brings it back.
            WHERE el.is_active = 1 AND lg.is_active = 1
            GROUP BY el.employee_pk_id
        ) elg ON elg.employee_pk_id = e.id
        INNER JOIN employment_type et ON e.employment_type_id = et.id
        INNER JOIN designation d ON e.designation_id = d.id
        LEFT JOIN office o ON e.office_id = o.id
        INNER JOIN company c ON c.id = e.company_id
        INNER JOIN team t ON e.team_id = t.id
        LEFT JOIN sub_team st ON e.sub_team_id = st.id
        INNER JOIN business_unit bu ON e.business_unit_id = bu.id
        LEFT JOIN unit u ON e.unit_id = u.id
        LEFT JOIN house h ON e.house_id = h.id
        LEFT JOIN personal_info pi ON pi.id = e.personal_info_id
        LEFT JOIN resignation r ON r.employee_id = e.id
    WHERE
        e.employee_id = ${employeeId};`;

# Fetch employees with filters.
#
# + payload - Get employees filter payload
# + leadEmail - If provided, restricts results to subordinates of this lead
# + return - Parameterized query for fetching employees
isolated function getEmployeesQuery(EmployeeSearchPayload payload, string? leadEmail = (),
        boolean includePersonalInfo = false) returns sql:ParameterizedQuery {

    int 'limit = payload.pagination.'limit;
    int offset = payload.pagination.offset;

    sql:ParameterizedQuery selectPrefix = `
        SELECT
            e.employee_id AS employeeId,
            e.first_name AS firstName,
            e.last_name AS lastName,
            e.work_email AS workEmail,
            e.employee_thumbnail AS employeeThumbnail,
            e.epf AS epf,
            e.work_location AS workLocation,
            e.start_date AS startDate,
            e.manager_email AS managerEmail,
            COALESCE(mgr.managerName, '') AS managerName,
            COALESCE(eam.additionalManagerEmails, '') AS additionalManagerEmails,
            COALESCE(sc.subordinateCount, 0) AS subordinateCount,
            e.employee_status AS employeeStatus,
            e.continuous_service_record AS continuousServiceRecord,
            -- See the note on the single-employee query: this walks the whole chain
            -- rather than one hop.
            (
                WITH RECURSIVE chain AS (
                    SELECT csr0.id, csr0.continuous_service_record, csr0.start_date
                    FROM employee csr0 WHERE csr0.id = e.continuous_service_record
                    UNION
                    SELECT csr1.id, csr1.continuous_service_record, csr1.start_date
                    FROM employee csr1 JOIN chain ON csr1.id = chain.continuous_service_record
                )
                SELECT MIN(chain.start_date) FROM chain
            ) AS continuousServiceDate,
            e.probation_end_date AS probationEndDate,
            e.agreement_end_date AS agreementEndDate,
            r.date AS resignationDate,
            r.final_day_in_office AS finalDayInOffice,
            r.final_day_of_employment AS finalDayOfEmployment,
            r.reason AS resignationReason,
            et.name AS employmentType,
            e.employment_type_id AS employmentTypeId,
            d.career_function_id AS careerFunctionId,
            CONCAT(
                d.designation,
                CASE WHEN NULLIF(TRIM(e.secondary_job_title), '') IS NOT NULL
                    THEN CONCAT(' ', TRIM(e.secondary_job_title)) ELSE '' END,
                CASE WHEN NULLIF(TRIM(e.job_role), '') IS NOT NULL
                    THEN CONCAT(' & ', TRIM(e.job_role)) ELSE '' END
            ) AS designation,
            e.designation_id AS designationId,
            d.job_band AS jobBand,
            e.secondary_job_title AS secondaryJobTitle,
            e.job_role AS jobRole,
            e.external_designation AS externalDesignation,
            o.name AS office,
            e.office_id AS officeId,
            bu.name AS businessUnit,
            e.business_unit_id AS businessUnitId,
            t.name AS team,
            e.team_id AS teamId,
            st.name AS subTeam,
            e.sub_team_id AS subTeamId,
            u.name AS unit,
            e.unit_id AS unitId,
            c.name AS company,
            e.company_id AS companyId,
            h.name AS house,
            e.house_id AS houseId,
            elg.leadershipGroups AS leadershipGroups,
            -- Personal information is selected only where the caller is entitled to it. The
            -- columns are omitted from the SQL rather than blanked afterwards, so data nobody
            -- may see is never read out of the database at all.
        `;

    sql:ParameterizedQuery personalInfoColumns = `
            pi.gender AS gender,
            pi.nic_or_passport AS nicOrPassport,
            pi.dob AS dateOfBirth,
            pi.nationality AS nationality,
            pi.personal_email AS personalEmail,
            pi.personal_phone AS personalPhone,
            pi.resident_number AS residentNumber,
            pi.address_line_1 AS addressLine1,
            pi.address_line_2 AS addressLine2,
            pi.city AS city,
            pi.state_or_province AS stateOrProvince,
            pi.postal_code AS postalCode,
            pi.country AS country,
            -- Emergency contacts are one-to-many, so they are flattened into a single
            -- cell here rather than widening the row: an employee may have any number
            -- of them, and fixed "Contact 1/2/3" columns would truncate or pad.
            (
                SELECT GROUP_CONCAT(
                    CONCAT_WS(' - ', piec.name, piec.relationship, piec.mobile)
                    ORDER BY piec.id SEPARATOR '; '
                )
                FROM personal_info_emergency_contacts piec
                WHERE piec.personal_info_id = pi.id AND piec.is_active = 1
            ) AS emergencyContacts,
        `;

    sql:ParameterizedQuery remainingQuery = `
            COUNT(*) OVER() AS totalCount
        FROM
            employee e
            LEFT JOIN (
                SELECT
                    employee_pk_id,
                    GROUP_CONCAT(additional_manager_email ORDER BY additional_manager_email SEPARATOR ',')
                    AS additionalManagerEmails
                FROM employee_additional_managers
                WHERE is_active = 1
                GROUP BY employee_pk_id
            ) eam ON eam.employee_pk_id = e.id

            LEFT JOIN (
                SELECT
                    el.employee_pk_id,
                    GROUP_CONCAT(lg.name ORDER BY lg.name SEPARATOR ',') AS leadershipGroups
                FROM employee_leadership el
                JOIN leadership_group lg ON lg.id = el.leadership_group_id
                -- Retired attributes are hidden; see the single-employee query.
                WHERE el.is_active = 1 AND lg.is_active = 1
                GROUP BY el.employee_pk_id
            ) elg ON elg.employee_pk_id = e.id

            LEFT JOIN (
                SELECT
                    LOWER(manager_email) AS managerEmail,
                    COUNT(*) AS subordinateCount
                FROM employee
                WHERE manager_email IS NOT NULL AND manager_email <> ''
                GROUP BY LOWER(manager_email)
            ) sc ON sc.managerEmail = LOWER(e.work_email)

            INNER JOIN personal_info pi ON pi.id = e.personal_info_id
            INNER JOIN employment_type et ON et.id = e.employment_type_id
            INNER JOIN designation d ON d.id = e.designation_id
            INNER JOIN company c ON c.id = e.company_id
            LEFT JOIN office o ON o.id = e.office_id
            INNER JOIN business_unit bu ON bu.id = e.business_unit_id
            INNER JOIN team t ON t.id = e.team_id
            LEFT JOIN sub_team st ON st.id = e.sub_team_id
            LEFT JOIN unit u ON u.id = e.unit_id
            LEFT JOIN house h ON h.id = e.house_id
            LEFT JOIN (
                SELECT
                    LOWER(work_email) AS managerEmail,
                    SUBSTRING_INDEX(
                        GROUP_CONCAT(CONCAT(first_name, ' ', last_name) ORDER BY id DESC SEPARATOR '||'), '||', 1
                    ) AS managerName
                FROM employee
                GROUP BY LOWER(work_email)
            ) mgr ON mgr.managerEmail = LOWER(e.manager_email)
            LEFT JOIN resignation r ON r.employee_id = e.id
        `;

    // Only the whole-chain list walks the chain, so only it can say which of the lead's
    // additional reports a member came through. As in reportingLineQuery, one is named only when
    // every route to the member starts from it, and never for the additional report themselves.
    //
    // The route lookup is an inner join, so it is also what restricts the list to the chain. A
    // separate `IN (SELECT pk_id FROM subordinate_tree)` filter would read the walk a second time,
    // and MySQL 8.0.27 shifts the columns of a recursive CTE read twice in one query.
    boolean walksChain = leadEmail is string && payload.filters.directReports == false;
    sql:ParameterizedQuery throughColumns = walksChain
        ? `
            via.employee_id AS throughEmployeeId,
            via.first_name AS throughFirstName,
            via.last_name AS throughLastName,
        `
        : `
            NULL AS throughEmployeeId,
            NULL AS throughFirstName,
            NULL AS throughLastName,
        `;
    sql:ParameterizedQuery throughJoins = walksChain
        ? `
            INNER JOIN (
                SELECT pk_id, MAX(root_additional IS NULL) AS reached_directly, MIN(root_additional) AS root_additional
                FROM subordinate_tree
                GROUP BY pk_id
            ) route ON route.pk_id = e.id
            LEFT JOIN employee via ON via.id = route.root_additional
                AND route.reached_directly = 0
                AND route.root_additional <> e.id
        `
        : ``;

    // Defaults to excluding personal information, so a caller that has not been considered
    // gets a field it did not expect rather than data it may not see.
    sql:ParameterizedQuery baseQuery = includePersonalInfo
        ? sql:queryConcat(selectPrefix, personalInfoColumns, throughColumns, remainingQuery, throughJoins)
        : sql:queryConcat(selectPrefix, throughColumns, remainingQuery, throughJoins);

    sql:ParameterizedQuery[] filters = [];

    // Lead restriction: must be the first filter so it cannot be bypassed.
    if leadEmail is string {
        if walksChain {
            // Show all subordinates recursively. The route join in throughJoins restricts the
            // rows to the chain, so there is no filter to add here; both follow walksChain.
            baseQuery = sql:queryConcat(subordinateTreeCte(leadEmail), baseQuery);
        } else {
            // Direct reports only (default)
            filters.push(`(
                LOWER(e.manager_email) = LOWER(${leadEmail})
                OR EXISTS (
                    SELECT 1
                    FROM employee_additional_managers leam
                    WHERE leam.employee_pk_id = e.id
                      AND leam.is_active = 1
                      AND LOWER(leam.additional_manager_email) = LOWER(${leadEmail})
                )
            )`);
        }
    }

    appendStringFilter(filters, payload.filters.title, `pi.title = ${payload.filters.title}`);
    appendStringFilter(filters, payload.filters.firstName, `LOWER(pi.first_name) = LOWER(${payload.filters.firstName})`);
    appendStringFilter(filters, payload.filters.lastName, `LOWER(pi.last_name) = LOWER(${payload.filters.lastName})`);
    appendStringFilter(filters, payload.filters.dateOfBirth, `pi.dob = ${payload.filters.dateOfBirth}`);
    appendStringFilter(filters, payload.filters.startDate, `e.start_date = ${payload.filters.startDate}`);
    appendStringFilter(filters, payload.filters.gender, `pi.gender = ${payload.filters.gender}`);
    appendStringFilter(filters, payload.filters.personalEmail, `LOWER(pi.personal_email) = LOWER(${payload.filters.personalEmail})`);
    appendStringFilter(filters, payload.filters.personalPhone, `pi.personal_phone = ${payload.filters.personalPhone}`);
    appendStringFilter(filters, payload.filters.residentNumber, `pi.resident_number = ${payload.filters.residentNumber}`);
    appendStringFilter(filters, payload.filters.city, `LOWER(pi.city) = LOWER(${payload.filters.city})`);
    appendStringFilter(filters, payload.filters.country, `LOWER(pi.country) = LOWER(${payload.filters.country})`);
    string[]? statusList = payload.filters.employeeStatuses;
    string? statusFilter = payload.filters.employeeStatus;
    if statusList is string[] && statusList.length() > 0 {
        // Multi-select status takes precedence over the single status + includeMarkedLeavers flag.
        string[] loweredStatuses = from string status in statusList
            select status.toLowerAscii();
        filters.push(sql:queryConcat(`LOWER(e.employee_status) IN (`, buildInClause(loweredStatuses), `)`));
    } else if statusFilter is string {
        if payload.filters.includeMarkedLeavers == true {
            filters.push(`(LOWER(e.employee_status) = LOWER(${statusFilter}) OR e.employee_status = 'Marked leaver')`);
        } else {
            filters.push(`LOWER(e.employee_status) = LOWER(${statusFilter})`);
        }
    }

    if payload.filters.managerEmail is string {
        filters.push(`LOWER(e.manager_email) LIKE LOWER(CONCAT('%', ${payload.filters.managerEmail}, '%'))`);
    }

    if payload.filters.nicOrPassport is int|string {
        filters.push(`pi.nic_or_passport = ${payload.filters.nicOrPassport}`);
    }

    appendIntFilter(filters, payload.filters.companyId, `e.company_id = ${payload.filters.companyId}`);
    appendIntFilter(filters, payload.filters.officeId, `e.office_id = ${payload.filters.officeId}`);
    appendIntFilter(filters, payload.filters.designationId, `e.designation_id = ${payload.filters.designationId}`);
    appendIntFilter(filters, payload.filters.careerFunctionId, `d.career_function_id = ${payload.filters.careerFunctionId}`);
    appendIntFilter(filters, payload.filters.businessUnitId, `e.business_unit_id = ${payload.filters.businessUnitId}`);
    appendIntFilter(filters, payload.filters.teamId, `e.team_id = ${payload.filters.teamId}`);
    appendIntFilter(filters, payload.filters.subTeamId, `e.sub_team_id = ${payload.filters.subTeamId}`);
    appendIntFilter(filters, payload.filters.unitId, `e.unit_id = ${payload.filters.unitId}`);
    int[]? employmentTypeList = payload.filters.employmentTypeIds;
    if employmentTypeList is int[] && employmentTypeList.length() > 0 {
        // Multi-select employment type takes precedence over the single employmentTypeId.
        filters.push(sql:queryConcat(`e.employment_type_id IN (`, buildIntInClause(employmentTypeList), `)`));
    } else {
        appendIntFilter(filters, payload.filters.employmentTypeId, `e.employment_type_id = ${payload.filters.employmentTypeId}`);
    }

    int[]? leadershipGroupList = payload.filters.leadershipGroupIds;
    if leadershipGroupList is int[] && leadershipGroupList.length() > 0 {
        // AND semantics: the employee must hold EVERY selected attribute, unlike the OR
        // multi-selects above. A correlated IN (SELECT ... HAVING ...) is used rather than a
        // join plus an outer HAVING so this composes with all three call sites, including
        // ones that do not GROUP BY. Retired attributes are left out, as they are from every
        // record and report: a Left employee may still hold one, and matching on it would
        // return them without the attribute showing in their row.
        filters.push(sql:queryConcat(
            `e.id IN (SELECT el_f.employee_pk_id FROM employee_leadership el_f
              JOIN leadership_group lg_f ON lg_f.id = el_f.leadership_group_id
              WHERE el_f.is_active = 1 AND lg_f.is_active = 1 AND el_f.leadership_group_id IN (`,
            buildIntInClause(leadershipGroupList),
            `) GROUP BY el_f.employee_pk_id
              HAVING COUNT(DISTINCT el_f.leadership_group_id) = ${leadershipGroupList.length()})`));
    }

    // By status rather than by comparing the start date with today: the scheduler moves a New
    // joiner to Active at midnight where they work, so the status is right for every location,
    // whereas the database server's own date is right for none in particular.
    if payload.filters.excludeFutureStartDate == true {
        filters.push(`e.employee_status <> ${EMPLOYEE_NEW_JOINER}`);
    }

    string? searchString = payload.searchString;

    if searchString is string {
        filters.push(buildTextTokenFilter(searchString));
    }

    sql:ParameterizedQuery retrieveEmployeeQuery = buildSqlSelectQuery(baseQuery, filters);
    sql:ParameterizedQuery orderByClause = buildOrderByClause(payload.sort);

    retrieveEmployeeQuery = sql:queryConcat(retrieveEmployeeQuery, orderByClause, ` LIMIT ${'limit} OFFSET ${offset};`);

    return retrieveEmployeeQuery;
};

# Fetch distinct managers.
#
# + return - Parameterized query for fetching distinct managers
isolated function getManagersQuery() returns sql:ParameterizedQuery =>
    `SELECT
        SUBSTRING_INDEX(
            GROUP_CONCAT(m.employee_id ORDER BY (m.employee_status = 'Active') DESC, m.id DESC SEPARATOR '||'), '||', 1
        ) AS employee_id,
        SUBSTRING_INDEX(
            GROUP_CONCAT(m.work_email ORDER BY (m.employee_status = 'Active') DESC, m.id DESC SEPARATOR '||'), '||', 1
        ) AS work_email
    FROM employee e
    JOIN employee m ON LOWER(e.manager_email) = LOWER(m.work_email)
    WHERE e.manager_email IS NOT NULL AND e.manager_email <> ''
    GROUP BY LOWER(m.work_email);`;

# The reporting chain below a lead, as a
# `subordinate_tree (pk_id, w_email, visited, traversable, root_additional)` CTE: everyone whose
# manager or active additional manager is the lead, then theirs, and so on.
#
# A row is `traversable` unless it is a Left employment whose work email also belongs to a
# current one. A rehire keeps their email, so the walk would otherwise continue from their
# earlier row, which still names the manager they had the first time, and hand their current
# reports to that manager. A leaver with no later employment stays traversable, so reports not
# yet reassigned remain in their former manager's chain.
#
# The current work emails are collected once in `current_email`. Looking them up per row made
# the walk from the top of the organisation about four times slower than before the rule.
# Missing work emails are left out of that list: a single NULL makes NOT IN unknown for every
# row, which would stop the walk at every leaver.
#
# `root_additional` is where a row's route started: the lead's additional report it came through,
# or NULL when it started from a direct report. The reporting line reads it to say who links
# someone into the team.
#
# Shared by the My Team list, the record-access check and the reporting line so they cannot
# disagree.
#
# + leadEmail - Work email of the lead
# + return - `WITH RECURSIVE` prefix to concatenate before a query that reads `subordinate_tree`
isolated function subordinateTreeCte(string leadEmail) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery traversable = `(
                e.employee_status <> ${EMPLOYEE_LEFT}
                OR LOWER(e.work_email) NOT IN (SELECT email FROM current_email)
            )`;
    return sql:queryConcat(
            `WITH RECURSIVE current_email (email) AS (
            SELECT DISTINCT LOWER(work_email)
            FROM employee
            WHERE employee_status <> ${EMPLOYEE_LEFT}
              AND work_email IS NOT NULL
        ),
        subordinate_tree (pk_id, w_email, visited, traversable, root_additional) AS (
            SELECT e.id, e.work_email, CAST(e.id AS CHAR(1000)), `, traversable, `, CAST(NULL AS SIGNED)
            FROM employee e
            WHERE LOWER(e.manager_email) = LOWER(${leadEmail})
            UNION
            SELECT e.id, e.work_email, CAST(e.id AS CHAR(1000)), `, traversable, `, e.id
            FROM employee e
            JOIN employee_additional_managers eam ON eam.employee_pk_id = e.id AND eam.is_active = 1
            WHERE LOWER(eam.additional_manager_email) = LOWER(${leadEmail})
            UNION ALL
            SELECT e.id, e.work_email, CONCAT(st.visited, ',', e.id), `, traversable, `, st.root_additional
            FROM employee e
            JOIN subordinate_tree st ON LOWER(e.manager_email) = LOWER(st.w_email)
            WHERE st.traversable = 1 AND NOT FIND_IN_SET(e.id, st.visited)
            UNION ALL
            SELECT e.id, e.work_email, CONCAT(st.visited, ',', e.id), `, traversable, `, st.root_additional
            FROM employee e
            JOIN employee_additional_managers eam ON eam.employee_pk_id = e.id AND eam.is_active = 1
            JOIN subordinate_tree st ON LOWER(eam.additional_manager_email) = LOWER(st.w_email)
            WHERE st.traversable = 1 AND NOT FIND_IN_SET(e.id, st.visited)
        ) `);
}

# Check if a target employee is a direct or additional subordinate of a lead.
#
# + leadEmail - Work email of the potential lead
# + employeeId - Employee ID of the target employee
# + return - Parameterized query returning 1 row if the relationship exists
isolated function isSubordinateOfLeadQuery(string leadEmail, string employeeId) returns sql:ParameterizedQuery =>
    sql:queryConcat(subordinateTreeCte(leadEmail), `
    SELECT 1
    FROM subordinate_tree
    WHERE pk_id = (SELECT id FROM employee WHERE employee_id = ${employeeId})
    LIMIT 1`);

# How a team member is linked to a lead, read from the lead's chain.
#
# A member can be reached by more than one route. The lead's additional report is named only
# when every route starts from one; when several do, MIN picks one. No row means the member is
# not in the lead's chain.
#
# + leadEmail - Work email of the lead
# + employeeId - Employee ID of the team member
# + return - Parameterized query returning at most one row
isolated function reportingLineQuery(string leadEmail, string employeeId) returns sql:ParameterizedQuery =>
    sql:queryConcat(subordinateTreeCte(leadEmail), `
    SELECT
        CASE
            WHEN LOWER(t.manager_email) = LOWER(${leadEmail}) THEN ${DIRECT}
            WHEN EXISTS (
                SELECT 1
                FROM employee_additional_managers eam
                WHERE eam.employee_pk_id = t.id
                  AND eam.is_active = 1
                  AND LOWER(eam.additional_manager_email) = LOWER(${leadEmail})
            ) THEN ${ADDITIONAL}
            ELSE ${INDIRECT}
        END AS relation,
        via.employee_id AS throughEmployeeId,
        via.first_name AS throughFirstName,
        via.last_name AS throughLastName
    FROM (
        SELECT pk_id, MAX(root_additional IS NULL) AS reached_directly, MIN(root_additional) AS root_additional
        FROM subordinate_tree
        WHERE pk_id = (SELECT id FROM employee WHERE employee_id = ${employeeId})
        GROUP BY pk_id
    ) r
    JOIN employee t ON t.id = r.pk_id
    LEFT JOIN employee via ON via.id = r.root_additional AND r.reached_directly = 0`);

# Check if an employee is a lead (has at least one direct or additional subordinate).
#
# + leadEmail - Work email of the employee to check
# + return - Parameterized query returning 1 row if the employee is a lead
isolated function isLeadQuery(string leadEmail) returns sql:ParameterizedQuery =>
    `SELECT 1
     FROM employee
     WHERE LOWER(manager_email) = LOWER(${leadEmail})
       AND manager_email IS NOT NULL
       AND manager_email <> ''
     UNION ALL
     SELECT 1
     FROM employee_additional_managers
     WHERE is_active = 1
       AND LOWER(additional_manager_email) = LOWER(${leadEmail})
     LIMIT 1;`;

# Fetch continuous service record by work email.
#
# A person may hold several employee rows under one work email (a rehire issues a new employee
# ID while reusing the same work email), and every stint is returned here by design. Ordering is
# newest-first by start date so the caller gets a stable, chronological service history; `id` is
# only a tiebreaker, as it does not track chronology.
#
# + workEmail - Work email of the employee
# + return - Parameterized query for continuous service record
isolated function getContinuousServiceRecordQuery(string workEmail) returns sql:ParameterizedQuery =>
    `SELECT 
        e.id AS id,
        e.employee_id AS employeeId,
        e.first_name AS firstName,
        e.last_name AS lastName,
        e.work_location AS workLocation,
        e.start_date AS startDate,
        e.employee_status AS employeeStatus,
        e.manager_email AS managerEmail,
        COALESCE(eam.additionalManagerEmails, '') AS additionalManagerEmails,
        CONCAT(
            d.designation,
            CASE WHEN NULLIF(TRIM(e.secondary_job_title), '') IS NOT NULL
                THEN CONCAT(' ', TRIM(e.secondary_job_title)) ELSE '' END,
            CASE WHEN NULLIF(TRIM(e.job_role), '') IS NOT NULL
                THEN CONCAT(' & ', TRIM(e.job_role)) ELSE '' END
        ) AS designation,
        e.secondary_job_title AS secondaryJobTitle,
        o.name AS office,
        bu.name AS businessUnit,
        c.name AS company,
        t.name AS team,
        st.name AS subTeam,
        u.name AS unit
    FROM employee e
        LEFT JOIN (
            SELECT 
                employee_pk_id,
                GROUP_CONCAT(additional_manager_email ORDER BY additional_manager_email SEPARATOR ',') 
                AS additionalManagerEmails
            FROM employee_additional_managers
            WHERE is_active = 1
            GROUP BY employee_pk_id
        ) eam ON eam.employee_pk_id = e.id
        INNER JOIN employment_type et ON e.employment_type_id = et.id
        INNER JOIN designation d ON e.designation_id = d.id
        LEFT JOIN office o ON e.office_id = o.id
        INNER JOIN company c ON c.id = e.company_id
        INNER JOIN team t ON e.team_id = t.id
        LEFT JOIN sub_team st ON e.sub_team_id = st.id
        INNER JOIN business_unit bu ON e.business_unit_id = bu.id
        LEFT JOIN unit u ON e.unit_id = u.id
    WHERE
        e.work_email = ${workEmail}
        AND et.is_active = 1
        AND et.name IN ('Permanent')
    ORDER BY e.start_date DESC, e.id DESC;`;

# Fetch employee personal information.
#
# + employeeId - Employee ID
# + return - Query to get employee personal information
isolated function getEmployeePersonalInfoQuery(string employeeId) returns sql:ParameterizedQuery =>
    `SELECT 
        nic_or_passport,
        p.first_name AS firstName,
        p.last_name AS lastName,
        full_name,
        title,
        dob,
        gender,
        personal_email,
        personal_phone,
        resident_number,
        address_line_1,
        address_line_2,
        city,
        state_or_province,
        postal_code,
        country,
        nationality
    FROM personal_info p
    INNER JOIN employee e ON p.id = e.personal_info_id
        WHERE e.employee_id = ${employeeId};`;

# Fetch emergency contacts by personal info ID.
#
# + employeeId - Employee ID
# + return - Query to fetch emergency contacts
isolated function getEmergencyContactsByEmployeeIdQuery(string employeeId) returns sql:ParameterizedQuery =>
    `SELECT
        piec.name,
        piec.relationship,
        piec.mobile,
        piec.telephone
    FROM personal_info_emergency_contacts piec
    INNER JOIN employee e ON e.personal_info_id = piec.personal_info_id
    WHERE e.employee_id = ${employeeId}
      AND is_active = 1;`;

# Get business units query.
# + includeInactive - If true, return all entities including inactive; otherwise active-only
# + return - Business units query
isolated function getBusinessUnitsQuery(boolean includeInactive = false) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = `SELECT bu.id, bu.name, bu.head_email, bu.is_active,
        (SELECT COUNT(*) FROM employee
            WHERE business_unit_id = bu.id AND employee_status = 'Active') AS active_employee_count
        FROM business_unit bu`;
    if !includeInactive {
        query = sql:queryConcat(query, ` WHERE bu.is_active = 1`);
    }
    return sql:queryConcat(query, ` ORDER BY bu.name;`);
}

# Get teams query.
#
# + buId - Business unit ID (optional)
# + includeInactive - If true, return all entities including inactive; otherwise active-only
# + return - Teams query
isolated function getTeamsQuery(int? buId = (), boolean includeInactive = false) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = `
        SELECT
            t.id, t.name, t.head_email, t.is_active,
            (SELECT COUNT(*) FROM employee
                WHERE team_id = t.id AND employee_status = 'Active') AS active_employee_count
        FROM
            team t`;

    if buId is int {
        query = sql:queryConcat(query, `
            LEFT JOIN
                business_unit_team but ON but.team_id = t.id
            WHERE
                but.business_unit_id = ${buId}`);
        if !includeInactive {
            query = sql:queryConcat(query, ` AND t.is_active = 1 AND but.is_active = 1`);
        }
    } else if !includeInactive {
        query = sql:queryConcat(query, ` WHERE t.is_active = 1`);
    }
    return sql:queryConcat(query, `
        ORDER BY t.name;`);
}

# Get sub teams query.
#
# + teamId - Team ID (optional)
# + includeInactive - If true, return all entities including inactive; otherwise active-only
# + return - Sub teams query
isolated function getSubTeamsQuery(int? teamId = (), boolean includeInactive = false) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = `
        SELECT DISTINCT
            st.id, st.name, st.head_email, st.is_active,
            (SELECT COUNT(*) FROM employee
                WHERE sub_team_id = st.id AND employee_status = 'Active') AS active_employee_count
        FROM
            sub_team st`;
    if teamId is int {
        query = sql:queryConcat(query, `
            INNER JOIN
                business_unit_team_sub_team butst ON butst.sub_team_id = st.id
            INNER JOIN
                business_unit_team but ON but.id = butst.business_unit_team_id
            WHERE
                but.team_id = ${teamId}`);
        if !includeInactive {
            query = sql:queryConcat(query,
                    ` AND st.is_active = 1 AND butst.is_active = 1 AND but.is_active = 1`);
        }
    } else if !includeInactive {
        query = sql:queryConcat(query, ` WHERE st.is_active = 1`);
    }
    return sql:queryConcat(query, `
        ORDER BY st.name;`);
}

# Fetch existing work emails.
#
# + emails - Work email list
# + return - Query to fetch existing work emails
isolated function getExistingWorkEmailsQuery(string[] emails) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery inClause = buildInClause(emails);
    return sql:queryConcat(
            `SELECT LOWER(work_email) AS work_email FROM employee WHERE LOWER(work_email) IN (`,
            inClause,
            `);`
    );
}

# Fetch existing NIC or passport values.
#
# + nics - NIC or passport list
# + return - Query to fetch existing NIC or passport values
isolated function getExistingNicOrPassportQuery(string[] nics) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery inClause = buildInClause(nics);
    return sql:queryConcat(
            `SELECT LOWER(nic_or_passport) AS nic_or_passport FROM personal_info WHERE LOWER(nic_or_passport) IN (`,
            inClause,
            `);`
    );
}

# Fetch existing EPF values.
#
# + epfs - EPF number list
# + return - Query to fetch existing EPF values
isolated function getExistingEpfsQuery(string[] epfs) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery inClause = buildInClause(epfs);
    return sql:queryConcat(
            `SELECT LOWER(epf) AS epf FROM employee WHERE LOWER(epf) IN (`,
            inClause,
            `);`
    );
}

# Build an SQL IN clause for a list of string values.
#
# + values - List of string values to include in the IN clause
# + return - Parameterized query representing the IN clause
isolated function buildInClause(string[] values) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery clause = ``;
    foreach int i in 0 ..< values.length() {
        clause = i == 0
            ? sql:queryConcat(clause, `${values[i]}`)
            : sql:queryConcat(clause, `, `, `${values[i]}`);
    }
    return clause;
}

# Build an SQL IN clause for a list of integer values.
#
# + values - List of integer values to include in the IN clause
# + return - Parameterized query representing the IN clause
isolated function buildIntInClause(int[] values) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery clause = ``;
    foreach int i in 0 ..< values.length() {
        clause = i == 0
            ? sql:queryConcat(clause, `${values[i]}`)
            : sql:queryConcat(clause, `, `, `${values[i]}`);
    }
    return clause;
}

# Get units query.
#
# + subTeamId - Sub team ID (optional)
# + includeInactive - If true, return all entities including inactive; otherwise active-only
# + return - Units query
isolated function getUnitsQuery(int? subTeamId = (), boolean includeInactive = false) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = `
        SELECT DISTINCT
            u.id, u.name, u.head_email, u.is_active,
            (SELECT COUNT(*) FROM employee
                WHERE unit_id = u.id AND employee_status = 'Active') AS active_employee_count
        FROM
            unit u`;
    if subTeamId is int {
        query = sql:queryConcat(query, `
            INNER JOIN
                business_unit_team_sub_team_unit butstu ON butstu.unit_id = u.id
            INNER JOIN
                business_unit_team_sub_team butst ON butst.id = butstu.business_unit_team_sub_team_id
            WHERE
                butst.sub_team_id = ${subTeamId}`);
        if !includeInactive {
            query = sql:queryConcat(query,
                    ` AND u.is_active = 1 AND butstu.is_active = 1 AND butst.is_active = 1`);
        }
    } else if !includeInactive {
        query = sql:queryConcat(query, ` WHERE u.is_active = 1`);
    }
    return sql:queryConcat(query, `
        ORDER BY u.name;`);
}

# Create business unit query.
#
# + name - Business unit name
# + headEmail - Head email
# + createdBy - Creator email
# + return - Insert query
isolated function createBusinessUnitQuery(string name, string headEmail, string createdBy)
        returns sql:ParameterizedQuery =>
    `INSERT INTO business_unit (name, head_email, created_by, updated_by)
     VALUES (${name}, ${headEmail}, ${createdBy}, ${createdBy});`;

# Update business unit query.
#
# + id - Business unit ID
# + name - Updated name (optional)
# + headEmail - Updated head email (optional)
# + isActive - Updated active status (optional)
# + updatedBy - Updater email
# + return - Update query or error if nothing to update
isolated function updateBusinessUnitQuery(int id, string? name, string? headEmail, boolean? isActive,
        string updatedBy) returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if name is string {
        updates.push(`name = ${name}`);
    }
    if headEmail is string {
        updates.push(`head_email = ${headEmail}`);
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError(ERROR_NO_FIELDS_TO_UPDATE);
    }
    updates.push(`updated_by = ${updatedBy}`);
    return sql:queryConcat(buildSqlUpdateQuery(`UPDATE business_unit SET `, updates), ` WHERE id = ${id};`);
}

# Create team query.
#
# + name - Team name
# + headEmail - Head email
# + createdBy - Creator email
# + return - Insert query
isolated function createTeamQuery(string name, string headEmail, string createdBy)
        returns sql:ParameterizedQuery =>
    `INSERT INTO team (name, head_email, created_by, updated_by)
     VALUES (${name}, ${headEmail}, ${createdBy}, ${createdBy});`;

# Update team query.
#
# + id - Team ID
# + name - Updated name (optional)
# + headEmail - Updated head email (optional)
# + isActive - Updated active status (optional)
# + updatedBy - Updater email
# + return - Update query or error if nothing to update
isolated function updateTeamQuery(int id, string? name, string? headEmail, boolean? isActive,
        string updatedBy) returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if name is string {
        updates.push(`name = ${name}`);
    }
    if headEmail is string {
        updates.push(`head_email = ${headEmail}`);
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError(ERROR_NO_FIELDS_TO_UPDATE);
    }
    updates.push(`updated_by = ${updatedBy}`);
    return sql:queryConcat(buildSqlUpdateQuery(`UPDATE team SET `, updates), ` WHERE id = ${id};`);
}

# Create sub-team query.
#
# + name - Sub-team name
# + headEmail - Head email
# + createdBy - Creator email
# + return - Insert query
isolated function createSubTeamQuery(string name, string headEmail, string createdBy)
        returns sql:ParameterizedQuery =>
    `INSERT INTO sub_team (name, head_email, created_by, updated_by)
     VALUES (${name}, ${headEmail}, ${createdBy}, ${createdBy});`;

# Update sub-team query.
#
# + id - Sub-team ID
# + name - Updated name (optional)
# + headEmail - Updated head email (optional)
# + isActive - Updated active status (optional)
# + updatedBy - Updater email
# + return - Update query or error if nothing to update
isolated function updateSubTeamQuery(int id, string? name, string? headEmail, boolean? isActive,
        string updatedBy) returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if name is string {
        updates.push(`name = ${name}`);
    }
    if headEmail is string {
        updates.push(`head_email = ${headEmail}`);
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError(ERROR_NO_FIELDS_TO_UPDATE);
    }
    updates.push(`updated_by = ${updatedBy}`);
    return sql:queryConcat(buildSqlUpdateQuery(`UPDATE sub_team SET `, updates), ` WHERE id = ${id};`);
}

# Create unit query.
#
# + name - Unit name
# + headEmail - Head email
# + createdBy - Creator email
# + return - Insert query
isolated function createUnitQuery(string name, string headEmail, string createdBy)
        returns sql:ParameterizedQuery =>
    `INSERT INTO unit (name, head_email, created_by, updated_by)
     VALUES (${name}, ${headEmail}, ${createdBy}, ${createdBy});`;

# Update unit query.
#
# + id - Unit ID
# + name - Updated name (optional)
# + headEmail - Updated head email (optional)
# + isActive - Updated active status (optional)
# + updatedBy - Updater email
# + return - Update query or error if nothing to update
isolated function updateUnitQuery(int id, string? name, string? headEmail, boolean? isActive,
        string updatedBy) returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if name is string {
        updates.push(`name = ${name}`);
    }
    if headEmail is string {
        updates.push(`head_email = ${headEmail}`);
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError(ERROR_NO_FIELDS_TO_UPDATE);
    }
    updates.push(`updated_by = ${updatedBy}`);
    return sql:queryConcat(buildSqlUpdateQuery(`UPDATE unit SET `, updates), ` WHERE id = ${id};`);
}

# Create business-unit → team mapping query.
#
# + businessUnitId - Business unit ID
# + teamId - Team ID
# + headEmail - Head email for this mapping
# + createdBy - Creator email
# + return - Insert query
isolated function createBusinessUnitTeamQuery(int businessUnitId, int teamId, string headEmail, string createdBy)
        returns sql:ParameterizedQuery =>
    `INSERT INTO business_unit_team (business_unit_id, team_id, head_email, created_by, updated_by)
     VALUES (${businessUnitId}, ${teamId}, ${headEmail}, ${createdBy}, ${createdBy})
     ON DUPLICATE KEY UPDATE
        id = LAST_INSERT_ID(id),
        is_active = 1,
        head_email = VALUES(head_email),
        updated_by = VALUES(updated_by),
        updated_on = CURRENT_TIMESTAMP(6);`;

# Update business-unit → team mapping query.
#
# + id - Mapping ID
# + headEmail - Updated head email (optional)
# + isActive - Updated active status (optional)
# + updatedBy - Updater email
# + return - Update query or error if nothing to update
isolated function updateBusinessUnitTeamQuery(int id, string? headEmail, boolean? isActive,
        string updatedBy) returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if headEmail is string {
        updates.push(`head_email = ${headEmail}`);
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError(ERROR_NO_FIELDS_TO_UPDATE);
    }
    updates.push(`updated_by = ${updatedBy}`);
    return sql:queryConcat(buildSqlUpdateQuery(`UPDATE business_unit_team SET `, updates), ` WHERE id = ${id};`);
}

# Create business-unit-team → sub-team mapping query.
#
# + businessUnitTeamId - Business unit team mapping ID
# + subTeamId - Sub-team ID
# + headEmail - Head email for this mapping
# + createdBy - Creator email
# + return - Insert query
isolated function createBusinessUnitTeamSubTeamQuery(int businessUnitTeamId, int subTeamId, string headEmail,
        string createdBy) returns sql:ParameterizedQuery =>
    `INSERT INTO business_unit_team_sub_team (business_unit_team_id, sub_team_id, head_email, created_by, updated_by)
     VALUES (${businessUnitTeamId}, ${subTeamId}, ${headEmail}, ${createdBy}, ${createdBy})
     ON DUPLICATE KEY UPDATE
        id = LAST_INSERT_ID(id),
        is_active = 1,
        head_email = VALUES(head_email),
        updated_by = VALUES(updated_by),
        updated_on = CURRENT_TIMESTAMP(6);`;

# Update business-unit-team → sub-team mapping query.
#
# + id - Mapping ID
# + headEmail - Updated head email (optional)
# + isActive - Updated active status (optional)
# + updatedBy - Updater email
# + return - Update query or error if nothing to update
isolated function updateBusinessUnitTeamSubTeamQuery(int id, string? headEmail, boolean? isActive,
        string updatedBy) returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if headEmail is string {
        updates.push(`head_email = ${headEmail}`);
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError(ERROR_NO_FIELDS_TO_UPDATE);
    }
    updates.push(`updated_by = ${updatedBy}`);
    return sql:queryConcat(buildSqlUpdateQuery(`UPDATE business_unit_team_sub_team SET `, updates),
            ` WHERE id = ${id};`);
}

# Create business-unit-team-sub-team → unit mapping query.
#
# + businessUnitTeamSubTeamId - Business unit team sub-team mapping ID
# + unitId - Unit ID
# + headEmail - Head email for this mapping
# + createdBy - Creator email
# + return - Insert query
isolated function createBusinessUnitTeamSubTeamUnitQuery(int businessUnitTeamSubTeamId, int unitId, string headEmail,
        string createdBy) returns sql:ParameterizedQuery =>
    `INSERT INTO business_unit_team_sub_team_unit
         (business_unit_team_sub_team_id, unit_id, head_email, created_by, updated_by)
     VALUES (${businessUnitTeamSubTeamId}, ${unitId}, ${headEmail}, ${createdBy}, ${createdBy})
     ON DUPLICATE KEY UPDATE
        id = LAST_INSERT_ID(id),
        is_active = 1,
        head_email = VALUES(head_email),
        updated_by = VALUES(updated_by),
        updated_on = CURRENT_TIMESTAMP(6);`;

# Update business-unit-team-sub-team → unit mapping query.
#
# + id - Mapping ID
# + headEmail - Updated head email (optional)
# + isActive - Updated active status (optional)
# + updatedBy - Updater email
# + return - Update query or error if nothing to update
isolated function updateBusinessUnitTeamSubTeamUnitQuery(int id, string? headEmail, boolean? isActive,
        string updatedBy) returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if headEmail is string {
        updates.push(`head_email = ${headEmail}`);
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError(ERROR_NO_FIELDS_TO_UPDATE);
    }
    updates.push(`updated_by = ${updatedBy}`);
    return sql:queryConcat(buildSqlUpdateQuery(`UPDATE business_unit_team_sub_team_unit SET `, updates),
            ` WHERE id = ${id};`);
}

# Get the company org chart structure query (includes all mapping metadata).
# Returns all BUs (active and inactive) with their nested teams, sub-teams, and units,
# enriched with mapping IDs and head emails for admin management.
#
# + return - Company org chart structure query
isolated function getCompanyOrgChartStructureQuery() returns sql:ParameterizedQuery =>
    `SELECT
        bu.id,
        bu.name,
        bu.head_email,
        bu.is_active,
        (SELECT COUNT(*) FROM employee
            WHERE business_unit_id = bu.id AND employee_status = 'Active') AS active_employee_count,
        COALESCE(
            (
                SELECT JSON_ARRAYAGG(team_sub.obj)
                FROM LATERAL (
                    SELECT JSON_OBJECT(
                        'id', t.id,
                        'name', t.name,
                        'headEmail', t.head_email,
                        'isActive', IF(t.is_active = 1, CAST('true' AS JSON), CAST('false' AS JSON)),
                        'mappingId', but.id,
                        'mappingHeadEmail', but.head_email,
                        'mappingIsActive', IF(but.is_active = 1, CAST('true' AS JSON), CAST('false' AS JSON)),
                        'subTeams',
                        COALESCE(
                            (
                                SELECT JSON_ARRAYAGG(subteam_sub.obj)
                                FROM LATERAL (
                                    SELECT JSON_OBJECT(
                                        'id', st.id,
                                        'name', st.name,
                                        'headEmail', st.head_email,
                                        'isActive', IF(st.is_active = 1, CAST('true' AS JSON), CAST('false' AS JSON)),
                                        'mappingId', butst.id,
                                        'mappingHeadEmail', butst.head_email,
                                        'mappingIsActive', IF(butst.is_active = 1,
                                            CAST('true' AS JSON), CAST('false' AS JSON)),
                                        'units',
                                        COALESCE(
                                            (
                                                SELECT JSON_ARRAYAGG(unit_sub.obj)
                                                FROM LATERAL (
                                                    SELECT JSON_OBJECT(
                                                        'id', u.id,
                                                        'name', u.name,
                                                        'headEmail', u.head_email,
                                                        'isActive', IF(u.is_active = 1,
                                                            CAST('true' AS JSON), CAST('false' AS JSON)),
                                                        'mappingId', butstu.id,
                                                        'mappingHeadEmail', butstu.head_email,
                                                        'mappingIsActive', IF(butstu.is_active = 1,
                                                            CAST('true' AS JSON), CAST('false' AS JSON))
                                                    ) AS obj
                                                    FROM business_unit_team_sub_team_unit butstu
                                                    INNER JOIN unit u ON u.id = butstu.unit_id
                                                    WHERE butstu.business_unit_team_sub_team_id = butst.id
                                                    ORDER BY u.name
                                                ) AS unit_sub
                                            ),
                                            JSON_ARRAY()
                                        )
                                    ) AS obj
                                    FROM business_unit_team_sub_team butst
                                    INNER JOIN sub_team st ON st.id = butst.sub_team_id
                                    WHERE butst.business_unit_team_id = but.id
                                    ORDER BY st.name
                                ) AS subteam_sub
                            ),
                            JSON_ARRAY()
                        )
                    ) AS obj
                    FROM business_unit_team but
                    INNER JOIN team t ON t.id = but.team_id
                    WHERE but.business_unit_id = bu.id
                    ORDER BY t.name
                ) AS team_sub
            ),
            JSON_ARRAY()
        ) AS teams
    FROM business_unit bu
    ORDER BY bu.name;`;

# Get full organization structure query.
#
# + return - Full organization structure query
isolated function getFullOrganizationStructureQuery() returns sql:ParameterizedQuery =>
    `SELECT
        bu.id,
        bu.name,
        COALESCE(
            (
                SELECT JSON_ARRAYAGG(team_sub.obj)
                FROM LATERAL (
                    SELECT JSON_OBJECT(
                        'id', t.id,
                        'name', t.name,
                        'subTeams',
                        COALESCE(
                            (
                                SELECT JSON_ARRAYAGG(subteam_sub.obj)
                                FROM LATERAL (
                                    SELECT JSON_OBJECT(
                                        'id', st.id,
                                        'name', st.name,
                                        'units',
                                        COALESCE(
                                            (
                                                SELECT JSON_ARRAYAGG(unit_sub.obj)
                                                FROM LATERAL (
                                                    SELECT JSON_OBJECT(
                                                        'id', u.id,
                                                        'name', u.name
                                                    ) AS obj
                                                    FROM business_unit_team_sub_team_unit butstu
                                                    INNER JOIN unit u ON u.id = butstu.unit_id
                                                    WHERE butstu.business_unit_team_sub_team_id = butst.id
                                                    ORDER BY u.name
                                                ) AS unit_sub
                                            ),
                                            JSON_ARRAY()
                                        )
                                    ) AS obj
                                    FROM business_unit_team_sub_team butst
                                    INNER JOIN sub_team st ON st.id = butst.sub_team_id
                                    WHERE butst.business_unit_team_id = but.id
                                    ORDER BY st.name
                                ) AS subteam_sub
                            ),
                            JSON_ARRAY()
                        )
                    ) AS obj
                    FROM business_unit_team but
                    INNER JOIN team t ON t.id = but.team_id
                    WHERE but.business_unit_id = bu.id
                    ORDER BY t.name
                ) AS team_sub
            ),
            JSON_ARRAY()
        ) AS teams
    FROM business_unit bu
    ORDER BY bu.name;`;

# Get career functions query.
#
# + includeInactive - If true, return all rows including inactive; otherwise active-only
# + return - Career functions query
isolated function getCareerFunctionsQuery(boolean includeInactive = false) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = `SELECT
            cf.id,
            cf.career_function,
            cf.is_active,
            (SELECT COUNT(*)
                FROM employee e
                JOIN designation d ON d.id = e.designation_id
                WHERE d.career_function_id = cf.id AND e.employee_status = 'Active'
            ) AS active_employee_count
        FROM career_function cf`;
    if !includeInactive {
        query = sql:queryConcat(query, ` WHERE cf.is_active = 1`);
    }
    return sql:queryConcat(query, ` ORDER BY cf.career_function;`);
}

# Get designations query.
#
# + careerFunctionId - Career function ID (optional)
# + includeInactive - If true, return all rows including inactive; otherwise active-only
# + return - Designations query
isolated function getDesignationsQuery(int? careerFunctionId = (), boolean includeInactive = false)
        returns sql:ParameterizedQuery {

    sql:ParameterizedQuery query = `SELECT
            d.id,
            d.designation,
            d.job_band,
            d.career_function_id,
            d.is_active,
            (SELECT COUNT(*)
                FROM employee e
                WHERE e.designation_id = d.id AND e.employee_status = 'Active'
            ) AS active_employee_count
        FROM designation d`;

    sql:ParameterizedQuery[] filters = [];
    if careerFunctionId is int {
        filters.push(`d.career_function_id = ${careerFunctionId}`);
    }
    if !includeInactive {
        filters.push(`d.is_active = 1`);
    }
    foreach int i in 0 ..< filters.length() {
        query = sql:queryConcat(query, i == 0 ? ` WHERE ` : ` AND `, filters[i]);
    }
    return sql:queryConcat(query, ` ORDER BY d.designation;`);
}

# Create a career function.
#
# + careerFunction - Career function name
# + createdBy - Email of the admin performing the action
# + return - Insert query
isolated function createCareerFunctionQuery(string careerFunction, string createdBy)
        returns sql:ParameterizedQuery =>
    `INSERT INTO career_function (career_function, created_by, updated_by)
     VALUES (${careerFunction}, ${createdBy}, ${createdBy});`;

# Update a career function.
#
# + id - Career function ID
# + careerFunction - New name, or nil to leave unchanged
# + isActive - New active flag, or nil to leave unchanged
# + updatedBy - Email of the admin performing the action
# + return - Update query, or NoFieldsToUpdateError when nothing was supplied
isolated function updateCareerFunctionQuery(int id, string? careerFunction, boolean? isActive, string updatedBy)
        returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if careerFunction is string {
        updates.push(`career_function = ${careerFunction}`);
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError("No fields to update");
    }
    updates.push(`updated_by = ${updatedBy}`);

    sql:ParameterizedQuery query = `UPDATE career_function SET `;
    foreach int i in 0 ..< updates.length() {
        query = sql:queryConcat(query, i == 0 ? `` : `, `, updates[i]);
    }
    return sql:queryConcat(query, ` WHERE id = ${id};`);
}

# Create a designation.
#
# + designation - Designation name
# + jobBand - Job band, or nil
# + careerFunctionId - Parent career function ID, or nil for unassigned
# + createdBy - Email of the admin performing the action
# + return - Insert query
isolated function createDesignationQuery(string designation, int? jobBand, int? careerFunctionId, string createdBy)
        returns sql:ParameterizedQuery =>
    `INSERT INTO designation (designation, job_band, career_function_id, created_by, updated_by)
     VALUES (${designation}, ${jobBand}, ${careerFunctionId}, ${createdBy}, ${createdBy});`;

# Update a designation.
#
# + id - Designation ID
# + designation - New name, or nil to leave unchanged
# + jobBand - New job band; -1 (JOB_BAND_CLEAR_SENTINEL) clears it to NULL; nil leaves it unchanged
# + careerFunctionId - New parent career function ID; -1 (CAREER_FUNCTION_CLEAR_SENTINEL) clears it to NULL; nil leaves it unchanged
# + isActive - New active flag, or nil to leave unchanged
# + updatedBy - Email of the admin performing the action
# + return - Update query, or NoFieldsToUpdateError when nothing was supplied
isolated function updateDesignationQuery(int id, string? designation, int? jobBand, int? careerFunctionId,
        boolean? isActive, string updatedBy) returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if designation is string {
        updates.push(`designation = ${designation}`);
    }
    if jobBand is int {
        if jobBand == JOB_BAND_CLEAR_SENTINEL {
            updates.push(`job_band = NULL`);
        } else {
            updates.push(`job_band = ${jobBand}`);
        }
    }
    if careerFunctionId is int {
        if careerFunctionId == CAREER_FUNCTION_CLEAR_SENTINEL {
            updates.push(`career_function_id = NULL`);
        } else {
            updates.push(`career_function_id = ${careerFunctionId}`);
        }
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError("No fields to update");
    }
    updates.push(`updated_by = ${updatedBy}`);

    sql:ParameterizedQuery query = `UPDATE designation SET `;
    foreach int i in 0 ..< updates.length() {
        query = sql:queryConcat(query, i == 0 ? `` : `, `, updates[i]);
    }
    return sql:queryConcat(query, ` WHERE id = ${id};`);
}

# Count active employees and new joiners holding a designation.
#
# + id - Designation ID
# + return - Query counting active employees and new joiners
isolated function countActiveEmployeesInDesignationQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) AS count FROM employee WHERE designation_id = ${id} AND employee_status IN ('Active', 'New joiner');`;

# Count active employees and new joiners across a career function's designations.
#
# + id - Career function ID
# + return - Query counting active employees and new joiners
isolated function countActiveEmployeesInCareerFunctionQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) AS count
     FROM employee e
     JOIN designation d ON d.id = e.designation_id
     WHERE d.career_function_id = ${id} AND e.employee_status IN ('Active', 'New joiner');`;

# Get companies query.
#
# + return - Companies query
isolated function getCompaniesQuery() returns sql:ParameterizedQuery =>
    `SELECT 
        c.id,
        c.name,
        c.prefix,
        c.location,
        CASE 
            WHEN COUNT(cal.id) = 0 THEN NULL
            ELSE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'location', cal2.allowed_location,
                        'probationPeriod', cal2.probation_period
                )
            )
        FROM companies_allowed_locations cal2
        WHERE cal2.company_id = c.id AND cal2.is_active = 1
        ORDER BY cal2.allowed_location
        )
    END AS allowedLocations
    FROM company c
    LEFT JOIN companies_allowed_locations cal 
        ON c.id = cal.company_id AND cal.is_active = 1
    GROUP BY c.id, c.name, c.prefix, c.location;`;

# Get the timezone of every company work location.
#
# Inactive locations are included: an employee keeps a location after it stops being offered
# for onboarding, and their dates still need its timezone.
#
# + return - Query returning each location's company, name and timezone
isolated function getLocationTimeZonesQuery() returns sql:ParameterizedQuery =>
    `SELECT company_id, allowed_location, time_zone FROM companies_allowed_locations`;

# Get offices query.
#
# + companyId - Company ID (optional)
# + return - Offices query
isolated function getOfficesQuery(int? companyId = ()) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = `
        SELECT 
            id,
            name,
            location
        FROM office`;
    if companyId is int {
        query = sql:queryConcat(query, ` WHERE company_id = ${companyId}`);
    }
    return sql:queryConcat(query, `;`);
}

# Get employment types query.
#
# + return - Employment types query
isolated function getEmploymentTypesQuery() returns sql:ParameterizedQuery =>
    `SELECT
        id,
        name,
        is_active
    FROM employment_type;`;

# Fetch IDP group names mapped to a given employment type.
#
# + employmentTypeId - Employment type ID
# + return - Parameterized query returning group_name rows
isolated function getAsgardeoGroupsForEmploymentTypeQuery(int employmentTypeId) returns sql:ParameterizedQuery =>
    `SELECT group_name AS groupName
     FROM employment_type_idp_group
     WHERE employment_type_id = ${employmentTypeId};`;

# Fetch Asgardeo group names mapped to a given team and employment type.
#
# + teamId - Team ID
# + employmentTypeId - Employment type ID
# + return - Parameterized query returning group_name rows
isolated function getAsgardeoGroupsForTeamQuery(int teamId, int employmentTypeId) returns sql:ParameterizedQuery =>
    `SELECT group_name AS groupName
     FROM team_asgardeo_groups
     WHERE team_id = ${teamId} AND employment_type_id = ${employmentTypeId};`;

# Get houses query.
#
# + return - Houses query
isolated function getHousesQuery() returns sql:ParameterizedQuery =>
    `SELECT id, name FROM house WHERE is_active = 1 ORDER BY name`;

# Fetch the assignable leadership attributes.
#
# + return - Parameterized query returning active leadership_group rows
isolated function getLeadershipGroupsQuery() returns sql:ParameterizedQuery =>
    `SELECT id, name, is_active AS isActive
     FROM leadership_group
     WHERE is_active = 1
     ORDER BY name;`;

# The employee statuses whose holders block retiring a leadership attribute. A Left
# employee's assignment does not: it stays in the DB and history, and is hidden once the
# attribute is retired.
#
# + return - Parameterized list of the blocking statuses, for an IN (...) clause
isolated function leadershipHolderStatuses() returns sql:ParameterizedQuery =>
    `${EMPLOYEE_ACTIVE}, ${EMPLOYEE_MARKED_LEAVER}, ${EMPLOYEE_NEW_JOINER}`;

# Every leadership attribute, retired ones included, with how many current employees hold it.
#
# + return - Parameterized query returning LeadershipGroupWithUsage rows, active first
isolated function getLeadershipGroupsWithUsageQuery() returns sql:ParameterizedQuery =>
    sql:queryConcat(
        `SELECT lg.id, lg.name, lg.is_active AS isActive, COUNT(e.id) AS holderCount
         FROM leadership_group lg
         LEFT JOIN employee_leadership el
            ON el.leadership_group_id = lg.id AND el.is_active = 1
         LEFT JOIN employee e
            ON e.id = el.employee_pk_id AND e.employee_status IN (`, leadershipHolderStatuses(), `)
         GROUP BY lg.id, lg.name, lg.is_active
         ORDER BY lg.is_active DESC, lg.name;`);

# Count the current employees holding a leadership attribute.
#
# + id - Leadership attribute ID
# + return - Parameterized query returning the holder count
isolated function countLeadershipGroupHoldersQuery(int id) returns sql:ParameterizedQuery =>
    sql:queryConcat(
        `SELECT COUNT(*)
         FROM employee_leadership el
         JOIN employee e ON e.id = el.employee_pk_id
         WHERE el.leadership_group_id = ${id} AND el.is_active = 1
           AND e.employee_status IN (`, leadershipHolderStatuses(), `);`);

# Create a leadership attribute.
#
# + name - Attribute name, already trimmed
# + createdBy - Email of the admin performing the action
# + return - Insert query
isolated function createLeadershipGroupQuery(string name, string createdBy) returns sql:ParameterizedQuery =>
    `INSERT INTO leadership_group (name, created_by, updated_by)
     VALUES (${name}, ${createdBy}, ${createdBy});`;

# Rename, retire or reactivate a leadership attribute.
#
# Retiring carries its own guard, so an attribute cannot be retired while current employees
# hold it even if one is assigned between a check and this write. A guarded retire that
# matches no row is therefore either an unknown ID or an attribute still in use; the caller
# tells the two apart.
#
# + id - Leadership attribute ID
# + name - New name, already trimmed, or nil to leave unchanged
# + isActive - New active flag, or nil to leave unchanged
# + updatedBy - Email of the admin performing the action
# + return - Update query, or NoFieldsToUpdateError when nothing was supplied
isolated function updateLeadershipGroupQuery(int id, string? name, boolean? isActive, string updatedBy)
        returns sql:ParameterizedQuery|error {

    sql:ParameterizedQuery[] updates = [];
    if name is string {
        updates.push(`name = ${name}`);
    }
    if isActive is boolean {
        updates.push(`is_active = ${isActive}`);
    }
    if updates.length() == 0 {
        return error NoFieldsToUpdateError("No fields to update");
    }
    updates.push(`updated_by = ${updatedBy}`);

    sql:ParameterizedQuery query = `UPDATE leadership_group SET `;
    foreach int i in 0 ..< updates.length() {
        query = sql:queryConcat(query, i == 0 ? `` : `, `, updates[i]);
    }
    query = sql:queryConcat(query, ` WHERE id = ${id}`);
    if isActive == false {
        query = sql:queryConcat(query,
            ` AND NOT EXISTS (
                SELECT 1 FROM employee_leadership el
                JOIN employee e ON e.id = el.employee_pk_id
                WHERE el.leadership_group_id = ${id} AND el.is_active = 1
                  AND e.employee_status IN (`, leadershipHolderStatuses(), `))`);
    }
    return sql:queryConcat(query, `;`);
}

# Check whether a leadership attribute exists.
#
# + id - Leadership attribute ID
# + return - Parameterized query returning 1 when it exists
isolated function leadershipGroupExistsQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) FROM leadership_group WHERE id = ${id};`;

# Add employee personal information query. Upserts on the nic_or_passport UNIQUE key so
# rehiring someone (same NIC/Passport) refreshes their existing personal_info row instead of
# failing — `id = LAST_INSERT_ID(id)` makes the update branch still resolve to that row's own
# id when the caller queries `SELECT LAST_INSERT_ID()` afterward (see addPersonalInfo).
#
# + payload - Create personal info payload
# + createdBy - Creator/updater of the personal info record
# + return - Personal info upsert query
isolated function addEmployeePersonalInfoQuery(CreatePersonalInfoPayload payload, string createdBy)
    returns sql:ParameterizedQuery =>
    `INSERT INTO personal_info
        (
            nic_or_passport,
            first_name,
            last_name,
            full_name,
            title,
            dob,
            gender,
            personal_email,
            personal_phone,
            resident_number,
            address_line_1,
            address_line_2,
            city,
            state_or_province,
            postal_code,
            country,
            nationality,
            created_by,
            updated_by
        )
    VALUES
        (
            ${payload.nicOrPassport},
            ${payload.firstName},
            ${payload.lastName},
            ${payload.fullName},
            ${payload.title},
            ${payload.dob},
            ${payload.gender},
            ${payload.personalEmail},
            ${payload.personalPhone},
            ${payload.residentNumber},
            ${payload.addressLine1},
            ${payload.addressLine2},
            ${payload.city},
            ${payload.stateOrProvince},
            ${payload.postalCode},
            ${payload.country},
            ${payload.nationality},
            ${createdBy},
            ${createdBy}
        )
    ON DUPLICATE KEY UPDATE
        id = LAST_INSERT_ID(id),
        first_name = VALUES(first_name),
        last_name = VALUES(last_name),
        full_name = VALUES(full_name),
        title = VALUES(title),
        dob = VALUES(dob),
        gender = VALUES(gender),
        personal_email = VALUES(personal_email),
        personal_phone = VALUES(personal_phone),
        resident_number = VALUES(resident_number),
        address_line_1 = VALUES(address_line_1),
        address_line_2 = VALUES(address_line_2),
        city = VALUES(city),
        state_or_province = VALUES(state_or_province),
        postal_code = VALUES(postal_code),
        country = VALUES(country),
        nationality = VALUES(nationality),
        updated_by = ${createdBy};`;

# Fetch company prefix and employment type required for generating the next employee ID.
#
# + companyId - Company ID of the new employee
# + employmentTypeId - Employment type ID of the new employee
# + return - Query returning `companyPrefix`, `employmentType` and `isActive` columns
isolated function getEmployeeIdContextQuery(int companyId, int employmentTypeId)
    returns sql:ParameterizedQuery =>
    `SELECT
        c.prefix        AS companyPrefix,
        UPPER(et.name)  AS employmentType,
        et.is_active    AS isActive
    FROM employment_type et
    JOIN company c ON c.id = ${companyId}
    WHERE et.id = ${employmentTypeId}`;

# Fetch and lock the current numeric maximum within a digit-family sequence, scoped purely by the
# ID string pattern (prefix + leading digit) rather than by employment type. This means an
# employee tagged with any type — including inactive/legacy ones the caller never listed — can
# never be invisible to this count, which is what a type-filtered scan allowed to happen.
#
# Note on `FOR UPDATE`: this row lock only has effect when the query runs inside a database
# transaction. The bulk-onboarding caller (`generateBulkEmployeeId`) does hold it inside a real
# transaction, so it gets actual mutual exclusion. The single-onboarding caller
# (`getNextIdInFamily` -> `getFamilyMax`, invoked from `generateEmployeeId` in utils.bal) does
# NOT wrap this in a transaction, so on that path the lock is released as soon as the query
# returns and provides no real protection against a concurrent check-then-act race. That race is
# a known, already-accepted limitation and intentionally out of scope here — this note exists so
# `FOR UPDATE` isn't mistaken for an effective lock on the single-onboarding path.
#
# + prefix - The ID prefix (company prefix or CONSULTANCY_ID_PREFIX)
# + digit - The required leading digit for this family, as a single character ("0", "1", or "5")
# + return - Query returning the current numeric maximum for this family (0 if none exist yet)
isolated function getNextIdInFamilyQuery(string prefix, string digit) returns sql:ParameterizedQuery =>
    `SELECT
        COALESCE(
            MAX(CAST(SUBSTRING(employee_id, ${prefix.length() + 1}) AS UNSIGNED)),
            0
        ) AS lastNumericId
    FROM employee
    WHERE
        employee_id LIKE ${prefix + digit + "%"}
        AND employee_id NOT LIKE ${prefix + "_%-%"}
    ORDER BY CAST(SUBSTRING(employee_id, ${prefix.length() + 1}) AS UNSIGNED) DESC
    LIMIT 1
    FOR UPDATE`; // Lock has no effect here on the single-onboarding path — see doc comment above.

# Add employee query.
#
# + payload - Add employee payload
# + createdBy - Creator of the employee record
# + personalInfoId - Personal info ID
# + employeeId - Employee ID to be inserted
# + return - Employee insert query
isolated function addEmployeeQuery(CreateEmployeePayload payload, string createdBy, int personalInfoId, string employeeId)
    returns sql:ParameterizedQuery =>
    `INSERT INTO employee
        (
            employee_id,
            first_name,
            last_name,
            epf,
            company_id,
            work_location,
            work_email,
            start_date,
            secondary_job_title,
            job_role,
            external_designation,
            manager_email,
            employee_status,
            continuous_service_record,
            employee_thumbnail,
            probation_end_date,
            agreement_end_date,
            personal_info_id,
            employment_type_id,
            designation_id,
            office_id,
            team_id,
            sub_team_id,
            business_unit_id,
            unit_id,
            house_id,
            created_by,
            updated_by
        )
    VALUES
        (
            ${employeeId},
            ${payload.firstName},
            ${payload.lastName},
            ${payload.epf},
            ${payload.companyId},
            ${payload.workLocation},
            ${payload.workEmail ?: FUTURE_JOINER_EMAIL},
            ${payload.startDate},
            ${payload.secondaryJobTitle},
            ${payload.jobRole},
            ${payload.externalDesignation},
            ${payload.managerEmail},
            ${payload.employeeStatus},
            ${payload.continuousServiceRecord},
            ${payload.employeeThumbnail},
            ${payload.probationEndDate},
            ${payload.agreementEndDate},
            ${personalInfoId},
            ${payload.employmentTypeId},
            ${payload.designationId},
            ${payload.officeId},
            ${payload.teamId},
            ${payload.subTeamId},
            ${payload.businessUnitId},
            ${payload.unitId},
            ${payload.houseId},
            ${createdBy},
            ${createdBy}
        );`;

# Update employee personal information query.
#
# + employeeId - Personal info ID
# + payload - Personal info update payload
# + updatedBy - Updater of the personal info record
# + return - sql:ParameterizedQuery - Update query for personal info
isolated function updateEmployeePersonalInfoQuery(string employeeId, UpdateEmployeePersonalInfoPayload payload, string updatedBy)
    returns sql:ParameterizedQuery {

    sql:ParameterizedQuery mainQuery = `UPDATE personal_info SET `;
    sql:ParameterizedQuery[] updates = [];

    if payload.nicOrPassport != () {
        updates.push(`nic_or_passport = ${payload.nicOrPassport}`);
    }

    if payload.firstName != () {
        updates.push(`first_name = ${payload.firstName}`);
    }

    if payload.lastName != () {
        updates.push(`last_name = ${payload.lastName}`);
    }

    if payload.fullName != () {
        updates.push(`full_name = ${payload.fullName}`);
    }

    if payload.title != () {
        updates.push(`title = ${payload.title}`);
    }

    if payload.dob != () {
        updates.push(`dob = ${payload.dob}`);
    }

    if payload.gender != () {
        updates.push(`gender = ${payload.gender}`);
    }

    if payload.nationality != () {
        updates.push(`nationality = ${payload.nationality}`);
    }

    if payload.personalEmail is string {
        if payload.personalEmail == "" {
            updates.push(`personal_email = NULL`);
        } else {
            updates.push(`personal_email = ${payload.personalEmail}`);
        }
    }

    if payload.personalPhone is string {
        if payload.personalPhone == "" {
            updates.push(`personal_phone = NULL`);
        } else {
            updates.push(`personal_phone = ${payload.personalPhone}`);
        }
    }

    if payload.residentNumber is string {
        if payload.residentNumber == "" {
            updates.push(`resident_number = NULL`);
        } else {
            updates.push(`resident_number = ${payload.residentNumber}`);
        }
    }

    if payload.addressLine1 is string {
        if payload.addressLine1 == "" {
            updates.push(`address_line_1 = NULL`);
        } else {
            updates.push(`address_line_1 = ${payload.addressLine1}`);
        }
    }

    if payload.addressLine2 is string {
        if payload.addressLine2 == "" {
            updates.push(`address_line_2 = NULL`);
        } else {
            updates.push(`address_line_2 = ${payload.addressLine2}`);
        }
    }

    if payload.city is string {
        if payload.city == "" {
            updates.push(`city = NULL`);
        } else {
            updates.push(`city = ${payload.city}`);
        }
    }

    if payload.stateOrProvince is string {
        if payload.stateOrProvince == "" {
            updates.push(`state_or_province = NULL`);
        } else {
            updates.push(`state_or_province = ${payload.stateOrProvince}`);
        }
    }

    if payload.postalCode is string {
        if payload.postalCode == "" {
            updates.push(`postal_code = NULL`);
        } else {
            updates.push(`postal_code = ${payload.postalCode}`);
        }
    }

    if payload.country is string {
        if payload.country == "" {
            updates.push(`country = NULL`);
        } else {
            updates.push(`country = ${payload.country}`);
        }
    }

    updates.push(`updated_by = ${updatedBy}`);

    sql:ParameterizedQuery query = buildSqlUpdateQuery(mainQuery, updates);

    sql:ParameterizedQuery finalQuery = sql:queryConcat(query, `
        WHERE id = (SELECT personal_info_id FROM employee WHERE employee_id = ${employeeId})
    `);

    return finalQuery;
}

# Update the denormalized first/last name copies held on the employee row itself.
#
# `employee.first_name`/`employee.last_name` are separate columns from
# `personal_info.first_name`/`personal_info.last_name` (both are populated at creation time
# from the two halves of CreateEmployeePayload) and are what the employee directory, search,
# and detail views actually read. They must be kept in sync whenever a personal-info edit
# changes the name, or those views silently keep showing the old name.
#
# + employeeId - Employee ID
# + payload - Personal info update payload
# + updatedBy - Updater of the employee record
# + return - sql:ParameterizedQuery - Update query for the employee row's name columns
isolated function updateEmployeeNameQuery(string employeeId, UpdateEmployeePersonalInfoPayload payload, string updatedBy)
    returns sql:ParameterizedQuery {

    sql:ParameterizedQuery mainQuery = `UPDATE employee SET `;
    sql:ParameterizedQuery[] updates = [];

    if payload.firstName != () {
        updates.push(`first_name = ${payload.firstName}`);
    }

    if payload.lastName != () {
        updates.push(`last_name = ${payload.lastName}`);
    }

    updates.push(`updated_by = ${updatedBy}`);

    sql:ParameterizedQuery query = buildSqlUpdateQuery(mainQuery, updates);

    return sql:queryConcat(query, `
        WHERE employee_id = ${employeeId}
    `);
}

# Add emergency contact query.
#
# + employeeId - Employee ID
# + contact - Emergency contact details
# + actor - User creating the emergency contact record
# + return - sql:ParameterizedQuery - Insert query for emergency contacts
isolated function addPersonalInfoEmergencyContactQuery(string employeeId, EmergencyContact contact, string actor)
    returns sql:ParameterizedQuery =>
    `INSERT INTO personal_info_emergency_contacts
        (
            personal_info_id,
            name,
            mobile,
            telephone,
            relationship,
            is_active,
            created_by,
            updated_by
        )
    VALUES
        (
            (SELECT personal_info_id FROM employee WHERE employee_id = ${employeeId}),
            ${contact.name},
            ${contact.mobile},
            ${contact.telephone},
            ${contact.relationship},
            1,
            ${actor},
            ${actor}
        )
    ON DUPLICATE KEY UPDATE
        is_active = 1,
        name = ${contact.name},
        mobile = ${contact.mobile},
        telephone = ${contact.telephone},
        relationship = ${contact.relationship},
        updated_by = ${actor},
        updated_on = CURRENT_TIMESTAMP(6);`;

# Fetch active emergency contact full rows for an employee.
#
# + employeeId - Employee ID string
# + return - Query to get active emergency contact rows
isolated function getEmergencyContactRowsQuery(string employeeId)
    returns sql:ParameterizedQuery =>
    `SELECT piec.name,
            piec.telephone,
            piec.relationship,
            piec.mobile
     FROM personal_info_emergency_contacts piec
     INNER JOIN employee e ON e.personal_info_id = piec.personal_info_id
     WHERE e.employee_id = ${employeeId}
       AND piec.is_active = 1;`;

# Delete emergency contact query.
#
# + employeeId - Employee ID string
# + mobile - Mobile number of the contact to deactivate
# + actor - User performing the operation
# + return - Query to soft-delete one emergency contact
isolated function deleteEmergencyContactQuery(string employeeId, string mobile, string actor)
    returns sql:ParameterizedQuery =>
    `UPDATE personal_info_emergency_contacts piec
      INNER JOIN employee e ON e.personal_info_id = piec.personal_info_id
      SET piec.is_active = 0,
          piec.updated_by = ${actor},
          piec.updated_on = CURRENT_TIMESTAMP(6)
      WHERE e.employee_id = ${employeeId}
        AND piec.mobile = ${mobile}
        AND piec.is_active = 1;`;

# Update employee job information query.
#
# + employeeId - Employee ID
# + payload - Job information update payload
# + updatedBy - User performing the update
# + return - sql:ParameterizedQuery - Update query for employee job info
isolated function updateEmployeeJobInfoQuery(string employeeId, UpdateEmployeeJobInfoPayload payload, string updatedBy)
    returns sql:ParameterizedQuery {

    sql:ParameterizedQuery mainQuery = `UPDATE employee SET `;
    sql:ParameterizedQuery[] updates = [];

    if payload.epf is string {
        if payload.epf == "" {
            updates.push(`epf = NULL`);
        } else {
            updates.push(`epf = ${payload.epf}`);
        }
    }

    if payload.companyId != () {
        updates.push(`company_id = ${payload.companyId}`);
    }

    if payload.workLocation != () {
        updates.push(`work_location = ${payload.workLocation}`);
    }

    if payload.workEmail != () {
        updates.push(`work_email = ${payload.workEmail}`);
    }

    if payload.startDate != () {
        updates.push(`start_date = ${payload.startDate}`);
    }

    if payload.secondaryJobTitle is string {
        if payload.secondaryJobTitle == "" {
            updates.push(`secondary_job_title = NULL`);
        } else {
            updates.push(`secondary_job_title = ${payload.secondaryJobTitle}`);
        }
    }

    if payload.jobRole is string {
        if payload.jobRole == "" {
            updates.push(`job_role = NULL`);
        } else {
            updates.push(`job_role = ${payload.jobRole}`);
        }
    }

    if payload.externalDesignation is string {
        if payload.externalDesignation == "" {
            updates.push(`external_designation = NULL`);
        } else {
            updates.push(`external_designation = ${payload.externalDesignation}`);
        }
    }

    if payload.managerEmail != () {
        updates.push(`manager_email = ${payload.managerEmail}`);
    }

    if payload.employeeThumbnail is string {
        if payload.employeeThumbnail == "" {
            updates.push(`employee_thumbnail = NULL`);
        } else {
            updates.push(`employee_thumbnail = ${payload.employeeThumbnail}`);
        }
    }

    if payload.probationEndDate is string {
        if payload.probationEndDate == "" {
            updates.push(`probation_end_date = NULL`);
        } else {
            updates.push(`probation_end_date = ${payload.probationEndDate}`);
        }
    }

    if payload.agreementEndDate is string {
        if payload.agreementEndDate == "" {
            updates.push(`agreement_end_date = NULL`);
        } else {
            updates.push(`agreement_end_date = ${payload.agreementEndDate}`);
        }
    }

    if payload.employmentTypeId != () {
        updates.push(`employment_type_id = ${payload.employmentTypeId}`);
    }

    if payload.designationId != () {
        updates.push(`designation_id = ${payload.designationId}`);
    }

    // The frontend only ever includes officeId/unitId/houseId in the PATCH body when their
    // value actually changed (it diffs against the pre-edit form state and omits unchanged
    // keys) — so `payload.X is ()` means "this field wasn't part of this edit," NOT "clear
    // it." officeId/unitId ARE legitimately user-clearable (the edit form has a "None"
    // option), so an explicit clear is sent as the OFFICE_CLEAR_SENTINEL / UNIT_CLEAR_SENTINEL
    // value (-1), matching the same pattern already used for jobBand/careerFunctionId in
    // updateDesignationQuery. Absence (`is ()`) is intentionally not handled here — the column
    // is simply left untouched.
    if payload.officeId is int {
        if payload.officeId == OFFICE_CLEAR_SENTINEL {
            updates.push(`office_id = NULL`);
        } else {
            updates.push(`office_id = ${payload.officeId}`);
        }
    }

    if payload.teamId != () {
        updates.push(`team_id = ${payload.teamId}`);
    }

    if payload.subTeamId != () {
        updates.push(`sub_team_id = ${payload.subTeamId}`);
    }

    if payload.businessUnitId != () {
        updates.push(`business_unit_id = ${payload.businessUnitId}`);
    }

    if payload.unitId is int {
        if payload.unitId == UNIT_CLEAR_SENTINEL {
            updates.push(`unit_id = NULL`);
        } else {
            updates.push(`unit_id = ${payload.unitId}`);
        }
    }

    // houseId is system-computed at employee creation (from the numeric part of the employee
    // ID) and is never included by the job-info edit form's diff — unlike officeId/unitId,
    // there is no "clear the house" user action, so absence here always means "not part of
    // this edit." Set only when explicitly provided; never null it on omission.
    if payload.houseId is int {
        updates.push(`house_id = ${payload.houseId}`);
    }

    if payload.continuousServiceRecord is int {
        if payload.continuousServiceRecord == CONTINUOUS_SERVICE_RECORD_CLEAR_SENTINEL {
            updates.push(`continuous_service_record = NULL`);
        } else {
            updates.push(`continuous_service_record = ${payload.continuousServiceRecord}`);
        }
    }

    if payload.employeeStatus is EmployeeStatus {
        updates.push(`employee_status = ${payload.employeeStatus}`);
    }

    updates.push(`updated_by = ${updatedBy}`);

    sql:ParameterizedQuery query = buildSqlUpdateQuery(mainQuery, updates);

    sql:ParameterizedQuery finalQuery = sql:queryConcat(query, `
        WHERE employee_id = ${employeeId}
    `);

    return finalQuery;
}

# Upsert the resignation record for an employee.
# Fields not provided in the payload (null) preserve the existing DB value.
#
# + employeeId - Employee ID string
# + payload - Job information update payload containing leaver fields
# + updatedBy - User performing the update
# + return - sql:ParameterizedQuery - Upsert query for the resignation table
isolated function upsertResignationQuery(string employeeId, UpdateEmployeeJobInfoPayload payload, string updatedBy)
    returns sql:ParameterizedQuery {

    string? finalDayInOffice = payload.finalDayInOffice;
    string? finalDayOfEmployment = payload.finalDayOfEmployment;
    string? resignationReason = payload.resignationReason;

    return `INSERT INTO resignation
        (
            employee_id,
            date,
            final_day_in_office,
            final_day_of_employment,
            reason,
            created_by,
            updated_by
        )
    SELECT
        e.id,
        CURRENT_TIMESTAMP(6),
        ${finalDayInOffice},
        ${finalDayOfEmployment},
        ${resignationReason},
        ${updatedBy},
        ${updatedBy}
    FROM employee e
    WHERE e.employee_id = ${employeeId}
    ON DUPLICATE KEY UPDATE
        date                    = IF(date IS NULL, CURRENT_TIMESTAMP(6), date),
        final_day_in_office     = IF(VALUES(final_day_in_office) IS NOT NULL, VALUES(final_day_in_office), final_day_in_office),
        final_day_of_employment = IF(VALUES(final_day_of_employment) IS NOT NULL, VALUES(final_day_of_employment), final_day_of_employment),
        reason                  = IF(VALUES(reason) IS NOT NULL, VALUES(reason), reason),
        updated_by              = ${updatedBy},
        updated_on              = CURRENT_TIMESTAMP(6)`;
}

# Insert the `internship` row for a newly created employee, only when that employee's
# employment type is INTERNSHIP - for any other type nothing is inserted.
#
# + employeePkId - Primary key (`employee.id`) of the new employee
# + university - University the intern attends
# + createdBy - Creator of the record
# + return - Query to add the internship row
isolated function addInternshipQuery(int employeePkId, string university, string createdBy)
    returns sql:ParameterizedQuery =>
    `INSERT INTO internship (employee_id, university, created_by, updated_by)
    SELECT e.id, ${university}, ${createdBy}, ${createdBy}
    FROM employee e
        INNER JOIN employment_type et ON et.id = e.employment_type_id
    WHERE e.id = ${employeePkId} AND et.name = ${INTERNSHIP}`;

# Get the universities already recorded for interns, one per name regardless of case or
# surrounding spaces, most common first - the suggestions for the onboarding form.
#
# + return - Query to get the distinct university names
isolated function getUniversitiesQuery() returns sql:ParameterizedQuery =>
    `SELECT MIN(TRIM(university)) AS university
    FROM internship
    WHERE university IS NOT NULL AND TRIM(university) <> ''
    GROUP BY LOWER(TRIM(university))
    ORDER BY COUNT(*) DESC, university ASC`;

# Delete an employee's `internship` row.
#
# + employeePkId - Primary key (`employee.id`) of the employee
# + return - Query to delete the internship row
isolated function deleteInternshipQuery(int employeePkId) returns sql:ParameterizedQuery =>
    `DELETE FROM internship WHERE employee_id = ${employeePkId}`;

# Add an additional manager for an employee.
#
# + id - Employee ID
# + email - Additional manager email address
# + actor - User creating the additional manager record
# + return - sql:ParameterizedQuery - Insert query for an additional managers
isolated function addEmployeeAdditionalManagerQuery(int id, string email, string actor)
    returns sql:ParameterizedQuery =>
    `INSERT INTO employee_additional_managers
        (
            employee_pk_id,
            additional_manager_email,
            is_active,
            created_by,
            updated_by
        )
      VALUES
        (
            ${id}, 
            ${email}, 
            1,
            ${actor}, 
            ${actor}
        )
    ON DUPLICATE KEY UPDATE
        is_active = 1,
        updated_by = ${actor},
        updated_on = CURRENT_TIMESTAMP(6);`;

# Fetch active additional manager emails for an employee.
#
# + employeeId - Employee ID string
# + return - Query to get active additional manager emails
isolated function getAdditionalManagerEmailsQuery(string employeeId)
    returns sql:ParameterizedQuery =>
    `SELECT eam.additional_manager_email
     FROM employee_additional_managers eam
     INNER JOIN employee e ON e.id = eam.employee_pk_id
     WHERE e.employee_id = ${employeeId}
       AND eam.is_active = 1;`;

# Delete an additional manager for an employee.
#
# + employeeId - Employee ID string
# + email - Additional manager email to deactivate
# + actor - User performing the operation
# + return - Query to soft-delete one additional manager
isolated function deleteAdditionalManagerQuery(string employeeId, string email, string actor)
    returns sql:ParameterizedQuery =>
    `UPDATE employee_additional_managers eam
      INNER JOIN employee e ON e.id = eam.employee_pk_id
      SET eam.is_active = 0,
          eam.updated_by = ${actor},
          eam.updated_on = CURRENT_TIMESTAMP(6)
      WHERE e.employee_id = ${employeeId}
        AND LOWER(eam.additional_manager_email) = LOWER(${email})
        AND eam.is_active = 1;`;

# Inactivate all additional-manager relationships where the leaving
# employee's email is recorded as the additional manager for other employees.
#
# + managerEmail - Work email of the employee who is leaving
# + actor - User performing the operation
# + return - Parameterized query
isolated function inactivateAdditionalManagerRelationshipsQuery(string managerEmail, string actor)
    returns sql:ParameterizedQuery =>
    `UPDATE employee_additional_managers eam
     SET eam.is_active = 0,
         eam.updated_by = ${actor},
         eam.updated_on = CURRENT_TIMESTAMP(6)
     WHERE LOWER(eam.additional_manager_email) = LOWER(${managerEmail})
       AND eam.is_active = 1;`;

# Fetch the leadership attribute IDs an employee currently holds.
#
# Retired attributes are left out: the edit form must not offer them back, and a save
# validates every submitted ID against the active set.
#
# + employeeId - Employee business key
# + return - Parameterized query returning active leadership_group_id values
isolated function getEmployeeLeadershipIdsQuery(string employeeId) returns sql:ParameterizedQuery =>
    `SELECT el.leadership_group_id AS leadershipGroupId
     FROM employee_leadership el
     JOIN employee e ON e.id = el.employee_pk_id
     JOIN leadership_group lg ON lg.id = el.leadership_group_id
     WHERE e.employee_id = ${employeeId} AND el.is_active = 1 AND lg.is_active = 1;`;

# Deactivate the attributes an employee holds that are not in the desired set.
#
# Only active attributes are touched; see syncEmployeeLeadership for why a retired one is
# kept.
#
# + employeeId - Employee business key
# + groupIds - The complete desired set of attribute IDs
# + actor - Email recorded in updated_by, and thus in the audit trail
# + return - Parameterized update
isolated function deactivateEmployeeLeadershipQuery(string employeeId, int[] groupIds, string actor)
        returns sql:ParameterizedQuery {

    sql:ParameterizedQuery query =
        `UPDATE employee_leadership el
         JOIN employee e ON e.id = el.employee_pk_id
         JOIN leadership_group lg ON lg.id = el.leadership_group_id
         SET el.is_active = 0, el.updated_by = ${actor}
         WHERE e.employee_id = ${employeeId} AND el.is_active = 1 AND lg.is_active = 1`;
    return groupIds.length() == 0
        ? query
        : sql:queryConcat(query, ` AND el.leadership_group_id NOT IN (`, buildIntInClause(groupIds), `)`);
}

# Assign an attribute, reviving a previously removed row rather than inserting a duplicate.
#
# The unique key (employee_pk_id, leadership_group_id) makes a plain INSERT fail for an
# attribute the employee held before, so this upserts. The SELECT supplies employee_pk_id
# from the business key.
#
# + employeeId - Employee business key
# + groupId - Leadership attribute to assign
# + actor - Email recorded in created_by/updated_by, and thus in the audit trail
# + return - Parameterized upsert
isolated function assignEmployeeLeadershipQuery(string employeeId, int groupId, string actor)
        returns sql:ParameterizedQuery =>
    `INSERT INTO employee_leadership
        (employee_pk_id, leadership_group_id, is_active, created_by, updated_by)
     SELECT e.id, ${groupId}, 1, ${actor}, ${actor}
     FROM employee e WHERE e.employee_id = ${employeeId}
     ON DUPLICATE KEY UPDATE is_active = 1, updated_by = ${actor};`;

# Build query to fetch vehicles.
#
# + owner - Filter : Owner of the vehicles
# + vehicleStatus - Filter :  status of the vehicle
# + vehicleType - Filter :  type of the vehicle
# + 'limit - Limit of the response  
# + offset - Offset of the response
# + return - sql:ParameterizedQuery - Select query for the vehicles
isolated function fetchVehiclesQuery(string? owner, VehicleStatus? vehicleStatus, VehicleTypes? vehicleType,
        int? 'limit, int? offset) returns sql:ParameterizedQuery {

    sql:ParameterizedQuery mainQuery = `
        SELECT 
            vehicle_id as 'vehicleId',
            employee_email as 'owner',
            vehicle_registration_number as 'vehicleRegistrationNumber',
            vehicle_type as 'vehicleType',
            vehicle_status as 'vehicleStatus',
            DATE_FORMAT(created_on, '%Y-%m-%d %H:%i:%s') AS 'createdOn',
            created_by as createdBy,
            DATE_FORMAT(updated_on, '%Y-%m-%d %H:%i:%s') AS 'updatedOn',
            updated_by as updatedBy,
            COUNT(*) OVER() AS totalCount
        FROM vehicle
    `;

    // Setting the filters.
    sql:ParameterizedQuery[] filters = [];

    if owner is string {
        filters.push(` employee_email = ${owner}`);
    }

    if vehicleStatus is VehicleStatus {
        filters.push(` vehicle_status = ${vehicleStatus}`);
    }

    if vehicleType is VehicleTypes {
        filters.push(` vehicle_type = ${vehicleType}`);
    }

    // Building the WHERE clause.
    mainQuery = buildSqlSelectQuery(mainQuery, filters);

    // Sorting the result by created_on.
    mainQuery = sql:queryConcat(mainQuery, ` ORDER BY created_on DESC`);

    // Setting the limit and offset.
    if 'limit is int {
        mainQuery = sql:queryConcat(mainQuery, ` LIMIT ${'limit}`);
        if offset is int {
            mainQuery = sql:queryConcat(mainQuery, ` OFFSET ${offset}`);
        }
    } else {
        mainQuery = sql:queryConcat(mainQuery, ` LIMIT ${DEFAULT_LIMIT}`);
    }

    return mainQuery;
}

# Get owner email of a vehicle by id.
#
# + vehicleId - Vehicle ID
# + return - Query to get the owner email of the vehicle
isolated function getVehicleOwnerQuery(int vehicleId) returns sql:ParameterizedQuery =>
    `SELECT employee_email as 'owner' FROM vehicle
     WHERE vehicle_id = ${vehicleId} AND vehicle_status = 'ACTIVE'
     LIMIT 1`;

# Build query to persist a vehicle.
#
# + payload - Payload containing the vehicle details
# + return - sql:ParameterizedQuery - Insert query for the new vehicle
isolated function addVehicleQuery(AddVehiclePayload payload) returns sql:ParameterizedQuery
=> `
    INSERT INTO vehicle
    (
        employee_email,
        vehicle_registration_number,
        vehicle_type,
        vehicle_status,
        created_by,
        updated_by
    )
    VALUES
    (
        ${payload.owner},
        ${payload.vehicleRegistrationNumber},
        ${payload.vehicleType},
        ${payload.vehicleStatus},
        ${payload.createdBy},
        ${payload.createdBy}
    );
`;

# Build query to update the vehicle.
#
# + payload - Payload containing the vehicle details
# + return - sql:ParameterizedQuery - Update query for the specific vehicle
isolated function updateVehicleQuery(UpdateVehiclePayload payload) returns sql:ParameterizedQuery {
    UpdateVehiclePayload {vehicleId, vehicleStatus, updatedBy} = payload;

    sql:ParameterizedQuery mainQuery = `
        UPDATE 
            vehicle
        SET 
    `;

    sql:ParameterizedQuery subQuery = `
        WHERE vehicle_id = ${vehicleId}
    `;

    // Setting the updates based on the payload.
    sql:ParameterizedQuery[] filters = [];

    if vehicleStatus is VehicleStatus {
        filters.push(` vehicle_status = ${vehicleStatus}`);
    }

    // Setting the updated by.
    filters.push(` updated_by = ${updatedBy}`);

    mainQuery = buildSqlUpdateQuery(mainQuery, filters);

    return sql:queryConcat(mainQuery, subQuery);
}

# Get parking floors.
#
# + return - Query to get parking floors
isolated function getParkingFloorsQuery() returns sql:ParameterizedQuery =>
    `SELECT
        id,
        name,
        display_order as 'displayOrder',
        coins_per_slot as 'coinsPerSlot'
    FROM parking_floor
    WHERE is_active = 1
    ORDER BY display_order ASC, id ASC`;

# Get parking slots for a floor for a date.
#
# + floorId - Floor id
# + bookingDate - Booking date (YYYY-MM-DD)
# + pendingExpiryMinutes - Pending expiry duration in minutes
# + return - Query to get parking slots with isBooked
isolated function getParkingSlotsByFloorQuery(int floorId, string bookingDate, int pendingExpiryMinutes)
        returns sql:ParameterizedQuery =>
    `SELECT
        ps.slot_id as 'slotId',
        ps.floor_id as 'floorId',
        pf.name as 'floorName',
        pf.coins_per_slot as 'coinsPerSlot',
        (CASE WHEN EXISTS (
            SELECT 1 FROM parking_reservation pr
            WHERE pr.slot_id = ps.slot_id
              AND pr.booking_date = ${bookingDate}
              AND (
                pr.status = ${CONFIRMED}
                OR (pr.status = ${PENDING}
                    AND pr.created_on >= DATE_SUB(NOW(), INTERVAL ${pendingExpiryMinutes} MINUTE))
              )
        ) THEN 1 ELSE 0 END) as 'isBooked'
    FROM parking_slot ps
    INNER JOIN parking_floor pf ON ps.floor_id = pf.id
    WHERE ps.floor_id = ${floorId}
    ORDER BY ps.slot_id ASC
`;

# Get parking slot by id.
#
# + slotId - Slot id
# + return - Query to get parking slot
isolated function getParkingSlotByIdQuery(string slotId) returns sql:ParameterizedQuery =>
    `SELECT
        ps.slot_id as 'slotId',
        ps.floor_id as 'floorId',
        pf.name as 'floorName',
        pf.coins_per_slot as 'coinsPerSlot',
        0 as 'isBooked'
    FROM parking_slot ps
    INNER JOIN parking_floor pf ON ps.floor_id = pf.id
    WHERE ps.slot_id = ${slotId}`;

# Get active reservation id for slot and date (existence check).
#
# + slotId - Slot id
# + bookingDate - Booking date (YYYY-MM-DD)
# + pendingExpiryMinutes - Pending expiry duration in minutes
# + return - Query to get reservation id if slot is unavailable
isolated function getActiveParkingReservationForSlotDateQuery(string slotId, string bookingDate,
        int pendingExpiryMinutes)
    returns sql:ParameterizedQuery =>
    `SELECT id
    FROM parking_reservation
    WHERE slot_id = ${slotId}
      AND booking_date = ${bookingDate}
      AND (
        status = ${CONFIRMED}
        OR (status = ${PENDING}
            AND created_on >= DATE_SUB(NOW(), INTERVAL ${pendingExpiryMinutes} MINUTE))
      )
    LIMIT 1`;

# Expire stale pending reservations (PENDING -> EXPIRED) for slot/date.
#
# + slotId - Slot id
# + bookingDate - Booking date (YYYY-MM-DD)
# + expiryMinutes - Expiry duration in minutes
# + return - Query to mark stale pending reservation as EXPIRED
isolated function expireStalePendingParkingReservationForSlotDateQuery(string slotId, string bookingDate,
        int expiryMinutes) returns sql:ParameterizedQuery =>
    `UPDATE parking_reservation
    SET status = ${EXPIRED}
    WHERE slot_id = ${slotId}
      AND booking_date = ${bookingDate}
      AND status = ${PENDING}
      AND created_on < DATE_SUB(NOW(), INTERVAL ${expiryMinutes} MINUTE)`;

# Get the caller's active reservation for a date (existence + reuse check).
#
# + employeeEmail - Employee email
# + bookingDate - Booking date (YYYY-MM-DD)
# + pendingExpiryMinutes - Pending expiry duration in minutes
# + return - Query to get the employee's active reservation for the date
isolated function getActiveParkingReservationForEmployeeDateQuery(string employeeEmail, string bookingDate,
        int pendingExpiryMinutes) returns sql:ParameterizedQuery =>
    `SELECT
        id,
        slot_id as 'slotId',
        vehicle_id as 'vehicleId',
        status,
        coins_amount as 'coinsAmount'
    FROM parking_reservation
    WHERE employee_email = ${employeeEmail}
      AND booking_date = ${bookingDate}
      AND (
        status = ${CONFIRMED}
        OR (status = ${PENDING}
            AND created_on >= DATE_SUB(NOW(), INTERVAL ${pendingExpiryMinutes} MINUTE))
      )
    LIMIT 1`;

# Expire the caller's stale pending reservations (PENDING -> EXPIRED) for a date (any slot).
#
# + employeeEmail - Employee email
# + bookingDate - Booking date (YYYY-MM-DD)
# + expiryMinutes - Expiry duration in minutes
# + return - Query to mark the employee's stale pending reservations as EXPIRED
isolated function expireStalePendingParkingReservationsForEmployeeDateQuery(string employeeEmail, string bookingDate,
        int expiryMinutes) returns sql:ParameterizedQuery =>
    `UPDATE parking_reservation
    SET status = ${EXPIRED}
    WHERE employee_email = ${employeeEmail}
      AND booking_date = ${bookingDate}
      AND status = ${PENDING}
      AND created_on < DATE_SUB(NOW(), INTERVAL ${expiryMinutes} MINUTE)`;

# Update the vehicle on a parking reservation.
#
# + reservationId - Reservation id
# + vehicleId - Registered vehicle id to set
# + updatedBy - User performing the update
# + return - Query to update the reservation's vehicle
isolated function updateParkingReservationVehicleQuery(int reservationId, int vehicleId, string updatedBy)
        returns sql:ParameterizedQuery =>
    `UPDATE parking_reservation
    SET vehicle_id = ${vehicleId}, updated_by = ${updatedBy}
    WHERE id = ${reservationId}`;

# Insert parking reservation (PENDING).
#
# + payload - Reservation payload
# + return - Query to insert parking reservation
isolated function addParkingReservationQuery(AddParkingReservationPayload payload) returns sql:ParameterizedQuery =>
    `
    INSERT INTO parking_reservation
    (
        slot_id, 
        booking_date, 
        employee_email, 
        vehicle_id,
        status,
        coins_amount,
        transaction_hash,
        created_by,
        updated_by
    )
    VALUES
    (
        ${payload.slotId},
        ${payload.bookingDate},
        ${payload.employeeEmail},
        ${payload.vehicleId},
        ${PENDING},
        ${payload.coinsAmount},
        ${payload.transactionHash},
        ${payload.createdBy},
        ${payload.createdBy}
    );
`;

# Get parking reservation by id.
#
# + reservationId - Reservation id
# + return - Query to get reservation details
isolated function getParkingReservationByIdQuery(int reservationId) returns sql:ParameterizedQuery =>
    `SELECT
        pr.id,
        pr.slot_id as 'slotId',
        pr.booking_date as 'bookingDate',
        pr.employee_email as 'employeeEmail',
        pr.vehicle_id as 'vehicleId',
        v.vehicle_registration_number as 'vehicleRegistrationNumber',
        v.vehicle_type as 'vehicleType',
        pr.status,
        pr.transaction_hash as 'paymentReference',
        pr.coins_amount as 'coinsAmount',
        pf.name as 'floorName',
        DATE_FORMAT(pr.created_on, '%Y-%m-%d %H:%i:%s') AS 'createdOn',
        pr.created_by as 'createdBy',
        DATE_FORMAT(pr.updated_on, '%Y-%m-%d %H:%i:%s') AS 'updatedOn',
        pr.updated_by as 'updatedBy'
    FROM parking_reservation pr
    INNER JOIN parking_slot ps ON pr.slot_id = ps.slot_id
    INNER JOIN parking_floor pf ON ps.floor_id = pf.id
    INNER JOIN vehicle v ON pr.vehicle_id = v.vehicle_id
    WHERE pr.id = ${reservationId}`;

# Atomically confirm a pending parking reservation (PENDING -> CONFIRMED).
#
# + reservationId - Reservation id
# + paymentReference - Payment reference to persist
# + updatedBy - User performing the confirmation
# + return - Query that transitions the reservation only while it is still PENDING
isolated function confirmParkingReservationQuery(int reservationId, string paymentReference, string updatedBy)
    returns sql:ParameterizedQuery =>
    `UPDATE parking_reservation
        SET status = ${CONFIRMED}, transaction_hash = ${paymentReference}, updated_by = ${updatedBy}
        WHERE id = ${reservationId} AND status = ${PENDING}`;

# Get parking reservations by employee.
#
# + employeeEmail - Employee email
# + fromDate - From date (optional)
# + toDate - To date (optional)
# + return - Query to get reservations
isolated function getParkingReservationsByEmployeeQuery(string employeeEmail, string? fromDate, string? toDate)
    returns sql:ParameterizedQuery {

    sql:ParameterizedQuery mainQuery = `
    SELECT
        pr.id,
        pr.slot_id as 'slotId',
        pr.booking_date as 'bookingDate',
        pr.employee_email as 'employeeEmail',
        pr.vehicle_id as 'vehicleId',
        v.vehicle_registration_number as 'vehicleRegistrationNumber',
        v.vehicle_type as 'vehicleType',
        pr.status,
        pr.transaction_hash as 'paymentReference',
        pr.coins_amount as 'coinsAmount',
        pf.name as 'floorName',
        DATE_FORMAT(pr.created_on, '%Y-%m-%d %H:%i:%s') AS 'createdOn',
        pr.created_by as 'createdBy',
        DATE_FORMAT(pr.updated_on, '%Y-%m-%d %H:%i:%s') AS 'updatedOn',
        pr.updated_by as 'updatedBy'
    FROM parking_reservation pr
    INNER JOIN parking_slot ps ON pr.slot_id = ps.slot_id
    INNER JOIN parking_floor pf ON ps.floor_id = pf.id
    INNER JOIN vehicle v ON pr.vehicle_id = v.vehicle_id`;

    sql:ParameterizedQuery[] filters = [` pr.employee_email = ${employeeEmail}`];

    if fromDate is string {
        filters.push(` pr.booking_date >= ${fromDate}`);
    }
    if toDate is string {
        filters.push(` pr.booking_date <= ${toDate}`);
    }

    mainQuery = buildSqlSelectQuery(mainQuery, filters);

    return sql:queryConcat(mainQuery, ` ORDER BY pr.booking_date DESC, pr.created_on DESC`);
}

# Fetch a mapping of work email to full name for all employees.
#
# + return - Parameterized query returning work_email and full_name columns
isolated function getEmployeeEmailToNameMapQuery() returns sql:ParameterizedQuery =>
    `SELECT work_email, CONCAT(first_name, ' ', last_name) AS full_name FROM employee;`;

# Count active employees and new joiners in a business unit.
#
# + id - Business unit ID
# + return - Query counting active employees and new joiners with business_unit_id = id
isolated function countActiveEmployeesInBusinessUnitQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) AS count FROM employee WHERE business_unit_id = ${id} AND employee_status IN ('Active', 'New joiner')`;

# Count active employees and new joiners in a business-unit–team mapping.
#
# + id - business_unit_team mapping ID
# + return - Query counting active employees and new joiners matching that BU+Team combination
isolated function countActiveEmployeesInBUTeamMappingQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) AS count FROM employee e
     JOIN business_unit_team but ON but.id = ${id}
     WHERE e.business_unit_id = but.business_unit_id AND e.team_id = but.team_id AND e.employee_status IN ('Active', 'New joiner')`;

# Count active employees and new joiners in a business-unit–team–sub-team mapping.
#
# + id - business_unit_team_sub_team mapping ID
# + return - Query counting active employees and new joiners matching that BU+Team+SubTeam combination
isolated function countActiveEmployeesInBUTeamSubTeamMappingQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) AS count FROM employee e
     JOIN business_unit_team_sub_team butst ON butst.id = ${id}
     JOIN business_unit_team but ON but.id = butst.business_unit_team_id
     WHERE e.business_unit_id = but.business_unit_id AND e.team_id = but.team_id
       AND e.sub_team_id = butst.sub_team_id AND e.employee_status IN ('Active', 'New joiner')`;

# Count active employees and new joiners in a business-unit–team–sub-team–unit mapping.
#
# + id - business_unit_team_sub_team_unit mapping ID
# + return - Query counting active employees and new joiners matching that BU+Team+SubTeam+Unit combination
isolated function countActiveEmployeesInBUTeamSubTeamUnitMappingQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) AS count FROM employee e
     JOIN business_unit_team_sub_team_unit butstu ON butstu.id = ${id}
     JOIN business_unit_team_sub_team butst ON butst.id = butstu.business_unit_team_sub_team_id
     JOIN business_unit_team but ON but.id = butst.business_unit_team_id
     WHERE e.business_unit_id = but.business_unit_id AND e.team_id = but.team_id
       AND e.sub_team_id = butst.sub_team_id AND e.unit_id = butstu.unit_id AND e.employee_status IN ('Active', 'New joiner')`;

# Count active employees and new joiners in a team.
#
# + id - Team ID
# + return - Query counting active employees and new joiners with team_id = id
isolated function countActiveEmployeesInTeamQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) AS count FROM employee WHERE team_id = ${id} AND employee_status IN ('Active', 'New joiner')`;

# Count active employees and new joiners in a sub-team.
#
# + id - Sub-team ID
# + return - Query counting active employees and new joiners with sub_team_id = id
isolated function countActiveEmployeesInSubTeamQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) AS count FROM employee WHERE sub_team_id = ${id} AND employee_status IN ('Active', 'New joiner')`;

# Count active employees and new joiners in a unit.
#
# + id - Unit ID
# + return - Query counting active employees and new joiners with unit_id = id
isolated function countActiveEmployeesInUnitQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT COUNT(*) AS count FROM employee WHERE unit_id = ${id} AND employee_status IN ('Active', 'New joiner')`;

# Delete an employee record.
#
# + employeeId - Employee ID string
# + return - Parameterized query to delete an employee
isolated function deleteEmployeeQuery(string employeeId) returns sql:ParameterizedQuery =>
    `DELETE FROM employee WHERE employee_id = ${employeeId};`;

# Delete a personal info record.
#
# + personalInfoId - Primary key of the personal_info row
# + return - Parameterized query to delete a personal info record
isolated function deletePersonalInfoQuery(int personalInfoId) returns sql:ParameterizedQuery =>
    `DELETE FROM personal_info WHERE id = ${personalInfoId};`;

# Delete employee audit rows for an employee.
#
# + employeePkId - Primary key of the employee row
# + return - Parameterized query to delete employee audit rows
isolated function deleteEmployeeAuditQuery(int employeePkId) returns sql:ParameterizedQuery =>
    `DELETE FROM employee_audit WHERE employee_pk_id = ${employeePkId};`;

# Delete additional managers audit rows for an employee.
#
# + employeePkId - Primary key of the employee row
# + return - Parameterized query to delete additional managers audit rows
isolated function deleteEmployeeAdditionalManagersAuditQuery(int employeePkId) returns sql:ParameterizedQuery =>
    `DELETE FROM employee_additional_managers_audit WHERE employee_pk_id = ${employeePkId};`;

# Delete leadership attribute audit rows for an employee.
#
# + employeePkId - Primary key of the employee row
# + return - Parameterized query to delete leadership attribute audit rows
isolated function deleteEmployeeLeadershipAuditQuery(int employeePkId) returns sql:ParameterizedQuery =>
    `DELETE FROM employee_leadership_audit WHERE employee_pk_id = ${employeePkId};`;

# Delete emergency contacts audit rows for a personal info record.
#
# + personalInfoId - Primary key of the personal_info row
# + return - Parameterized query to delete emergency contacts audit rows
isolated function deleteEmployeeEmergencyContactsAuditQuery(int personalInfoId) returns sql:ParameterizedQuery =>
    `DELETE FROM personal_info_emergency_contacts_audit WHERE personal_info_id = ${personalInfoId};`;

# Delete personal info audit rows for a personal info record.
#
# + personalInfoId - Primary key of the personal_info row
# + return - Parameterized query to delete personal info audit rows
isolated function deletePersonalInfoAuditQuery(int personalInfoId) returns sql:ParameterizedQuery =>
    `DELETE FROM personal_info_audit WHERE personal_info_pk_id = ${personalInfoId};`;

# Resolve the person behind a work email.
#
# A person may hold several employee rows over time (a rehire issues a new employee ID while
# reusing the same work email), so this deliberately returns the personal_info_id rather than an
# employee ID.
#
# Those rows do NOT always share one personal_info_id — historical stints were migrated in with
# their own personal_info rows — so LIMIT 1 must pick deliberately rather than arbitrarily. It
# resolves to the latest employment (newest start date), matching the record the caller is
# identified by elsewhere; `id` is only a tiebreaker, as it does not track chronology.
#
# + workEmail - Work email of the person
# + return - Parameterized query returning the person's personal_info_id
isolated function getPersonalInfoIdByWorkEmailQuery(string workEmail) returns sql:ParameterizedQuery =>
    `SELECT personal_info_id FROM employee WHERE work_email = ${workEmail}
     ORDER BY start_date DESC, id DESC LIMIT 1;`;

# Resolve the person behind an employee ID.
#
# + employeeId - Employee ID of any one of the person's employment records
# + return - Parameterized query returning the person's personal_info_id
isolated function getPersonalInfoIdByEmployeeIdQuery(string employeeId) returns sql:ParameterizedQuery =>
    `SELECT personal_info_id FROM employee WHERE employee_id = ${employeeId} LIMIT 1;`;

# All employment periods for the person behind an employee ID.
#
# + employeeId - Employee ID of any one of the person's employment records
# + return - Parameterized query returning every employment period, newest first
isolated function getEmploymentPeriodsQuery(string employeeId) returns sql:ParameterizedQuery =>
    `SELECT
        e.id AS id,
        e.employee_id AS employeeId,
        et.name AS employmentType,
        e.start_date AS startDate,
        r.final_day_of_employment AS endDate,
        e.work_email AS workEmail,
        csr.employee_id AS continuousServiceRecord
    FROM employee e
        JOIN employment_type et ON et.id = e.employment_type_id
        LEFT JOIN resignation r ON r.employee_id = e.id
        LEFT JOIN employee csr ON csr.id = e.continuous_service_record
    WHERE e.id IN (
        WITH RECURSIVE anchor AS (
            SELECT id, personal_info_id, continuous_service_record
            FROM employee WHERE employee_id = ${employeeId}
        ),
        -- Walk backwards: each row points at the employment that preceded it.
        earlier AS (
            SELECT id, continuous_service_record FROM anchor
            UNION
            SELECT e2.id, e2.continuous_service_record
            FROM employee e2 JOIN earlier ON e2.id = earlier.continuous_service_record
        ),
        -- Walk forwards: find rows pointing back at anything already collected.
        later AS (
            SELECT id FROM anchor
            UNION
            SELECT e3.id
            FROM employee e3 JOIN later ON e3.continuous_service_record = later.id
        )
        SELECT id FROM earlier
        UNION SELECT id FROM later
        -- Rehires where the identity record does match are still picked up here.
        UNION SELECT e4.id FROM employee e4
            JOIN anchor ON e4.personal_info_id = anchor.personal_info_id
    )
    ORDER BY e.start_date DESC`;

# Fetch audit snapshots from the employee_audit table for a set of employee rows.
#
# + employeePkIds - Employee table primary keys belonging to the person
# + return - Parameterized query returning employee_audit rows tagged with their source table
isolated function getEmployeeAuditSnapshotsQuery(int[] employeePkIds) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery inClause = buildIntInClause(employeePkIds);
    return sql:queryConcat(
            `SELECT
                employee_pk_id AS employeePkId,
                'employee_audit' AS sourceTable,
                action_type AS actionType,
                action_by AS actionBy,
                action_on AS actionOn,
                data AS data
            FROM employee_audit
            WHERE employee_pk_id IN (`,
            inClause,
            `)
            ORDER BY action_on ASC`
    );
}

# Fetch audit snapshots from the employee_additional_managers_audit table for a set of employee rows.
#
# + employeePkIds - Employee table primary keys belonging to the person
# + return - Parameterized query returning employee_additional_managers_audit rows tagged with their source table
isolated function getEmployeeAdditionalManagersAuditSnapshotsQuery(int[] employeePkIds)
    returns sql:ParameterizedQuery {
    sql:ParameterizedQuery inClause = buildIntInClause(employeePkIds);
    return sql:queryConcat(
            `SELECT
                employee_pk_id AS employeePkId,
                'employee_additional_managers_audit' AS sourceTable,
                action_type AS actionType,
                action_by AS actionBy,
                action_on AS actionOn,
                data AS data
            FROM employee_additional_managers_audit
            WHERE employee_pk_id IN (`,
            inClause,
            `)
            ORDER BY action_on ASC`
    );
}

# Fetch audit snapshots from the employee_leadership_audit table for a set of employee rows.
#
# + employeePkIds - Employee table primary keys belonging to the person
# + return - Parameterized query returning employee_leadership_audit rows tagged with their source table
isolated function getEmployeeLeadershipAuditSnapshotsQuery(int[] employeePkIds)
    returns sql:ParameterizedQuery {
    sql:ParameterizedQuery inClause = buildIntInClause(employeePkIds);
    return sql:queryConcat(
            `SELECT
                employee_pk_id AS employeePkId,
                'employee_leadership_audit' AS sourceTable,
                action_type AS actionType,
                action_by AS actionBy,
                action_on AS actionOn,
                data AS data
            FROM employee_leadership_audit
            WHERE employee_pk_id IN (`,
            inClause,
            `)
            ORDER BY action_on ASC`
    );
}

# Fetch audit snapshots from the resignation_audit table for a set of employee rows.
#
# resignation keys on employee_id, so its audit keys on employee_pk_id exactly as employee_audit does
# and needs none of the anchor-row indirection personal_info_audit requires.
#
# + employeePkIds - Employee table primary keys belonging to the person
# + return - Parameterized query returning resignation_audit rows tagged with their source table
isolated function getResignationAuditSnapshotsQuery(int[] employeePkIds) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery inClause = buildIntInClause(employeePkIds);
    return sql:queryConcat(
            `SELECT
                employee_pk_id AS employeePkId,
                'resignation_audit' AS sourceTable,
                action_type AS actionType,
                action_by AS actionBy,
                action_on AS actionOn,
                data AS data
            FROM resignation_audit
            WHERE employee_pk_id IN (`,
            inClause,
            `)
            ORDER BY action_on ASC`
    );
}

# Fetch audit snapshots from the personal_info_audit table for the person behind a set of employee rows.
#
# personal_info_audit keys on personal_info_pk_id, not employee_pk_id. All employee rows belonging to one
# person share the same personal_info_id, so it is resolved once from any single employee primary key in
# the set (the first one) rather than joined against the whole set, which would otherwise multiply rows.
#
# + employeePkIds - Employee table primary keys belonging to the person
# + return - Parameterized query returning personal_info_audit rows tagged with their source table; each
# row's employeePkId is the resolving employee primary key, not necessarily the one active at that time
isolated function getPersonalInfoAuditSnapshotsQuery(int[] employeePkIds) returns sql:ParameterizedQuery {
    int anchorEmployeePkId = employeePkIds[0];
    return `SELECT
                ${anchorEmployeePkId} AS employeePkId,
                'personal_info_audit' AS sourceTable,
                pia.action_type AS actionType,
                pia.action_by AS actionBy,
                pia.action_on AS actionOn,
                pia.data AS data
            FROM personal_info_audit pia
            WHERE pia.personal_info_pk_id = (
                SELECT personal_info_id FROM employee WHERE id = ${anchorEmployeePkId}
            )
            ORDER BY pia.action_on ASC`;
}

# Every id-to-name mapping needed to render history events, in one query.
#
# Audit snapshots store foreign keys (`unit_id`, `designation_id`, ...), which are
# meaningless to a reader. This resolves them in a single round trip rather than one
# query per lookup table. `designation` names its column `designation`; every other
# lookup table uses `name`.
#
# Every string is given an explicit COLLATE. The lookup tables do not agree among
# themselves — `house.name` is utf8mb4_unicode_ci while the rest are utf8mb4_0900_ai_ci —
# and the literals would otherwise take the connection default, so a bare UNION fails with
# "Illegal mix of collations" (MySQL 1271).
#
# + return - Parameterized query returning (field, id, name) rows
isolated function getHistoryLookupNamesQuery() returns sql:ParameterizedQuery =>
    `SELECT 'business_unit_id' COLLATE utf8mb4_general_ci AS field,
            id, name COLLATE utf8mb4_general_ci AS name FROM business_unit
     UNION ALL SELECT 'team_id' COLLATE utf8mb4_general_ci,
            id, name COLLATE utf8mb4_general_ci FROM team
     UNION ALL SELECT 'sub_team_id' COLLATE utf8mb4_general_ci,
            id, name COLLATE utf8mb4_general_ci FROM sub_team
     UNION ALL SELECT 'unit_id' COLLATE utf8mb4_general_ci,
            id, name COLLATE utf8mb4_general_ci FROM unit
     UNION ALL SELECT 'designation_id' COLLATE utf8mb4_general_ci,
            id, designation COLLATE utf8mb4_general_ci FROM designation
     UNION ALL SELECT 'employment_type_id' COLLATE utf8mb4_general_ci,
            id, name COLLATE utf8mb4_general_ci FROM employment_type
     UNION ALL SELECT 'company_id' COLLATE utf8mb4_general_ci,
            id, name COLLATE utf8mb4_general_ci FROM company
     UNION ALL SELECT 'office_id' COLLATE utf8mb4_general_ci,
            id, name COLLATE utf8mb4_general_ci FROM office
     UNION ALL SELECT 'house_id' COLLATE utf8mb4_general_ci,
            id, name COLLATE utf8mb4_general_ci FROM house
     UNION ALL SELECT 'leadership_group' COLLATE utf8mb4_general_ci,
            id, name COLLATE utf8mb4_general_ci FROM leadership_group`;

# Whether an employee ID names the person's current (most recent) employment.
#
# `manager_email` is never cleared when an employment ends, so an old row keeps naming a
# former manager forever. Any check built on that column therefore has to be paired with a
# currency test, or a former lead retains access to a person they no longer manage.
#
# + employeeId - Employee ID to test
# + return - Parameterized query returning 1 when this is the person's latest employment
isolated function isCurrentEmploymentQuery(string employeeId) returns sql:ParameterizedQuery =>
    `SELECT 1 FROM employee target
     WHERE target.employee_id = ${employeeId}
        AND target.id = (
            -- Resolved through the same chain the history itself walks, not through
            -- personal_info_id. A person's employments can hold different personal_info rows
            -- (one NIC recorded several ways), in which case every row would look "latest"
            -- within its own group of one and the check would pass for all of them.
            WITH RECURSIVE anchor AS (
                SELECT id, personal_info_id, continuous_service_record
                FROM employee WHERE employee_id = ${employeeId}
            ),
            earlier AS (
                SELECT id, continuous_service_record FROM anchor
                UNION
                SELECT e2.id, e2.continuous_service_record
                FROM employee e2 JOIN earlier ON e2.id = earlier.continuous_service_record
            ),
            later AS (
                SELECT id FROM anchor
                UNION
                SELECT e3.id FROM employee e3 JOIN later ON e3.continuous_service_record = later.id
            ),
            whole_person AS (
                SELECT id FROM earlier
                UNION SELECT id FROM later
                UNION SELECT e4.id FROM employee e4
                    JOIN anchor ON e4.personal_info_id = anchor.personal_info_id
            )
            SELECT latest.id FROM employee latest
            JOIN whole_person ON whole_person.id = latest.id
            ORDER BY latest.start_date DESC, latest.id DESC
            LIMIT 1
        )
     LIMIT 1;`;

# Insert a scheduled change.
#
# + employeeId - Employee table primary key
# + payload - Effective date and the fields to change
# + expected - What those fields hold now, for the supersede check on the day
# + createdBy - Email of the person scheduling the change
# + return - Parameterized insert query
isolated function insertScheduledChangeQuery(int employeeId, string effectiveDate,
        string columnChanges, string expected, string createdBy) returns sql:ParameterizedQuery =>
    `INSERT INTO scheduled_employee_change
            (employee_id, effective_date, changes, expected, created_by, updated_by)
        VALUES (${employeeId}, ${effectiveDate}, ${columnChanges}, ${expected},
            ${createdBy}, ${createdBy})`;

# Fetch the scheduled changes for one employee, newest first.
#
# + employeeId - Employee table primary key
# + pendingOnly - Limit to changes still waiting for their date
# + return - Parameterized query returning the rows, with the employee's identifier
isolated function getScheduledChangesQuery(int employeeId, boolean pendingOnly)
    returns sql:ParameterizedQuery {
    sql:ParameterizedQuery base = `SELECT
            sc.id,
            sc.employee_id AS employeeId,
            e.employee_id AS employeeIdentifier,
            DATE_FORMAT(sc.effective_date, '%Y-%m-%d') AS effectiveDate,
            sc.changes,
            sc.expected,
            sc.status,
            DATE_FORMAT(sc.applied_on, '%Y-%m-%d %H:%i:%s') AS appliedOn,
            sc.failure_reason AS failureReason,
            sc.created_by AS createdBy,
            DATE_FORMAT(sc.created_on, '%Y-%m-%d %H:%i:%s') AS createdOn
        FROM scheduled_employee_change sc
        JOIN employee e ON e.id = sc.employee_id
        WHERE sc.employee_id = ${employeeId}`;
    sql:ParameterizedQuery pending = ` AND sc.status = 'PENDING'`;
    sql:ParameterizedQuery ordering = ` ORDER BY sc.effective_date ASC, sc.id ASC`;
    return pendingOnly
        ? sql:queryConcat(base, pending, ordering)
        : sql:queryConcat(base, ordering);
}

# Fetch one scheduled change by id.
#
# + id - Scheduled change id
# + return - Parameterized query returning the row, with the employee's identifier
isolated function getScheduledChangeByIdQuery(int id) returns sql:ParameterizedQuery =>
    `SELECT
        sc.id,
        sc.employee_id AS employeeId,
        e.employee_id AS employeeIdentifier,
        DATE_FORMAT(sc.effective_date, '%Y-%m-%d') AS effectiveDate,
        sc.changes,
        sc.expected,
        sc.status,
        DATE_FORMAT(sc.applied_on, '%Y-%m-%d %H:%i:%s') AS appliedOn,
        sc.failure_reason AS failureReason,
        sc.created_by AS createdBy,
        DATE_FORMAT(sc.created_on, '%Y-%m-%d %H:%i:%s') AS createdOn
    FROM scheduled_employee_change sc
    JOIN employee e ON e.id = sc.employee_id
    WHERE sc.id = ${id}`;


# Move a scheduled change out of PENDING.
#
# + id - Scheduled change id
# + status - Status to record
# + failureReason - Why it was not applied, where that applies
# + updatedBy - Who or what closed the row out
# + return - Parameterized update query
isolated function updateScheduledChangeStatusQuery(int id, string status, string? failureReason,
        string updatedBy) returns sql:ParameterizedQuery =>
    `UPDATE scheduled_employee_change
     SET status = ${status},
         applied_on = CASE WHEN ${status} = 'APPLIED' THEN CURRENT_TIMESTAMP(6) ELSE applied_on END,
         failure_reason = ${failureReason},
         updated_by = ${updatedBy}
     WHERE id = ${id} AND status = 'PENDING'`;

# Fetch the house from a returning employee's most recent previous employment.
#
# The most recent employment only, ordered by start date and then by id for two starting
# the same day. It is not searched backwards for one that happens to carry a house: the
# house someone should return to is the one from where they last were, and reaching past
# that into an older employment would hand them an affiliation they may have left behind
# several roles ago. Where the latest employment has no house, the caller falls back to
# deriving one from the employee ID.
#
# The house is joined rather than read directly, and the join carries `is_active = 1`, so a
# house that has since been retired reads as absent and takes the same fallback. Houses are
# soft-deleted, so matching on id alone would keep resolving one and hand the returning
# employee a house the House dropdown no longer offers.
#
# + workEmail - Work email of the employee being onboarded
# + return - Parameterized query returning the previous house id, if there is one
isolated function getPreviousHouseIdQuery(string workEmail) returns sql:ParameterizedQuery =>
    `SELECT h.id AS houseId
     FROM employee e
     LEFT JOIN house h ON h.id = e.house_id AND h.is_active = 1
     WHERE e.work_email = ${workEmail}
     ORDER BY e.start_date DESC, e.id DESC
     LIMIT 1`;

# Fetch the house from the most recent employment of the person behind a NIC/Passport.
#
# The same rules as getPreviousHouseIdQuery, matched on the person rather than the work email,
# so a returning employee is recognised even when their email has changed or is a placeholder.
#
# + nicOrPassport - NIC/Passport of the employee being onboarded
# + return - Parameterized query returning the previous house id, if there is one
isolated function getPreviousHouseIdByNicQuery(string nicOrPassport) returns sql:ParameterizedQuery =>
    `SELECT h.id AS houseId
     FROM employee e
     INNER JOIN personal_info p ON p.id = e.personal_info_id
     LEFT JOIN house h ON h.id = e.house_id AND h.is_active = 1
     WHERE p.nic_or_passport = ${nicOrPassport}
     ORDER BY e.start_date DESC, e.id DESC
     LIMIT 1`;
