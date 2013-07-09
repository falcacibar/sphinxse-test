USE `sphinxse-test`;

INSTALL PLUGIN sphinx SONAME 'ha_sphinx.so';

CREATE TABLE `sphinxse-test` (
	`id` BIGINT(20) UNSIGNED NOT NULL,
	`weight` BIGINT(20) NOT NULL,
	`query` VARCHAR(3072) NOT NULL,
	`group_id` BIGINT(20) NULL DEFAULT NULL,
	INDEX `query` (`query`(1024))
)
COLLATE='utf8_general_ci'
ENGINE=SPHINX;

