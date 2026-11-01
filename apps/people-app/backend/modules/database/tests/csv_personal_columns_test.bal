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

import ballerina/test;

# An employee carrying every personal field, used to prove the report CSV reaches them.
#
# + return - Employee record with every personal field populated
isolated function personalFieldEmployee() returns Employee => {
    employeeId: "LK999999",
    firstName: "Test",
    lastName: "Employee",
    workEmail: "employee@example.invalid",
    employeeThumbnail: (),
    epf: "9999",
    company: "Example Company",
    companyId: 1,
    workLocation: "Testland",
    startDate: "2021-01-01",
    managerEmail: "lead@example.invalid",
    employeeStatus: "Active",
    employmentType: "Example Employment Type",
    employmentTypeId: 1,
    careerFunctionId: 1,
    designation: "Example Designation",
    designationId: 1,
    businessUnit: "Example Business Unit",
    businessUnitId: 1,
    team: "Example Team",
    teamId: 1,
    subordinateCount: 0,
    additionalManagerEmails: (),
    agreementEndDate: (),
    continuousServiceDate: (),
    continuousServiceRecord: (),
    externalDesignation: (),
    finalDayInOffice: (),
    finalDayOfEmployment: (),
    house: (),
    houseId: (),
    jobBand: (),
    jobRole: (),
    managerName: (),
    office: (),
    officeId: (),
    probationEndDate: (),
    resignationDate: (),
    resignationReason: (),
    secondaryJobTitle: (),
    subTeam: (),
    subTeamId: (),
    unit: (),
    unitId: (),
    gender: "Male",
    nicOrPassport: "NIC-TEST-0001",
    dateOfBirth: "1900-01-01",
    nationality: "Testlandish",
    personalEmail: "personal@example.invalid",
    personalPhone: "PHONE-0000001",
    residentNumber: "RESIDENT-0001",
    addressLine1: "1 Example Street",
    addressLine2: "Example Lane",
    city: "Exampleton",
    stateOrProvince: "Example Province",
    postalCode: "00000",
    country: "Testland",
    emergencyContacts: "Contact One - Parent - PHONE-0000002; Contact Two - Sibling - PHONE-0000003"
};

# The personal column keys, paired with the value each should carry into the CSV.
#
# + return - Map of personal column key to the value it should carry in the CSV
isolated function personalExpectations() returns map<string> => {
    "nicOrPassport": "NIC-TEST-0001",
    "dateOfBirth": "1900-01-01",
    "nationality": "Testlandish",
    "personalEmail": "personal@example.invalid",
    "personalPhone": "PHONE-0000001",
    "residentNumber": "RESIDENT-0001",
    "addressLine1": "1 Example Street",
    "addressLine2": "Example Lane",
    "city": "Exampleton",
    "stateOrProvince": "Example Province",
    "postalCode": "00000",
    "country": "Testland",
    "emergencyContacts": "Contact One - Parent - PHONE-0000002; Contact Two - Sibling - PHONE-0000003"
};

@test:Config {}
isolated function testEmployeeCsvIncludesPersonalColumnsWhenRequested() {
    map<string> expected = personalExpectations();
    string[] keys = expected.keys();
    string csv = buildEmployeeCsv([personalFieldEmployee()], {}, keys, []);

    foreach string key in keys {
        string value = expected.get(key);
        test:assertTrue(csv.includes(value),
                string `active-employee CSV is missing the value for '${key}': ${value}`);
    }
}

@test:Config {}
isolated function testResignationCsvIncludesPersonalColumnsWhenRequested() {
    map<string> expected = personalExpectations();
    string[] keys = expected.keys();
    string csv = buildResignationCsv([personalFieldEmployee()], {}, keys, []);

    foreach string key in keys {
        string value = expected.get(key);
        test:assertTrue(csv.includes(value),
                string `resignation CSV is missing the value for '${key}': ${value}`);
    }
}

@test:Config {}
isolated function testPersonalColumnsAreAbsentUnlessRequested() {
    // The default export must stay free of personal data: passing no column allowlist
    // still yields every column, so a caller that asks for nothing gets everything —
    // it is the frontend's default selection that omits them. Asking for a single
    // non-personal column must not smuggle personal values in.
    string csv = buildEmployeeCsv([personalFieldEmployee()], {}, ["employeeId"], []);

    test:assertFalse(csv.includes("NIC-TEST-0001"), "NIC leaked into a CSV that did not request it");
    test:assertFalse(csv.includes("personal@example.invalid"),
            "personal email leaked into a CSV that did not request it");
    test:assertTrue(csv.includes("LK999999"), "requested employeeId column is missing");
}

@test:Config {}
isolated function testPersonalColumnHeadersAreLabelled() {
    string csv = buildEmployeeCsv([personalFieldEmployee()], {},
            ["nicOrPassport", "dateOfBirth", "emergencyContacts"], []);

    test:assertTrue(csv.includes("NIC/Passport"), "NIC/Passport header missing");
    test:assertTrue(csv.includes("Date of Birth"), "Date of Birth header missing");
    test:assertTrue(csv.includes("Emergency Contacts"), "Emergency Contacts header missing");
}
