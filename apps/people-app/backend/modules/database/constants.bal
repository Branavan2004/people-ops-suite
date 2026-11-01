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

# A constant default limit of a database query
public const DEFAULT_LIMIT = 100;

# A constant error message for no rows updated
const ERROR_NO_ROWS_UPDATED = "No rows were updated";

# A constant error message for an update payload that carries no fields to update
const ERROR_NO_FIELDS_TO_UPDATE = "No fields to update";

# A constant max token count for search operations
const MAX_TOKEN_COUNT = 10;

# A constant default page number
const DEFAULT_PAGE_NUMBER = 1;

# A constant default records per page
const DEFAULT_RECORDS_PER_PAGE = 20;

# Prefix shared by all consultancy-type employee IDs 
public const CONSULTANCY_ID_PREFIX = "CON";

# Constants for bulk insert operation status codes
public const BULK_INSERT_SUCCESS = 1000;
public const BULK_INSERT_DUPLICATE = 1001;
public const BULK_INSERT_FAILED = 1002;

# MySQL error code for a duplicate entry on a unique index/key.
const MYSQL_DUPLICATE_ENTRY_ERROR_CODE = 1062;

# MySQL error code for a failed foreign key constraint on insert/update.
const MYSQL_FK_CONSTRAINT_ERROR_CODE = 1452;

# Sentinel value for updateDesignationQuery's jobBand parameter that clears job_band to NULL.
public const JOB_BAND_CLEAR_SENTINEL = -1;

# Sentinel value for updateDesignationQuery's careerFunctionId parameter that clears career_function_id to NULL.
public const CAREER_FUNCTION_CLEAR_SENTINEL = -1;

# Sentinel value for updateEmployeeJobInfoQuery's officeId parameter that clears office_id to NULL.
public const OFFICE_CLEAR_SENTINEL = -1;

# Sentinel value for updateEmployeeJobInfoQuery's unitId parameter that clears unit_id to NULL.
public const UNIT_CLEAR_SENTINEL = -1;

# Sentinel value for updateEmployeeJobInfoQuery's continuousServiceRecord parameter that clears
# continuous_service_record to NULL.
public const CONTINUOUS_SERVICE_RECORD_CLEAR_SENTINEL = -1;

# Message returned when a departure's final day of employment precedes its last day in office.
public const RESIGNATION_DATE_ORDER_ERROR =
        "Final day of employment cannot be before the last day in office";

# Work email stored for a new joiner whose account does not exist yet. Onboarding stores it
# when the email is left empty; it is shared by every such joiner, so it never identifies a
# person and is skipped by every lookup that recognises a returning employee by email.
public const FUTURE_JOINER_EMAIL = "future-joiner@wso2.com";

# Work email held by former employees whose real address is not on record. Like
# FUTURE_JOINER_EMAIL it is shared and never identifies a person.
public const EX_EMPLOYEE_EMAIL = "ex-employee@wso2.com";

# Where HR works. Used as the local timezone for an employee whose work location has no
# usable timezone on record, so whether they have started is still decided.
public const DEFAULT_TIME_ZONE = "Asia/Colombo";
