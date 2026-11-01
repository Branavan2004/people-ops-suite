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

# Get an employee's name and current lead from the HR entity service.
#
# + email - Work email of the employee
# + return - The employee, or an error if the lookup failed or no employee has that email
public isolated function getEmployee(string email) returns Employee|error {
    string document = string `
        query getEmployee($email: String!) {
            employee(email: $email) {
                firstName
                lastName
                managerEmail
            }
        }
    `;

    SingleEmployeeResponse response = check hrClient->execute(document, {email});
    Employee? employee = response.data.employee;
    if employee is () {
        return error(string `Employee not found: ${email}`);
    }
    return employee;
}

# Full name of an employee, for the email body.
#
# + employee - Employee from the HR entity service
# + fallback - Value to use when the employee has no first name on record
# + return - Full name, or the fallback
public isolated function fullName(Employee employee, string fallback) returns string {
    string? firstName = employee.firstName;
    if firstName is () || firstName.trim() == "" {
        return fallback;
    }
    string? lastName = employee.lastName;
    return lastName is string && lastName.trim() != "" ? string `${firstName} ${lastName}` : firstName;
}

# First name of an employee, for the email greeting.
#
# + employee - Employee from the HR entity service
# + fallback - Value to use when the employee has no first name on record
# + return - First name, or the fallback
public isolated function firstName(Employee employee, string fallback) returns string {
    string? firstName = employee.firstName;
    return firstName is string && firstName.trim() != "" ? firstName : fallback;
}

# Current lead of an employee, as recorded in the HR entity service.
#
# + employee - Employee from the HR entity service
# + return - The lead's work email, or nil when none is recorded
public isolated function leadEmail(Employee employee) returns string? {
    string? managerEmail = employee.managerEmail;
    return managerEmail is string && managerEmail.trim() != "" ? managerEmail.trim() : ();
}
