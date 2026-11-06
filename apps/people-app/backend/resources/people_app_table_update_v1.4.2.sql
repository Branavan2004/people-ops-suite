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

-- =====================================================================
-- people_app_table_update_v1.4.2.sql
--
-- Runs against a database already at v1.4.1.
--
-- Adds the `internship` table for the intern-only data that `employee`
-- does not already hold: university. Every other
-- intern detail is read from the intern's `employee` row.
--
-- Keyed by employee.id (one row per intern), following the `resignation`
-- table pattern.
-- =====================================================================

-- Internship table
CREATE TABLE `internship` (
  `employee_id` INT PRIMARY KEY,
  `university` VARCHAR(200) NULL,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT `fk_emp_internship`
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`id`)
);
