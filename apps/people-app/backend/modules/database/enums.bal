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

# [Database] Enum for vehicle types.
public enum VehicleTypes {
    CAR,
    MOTORCYCLE
}

# [Database] Enum for vehicle statuses.
public enum VehicleStatus {
    ACTIVE,
    INACTIVE
}

# [Database] Enum for parking reservation status.
public enum ParkingReservationStatus {
    PENDING,
    CONFIRMED,
    EXPIRED,
    DUPLICATE
}

# [Database] Enum for employee statuses.
public enum EmployeeStatus {
    EMPLOYEE_ACTIVE = "Active",
    EMPLOYEE_LEFT = "Left",
    EMPLOYEE_MARKED_LEAVER = "Marked leaver",
    # Onboarded with a start date still to come; the scheduler makes them Active on that date.
    EMPLOYEE_NEW_JOINER = "New joiner"
}

# [Database] Enum for employment types.
public enum EmploymentTypeName {
    PERMANENT = "PERMANENT",
    PROBATION = "PROBATION",
    INTERNSHIP = "INTERNSHIP",
    CONSULTANCY = "CONSULTANCY",
    ADVISORY_CONSULTANCY = "ADVISORY CONSULTANCY",
    PART_TIME_CONSULTANCY = "PART TIME CONSULTANCY",
    FIXED_TERM = "FIXED TERM CONTRACT"
}

# [Database] Enum for how a team member relates to the lead viewing them.
public enum ReportingRelation {
    # The lead is their manager
    DIRECT,
    # The lead is one of their additional managers, and not their manager
    ADDITIONAL,
    # Further down the lead's chain
    INDIRECT
}
