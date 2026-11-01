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

import ballerina/sql;

# [Configurable] Leave database configs.
type DatabaseConfig record {|
    # User of the database
    string user;
    # Password of the database
    string password;
    # Name of the database
    string database;
    # Host of the database
    string host;
    # Port of the database
    int port;
    # Maximum number of open connections
    int maxOpenConnections;
    # Maximum lifetime of a connection
    decimal maxConnectionLifeTime;
    # Minimum number of open connections
    int minIdleConnections;
|};

# An approved sabbatical leave that is due for its reminder email.
public type SabbaticalReminder record {|
    # Leave id
    int id;
    # Email of the employee taking the sabbatical
    string email;
    # Email of the lead who approved the sabbatical; the fallback recipient when HR has no lead
    @sql:Column {name: "approver_email"}
    string? approverEmail;
    # Leave start date (yyyy-mm-dd)
    @sql:Column {name: "start_date"}
    string startDate;
    # Leave end date (yyyy-mm-dd)
    @sql:Column {name: "end_date"}
    string endDate;
    # Number of calendar days the leave spans, both ends included
    @sql:Column {name: "duration_days"}
    int durationDays;
|};
