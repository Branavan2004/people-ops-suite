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

-- ---------------------------------------------------------------------------
-- Work location timezones
--
-- New joiners become Active, and scheduled changes apply, once their date begins
-- where the employee works; Marked leavers become Left once their final day is
-- over there. Where they work is their company's work location, so each location
-- records the timezone its employees' dates are read in.
--
-- A country spanning several timezones takes its main one. Staff in its other
-- zones move a few hours either side of their own midnight: with US on New York
-- time, a Los Angeles joiner is activated at 21:00 the evening before their first day.
-- ---------------------------------------------------------------------------

ALTER TABLE `companies_allowed_locations`
  ADD COLUMN `time_zone` VARCHAR(64) NULL AFTER `probation_period`;

UPDATE `companies_allowed_locations`
SET `time_zone` = CASE TRIM(`allowed_location`)
    WHEN 'Sri Lanka'      THEN 'Asia/Colombo'
    WHEN 'Sri Lanka - TL' THEN 'Asia/Colombo'
    WHEN 'India'          THEN 'Asia/Kolkata'
    WHEN 'Bangladesh'     THEN 'Asia/Dhaka'
    WHEN 'Thailand'       THEN 'Asia/Bangkok'
    WHEN 'Singapore'      THEN 'Asia/Singapore'
    WHEN 'Hong Kong'      THEN 'Asia/Hong_Kong'
    WHEN 'UAE'            THEN 'Asia/Dubai'
    WHEN 'Saudi Arabia'   THEN 'Asia/Riyadh'
    WHEN 'Australia'      THEN 'Australia/Sydney'
    WHEN 'New Zealand'    THEN 'Pacific/Auckland'
    WHEN 'UK'             THEN 'Europe/London'
    WHEN 'UK - TL'        THEN 'Europe/London'
    WHEN 'Portugal'       THEN 'Europe/Lisbon'
    WHEN 'Spain'          THEN 'Europe/Madrid'
    WHEN 'Spain - VP'     THEN 'Europe/Madrid'
    WHEN 'France'         THEN 'Europe/Paris'
    WHEN 'Netherlands'    THEN 'Europe/Amsterdam'
    WHEN 'Germany'        THEN 'Europe/Berlin'
    WHEN 'Italy'          THEN 'Europe/Rome'
    WHEN 'Sweden'         THEN 'Europe/Stockholm'
    WHEN 'Greece'         THEN 'Europe/Athens'
    WHEN 'Ukraine'        THEN 'Europe/Kyiv'
    WHEN 'Morocco'        THEN 'Africa/Casablanca'
    WHEN 'South Africa'   THEN 'Africa/Johannesburg'
    WHEN 'Kenya'          THEN 'Africa/Nairobi'
    WHEN 'Brazil'         THEN 'America/Sao_Paulo'
    WHEN 'Brazil - TL'    THEN 'America/Sao_Paulo'
    WHEN 'Argentina'      THEN 'America/Argentina/Buenos_Aires'
    WHEN 'Colombia'       THEN 'America/Bogota'
    WHEN 'Columbia'       THEN 'America/Bogota'
    WHEN 'Mexico'         THEN 'America/Mexico_City'
    WHEN 'Canada'         THEN 'America/Toronto'
    WHEN 'US'             THEN 'America/New_York'
    WHEN 'US - VP'        THEN 'America/New_York'
END
WHERE `time_zone` IS NULL;

-- No default: a location left out above stops the migration here instead of
-- quietly taking a timezone nobody chose. The column already exists by then, so
-- add a WHEN for the location and run this file again from the UPDATE above.
ALTER TABLE `companies_allowed_locations`
  MODIFY COLUMN `time_zone` VARCHAR(64) NOT NULL;
