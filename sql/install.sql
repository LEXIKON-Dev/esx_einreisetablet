CREATE TABLE IF NOT EXISTS `einreisetablet_status` (
    `identifier` VARCHAR(60) NOT NULL,
    `eingereist` TINYINT(1) NOT NULL DEFAULT 0,
    `eingereist_at` TIMESTAMP NULL DEFAULT NULL,
    `eingereist_by` VARCHAR(100) NULL DEFAULT NULL,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `einreisetablet_questions` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `question` TEXT NOT NULL,
    `sort_order` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `einreisetablet_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `target_identifier` VARCHAR(60) NOT NULL,
    `target_name` VARCHAR(100) NOT NULL,
    `staff_identifier` VARCHAR(60) NOT NULL,
    `staff_name` VARCHAR(100) NOT NULL,
    `action` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
