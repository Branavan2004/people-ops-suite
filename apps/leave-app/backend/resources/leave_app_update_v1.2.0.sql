-- Copyright (c) 2026 WSO2 LLC. (https://www.wso2.com).
--
-- WSO2 LLC. licenses this file to you under the Apache License,
-- Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing,
-- software distributed under the License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
-- KIND, either express or implied.  See the License for the
-- specific language governing permissions and limitations
-- under the License.

-- Leave App v1.2.0
-- France leave types: Compassionate Leave and Other Authorized Leave (the latter needs lead approval),
-- plus an encrypted sick note attachment for France sick leave. leave_attachments holds the AES-GCM
-- encrypted note (one per leave), leave_attachment_downloads audits every download, and the two new
-- leave_submissions columns drive the approval reminder and store the rejection reason.

CREATE TABLE leave_attachments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  leave_id INT UNSIGNED NOT NULL UNIQUE,
  content MEDIUMBLOB NULL,
  iv VARBINARY(12) NULL,
  key_id INT NOT NULL,
  content_type VARCHAR(32) NOT NULL,
  size_bytes INT NOT NULL,
  uploaded_by VARCHAR(255) NOT NULL,
  uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP NULL DEFAULT NULL,
  FOREIGN KEY (leave_id) REFERENCES leave_submissions(id)
);

CREATE TABLE leave_attachment_downloads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  attachment_id INT NOT NULL,
  leave_id INT UNSIGNED NOT NULL,
  downloaded_by VARCHAR(255) NOT NULL,
  downloaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (attachment_id) REFERENCES leave_attachments(id)
);

ALTER TABLE leave_submissions
  ADD COLUMN approval_reminder_sent_on TIMESTAMP NULL DEFAULT NULL,
  ADD COLUMN rejection_reason VARCHAR(500) NULL DEFAULT NULL;
