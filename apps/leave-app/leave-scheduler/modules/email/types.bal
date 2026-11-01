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

# OAuth2 client auth configurations.
type Oauth2Config record {|
    # Token URL
    string tokenUrl;
    # Client ID
    string clientId;
    # Client Secret
    string clientSecret;
|};

# [Configurable] Email notification service configs.
type EmailServiceConfig record {|
    # Email Service Endpoint
    string emailServiceEndpoint;
    # Auth Configurations
    Oauth2Config oauthConfig;
    # Sender email
    string 'from;
    # People Operations group, copied on every reminder
    string[] peopleOperationsRecipients;
|};

# Payload of the email alerting service.
type EmailPayload record {|
    # Recipient email(s) as string array
    string[] to;
    # Sender email
    string 'from;
    # Email subject
    string subject;
    # Email template
    string template;
    # CC'ed recipient email(s) as string array
    string[] cc?;
|};

# Details of one sabbatical reminder email.
public type SabbaticalReminderDetails record {|
    # Display name of the employee taking the sabbatical
    string employeeName;
    # Email of the employee taking the sabbatical
    string employeeEmail;
    # Email of the lead the reminder is sent to
    string leadEmail;
    # First name of the lead, for the greeting
    string leadName;
    # Leave start date (yyyy-mm-dd)
    string startDate;
    # Leave end date (yyyy-mm-dd)
    string endDate;
    # Number of calendar days the leave spans
    int durationDays;
|};
