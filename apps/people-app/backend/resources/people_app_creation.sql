DROP TABLE IF EXISTS resignation_audit;
DROP TABLE IF EXISTS resignation;
DROP TABLE IF EXISTS scheduled_employee_change;
DROP TABLE IF EXISTS parking_reservation;
DROP TABLE IF EXISTS parking_slot;
DROP TABLE IF EXISTS parking_floor;
DROP TABLE IF EXISTS vehicle;
DROP TABLE IF EXISTS employee_additional_managers_audit;
DROP TABLE IF EXISTS employee_audit;
DROP TABLE IF EXISTS personal_info_emergency_contacts_audit;
DROP TABLE IF EXISTS personal_info_audit;
DROP TABLE IF EXISTS employee_additional_managers;
DROP TABLE IF EXISTS employee_leadership_audit;
DROP TABLE IF EXISTS employee_leadership;
DROP TABLE IF EXISTS leadership_group_audit;
DROP TABLE IF EXISTS leadership_group;
DROP TABLE IF EXISTS employee;
DROP TABLE IF EXISTS house;
DROP TABLE IF EXISTS recruit;
DROP TABLE IF EXISTS business_unit_team_sub_team_unit;
DROP TABLE IF EXISTS business_unit_team_sub_team;
DROP TABLE IF EXISTS business_unit_team;
DROP TABLE IF EXISTS team_asgardeo_groups;
DROP TABLE IF EXISTS unit;
DROP TABLE IF EXISTS sub_team;
DROP TABLE IF EXISTS team;
DROP TABLE IF EXISTS business_unit;
DROP TABLE IF EXISTS office;
DROP TABLE IF EXISTS companies_allowed_locations;
DROP TABLE IF EXISTS company;
DROP TABLE IF EXISTS designation_audit;
DROP TABLE IF EXISTS career_function_audit;
DROP TABLE IF EXISTS designation;
DROP TABLE IF EXISTS career_function;
DROP TABLE IF EXISTS employment_type_idp_group;
DROP TABLE IF EXISTS employment_type;
DROP TABLE IF EXISTS personal_info_emergency_contacts;
DROP TABLE IF EXISTS personal_info;

CREATE TABLE `vehicle` (
  `vehicle_id` int NOT NULL AUTO_INCREMENT,
  `employee_email` varchar(45) NOT NULL,
  `vehicle_registration_number` varchar(45) NOT NULL,
  `vehicle_type` enum('CAR','MOTORCYCLE') NOT NULL,
  `vehicle_status` enum('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE',
  `created_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `created_by` varchar(45) NOT NULL,
  `updated_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `updated_by` varchar(60) NOT NULL,
  PRIMARY KEY (`vehicle_id`)
);

CREATE TABLE `business_unit` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(45) NOT NULL,
  `head_email` VARCHAR(254) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`)
);

CREATE TABLE `team` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(45) NOT NULL,
  `head_email` VARCHAR(254) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`)
);

CREATE TABLE `business_unit_team` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `business_unit_id` INT NOT NULL,
  `team_id` INT NOT NULL,
  `head_email` VARCHAR(254) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_but_bu`
    FOREIGN KEY (`business_unit_id`) REFERENCES `business_unit` (`id`),
  CONSTRAINT `fk_but_team`
    FOREIGN KEY (`team_id`) REFERENCES `team` (`id`)
);

CREATE TABLE `sub_team` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(45) NOT NULL,
  `head_email` VARCHAR(254) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`)
);

CREATE TABLE `business_unit_team_sub_team` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `business_unit_team_id` INT NOT NULL,
  `sub_team_id` INT NOT NULL,
  `head_email` VARCHAR(254) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_butst_but`
    FOREIGN KEY (`business_unit_team_id`) REFERENCES `business_unit_team` (`id`),
  CONSTRAINT `fk_butst_st`
    FOREIGN KEY (`sub_team_id`) REFERENCES `sub_team` (`id`)
);

CREATE TABLE `unit` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(45) NOT NULL,
  `head_email` VARCHAR(254) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`)
);

CREATE TABLE `business_unit_team_sub_team_unit` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `business_unit_team_sub_team_id` INT NOT NULL,
  `unit_id` INT NOT NULL,
  `head_email` VARCHAR(254) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_butstu_butst`
    FOREIGN KEY (`business_unit_team_sub_team_id`) REFERENCES `business_unit_team_sub_team` (`id`),
  CONSTRAINT `fk_butstu_unit`
    FOREIGN KEY (`unit_id`) REFERENCES `unit` (`id`)
);

-- Company table
CREATE TABLE `company` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `prefix` VARCHAR(20) NOT NULL,
  `location` VARCHAR(255) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`)
);

-- Office table
CREATE TABLE `office` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` INT NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `location` VARCHAR(255) NOT NULL,
  `working_locations` JSON NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  KEY `idx_office_company_id_id` (`company_id`, `id`),
  CONSTRAINT `fk_office_company`
    FOREIGN KEY (`company_id`) REFERENCES `company` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
);

-- Career_function table
CREATE TABLE `career_function` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `career_function` VARCHAR(150) NOT NULL,
  `is_active` TINYINT(1) NULL DEFAULT 1, 
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
);

-- Designation table
CREATE TABLE `designation` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `designation` VARCHAR(150) NOT NULL,
  `job_band` INT NULL,
  `career_function_id` INT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,  
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT `fk_designation_career_function`
    FOREIGN KEY (`career_function_id`) REFERENCES `career_function` (`id`)
);

-- Employment_types table
CREATE TABLE `employment_type` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `is_active` TINYINT(1) NULL DEFAULT 1, 
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`)
);

-- Personal_info table
CREATE TABLE `personal_info` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `nic_or_passport` VARCHAR(20) NOT NULL UNIQUE,
  `first_name` VARCHAR(100) NOT NULL,
  `last_name` VARCHAR(100) NOT NULL,
  `full_name` VARCHAR(255) NOT NULL DEFAULT (CONCAT(first_name, ' ', last_name)),
  `title` VARCHAR(100) NOT NULL,
  `dob` DATE NOT NULL,
  `gender` VARCHAR(20) NOT NULL DEFAULT 'Not Specified',
  `personal_email` VARCHAR(254),
  `personal_phone` VARCHAR(100),
  `resident_number` VARCHAR(100),
  `address_line_1` VARCHAR(255),
  `address_line_2` VARCHAR(255),
  `city` VARCHAR(100),
  `state_or_province` VARCHAR(100),
  `postal_code` VARCHAR(20),
  `country` VARCHAR(100),
  `nationality` VARCHAR(100) NOT NULL,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
);

-- Recruit table
CREATE TABLE `recruit` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `first_name` VARCHAR(255) NOT NULL,
  `last_name` VARCHAR(255) NOT NULL,
  `work_email` VARCHAR(254) NULL,
  `date_of_join` DATE NOT NULL,
  `probation_end_date` DATE NULL,
  `agreement_end_date` DATE NULL,
  `employment_location` VARCHAR(255) NULL,
  `work_location` VARCHAR(100) NULL,
  `reports_to` VARCHAR(254) NULL,
  `manager_email` VARCHAR(254) NULL,
  `compensation` JSON NULL,
  `additional_comments` BLOB NULL,
  `status` VARCHAR(255) NOT NULL,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `business_unit` INT NOT NULL,
  `unit` INT NULL,
  `team` INT NOT NULL,
  `sub_team` INT NOT NULL,
  `company` INT NOT NULL,
  `office` INT NOT NULL,
  `employment_type` INT NOT NULL,
  `designation_id` INT NOT NULL,
  `personal_info_id` INT NULL,
  CONSTRAINT `fk_recruit_personal_info`
    FOREIGN KEY (`personal_info_id`) REFERENCES `personal_info` (`id`),
  CONSTRAINT `fk_recruit_bu`
    FOREIGN KEY (`business_unit`) REFERENCES `business_unit` (`id`),
  CONSTRAINT `fk_recruit_team`
    FOREIGN KEY (`team`) REFERENCES `team` (`id`),
  CONSTRAINT `fk_recruit_subteam`
    FOREIGN KEY (`sub_team`) REFERENCES `sub_team` (`id`),
  CONSTRAINT `fk_recruit_unit`
    FOREIGN KEY (`unit`) REFERENCES `unit` (`id`),
  CONSTRAINT `fk_recruit_company`
    FOREIGN KEY (`company`) REFERENCES `company` (`id`),
  CONSTRAINT `fk_recruit_office`
    FOREIGN KEY (`office`) REFERENCES `office` (`id`),
  CONSTRAINT `fk_recruit_designation`
    FOREIGN KEY (`designation_id`) REFERENCES `designation` (`id`),
  CONSTRAINT `fk_recruit_employment_type`
    FOREIGN KEY (`employment_type`) REFERENCES `employment_type` (`id`)
);

-- House table
CREATE TABLE `house` (
  `id`        INT          NOT NULL AUTO_INCREMENT,
  `name`      VARCHAR(100) NOT NULL,
  `is_active` TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_house_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `house` (`name`) VALUES
  ('CloudBots'),
  ('Titans'),
  ('Legions'),
  ('Wild Boars');

-- Employee table
CREATE TABLE `employee` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `employee_id` VARCHAR(99) UNIQUE,
  `first_name` VARCHAR(150) NOT NULL,
  `last_name` VARCHAR(150) NOT NULL,
  `epf` VARCHAR(45) NULL,
  `work_location` VARCHAR(100) NOT NULL,
  `work_phone` VARCHAR(20) NULL,
  `relocation_status` VARCHAR(100) NULL,
  `work_email` VARCHAR(254) NOT NULL,
  `start_date` DATE NOT NULL,
  `secondary_job_title` VARCHAR(100) NULL,
  `job_role` VARCHAR(100) NULL,
  `external_designation` VARCHAR(100) NULL,
  `manager_email` VARCHAR(254) NOT NULL,
  `employee_status` VARCHAR(50) NOT NULL,
  `continuous_service_record` INT NULL,
  `employee_thumbnail` VARCHAR(2048) NULL,
  `probation_end_date` DATE NULL,
  `last_promoted_date` DATE NULL,
  `agreement_end_date` DATE NULL,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `employment_type_id` INT NOT NULL,
  `designation_id` INT NOT NULL,
  `company_id` int NOT NULL,
  `office_id` INT NULL,
  `team_id` INT NOT NULL,
  `sub_team_id` INT NULL,
  `business_unit_id` INT NOT NULL,
  `unit_id` INT NULL,
  `house_id` INT NULL DEFAULT NULL,
  `personal_info_id` INT NOT NULL,
  CONSTRAINT `fk_emp_personal_info`
    FOREIGN KEY (`personal_info_id`) REFERENCES `personal_info` (`id`),
  CONSTRAINT `fk_emp_employment_type`
    FOREIGN KEY (`employment_type_id`) REFERENCES `employment_type` (`id`),
  CONSTRAINT `fk_emp_designation`
    FOREIGN KEY (`designation_id`) REFERENCES `designation` (`id`),
  CONSTRAINT `fk_emp_company`
    FOREIGN KEY (`company_id`) REFERENCES `company` (`id`),
  CONSTRAINT `fk_emp_office_company`
    FOREIGN KEY (`company_id`, `office_id`) REFERENCES `office` (`company_id`, `id`),
  CONSTRAINT `fk_emp_team`
    FOREIGN KEY (`team_id`) REFERENCES `team` (`id`),
  CONSTRAINT `fk_emp_subteam`
    FOREIGN KEY (`sub_team_id`) REFERENCES `sub_team` (`id`),
  CONSTRAINT `fk_emp_bu`
    FOREIGN KEY (`business_unit_id`) REFERENCES `business_unit` (`id`),
  CONSTRAINT `fk_emp_unit`
    FOREIGN KEY (`unit_id`) REFERENCES `unit` (`id`),
  CONSTRAINT `fk_emp_house`
    FOREIGN KEY (`house_id`) REFERENCES `house` (`id`),
  CONSTRAINT `fk_emp_continuous_service_record`
    FOREIGN KEY (`continuous_service_record`) REFERENCES `employee` (`id`)
);

-- Resignation table
CREATE TABLE `resignation` (
  `employee_id` INT PRIMARY KEY,
  `final_day_in_office` DATE NULL,
  `final_day_of_employment` DATE NULL,
  `reason` VARCHAR(300) NULL,
  `date` DATE NULL,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT `fk_emp_resignation`
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`id`)
);

-- Scheduled employee changes
--
-- An edit to an employee's general information can be given a future date instead of
-- being applied on save. `changes` holds only the fields being changed, in the shape the
-- job-info update payload expects; `expected` holds what those fields were when the
-- change was scheduled, so the sweep can tell a change that still makes sense from one
-- that would undo a more recent decision.
CREATE TABLE `scheduled_employee_change` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `employee_id` INT NOT NULL,
  `effective_date` DATE NOT NULL,
  `changes` JSON NOT NULL,
  `expected` JSON NOT NULL,
  `status` ENUM('PENDING', 'APPLIED', 'CANCELLED', 'SUPERSEDED', 'FAILED')
    NOT NULL DEFAULT 'PENDING',
  `applied_on` TIMESTAMP(6) NULL,
  `failure_reason` VARCHAR(500) NULL,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  KEY `idx_sched_change_due` (`status`, `effective_date`),
  KEY `idx_sched_change_employee` (`employee_id`, `status`),
  CONSTRAINT `fk_sched_change_employee`
    FOREIGN KEY (`employee_id`) REFERENCES `employee` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

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

-- Additional_managers table
CREATE TABLE `employee_additional_managers` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `employee_pk_id` INT NOT NULL,
  `additional_manager_email` VARCHAR(254) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_eam_employee_email` (`employee_pk_id`, `additional_manager_email`),
  KEY `idx_eam_manager_email` (`additional_manager_email`),
  CONSTRAINT `fk_eam_employee`
    FOREIGN KEY (`employee_pk_id`) REFERENCES `employee` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- Emergency_contacts table
CREATE TABLE `personal_info_emergency_contacts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `personal_info_id` INT NOT NULL,
  `name` VARCHAR(150) NOT NULL,
  `mobile` VARCHAR(20) NOT NULL,
  `telephone` VARCHAR(20) NULL,
  `relationship` VARCHAR(100) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ec_personal_mobile` (`personal_info_id`, `mobile`),
  KEY `idx_ec_personal_info_id` (`personal_info_id`),
  KEY `idx_ec_mobile` (`mobile`),
  CONSTRAINT `fk_ec_personal_info`
    FOREIGN KEY (`personal_info_id`) REFERENCES `personal_info` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Companies allowed locations table
CREATE TABLE `companies_allowed_locations` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` INT NOT NULL,
  `allowed_location` VARCHAR(255) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `probation_period` tinyint unsigned DEFAULT NULL,
  -- IANA timezone the location's employees' dates are read in, e.g. 'Asia/Colombo'
  `time_zone` VARCHAR(64) NOT NULL,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cal_company_location` (`company_id`, `allowed_location`),
  KEY `idx_cal_company_id` (`company_id`),
  KEY `idx_cal_location` (`allowed_location`),
  CONSTRAINT `fk_cal_company`
    FOREIGN KEY (`company_id`) REFERENCES `company` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Parking floor table
CREATE TABLE `parking_floor` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(45) NOT NULL,
  `display_order` int NOT NULL DEFAULT 0,
  `coins_per_slot` decimal(10, 4) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `created_by` varchar(100) NOT NULL,
  `updated_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `updated_by` varchar(100) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Parking slot table
CREATE TABLE `parking_slot` (
  `slot_id` varchar(10) NOT NULL,
  `floor_id` int NOT NULL,
  `created_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `created_by` varchar(100) NOT NULL,
  `updated_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `updated_by` varchar(100) NOT NULL,
  PRIMARY KEY (`slot_id`),
  CONSTRAINT `fk_ps_floor` FOREIGN KEY (`floor_id`) REFERENCES `parking_floor` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Parking reservation table
CREATE TABLE `parking_reservation` (
  `id` int NOT NULL AUTO_INCREMENT,
  `slot_id` varchar(10) NOT NULL,
  `booking_date` date NOT NULL,
  `employee_email` varchar(100) NOT NULL,
  `vehicle_id` int NOT NULL,
  `status` enum('PENDING','CONFIRMED','EXPIRED','DUPLICATE') NOT NULL DEFAULT 'PENDING',
  `transaction_hash` varchar(255) DEFAULT NULL,
  `coins_amount` decimal(10, 4) NOT NULL,
  `created_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `created_by` varchar(100) NOT NULL,
  `updated_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `updated_by` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_pr_slot` FOREIGN KEY (`slot_id`) REFERENCES `parking_slot` (`slot_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_pr_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicle` (`vehicle_id`) ON DELETE RESTRICT,
  KEY `idx_pr_slot_booking_date` (`slot_id`, `booking_date`),
  UNIQUE KEY `uk_parking_reservation_tx_hash` (`transaction_hash`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Functional UNIQUE index
CREATE UNIQUE INDEX `uk_active_slot_booking_date` ON `parking_reservation` ((
  CASE
    WHEN `status` IN ('PENDING', 'CONFIRMED') THEN CONCAT(`slot_id`, '|', `booking_date`)
    ELSE NULL
  END
));

-- Functional UNIQUE index: one active (PENDING/CONFIRMED) reservation per employee per date.
CREATE UNIQUE INDEX `uk_active_employee_booking_date` ON `parking_reservation` ((
  CASE
    WHEN `status` IN ('PENDING', 'CONFIRMED') THEN CONCAT(`employee_email`, '|', `booking_date`)
    ELSE NULL
  END
));

-- Personal Info Audit table
CREATE TABLE `personal_info_audit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `personal_info_pk_id` int DEFAULT NULL,
  `action_type` enum('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `action_by` varchar(254) NOT NULL,
  `db_user` varchar(254) NULL,
  `action_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `data` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pi_audit_pi_pk` (`personal_info_pk_id`),
  KEY `idx_pi_audit_action_on` (`action_on`),
  CONSTRAINT `fk_pi_audit_personal_info` FOREIGN KEY (`personal_info_pk_id`) REFERENCES `personal_info` (`id`) ON DELETE
  SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Emergency Contacts Audit table
CREATE TABLE `personal_info_emergency_contacts_audit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `personal_info_id` int DEFAULT NULL,
  `action_type` enum('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `action_by` varchar(254) NOT NULL,
  `db_user` varchar(254) NULL,
  `action_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `data` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ec_audit_personal_info_id` (`personal_info_id`),
  KEY `idx_ec_audit_action_on` (`action_on`),
  CONSTRAINT `fk_personal_info_emergency_contacts_audit_personal_info_id`
    FOREIGN KEY (`personal_info_id`) REFERENCES `personal_info` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Employee Audit table
CREATE TABLE `employee_audit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_pk_id` int DEFAULT NULL,
  `action_type` enum('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `action_by` varchar(254) NOT NULL,
  `db_user` varchar(254) NULL,
  `action_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `data` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_emp_audit_employee_pk` (`employee_pk_id`),
  KEY `idx_emp_audit_action_on` (`action_on`),
  CONSTRAINT `fk_emp_audit_employee` FOREIGN KEY (`employee_pk_id`) REFERENCES `employee` (`id`) ON DELETE
  SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Resignation Audit table
CREATE TABLE `resignation_audit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_pk_id` int DEFAULT NULL,
  `action_type` enum('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `action_by` varchar(254) NOT NULL,
  `db_user` varchar(254) NULL,
  `action_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `data` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_resignation_audit_employee_pk` (`employee_pk_id`),
  KEY `idx_resignation_audit_action_on` (`action_on`),
  CONSTRAINT `fk_resignation_audit_employee` FOREIGN KEY (`employee_pk_id`) REFERENCES `employee` (`id`) ON DELETE
  SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Additional Managers Audit table
CREATE TABLE `employee_additional_managers_audit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_pk_id` int DEFAULT NULL,
  `action_type` enum('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `action_by` varchar(254) NOT NULL,
  `db_user` varchar(254) NULL,
  `action_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `data` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_eam_audit_employee_pk_id` (`employee_pk_id`),
  KEY `idx_eam_audit_action_on` (`action_on`),
  CONSTRAINT `fk_employee_additional_managers_audit_employee_pk_id`
    FOREIGN KEY (`employee_pk_id`) REFERENCES `employee` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Employment Type IDP Group Mapping Table
CREATE TABLE `employment_type_idp_group` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `employment_type_id` INT NOT NULL,
  `group_name` VARCHAR(255) NOT NULL,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_etag_employment_type_group` (`employment_type_id`, `group_name`),
  KEY `idx_etag_employment_type_id` (`employment_type_id`),
  CONSTRAINT `fk_etag_employment_type`
    FOREIGN KEY (`employment_type_id`) REFERENCES `employment_type` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Procedure: prc_personal_info_audit
DROP PROCEDURE IF EXISTS prc_personal_info_audit;
DELIMITER //
CREATE PROCEDURE `prc_personal_info_audit`(
  IN p_id                BIGINT,
  IN p_action_type       VARCHAR(10),
  IN p_action_by         VARCHAR(254),
  IN p_nic_or_passport   VARCHAR(50),
  IN p_first_name        VARCHAR(100),
  IN p_last_name         VARCHAR(100),
  IN p_full_name         VARCHAR(255),
  IN p_title             VARCHAR(100),
  IN p_dob               DATE,
  IN p_gender            VARCHAR(20),
  IN p_personal_email    VARCHAR(254),
  IN p_personal_phone    VARCHAR(100),
  IN p_resident_number   VARCHAR(100),
  IN p_address_line_1    VARCHAR(255),
  IN p_address_line_2    VARCHAR(255),
  IN p_city              VARCHAR(100),
  IN p_state_or_province VARCHAR(100),
  IN p_postal_code       VARCHAR(20),
  IN p_country           VARCHAR(100),
  IN p_nationality       VARCHAR(100),
  IN p_created_by        VARCHAR(254),
  IN p_created_on        DATETIME(6),
  IN p_updated_by        VARCHAR(254),
  IN p_updated_on        DATETIME(6)
)
BEGIN
  INSERT INTO personal_info_audit (personal_info_pk_id, action_type, action_by, db_user, action_on, data)
  VALUES (
    p_id,
    p_action_type,
    p_action_by,
    USER(),
    CURRENT_TIMESTAMP(6),
    JSON_OBJECT(
      'id',                p_id,
      'nic_or_passport',   p_nic_or_passport,
      'first_name',        p_first_name,
      'last_name',         p_last_name,
      'full_name',         p_full_name,
      'title',             p_title,
      'dob',               p_dob,
      'gender',            p_gender,
      'personal_email',    p_personal_email,
      'personal_phone',    p_personal_phone,
      'resident_number',   p_resident_number,
      'address_line_1',    p_address_line_1,
      'address_line_2',    p_address_line_2,
      'city',              p_city,
      'state_or_province', p_state_or_province,
      'postal_code',       p_postal_code,
      'country',           p_country,
      'nationality',       p_nationality,
      'created_by',        p_created_by,
      'created_on',        p_created_on,
      'updated_by',        p_updated_by,
      'updated_on',        p_updated_on
    )
  );
END//
DELIMITER ;

-- Trigger: trg_personal_info_audit_insert
DELIMITER //
CREATE TRIGGER `trg_personal_info_audit_insert`
AFTER INSERT ON `personal_info`
FOR EACH ROW
BEGIN
  CALL prc_personal_info_audit(
    NEW.id, 'INSERT', COALESCE(NULLIF(TRIM(NEW.created_by), ''), 'SYSTEM'),
    NEW.nic_or_passport,  NEW.first_name,        NEW.last_name,
    NEW.full_name,        NEW.title,             NEW.dob,
    NEW.gender,           NEW.personal_email,    NEW.personal_phone,
    NEW.resident_number,  NEW.address_line_1,    NEW.address_line_2,
    NEW.city,             NEW.state_or_province, NEW.postal_code,
    NEW.country,          NEW.nationality,
    NEW.created_by,       NEW.created_on,
    NEW.updated_by,       NEW.updated_on
  );
END//
DELIMITER ;

-- Trigger: trg_personal_info_audit_update
DELIMITER //
CREATE TRIGGER `trg_personal_info_audit_update`
AFTER UPDATE ON `personal_info`
FOR EACH ROW
BEGIN
  CALL prc_personal_info_audit(
    NEW.id, 'UPDATE', COALESCE(NULLIF(TRIM(NEW.updated_by), ''), 'SYSTEM'),
    NEW.nic_or_passport,  NEW.first_name,        NEW.last_name,
    NEW.full_name,        NEW.title,             NEW.dob,
    NEW.gender,           NEW.personal_email,    NEW.personal_phone,
    NEW.resident_number,  NEW.address_line_1,    NEW.address_line_2,
    NEW.city,             NEW.state_or_province, NEW.postal_code,
    NEW.country,          NEW.nationality,
    NEW.created_by,       NEW.created_on,
    NEW.updated_by,       NEW.updated_on
  );
END//
DELIMITER ;

-- Procedure: prc_personal_info_emergency_contacts_audit
DROP PROCEDURE IF EXISTS prc_personal_info_emergency_contacts_audit;
DELIMITER //
CREATE PROCEDURE `prc_personal_info_emergency_contacts_audit`(
  IN p_personal_info_id  BIGINT,
  IN p_action_type       VARCHAR(10),
  IN p_action_by         VARCHAR(254),
  IN p_id                BIGINT,
  IN p_name              VARCHAR(200),
  IN p_mobile            VARCHAR(20),
  IN p_telephone         VARCHAR(20),
  IN p_relationship      VARCHAR(100),
  IN p_is_active         TINYINT(1),
  IN p_created_by        VARCHAR(254),
  IN p_created_on        DATETIME(6),
  IN p_updated_by        VARCHAR(254),
  IN p_updated_on        DATETIME(6)
)
BEGIN
  INSERT INTO personal_info_emergency_contacts_audit
    (personal_info_id, action_type, action_by, db_user, action_on, data)
  VALUES (
    p_personal_info_id,
    p_action_type,
    p_action_by,
    USER(),
    CURRENT_TIMESTAMP(6),
    JSON_OBJECT(
      'id',               p_id,
      'personal_info_id', p_personal_info_id,
      'name',             p_name,
      'mobile',           p_mobile,
      'telephone',        p_telephone,
      'relationship',     p_relationship,
      'is_active',        p_is_active,
      'created_by',       p_created_by,
      'created_on',       p_created_on,
      'updated_by',       p_updated_by,
      'updated_on',       p_updated_on
    )
  );
END//
DELIMITER ;

-- Trigger: trg_personal_info_emergency_contacts_audit_insert
DELIMITER //
CREATE TRIGGER `trg_personal_info_emergency_contacts_audit_insert`
AFTER INSERT ON `personal_info_emergency_contacts`
FOR EACH ROW
BEGIN
  CALL prc_personal_info_emergency_contacts_audit(
    NEW.personal_info_id,
    'INSERT',
    COALESCE(NULLIF(TRIM(NEW.created_by), ''), 'SYSTEM'),
    NEW.id,               NEW.name,         NEW.mobile,
    NEW.telephone,        NEW.relationship, NEW.is_active,
    NEW.created_by,       NEW.created_on,
    NEW.updated_by,       NEW.updated_on
  );
END//
DELIMITER ;

-- Trigger: trg_personal_info_emergency_contacts_audit_update (logs DELETE if is_active flipped to 0)
DELIMITER //
CREATE TRIGGER `trg_personal_info_emergency_contacts_audit_update`
AFTER UPDATE ON `personal_info_emergency_contacts`
FOR EACH ROW
BEGIN
  CALL prc_personal_info_emergency_contacts_audit(
    NEW.personal_info_id,
    CASE WHEN OLD.is_active = 1 AND NEW.is_active = 0 THEN 'DELETE' ELSE 'UPDATE' END,
    COALESCE(NULLIF(TRIM(NEW.updated_by), ''), 'SYSTEM'),
    NEW.id,               NEW.name,         NEW.mobile,
    NEW.telephone,        NEW.relationship, NEW.is_active,
    NEW.created_by,       NEW.created_on,
    NEW.updated_by,       NEW.updated_on
  );
END//
DELIMITER ;

-- Procedure: prc_employee_audit
DROP PROCEDURE IF EXISTS prc_employee_audit;
DELIMITER //
CREATE PROCEDURE `prc_employee_audit`(
  IN p_id                        BIGINT,
  IN p_action_type               VARCHAR(10),
  IN p_action_by                 VARCHAR(254),
  IN p_employee_id               VARCHAR(99),
  IN p_first_name                VARCHAR(150),
  IN p_last_name                 VARCHAR(150),
  IN p_epf                       VARCHAR(50),
  IN p_work_location             VARCHAR(100),
  IN p_work_phone                VARCHAR(20),
  IN p_relocation_status         VARCHAR(100),
  IN p_work_email                VARCHAR(254),
  IN p_start_date                DATE,
  IN p_secondary_job_title       VARCHAR(100),
  IN p_job_role                  VARCHAR(255),
  IN p_external_designation      VARCHAR(100),
  IN p_manager_email             VARCHAR(254),
  IN p_employee_status           VARCHAR(50),
  IN p_continuous_service_record VARCHAR(99),
  IN p_employee_thumbnail        VARCHAR(2048),
  IN p_probation_end_date        DATE,
  IN p_last_promoted_date        DATE,
  IN p_agreement_end_date        DATE,
  IN p_employment_type_id        BIGINT,
  IN p_designation_id            BIGINT,
  IN p_company_id                BIGINT,
  IN p_office_id                 BIGINT,
  IN p_team_id                   BIGINT,
  IN p_sub_team_id               BIGINT,
  IN p_business_unit_id          BIGINT,
  IN p_unit_id                   BIGINT,
  IN p_house_id                  BIGINT,
  IN p_personal_info_id          BIGINT,
  IN p_created_by                VARCHAR(254),
  IN p_created_on                DATETIME(6),
  IN p_updated_by                VARCHAR(254),
  IN p_updated_on                DATETIME(6)
)
BEGIN
  INSERT INTO employee_audit (employee_pk_id, action_type, action_by, db_user, action_on, data)
  VALUES (
    p_id,
    p_action_type,
    p_action_by,
    USER(),
    CURRENT_TIMESTAMP(6),
    JSON_OBJECT(
      'id',                        p_id,
      'employee_id',               p_employee_id,
      'first_name',                p_first_name,
      'last_name',                 p_last_name,
      'epf',                       p_epf,
      'work_location',             p_work_location,
      'work_phone',                p_work_phone,
      'relocation_status',         p_relocation_status,
      'work_email',                p_work_email,
      'start_date',                p_start_date,
      'secondary_job_title',       p_secondary_job_title,
      'job_role',                  p_job_role,
      'external_designation',      p_external_designation,
      'manager_email',             p_manager_email,
      'employee_status',           p_employee_status,
      'continuous_service_record', p_continuous_service_record,
      'employee_thumbnail',        p_employee_thumbnail,
      'probation_end_date',        p_probation_end_date,
      'last_promoted_date',        p_last_promoted_date,
      'agreement_end_date',        p_agreement_end_date,
      'employment_type_id',        p_employment_type_id,
      'designation_id',            p_designation_id,
      'company_id',                p_company_id,
      'office_id',                 p_office_id,
      'team_id',                   p_team_id,
      'sub_team_id',               p_sub_team_id,
      'business_unit_id',          p_business_unit_id,
      'unit_id',                   p_unit_id,
      'house_id',                  p_house_id,
      'personal_info_id',          p_personal_info_id,
      'created_by',                p_created_by,
      'created_on',                p_created_on,
      'updated_by',                p_updated_by,
      'updated_on',                p_updated_on
    )
  );
END//
DELIMITER ;

-- Trigger: trg_employee_audit_insert
DELIMITER //
CREATE TRIGGER `trg_employee_audit_insert`
AFTER INSERT ON `employee`
FOR EACH ROW
BEGIN
  CALL prc_employee_audit(
    NEW.id, 'INSERT', COALESCE(NULLIF(TRIM(NEW.created_by), ''), 'SYSTEM'),
    NEW.employee_id,               NEW.first_name,          NEW.last_name,
    NEW.epf,                       NEW.work_location,        NEW.work_phone,
    NEW.relocation_status,         NEW.work_email,           NEW.start_date,
    NEW.secondary_job_title,       NEW.job_role,             NEW.external_designation,
    NEW.manager_email,             NEW.employee_status,
    NEW.continuous_service_record, NEW.employee_thumbnail,
    NEW.probation_end_date,        NEW.last_promoted_date,   NEW.agreement_end_date,
    NEW.employment_type_id,        NEW.designation_id,       NEW.company_id,
    NEW.office_id,                 NEW.team_id,              NEW.sub_team_id,
    NEW.business_unit_id,          NEW.unit_id,              NEW.house_id,
    NEW.personal_info_id,
    NEW.created_by,                NEW.created_on,
    NEW.updated_by,                NEW.updated_on
  );
END//
DELIMITER ;

-- Trigger: trg_employee_audit_update
DELIMITER //
CREATE TRIGGER `trg_employee_audit_update`
AFTER UPDATE ON `employee`
FOR EACH ROW
BEGIN
  CALL prc_employee_audit(
    NEW.id, 'UPDATE', COALESCE(NULLIF(TRIM(NEW.updated_by), ''), 'SYSTEM'),
    NEW.employee_id,               NEW.first_name,          NEW.last_name,
    NEW.epf,                       NEW.work_location,        NEW.work_phone,
    NEW.relocation_status,         NEW.work_email,           NEW.start_date,
    NEW.secondary_job_title,       NEW.job_role,             NEW.external_designation,
    NEW.manager_email,             NEW.employee_status,
    NEW.continuous_service_record, NEW.employee_thumbnail,
    NEW.probation_end_date,        NEW.last_promoted_date,   NEW.agreement_end_date,
    NEW.employment_type_id,        NEW.designation_id,       NEW.company_id,
    NEW.office_id,                 NEW.team_id,              NEW.sub_team_id,
    NEW.business_unit_id,          NEW.unit_id,              NEW.house_id,
    NEW.personal_info_id,
    NEW.created_by,                NEW.created_on,
    NEW.updated_by,                NEW.updated_on
  );
END//
DELIMITER ;

-- Trigger: trg_employee_no_self_continuous_service_insert
-- continuous_service_record cannot reference the row's own id (MySQL disallows a
-- CHECK constraint on this column since `id` is AUTO_INCREMENT). Must run AFTER
-- INSERT: NEW.id is 0 in a BEFORE INSERT trigger since the value isn't generated yet.
DELIMITER //
CREATE TRIGGER `trg_employee_no_self_continuous_service_insert`
AFTER INSERT ON `employee`
FOR EACH ROW
BEGIN
  IF NEW.continuous_service_record IS NOT NULL AND NEW.continuous_service_record = NEW.id THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'continuous_service_record cannot reference its own employee id';
  END IF;
END//
DELIMITER ;

-- Trigger: trg_employee_no_self_continuous_service_update
DELIMITER //
CREATE TRIGGER `trg_employee_no_self_continuous_service_update`
BEFORE UPDATE ON `employee`
FOR EACH ROW
BEGIN
  IF NEW.continuous_service_record IS NOT NULL AND NEW.continuous_service_record = NEW.id THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'continuous_service_record cannot reference its own employee id';
  END IF;
END//
DELIMITER ;

-- Procedure: prc_employee_additional_managers_audit
DROP PROCEDURE IF EXISTS prc_employee_additional_managers_audit;
DELIMITER //
CREATE PROCEDURE `prc_employee_additional_managers_audit`(
  IN p_employee_pk_id           BIGINT,
  IN p_action_type              VARCHAR(10),
  IN p_action_by                VARCHAR(254),
  IN p_id                       BIGINT,
  IN p_additional_manager_email VARCHAR(254),
  IN p_is_active                TINYINT(1),
  IN p_created_by               VARCHAR(254),
  IN p_created_on               DATETIME(6),
  IN p_updated_by               VARCHAR(254),
  IN p_updated_on               DATETIME(6)
)
BEGIN
  INSERT INTO employee_additional_managers_audit
    (employee_pk_id, action_type, action_by, db_user, action_on, data)
  VALUES (
    p_employee_pk_id,
    p_action_type,
    p_action_by,
    USER(),
    CURRENT_TIMESTAMP(6),
    JSON_OBJECT(
      'id',                       p_id,
      'employee_pk_id',           p_employee_pk_id,
      'additional_manager_email', p_additional_manager_email,
      'is_active',                p_is_active,
      'created_by',               p_created_by,
      'created_on',               p_created_on,
      'updated_by',               p_updated_by,
      'updated_on',               p_updated_on
    )
  );
END//
DELIMITER ;

-- Trigger: trg_employee_additional_managers_audit_insert
DELIMITER //
CREATE TRIGGER `trg_employee_additional_managers_audit_insert`
AFTER INSERT ON `employee_additional_managers`
FOR EACH ROW
BEGIN
  CALL prc_employee_additional_managers_audit(
    NEW.employee_pk_id,
    'INSERT',
    COALESCE(NULLIF(TRIM(NEW.created_by), ''), 'SYSTEM'),
    NEW.id,         NEW.additional_manager_email, NEW.is_active,
    NEW.created_by, NEW.created_on,
    NEW.updated_by, NEW.updated_on
  );
END//
DELIMITER ;

-- Trigger: trg_employee_additional_managers_audit_update (logs DELETE if is_active flipped to 0)
DELIMITER //
CREATE TRIGGER `trg_employee_additional_managers_audit_update`
AFTER UPDATE ON `employee_additional_managers`
FOR EACH ROW
BEGIN
  CALL prc_employee_additional_managers_audit(
    NEW.employee_pk_id,
    CASE WHEN OLD.is_active = 1 AND NEW.is_active = 0 THEN 'DELETE' ELSE 'UPDATE' END,
    COALESCE(NULLIF(TRIM(NEW.updated_by), ''), 'SYSTEM'),
    NEW.id,         NEW.additional_manager_email, NEW.is_active,
    NEW.created_by, NEW.created_on,
    NEW.updated_by, NEW.updated_on
  );
END//
DELIMITER ;

-- Procedure: prc_resignation_audit
--
-- Arguments are passed positionally from both triggers below. Adding a column
-- means adding it at the same ordinal in this signature and in BOTH CALL
-- argument lists, or every later argument shifts and the audit JSON is silently
-- written with values in the wrong keys.
DROP PROCEDURE IF EXISTS prc_resignation_audit;
DELIMITER //
CREATE PROCEDURE `prc_resignation_audit`(
  IN p_employee_pk_id           INT,
  IN p_action_type              VARCHAR(10),
  IN p_action_by                VARCHAR(254),
  IN p_final_day_in_office      DATE,
  IN p_final_day_of_employment  DATE,
  IN p_reason                   VARCHAR(300),
  IN p_date                     DATE,
  IN p_created_by               VARCHAR(254),
  IN p_created_on               DATETIME(6),
  IN p_updated_by               VARCHAR(254),
  IN p_updated_on               DATETIME(6)
)
BEGIN
  INSERT INTO resignation_audit
    (employee_pk_id, action_type, action_by, db_user, action_on, data)
  VALUES (
    p_employee_pk_id,
    p_action_type,
    p_action_by,
    USER(),
    CURRENT_TIMESTAMP(6),
    JSON_OBJECT(
      'employee_id',             p_employee_pk_id,
      'final_day_in_office',     p_final_day_in_office,
      'final_day_of_employment', p_final_day_of_employment,
      'reason',                  p_reason,
      'date',                    p_date,
      'created_by',              p_created_by,
      'created_on',              p_created_on,
      'updated_by',              p_updated_by,
      'updated_on',              p_updated_on
    )
  );
END//
DELIMITER ;

-- Trigger: trg_resignation_audit_insert
DELIMITER //
CREATE TRIGGER `trg_resignation_audit_insert`
AFTER INSERT ON `resignation`
FOR EACH ROW
BEGIN
  CALL prc_resignation_audit(
    NEW.employee_id,
    'INSERT',
    COALESCE(NULLIF(TRIM(NEW.created_by), ''), 'SYSTEM'),
    NEW.final_day_in_office,  NEW.final_day_of_employment,
    NEW.reason,               NEW.date,
    NEW.created_by,           NEW.created_on,
    NEW.updated_by,           NEW.updated_on
  );
END//
DELIMITER ;

-- Trigger: trg_resignation_audit_update
DELIMITER //
CREATE TRIGGER `trg_resignation_audit_update`
AFTER UPDATE ON `resignation`
FOR EACH ROW
BEGIN
  CALL prc_resignation_audit(
    NEW.employee_id,
    'UPDATE',
    COALESCE(NULLIF(TRIM(NEW.updated_by), ''), 'SYSTEM'),
    NEW.final_day_in_office,  NEW.final_day_of_employment,
    NEW.reason,               NEW.date,
    NEW.created_by,           NEW.created_on,
    NEW.updated_by,           NEW.updated_on
  );
END//
DELIMITER ;

-- Team Asgardeo Group Mapping Table
CREATE TABLE `team_asgardeo_groups` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `team_id` INT NOT NULL,
  `employment_type_id` INT NOT NULL,
  `group_name` VARCHAR(255) NOT NULL,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_tag_team_type_group` (`team_id`, `employment_type_id`, `group_name`),
  KEY `idx_tag_team_id` (`team_id`),
  KEY `idx_tag_employment_type_id` (`employment_type_id`),
  CONSTRAINT `fk_tag_team`
    FOREIGN KEY (`team_id`) REFERENCES `team` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tag_employment_type`
    FOREIGN KEY (`employment_type_id`) REFERENCES `employment_type` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Career Function Audit table
CREATE TABLE `career_function_audit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `career_function_pk_id` int DEFAULT NULL,
  `action_type` enum('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `action_by` varchar(254) NOT NULL,
  `db_user` varchar(254) NULL,
  `action_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `data` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_cf_audit_career_function_pk` (`career_function_pk_id`),
  KEY `idx_cf_audit_action_on` (`action_on`),
  CONSTRAINT `fk_cf_audit_career_function` FOREIGN KEY (`career_function_pk_id`) REFERENCES `career_function` (`id`) ON DELETE
  SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Designation Audit table
CREATE TABLE `designation_audit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `designation_pk_id` int DEFAULT NULL,
  `action_type` enum('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `action_by` varchar(254) NOT NULL,
  `db_user` varchar(254) NULL,
  `action_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `data` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_desig_audit_designation_pk` (`designation_pk_id`),
  KEY `idx_desig_audit_action_on` (`action_on`),
  CONSTRAINT `fk_desig_audit_designation` FOREIGN KEY (`designation_pk_id`) REFERENCES `designation` (`id`) ON DELETE
  SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Procedure: prc_career_function_audit
DROP PROCEDURE IF EXISTS prc_career_function_audit;
DELIMITER //
CREATE PROCEDURE `prc_career_function_audit`(
  IN p_id              INT,
  IN p_action_type     VARCHAR(10),
  IN p_action_by       VARCHAR(254),
  IN p_career_function VARCHAR(150),
  IN p_is_active       TINYINT(1),
  IN p_created_by      VARCHAR(254),
  IN p_created_on      DATETIME(6),
  IN p_updated_by      VARCHAR(254),
  IN p_updated_on      DATETIME(6)
)
BEGIN
  INSERT INTO career_function_audit (career_function_pk_id, action_type, action_by, db_user, action_on, data)
  VALUES (
    p_id,
    p_action_type,
    p_action_by,
    USER(),
    CURRENT_TIMESTAMP(6),
    JSON_OBJECT(
      'id',              p_id,
      'career_function', p_career_function,
      'is_active',       p_is_active,
      'created_by',      p_created_by,
      'created_on',      p_created_on,
      'updated_by',      p_updated_by,
      'updated_on',      p_updated_on
    )
  );
END//
DELIMITER ;

-- Trigger: trg_career_function_audit_insert
DELIMITER //
CREATE TRIGGER `trg_career_function_audit_insert`
AFTER INSERT ON `career_function`
FOR EACH ROW
BEGIN
  CALL prc_career_function_audit(
    NEW.id, 'INSERT', COALESCE(NULLIF(TRIM(NEW.created_by), ''), 'SYSTEM'),
    NEW.career_function, NEW.is_active,
    NEW.created_by,      NEW.created_on,
    NEW.updated_by,      NEW.updated_on
  );
END//
DELIMITER ;

-- Trigger: trg_career_function_audit_update
DELIMITER //
CREATE TRIGGER `trg_career_function_audit_update`
AFTER UPDATE ON `career_function`
FOR EACH ROW
BEGIN
  CALL prc_career_function_audit(
    NEW.id,
    CASE WHEN OLD.is_active = 1 AND NEW.is_active = 0 THEN 'DELETE' ELSE 'UPDATE' END,
    COALESCE(NULLIF(TRIM(NEW.updated_by), ''), 'SYSTEM'),
    NEW.career_function, NEW.is_active,
    NEW.created_by,      NEW.created_on,
    NEW.updated_by,      NEW.updated_on
  );
END//
DELIMITER ;

-- Procedure: prc_designation_audit
DROP PROCEDURE IF EXISTS prc_designation_audit;
DELIMITER //
CREATE PROCEDURE `prc_designation_audit`(
  IN p_id                 INT,
  IN p_action_type        VARCHAR(10),
  IN p_action_by          VARCHAR(254),
  IN p_designation        VARCHAR(150),
  IN p_job_band           INT,
  IN p_career_function_id INT,
  IN p_is_active          TINYINT(1),
  IN p_created_by         VARCHAR(254),
  IN p_created_on         DATETIME(6),
  IN p_updated_by         VARCHAR(254),
  IN p_updated_on         DATETIME(6)
)
BEGIN
  INSERT INTO designation_audit (designation_pk_id, action_type, action_by, db_user, action_on, data)
  VALUES (
    p_id,
    p_action_type,
    p_action_by,
    USER(),
    CURRENT_TIMESTAMP(6),
    JSON_OBJECT(
      'id',                 p_id,
      'designation',        p_designation,
      'job_band',           p_job_band,
      'career_function_id', p_career_function_id,
      'is_active',          p_is_active,
      'created_by',         p_created_by,
      'created_on',         p_created_on,
      'updated_by',         p_updated_by,
      'updated_on',         p_updated_on
    )
  );
END//
DELIMITER ;

-- Trigger: trg_designation_audit_insert
DELIMITER //
CREATE TRIGGER `trg_designation_audit_insert`
AFTER INSERT ON `designation`
FOR EACH ROW
BEGIN
  CALL prc_designation_audit(
    NEW.id, 'INSERT', COALESCE(NULLIF(TRIM(NEW.created_by), ''), 'SYSTEM'),
    NEW.designation,  NEW.job_band, NEW.career_function_id, NEW.is_active,
    NEW.created_by,   NEW.created_on,
    NEW.updated_by,   NEW.updated_on
  );
END//
DELIMITER ;

-- Trigger: trg_designation_audit_update
DELIMITER //
CREATE TRIGGER `trg_designation_audit_update`
AFTER UPDATE ON `designation`
FOR EACH ROW
BEGIN
  CALL prc_designation_audit(
    NEW.id,
    CASE WHEN OLD.is_active = 1 AND NEW.is_active = 0 THEN 'DELETE' ELSE 'UPDATE' END,
    COALESCE(NULLIF(TRIM(NEW.updated_by), ''), 'SYSTEM'),
    NEW.designation,  NEW.job_band, NEW.career_function_id, NEW.is_active,
    NEW.created_by,   NEW.created_on,
    NEW.updated_by,   NEW.updated_on
  );
END//
DELIMITER ;

-- ---------------------------------------------------------------------------
-- Leadership attributes (mirrors people_app_table_update_v1.2.1.sql)
--
-- The attribute list lives in leadership_group so adding one is an INSERT, not a
-- release. employee_leadership soft-deletes (is_active = 0) so the audit trail
-- stays meaningful; re-assigning a removed attribute revives the existing row.
-- ---------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS prc_leadership_group_audit;
DROP PROCEDURE IF EXISTS prc_employee_leadership_audit;

CREATE TABLE `leadership_group` (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(100) NOT NULL,
  `is_active`  TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(254) NOT NULL,
  `created_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by` VARCHAR(254) NOT NULL,
  `updated_on` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                 ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_leadership_group_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audits changes to the attribute list itself, the way career_function_audit does
-- for career functions. A rename or retirement changes what every holder's profile,
-- report and CSV column shows, so the previous value has to be recoverable.
CREATE TABLE `leadership_group_audit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `leadership_group_pk_id` int DEFAULT NULL,
  `action_type` enum('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `action_by` varchar(254) NOT NULL,
  `db_user` varchar(254) NULL,
  `action_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `data` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_lg_audit_leadership_group_pk` (`leadership_group_pk_id`),
  KEY `idx_lg_audit_action_on` (`action_on`),
  CONSTRAINT `fk_lg_audit_leadership_group`
    FOREIGN KEY (`leadership_group_pk_id`) REFERENCES `leadership_group` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Arguments are passed positionally from both triggers below. Adding a column
-- means adding it at the same ordinal in this signature and in BOTH CALL
-- argument lists, or every later argument shifts and the audit JSON is silently
-- written with values in the wrong keys.
DELIMITER //
CREATE PROCEDURE `prc_leadership_group_audit`(
  IN p_id          INT,
  IN p_action_type VARCHAR(10),
  IN p_action_by   VARCHAR(254),
  IN p_name        VARCHAR(100),
  IN p_is_active   TINYINT(1),
  IN p_created_by  VARCHAR(254),
  IN p_created_on  DATETIME(6),
  IN p_updated_by  VARCHAR(254),
  IN p_updated_on  DATETIME(6)
)
BEGIN
  INSERT INTO leadership_group_audit
    (leadership_group_pk_id, action_type, action_by, db_user, action_on, data)
  VALUES (
    p_id,
    p_action_type,
    p_action_by,
    USER(),
    CURRENT_TIMESTAMP(6),
    JSON_OBJECT(
      'id',         p_id,
      'name',       p_name,
      'is_active',  p_is_active,
      'created_by', p_created_by,
      'created_on', p_created_on,
      'updated_by', p_updated_by,
      'updated_on', p_updated_on
    )
  );
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER `trg_leadership_group_audit_insert`
AFTER INSERT ON `leadership_group`
FOR EACH ROW
BEGIN
  CALL prc_leadership_group_audit(
    NEW.id, 'INSERT', COALESCE(NULLIF(TRIM(NEW.created_by), ''), 'SYSTEM'),
    NEW.name,       NEW.is_active,
    NEW.created_by, NEW.created_on,
    NEW.updated_by, NEW.updated_on
  );
END//
DELIMITER ;

-- Logs DELETE when is_active flips 1 -> 0, UPDATE otherwise.
DELIMITER //
CREATE TRIGGER `trg_leadership_group_audit_update`
AFTER UPDATE ON `leadership_group`
FOR EACH ROW
BEGIN
  CALL prc_leadership_group_audit(
    NEW.id,
    CASE WHEN OLD.is_active = 1 AND NEW.is_active = 0 THEN 'DELETE' ELSE 'UPDATE' END,
    COALESCE(NULLIF(TRIM(NEW.updated_by), ''), 'SYSTEM'),
    NEW.name,       NEW.is_active,
    NEW.created_by, NEW.created_on,
    NEW.updated_by, NEW.updated_on
  );
END//
DELIMITER ;

-- Seeded after the audit triggers exist, so the audit log starts from the first row.
INSERT IGNORE INTO `leadership_group` (`name`, `created_by`, `updated_by`) VALUES
  ('Leadership Group',    'MIGRATION', 'MIGRATION'),
  ('Business Leadership', 'MIGRATION', 'MIGRATION'),
  ('Senior Leadership',   'MIGRATION', 'MIGRATION');

CREATE TABLE `employee_leadership` (
  `id`                  INT NOT NULL AUTO_INCREMENT,
  `employee_pk_id`      INT NOT NULL,
  `leadership_group_id` INT NOT NULL,
  `is_active`           TINYINT(1) NOT NULL DEFAULT 1,
  `created_by`          VARCHAR(254) NOT NULL,
  `created_on`          TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_by`          VARCHAR(254) NOT NULL,
  `updated_on`          TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                          ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_el_employee_group` (`employee_pk_id`, `leadership_group_id`),
  KEY `idx_el_group` (`leadership_group_id`),
  CONSTRAINT `fk_el_employee`
    FOREIGN KEY (`employee_pk_id`) REFERENCES `employee` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_el_group`
    FOREIGN KEY (`leadership_group_id`) REFERENCES `leadership_group` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `employee_leadership_audit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_pk_id` int DEFAULT NULL,
  `action_type` enum('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `action_by` varchar(254) NOT NULL,
  `db_user` varchar(254) NULL,
  `action_on` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `data` json NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_el_audit_employee_pk_id` (`employee_pk_id`),
  KEY `idx_el_audit_action_on` (`action_on`),
  CONSTRAINT `fk_employee_leadership_audit_employee_pk_id`
    FOREIGN KEY (`employee_pk_id`) REFERENCES `employee` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Arguments are passed positionally from both triggers below. Adding a column
-- means adding it at the same ordinal in this signature and in BOTH CALL
-- argument lists, or every later argument shifts and the audit JSON is silently
-- written with values in the wrong keys.
DELIMITER //
CREATE PROCEDURE `prc_employee_leadership_audit`(
  IN p_employee_pk_id      BIGINT,
  IN p_action_type         VARCHAR(10),
  IN p_action_by           VARCHAR(254),
  IN p_id                  BIGINT,
  IN p_leadership_group_id INT,
  IN p_is_active           TINYINT(1),
  IN p_previous_is_active  TINYINT(1),
  IN p_created_by          VARCHAR(254),
  IN p_created_on          DATETIME(6),
  IN p_updated_by          VARCHAR(254),
  IN p_updated_on          DATETIME(6)
)
BEGIN
  INSERT INTO employee_leadership_audit
    (employee_pk_id, action_type, action_by, db_user, action_on, data)
  VALUES (
    p_employee_pk_id,
    p_action_type,
    p_action_by,
    USER(),
    CURRENT_TIMESTAMP(6),
    JSON_OBJECT(
      'id',                  p_id,
      'employee_pk_id',      p_employee_pk_id,
      'leadership_group_id', p_leadership_group_id,
      'is_active',           p_is_active,
      -- NULL on INSERT. On UPDATE it tells a re-assignment (0 -> 1) apart from a
      -- re-save of an attribute already held (1 -> 1); both are logged as UPDATE.
      'previous_is_active',  p_previous_is_active,
      'created_by',          p_created_by,
      'created_on',          p_created_on,
      'updated_by',          p_updated_by,
      'updated_on',          p_updated_on
    )
  );
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER `trg_employee_leadership_audit_insert`
AFTER INSERT ON `employee_leadership`
FOR EACH ROW
BEGIN
  CALL prc_employee_leadership_audit(
    NEW.employee_pk_id,
    'INSERT',
    COALESCE(NULLIF(TRIM(NEW.created_by), ''), 'SYSTEM'),
    NEW.id,         NEW.leadership_group_id, NEW.is_active, NULL,
    NEW.created_by, NEW.created_on,
    NEW.updated_by, NEW.updated_on
  );
END//
DELIMITER ;

-- Logs DELETE when is_active flips 1 -> 0, UPDATE otherwise.
DELIMITER //
CREATE TRIGGER `trg_employee_leadership_audit_update`
AFTER UPDATE ON `employee_leadership`
FOR EACH ROW
BEGIN
  CALL prc_employee_leadership_audit(
    NEW.employee_pk_id,
    CASE WHEN OLD.is_active = 1 AND NEW.is_active = 0 THEN 'DELETE' ELSE 'UPDATE' END,
    COALESCE(NULLIF(TRIM(NEW.updated_by), ''), 'SYSTEM'),
    NEW.id,         NEW.leadership_group_id, NEW.is_active, OLD.is_active,
    NEW.created_by, NEW.created_on,
    NEW.updated_by, NEW.updated_on
  );
END//
DELIMITER ;
