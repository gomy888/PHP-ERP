-- =============================================================
--  智美成ERP系统 系统 · 全量数据库结构 (MySQL 8.0 / InnoDB / utf8mb4)
--  模块: 系统管理 / 基础资料 / 采购 / 销售业务 / 财务 / 仓库 / 生产
--  约定: 所有可编辑主表带 version(乐观锁) + updated_by(并发追溯)
-- =============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET @OLD_SQL_MODE = @@SQL_MODE;
SET SQL_MODE = 'NO_ENGINE_SUBSTITUTION';

CREATE DATABASE IF NOT EXISTS `erp_php`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `erp_php`;

-- =============================================================
--  一、系统管理 (后台管理)
-- =============================================================

DROP TABLE IF EXISTS `sys_user`;
CREATE TABLE `sys_user` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`      VARCHAR(50)  NOT NULL                COMMENT '登录账号',
  `password_hash` VARCHAR(255) NOT NULL                COMMENT 'password_hash() 散列',
  `real_name`     VARCHAR(50)  NOT NULL DEFAULT ''     COMMENT '姓名',
  `email`         VARCHAR(120) NOT NULL DEFAULT '',
  `phone`         VARCHAR(30)  NOT NULL DEFAULT '',
  `dept_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `role_id`       BIGINT UNSIGNED NOT NULL DEFAULT 1,
  `position_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0  COMMENT '部门岗位(部门级权限模板)',
  `status`        TINYINT      NOT NULL DEFAULT 1      COMMENT '1启用 0停用',
  `is_locked`     TINYINT      NOT NULL DEFAULT 0      COMMENT '登录锁定标记',
  `fail_count`    INT          NOT NULL DEFAULT 0,
  `last_login_at` DATETIME     NULL,
  `last_login_ip` VARCHAR(45)  NOT NULL DEFAULT '',
  `remark`        VARCHAR(255) NOT NULL DEFAULT '',
  `version`       INT          NOT NULL DEFAULT 1      COMMENT '乐观锁',
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_username` (`username`),
  KEY `idx_user_role` (`role_id`),
  KEY `idx_user_dept` (`dept_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统用户';

DROP TABLE IF EXISTS `sys_role`;
CREATE TABLE `sys_role` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`        VARCHAR(50)  NOT NULL                COMMENT '角色标识',
  `name`        VARCHAR(50)  NOT NULL                COMMENT '角色名称',
  `data_scope`  ENUM('all','dept','dept_child','self') NOT NULL DEFAULT 'all' COMMENT '数据范围:全部/本部门/本部门及下级/仅本人',
  `sort`        INT          NOT NULL DEFAULT 0,
  `status`      TINYINT      NOT NULL DEFAULT 1,
  `remark`      VARCHAR(255) NOT NULL DEFAULT '',
  `version`     INT          NOT NULL DEFAULT 1,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_role_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色';

DROP TABLE IF EXISTS `sys_permission`;
CREATE TABLE `sys_permission` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(80)  NOT NULL                COMMENT '权限码 如 purchase.order.edit',
  `name`       VARCHAR(80)  NOT NULL,
  `module`     VARCHAR(30)  NOT NULL DEFAULT ''     COMMENT '所属模块',
  `type`       ENUM('menu','action') NOT NULL DEFAULT 'action',
  `parent_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `sort`       INT          NOT NULL DEFAULT 0,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_perm_code` (`code`),
  KEY `idx_perm_module` (`module`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='权限项';

DROP TABLE IF EXISTS `sys_role_permission`;
CREATE TABLE `sys_role_permission` (
  `role_id`       BIGINT UNSIGNED NOT NULL,
  `permission_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`role_id`, `permission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色权限关联';

DROP TABLE IF EXISTS `sys_dept`;
CREATE TABLE `sys_dept` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `parent_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `code`       VARCHAR(50)  NOT NULL DEFAULT '',
  `name`       VARCHAR(50)  NOT NULL,
  `leader`     VARCHAR(50)  NOT NULL DEFAULT '',
  `phone`      VARCHAR(30)  NOT NULL DEFAULT '',
  `sort`       INT          NOT NULL DEFAULT 0,
  `status`     TINYINT      NOT NULL DEFAULT 1,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  `version`    INT          NOT NULL DEFAULT 1,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_dept_parent` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='部门';

DROP TABLE IF EXISTS `sys_dept_position`;
CREATE TABLE `sys_dept_position` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `dept_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0  COMMENT '所属部门,0=全局岗位(所有部门可用)',
  `code`        VARCHAR(50)  NOT NULL                COMMENT '岗位标识',
  `name`        VARCHAR(50)  NOT NULL                COMMENT '岗位名称 如 业务员工/部门主管',
  `data_scope`  ENUM('all','dept','dept_child','self') NOT NULL DEFAULT 'dept' COMMENT '该岗位的数据范围',
  `is_manager`  TINYINT      NOT NULL DEFAULT 0      COMMENT '1=部门管理者(可见本部门及下级)',
  `status`      TINYINT      NOT NULL DEFAULT 1,
  `sort`        INT          NOT NULL DEFAULT 0,
  `remark`      VARCHAR(255) NOT NULL DEFAULT '',
  `version`     INT          NOT NULL DEFAULT 1,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_position_code` (`dept_id`, `code`),
  KEY `idx_position_dept` (`dept_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='部门岗位(部门级权限模板)';

DROP TABLE IF EXISTS `sys_position_permission`;
CREATE TABLE `sys_position_permission` (
  `position_id`   BIGINT UNSIGNED NOT NULL,
  `permission_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`position_id`, `permission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='岗位权限关联';

DROP TABLE IF EXISTS `sys_config`;
CREATE TABLE `sys_config` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key`   VARCHAR(80)  NOT NULL,
  `config_value` VARCHAR(500) NOT NULL DEFAULT '',
  `config_group` VARCHAR(50)  NOT NULL DEFAULT 'common',
  `remark`       VARCHAR(255) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cfg_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统参数';

DROP TABLE IF EXISTS `sys_dict_type`;
CREATE TABLE `sys_dict_type` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `dict_type`  VARCHAR(50)  NOT NULL,
  `dict_name`  VARCHAR(80)  NOT NULL,
  `status`     TINYINT      NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_dict_type` (`dict_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='字典类型';

DROP TABLE IF EXISTS `sys_dict_item`;
CREATE TABLE `sys_dict_item` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `dict_type_id` BIGINT UNSIGNED NOT NULL,
  `item_label`  VARCHAR(80)  NOT NULL,
  `item_value`  VARCHAR(80)  NOT NULL DEFAULT '',
  `sort`        INT          NOT NULL DEFAULT 0,
  `status`      TINYINT      NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_dict_item_type` (`dict_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='字典项';

DROP TABLE IF EXISTS `sys_log`;
CREATE TABLE `sys_log` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `user_name`   VARCHAR(50)  NOT NULL DEFAULT '',
  `module`      VARCHAR(30)  NOT NULL DEFAULT '',
  `action`      VARCHAR(50)  NOT NULL DEFAULT '',
  `target_type` VARCHAR(50)  NOT NULL DEFAULT '',
  `target_id`   VARCHAR(50)  NOT NULL DEFAULT '',
  `detail`      TEXT         NULL,
  `ip`          VARCHAR(45)  NOT NULL DEFAULT '',
  `user_agent`  VARCHAR(255) NOT NULL DEFAULT '',
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_log_user` (`user_id`),
  KEY `idx_log_module` (`module`),
  KEY `idx_log_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='操作审计日志';

DROP TABLE IF EXISTS `sys_login_log`;
CREATE TABLE `sys_login_log` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`   VARCHAR(50)  NOT NULL DEFAULT '',
  `user_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `ip`         VARCHAR(45)  NOT NULL DEFAULT '',
  `success`    TINYINT      NOT NULL DEFAULT 0,
  `message`    VARCHAR(255) NOT NULL DEFAULT '',
  `user_agent` VARCHAR(255) NOT NULL DEFAULT '',
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_login_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='登录日志';

DROP TABLE IF EXISTS `sys_online`;
CREATE TABLE `sys_online` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `session_id`    VARCHAR(64)  NOT NULL,
  `user_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `username`      VARCHAR(50)  NOT NULL DEFAULT '',
  `real_name`     VARCHAR(50)  NOT NULL DEFAULT '',
  `ip`            VARCHAR(45)  NOT NULL DEFAULT '',
  `user_agent`    VARCHAR(255) NOT NULL DEFAULT '',
  `module`        VARCHAR(30)  NOT NULL DEFAULT '',
  `resource_type` VARCHAR(50)  NOT NULL DEFAULT '',
  `resource_id`   VARCHAR(50)  NOT NULL DEFAULT '',
  `is_editing`    TINYINT      NOT NULL DEFAULT 0      COMMENT '是否正在编辑单据',
  `dirty`         TINYINT      NOT NULL DEFAULT 0      COMMENT '是否有未保存修改',
  `last_active_at` DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_online_session` (`session_id`),
  KEY `idx_online_active` (`last_active_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='在线用户/编辑占用';

DROP TABLE IF EXISTS `editing_lock`;
CREATE TABLE `editing_lock` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`       BIGINT UNSIGNED NOT NULL,
  `username`      VARCHAR(50)  NOT NULL DEFAULT '',
  `real_name`     VARCHAR(50)  NOT NULL DEFAULT '',
  `session_id`    VARCHAR(64)  NOT NULL DEFAULT '',
  `resource_type` VARCHAR(50)  NOT NULL,
  `resource_id`   VARCHAR(50)  NOT NULL,
  `resource_name` VARCHAR(120) NOT NULL DEFAULT '',
  `heartbeat_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_edit_lock` (`resource_type`, `resource_id`, `session_id`),
  KEY `idx_edit_hb` (`heartbeat_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='单据编辑占用锁';

DROP TABLE IF EXISTS `sys_sequence`;
CREATE TABLE `sys_sequence` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `prefix`     VARCHAR(20) NOT NULL,
  `biz_date`   DATE         NOT NULL,
  `current_no` INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_seq` (`prefix`, `biz_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='单据流水号';

-- =============================================================
--  二、基础资料
-- =============================================================

DROP TABLE IF EXISTS `md_unit`;
CREATE TABLE `md_unit` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(30)  NOT NULL,
  `name`       VARCHAR(30)  NOT NULL,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  `status`     TINYINT      NOT NULL DEFAULT 1,
  `version`    INT          NOT NULL DEFAULT 1,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_unit_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='计量单位';

DROP TABLE IF EXISTS `md_category`;
CREATE TABLE `md_category` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(30)  NOT NULL,
  `name`       VARCHAR(50)  NOT NULL,
  `parent_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `sort`       INT          NOT NULL DEFAULT 0,
  `status`     TINYINT      NOT NULL DEFAULT 1,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  `version`    INT          NOT NULL DEFAULT 1,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cat_code` (`code`),
  KEY `idx_cat_parent` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物料分类';

DROP TABLE IF EXISTS `md_product`;
CREATE TABLE `md_product` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`          VARCHAR(40)  NOT NULL                COMMENT '物料编码',
  `name`          VARCHAR(100) NOT NULL                COMMENT '名称',
  `spec`          VARCHAR(100) NOT NULL DEFAULT ''     COMMENT '规格',
  `unit_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `category_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `product_type`  ENUM('raw','semi','finished','goods','service') NOT NULL DEFAULT 'goods' COMMENT '原料/半成品/成品/商品/服务',
  `standard_cost` DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  `sale_price`    DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  `safety_stock`  DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '安全库存',
  `defect_rate`   DECIMAL(6,2)  NOT NULL DEFAULT 0.00   COMMENT '生产不良率(%),MRP 展开时按此多投产',
  `tax_rate`      DECIMAL(6,2)  NOT NULL DEFAULT 13.00,
  `barcode`       VARCHAR(60)  NOT NULL DEFAULT '',
  `is_batch`      TINYINT      NOT NULL DEFAULT 0,
  `status`        TINYINT      NOT NULL DEFAULT 1,
  `remark`        VARCHAR(255) NOT NULL DEFAULT '',
  `version`       INT          NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_code` (`code`),
  KEY `idx_product_type` (`product_type`),
  KEY `idx_product_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物料/商品';

DROP TABLE IF EXISTS `md_warehouse`;
CREATE TABLE `md_warehouse` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(30)  NOT NULL,
  `name`       VARCHAR(80)  NOT NULL,
  `type`       ENUM('raw','semi','finished','general') NOT NULL DEFAULT 'general',
  `location`   VARCHAR(120) NOT NULL DEFAULT '',
  `manager`    VARCHAR(50)  NOT NULL DEFAULT '',
  `phone`      VARCHAR(30)  NOT NULL DEFAULT '',
  `is_default` TINYINT      NOT NULL DEFAULT 0,
  `status`     TINYINT      NOT NULL DEFAULT 1,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  `version`    INT          NOT NULL DEFAULT 1,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_wh_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='仓库';

DROP TABLE IF EXISTS `md_customer`;
CREATE TABLE `md_customer` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`         VARCHAR(30)  NOT NULL,
  `name`         VARCHAR(120) NOT NULL,
  `short_name`   VARCHAR(60)  NOT NULL DEFAULT '',
  `type`         ENUM('company','individual') NOT NULL DEFAULT 'company',
  `contact`      VARCHAR(50)  NOT NULL DEFAULT '',
  `phone`        VARCHAR(30)  NOT NULL DEFAULT '',
  `email`        VARCHAR(120) NOT NULL DEFAULT '',
  `address`      VARCHAR(200) NOT NULL DEFAULT '',
  `tax_no`       VARCHAR(60)  NOT NULL DEFAULT '',
  `bank_name`    VARCHAR(120) NOT NULL DEFAULT '',
  `bank_account` VARCHAR(60)  NOT NULL DEFAULT '',
  `credit_limit` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '信用额度',
  `credit_days`  INT          NOT NULL DEFAULT 30    COMMENT '账期(天)',
  `salesman_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`       TINYINT      NOT NULL DEFAULT 1,
  `remark`       VARCHAR(255) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_customer_code` (`code`),
  KEY `idx_customer_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户';

DROP TABLE IF EXISTS `md_supplier`;
CREATE TABLE `md_supplier` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`         VARCHAR(30)  NOT NULL,
  `name`         VARCHAR(120) NOT NULL,
  `short_name`   VARCHAR(60)  NOT NULL DEFAULT '',
  `type`         ENUM('company','individual') NOT NULL DEFAULT 'company',
  `contact`      VARCHAR(50)  NOT NULL DEFAULT '',
  `phone`        VARCHAR(30)  NOT NULL DEFAULT '',
  `email`        VARCHAR(120) NOT NULL DEFAULT '',
  `address`      VARCHAR(200) NOT NULL DEFAULT '',
  `tax_no`       VARCHAR(60)  NOT NULL DEFAULT '',
  `bank_name`    VARCHAR(120) NOT NULL DEFAULT '',
  `bank_account` VARCHAR(60)  NOT NULL DEFAULT '',
  `pay_days`     INT          NOT NULL DEFAULT 30    COMMENT '付款账期(天)',
  `pay_terms`    VARCHAR(20)  NOT NULL DEFAULT 'credit' COMMENT '付款条件 prepay=预付款(款到发货) credit=账期(货到付款)',
  `prepay_rate`  DECIMAL(6,2) NOT NULL DEFAULT 0.00   COMMENT '默认预付比例(%)',
  `status`       TINYINT      NOT NULL DEFAULT 1,
  `remark`       VARCHAR(255) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_supplier_code` (`code`),
  KEY `idx_supplier_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='供应商';

DROP TABLE IF EXISTS `md_employee`;
CREATE TABLE `md_employee` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(30)  NOT NULL,
  `name`       VARCHAR(50)  NOT NULL,
  `dept_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `position`   VARCHAR(50)  NOT NULL DEFAULT '',
  `phone`      VARCHAR(30)  NOT NULL DEFAULT '',
  `email`      VARCHAR(120) NOT NULL DEFAULT '',
  `status`     TINYINT      NOT NULL DEFAULT 1,
  -- 人力资源档案
  `id_card`    VARCHAR(40)  NOT NULL DEFAULT '' COMMENT '身份证号',
  `gender`     VARCHAR(10)  NOT NULL DEFAULT '' COMMENT '性别',
  `birth_date` DATE         NULL COMMENT '出生日期',
  `education`  VARCHAR(30)  NOT NULL DEFAULT '' COMMENT '学历',
  `hire_date`  DATE         NULL COMMENT '入职日期',
  `leave_date` DATE         NULL COMMENT '离职日期',
  `employ_status` VARCHAR(20) NOT NULL DEFAULT 'regular' COMMENT '用工状态 probation/regular/left',
  `bank_account` VARCHAR(60) NOT NULL DEFAULT '' COMMENT '工资银行卡号',
  `emergency_contact` VARCHAR(50) NOT NULL DEFAULT '' COMMENT '紧急联系人',
  `emergency_phone`   VARCHAR(30) NOT NULL DEFAULT '' COMMENT '紧急联系电话',
  `remark`            VARCHAR(255) NOT NULL DEFAULT '' COMMENT '备注',
  `base_salary`      DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '基本工资',
  `post_salary`      DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '岗位工资',
  `performance_salary` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '绩效工资',
  `insurance_rate`   DECIMAL(6,2)  NOT NULL DEFAULT 10.00 COMMENT '社保公积金比例(%)',
  `tax_rate`         DECIMAL(6,2)  NOT NULL DEFAULT 0.00 COMMENT '个税预扣比例(%)',
  -- 五险一金分项(缴费基数 0 = 用工资基数(基本+岗位+绩效+津贴);个人比例 -1 = 用系统默认)
  `si_pension_base`      DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '养老保险缴费基数(0=工资基数)',
  `si_medical_base`      DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '医疗保险缴费基数(0=工资基数)',
  `si_unemployment_base` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '失业保险缴费基数(0=工资基数)',
  `si_housing_fund_base` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '住房公积金缴费基数(0=工资基数)',
  `si_pension_rate`      DECIMAL(6,2)  NOT NULL DEFAULT -1.00 COMMENT '养老保险个人比例(%)(-1=系统默认)',
  `si_medical_rate`      DECIMAL(6,2)  NOT NULL DEFAULT -1.00 COMMENT '医疗保险个人比例(%)(-1=系统默认)',
  `si_unemployment_rate` DECIMAL(6,2)  NOT NULL DEFAULT -1.00 COMMENT '失业保险个人比例(%)(-1=系统默认)',
  `si_housing_fund_rate` DECIMAL(6,2)  NOT NULL DEFAULT -1.00 COMMENT '住房公积金个人比例(%)(-1=系统默认)',
  -- 个税专项附加扣除(按月填写,单位:元/月)
  `tax_child_edu`      DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '子女教育扣除(元/月)',
  `tax_infant_care`    DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '3岁以下婴幼儿照护扣除(元/月)',
  `tax_continuing_edu` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '继续教育扣除(元/月)',
  `tax_medical_major`  DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '大病医疗扣除(元/月)',
  `tax_housing_loan`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '住房贷款利息扣除(元/月)',
  `tax_housing_rent`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '住房租金扣除(元/月)',
  `tax_elderly`        DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '赡养老人扣除(元/月)',
  `version`    INT          NOT NULL DEFAULT 1,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_emp_code` (`code`),
  KEY `idx_emp_dept` (`dept_id`),
  KEY `idx_emp_status` (`employ_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='员工(人力资源档案)';

-- =============================================================
--  三、采购管理
-- =============================================================

DROP TABLE IF EXISTS `pur_request`;
CREATE TABLE `pur_request` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`       VARCHAR(40)  NOT NULL                COMMENT '单号',
  `title`        VARCHAR(120) NOT NULL DEFAULT '',
  `req_date`     DATE         NOT NULL,
  `dept_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `requester_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `supplier_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`       ENUM('draft','submitted','approved','ordered','closed','void') NOT NULL DEFAULT 'draft',
  `total_qty`    DECIMAL(18,4) NOT NULL DEFAULT 0,
  `total_amount` DECIMAL(18,2) NOT NULL DEFAULT 0,
  `remark`       VARCHAR(500) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at`  DATETIME     NULL,
  `approved_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `closed_at`    DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pur_req_no` (`doc_no`),
  KEY `idx_pur_req_status` (`status`),
  KEY `idx_pur_req_date` (`req_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='请购单';

DROP TABLE IF EXISTS `pur_request_item`;
CREATE TABLE `pur_request_item` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `request_id` BIGINT UNSIGNED NOT NULL,
  `line_no`    INT          NOT NULL DEFAULT 0,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `qty`        DECIMAL(18,4) NOT NULL DEFAULT 0,
  `unit_price` DECIMAL(18,4) NOT NULL DEFAULT 0,
  `amount`     DECIMAL(18,2) NOT NULL DEFAULT 0,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_pur_req_item` (`request_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='请购明细';

DROP TABLE IF EXISTS `pur_order`;
CREATE TABLE `pur_order` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`        VARCHAR(40)  NOT NULL,
  `title`         VARCHAR(120) NOT NULL DEFAULT '',
  `order_date`    DATE         NOT NULL,
  `supplier_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `request_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `dept_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `buyer_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`        ENUM('draft','submitted','approved','partial','received','closed','void') NOT NULL DEFAULT 'draft',
  `total_qty`     DECIMAL(18,4) NOT NULL DEFAULT 0,
  `total_amount`  DECIMAL(18,2) NOT NULL DEFAULT 0,
  `tax_rate`      DECIMAL(6,2)  NOT NULL DEFAULT 13.00,
  `tax_amount`    DECIMAL(18,2) NOT NULL DEFAULT 0,
  `pay_term`      VARCHAR(20)  NOT NULL DEFAULT 'credit' COMMENT '付款条件 prepay=预付款(款到发货) credit=账期(货到付款)',
  `prepay_rate`   DECIMAL(6,2)  NOT NULL DEFAULT 0.00   COMMENT '预付比例(%)',
  `prepay_amount` DECIMAL(18,2) NOT NULL DEFAULT 0.00   COMMENT '预付金额(审核时按比例计算)',
  `delivery_date` DATE         NULL,
  `remark`        VARCHAR(500) NOT NULL DEFAULT '',
  `version`       INT          NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at`   DATETIME     NULL,
  `approved_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `closed_at`     DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pur_order_no` (`doc_no`),
  KEY `idx_pur_order_status` (`status`),
  KEY `idx_pur_order_supplier` (`supplier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购订单';

DROP TABLE IF EXISTS `pur_order_item`;
CREATE TABLE `pur_order_item` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id`     BIGINT UNSIGNED NOT NULL,
  `line_no`      INT          NOT NULL DEFAULT 0,
  `product_id`   BIGINT UNSIGNED NOT NULL,
  `qty`          DECIMAL(18,4) NOT NULL DEFAULT 0,
  `received_qty` DECIMAL(18,4) NOT NULL DEFAULT 0,
  `price`        DECIMAL(18,4) NOT NULL DEFAULT 0,
  `tax_rate`     DECIMAL(6,2)  NOT NULL DEFAULT 13.00,
  `amount`       DECIMAL(18,2) NOT NULL DEFAULT 0,
  `warehouse_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `remark`       VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_pur_order_item` (`order_id`),
  KEY `idx_pur_order_item_prod` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购订单明细';

DROP TABLE IF EXISTS `pur_receipt`;
CREATE TABLE `pur_receipt` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`       VARCHAR(40)  NOT NULL,
  `receipt_date` DATE         NOT NULL,
  `dept_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `order_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `contract_no`     VARCHAR(60)  NOT NULL DEFAULT '' COMMENT '关联合同编号',
  `contract_end_date` DATE       NULL COMMENT '合同到期日(到期提醒)',
  `supplier_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `warehouse_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `keeper_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`       ENUM('draft','posted','invoiced','void') NOT NULL DEFAULT 'draft',
  `total_qty`    DECIMAL(18,4) NOT NULL DEFAULT 0,
  `total_amount` DECIMAL(18,2) NOT NULL DEFAULT 0,
  `invoice_type` VARCHAR(20)  NOT NULL DEFAULT 'general' COMMENT '发票类型 general=普票 vat_special=增值税专用发票',
  `invoice_no`   VARCHAR(40)  NOT NULL DEFAULT '' COMMENT '发票号码',
  `invoice_date` DATE         NULL COMMENT '开票日期',
  `tax_rate`     DECIMAL(6,2)  NOT NULL DEFAULT 13.00 COMMENT '税率(%)',
  `amount_excl_tax` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '不含税金额(价税分离)',
  `tax_amount`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '税额(普票为0,专票可抵扣进项)',
  `remark`       VARCHAR(500) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `posted_at`    DATETIME     NULL,
  `posted_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pur_receipt_no` (`doc_no`),
  KEY `idx_pur_receipt_order` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购收货单';

DROP TABLE IF EXISTS `pur_receipt_item`;
CREATE TABLE `pur_receipt_item` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `receipt_id`    BIGINT UNSIGNED NOT NULL,
  `order_item_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `product_id`    BIGINT UNSIGNED NOT NULL,
  `qty`           DECIMAL(18,4) NOT NULL DEFAULT 0,
  `price`         DECIMAL(18,4) NOT NULL DEFAULT 0,
  `amount`        DECIMAL(18,2) NOT NULL DEFAULT 0,
  `batch_no`      VARCHAR(60)  NOT NULL DEFAULT '',
  `remark`        VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_pur_receipt_item` (`receipt_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购收货明细';

-- =============================================================
--  四、销售业务
-- =============================================================

DROP TABLE IF EXISTS `sal_quotation`;
CREATE TABLE `sal_quotation` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`      VARCHAR(40)  NOT NULL,
  `title`       VARCHAR(120) NOT NULL DEFAULT '',
  `quote_date`  DATE         NOT NULL,
  `dept_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `customer_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `salesman_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`      ENUM('draft','submitted','approved','ordered','void') NOT NULL DEFAULT 'draft',
  `total_qty`   DECIMAL(18,4) NOT NULL DEFAULT 0,
  `total_amount` DECIMAL(18,2) NOT NULL DEFAULT 0,
  `valid_until` DATE         NULL,
  `remark`      VARCHAR(500) NOT NULL DEFAULT '',
  `version`     INT          NOT NULL DEFAULT 1,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at` DATETIME     NULL,
  `approved_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sal_quo_no` (`doc_no`),
  KEY `idx_sal_quo_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售报价单';

DROP TABLE IF EXISTS `sal_quotation_item`;
CREATE TABLE `sal_quotation_item` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `quotation_id` BIGINT UNSIGNED NOT NULL,
  `line_no`      INT          NOT NULL DEFAULT 0,
  `product_id`   BIGINT UNSIGNED NOT NULL,
  `qty`          DECIMAL(18,4) NOT NULL DEFAULT 0,
  `price`        DECIMAL(18,4) NOT NULL DEFAULT 0,
  `discount`     DECIMAL(6,2)  NOT NULL DEFAULT 100.00 COMMENT '折扣率%',
  `amount`       DECIMAL(18,2) NOT NULL DEFAULT 0,
  `delivery_days` INT         NOT NULL DEFAULT 0,
  `remark`       VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_sal_quo_item` (`quotation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='报价明细';

DROP TABLE IF EXISTS `sal_order`;
CREATE TABLE `sal_order` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`        VARCHAR(40)  NOT NULL,
  `title`         VARCHAR(120) NOT NULL DEFAULT '',
  `order_date`    DATE         NOT NULL,
  `dept_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `customer_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `salesman_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `quotation_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`        ENUM('draft','submitted','approved','partial','delivered','closed','void') NOT NULL DEFAULT 'draft',
  `total_qty`     DECIMAL(18,4) NOT NULL DEFAULT 0,
  `total_amount`  DECIMAL(18,2) NOT NULL DEFAULT 0,
  `tax_rate`      DECIMAL(6,2)  NOT NULL DEFAULT 13.00,
  `tax_amount`    DECIMAL(18,2) NOT NULL DEFAULT 0,
  `delivery_date` DATE         NULL,
  `settle_type`   ENUM('cash','credit','monthly') NOT NULL DEFAULT 'cash',
  `remark`        VARCHAR(500) NOT NULL DEFAULT '',
  `version`       INT          NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at`   DATETIME     NULL,
  `approved_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `closed_at`     DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sal_order_no` (`doc_no`),
  KEY `idx_sal_order_status` (`status`),
  KEY `idx_sal_order_customer` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售订单';

DROP TABLE IF EXISTS `sal_order_item`;
CREATE TABLE `sal_order_item` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id`      BIGINT UNSIGNED NOT NULL,
  `line_no`       INT          NOT NULL DEFAULT 0,
  `product_id`    BIGINT UNSIGNED NOT NULL,
  `qty`           DECIMAL(18,4) NOT NULL DEFAULT 0,
  `delivered_qty` DECIMAL(18,4) NOT NULL DEFAULT 0,
  `price`         DECIMAL(18,4) NOT NULL DEFAULT 0,
  `discount`      DECIMAL(6,2)  NOT NULL DEFAULT 100.00,
  `amount`        DECIMAL(18,2) NOT NULL DEFAULT 0,
  `warehouse_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `remark`        VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_sal_order_item` (`order_id`),
  KEY `idx_sal_order_item_prod` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售订单明细';

DROP TABLE IF EXISTS `sal_delivery`;
CREATE TABLE `sal_delivery` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`       VARCHAR(40)  NOT NULL,
  `delivery_date` DATE        NOT NULL,
  `dept_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `order_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `contract_no`     VARCHAR(60)  NOT NULL DEFAULT '' COMMENT '关联合同编号',
  `contract_end_date` DATE       NULL COMMENT '合同到期日(到期提醒)',
  `customer_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `warehouse_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `keeper_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`       ENUM('draft','posted','invoiced','closed','void') NOT NULL DEFAULT 'draft',
  `total_qty`    DECIMAL(18,4) NOT NULL DEFAULT 0,
  `total_amount` DECIMAL(18,2) NOT NULL DEFAULT 0,
  `invoice_type` VARCHAR(20)  NOT NULL DEFAULT 'general' COMMENT '发票类型 general=普票 vat_special=增值税专用发票',
  `invoice_no`   VARCHAR(40)  NOT NULL DEFAULT '' COMMENT '发票号码',
  `invoice_date` DATE         NULL COMMENT '开票日期',
  `tax_rate`     DECIMAL(6,2)  NOT NULL DEFAULT 13.00 COMMENT '税率(%)',
  `amount_excl_tax` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '不含税金额(价税分离)',
  `tax_amount`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '销项税额(仅增值税专用发票)',
  `remark`       VARCHAR(500) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `posted_at`    DATETIME     NULL,
  `posted_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sal_del_no` (`doc_no`),
  KEY `idx_sal_del_order` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售发货单';

DROP TABLE IF EXISTS `sal_delivery_item`;
CREATE TABLE `sal_delivery_item` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `delivery_id`   BIGINT UNSIGNED NOT NULL,
  `order_item_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `product_id`    BIGINT UNSIGNED NOT NULL,
  `qty`           DECIMAL(18,4) NOT NULL DEFAULT 0,
  `price`         DECIMAL(18,4) NOT NULL DEFAULT 0,
  `amount`        DECIMAL(18,2) NOT NULL DEFAULT 0,
  `batch_no`      VARCHAR(60)  NOT NULL DEFAULT '',
  `remark`        VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_sal_del_item` (`delivery_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售发货明细';

-- =============================================================
--  五、仓库管理
-- =============================================================

DROP TABLE IF EXISTS `inv_stock`;
CREATE TABLE `inv_stock` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `warehouse_id` BIGINT UNSIGNED NOT NULL,
  `product_id`   BIGINT UNSIGNED NOT NULL,
  `qty`          DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '账面数量',
  `locked_qty`   DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '锁定数量',
  `avg_cost`     DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '移动加权平均成本',
  `total_amount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `version`      INT          NOT NULL DEFAULT 1,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_stock_wh_prod` (`warehouse_id`, `product_id`),
  KEY `idx_stock_prod` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存台账';

DROP TABLE IF EXISTS `inv_ledger`;
CREATE TABLE `inv_ledger` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `warehouse_id`  BIGINT UNSIGNED NOT NULL,
  `product_id`    BIGINT UNSIGNED NOT NULL,
  `biz_type`      VARCHAR(20)  NOT NULL                COMMENT 'purchase_receipt/sal_delivery/inv_transfer/inv_check/prd_pick/prd_report',
  `biz_id`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `biz_no`        VARCHAR(40)  NOT NULL DEFAULT '',
  `direction`     TINYINT      NOT NULL DEFAULT 1      COMMENT '1入库 -1出库',
  `qty`           DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '本次数量(正数)',
  `qty_after`     DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '变动后结存',
  `unit_cost`     DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  `amount`        DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `batch_no`      VARCHAR(60)  NOT NULL DEFAULT '',
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `remark`        VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_ledger_wh_prod` (`warehouse_id`, `product_id`),
  KEY `idx_ledger_biz` (`biz_type`, `biz_id`),
  KEY `idx_ledger_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='出入库流水';

DROP TABLE IF EXISTS `inv_transfer`;
CREATE TABLE `inv_transfer` (
  `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`            VARCHAR(40)  NOT NULL,
  `transfer_date`     DATE         NOT NULL,
  `dept_id`           BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `from_warehouse_id` BIGINT UNSIGNED NOT NULL,
  `to_warehouse_id`   BIGINT UNSIGNED NOT NULL,
  `handler_id`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`            ENUM('draft','posted','void') NOT NULL DEFAULT 'draft',
  `remark`            VARCHAR(500) NOT NULL DEFAULT '',
  `version`           INT          NOT NULL DEFAULT 1,
  `created_at`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `posted_at`         DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_inv_transfer_no` (`doc_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存调拨单';

DROP TABLE IF EXISTS `inv_transfer_item`;
CREATE TABLE `inv_transfer_item` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `transfer_id` BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `qty`        DECIMAL(18,4) NOT NULL DEFAULT 0,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_inv_transfer_item` (`transfer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='调拨明细';

DROP TABLE IF EXISTS `inv_check`;
CREATE TABLE `inv_check` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`       VARCHAR(40)  NOT NULL,
  `check_date`   DATE         NOT NULL,
  `dept_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `warehouse_id` BIGINT UNSIGNED NOT NULL,
  `checker_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`       ENUM('draft','posted','void') NOT NULL DEFAULT 'draft',
  `diff_amount`  DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `remark`       VARCHAR(500) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `posted_at`    DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_inv_check_no` (`doc_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存盘点单';

DROP TABLE IF EXISTS `inv_check_item`;
CREATE TABLE `inv_check_item` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `check_id`   BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `book_qty`   DECIMAL(18,4) NOT NULL DEFAULT 0,
  `real_qty`   DECIMAL(18,4) NOT NULL DEFAULT 0,
  `diff_qty`   DECIMAL(18,4) NOT NULL DEFAULT 0,
  `unit_cost`  DECIMAL(18,4) NOT NULL DEFAULT 0,
  `amount`     DECIMAL(18,2) NOT NULL DEFAULT 0,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_inv_check_item` (`check_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='盘点明细';

-- =============================================================
--  六、财务管理
-- =============================================================

DROP TABLE IF EXISTS `fin_account`;
CREATE TABLE `fin_account` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(30)  NOT NULL,
  `name`       VARCHAR(80)  NOT NULL,
  `type`       ENUM('cash','bank','alipay','wechat','other') NOT NULL DEFAULT 'bank',
  `bank_name`  VARCHAR(120) NOT NULL DEFAULT '',
  `account_no` VARCHAR(60)  NOT NULL DEFAULT '',
  `currency`   VARCHAR(10)  NOT NULL DEFAULT 'CNY',
  `balance`    DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `is_default` TINYINT      NOT NULL DEFAULT 0,
  `status`     TINYINT      NOT NULL DEFAULT 1,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  `version`    INT          NOT NULL DEFAULT 1,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fin_acct_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资金账户';

DROP TABLE IF EXISTS `fin_receivable`;
CREATE TABLE `fin_receivable` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`      VARCHAR(40)  NOT NULL,
  `biz_type`    VARCHAR(30)  NOT NULL DEFAULT 'sal_order',
  `biz_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `biz_no`      VARCHAR(40)  NOT NULL DEFAULT '',
  `dept_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `customer_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `bill_date`   DATE         NOT NULL,
  `due_date`    DATE         NULL,
  `contract_no` VARCHAR(40)  NOT NULL DEFAULT '' COMMENT '关联合同编号',
  `contract_expire_date` DATE NULL COMMENT '合同到期日(用于到期提醒)',
  `remind_days` INT          NOT NULL DEFAULT 30 COMMENT '到期前提醒天数',
  `source_module` VARCHAR(30) NOT NULL DEFAULT '' COMMENT '来源业务模块',
  `invoice_type` VARCHAR(20) NOT NULL DEFAULT 'general' COMMENT '发票类型 general=普票 vat_special=增值税专用发票',
  `invoice_no`   VARCHAR(40) NOT NULL DEFAULT '' COMMENT '发票号码',
  `tax_amount`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '对应税额(专票为销项税,已从应收中分离)',
  `amount`      DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `received_amount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `status`      ENUM('open','partial','settled','void') NOT NULL DEFAULT 'open',
  `remark`      VARCHAR(500) NOT NULL DEFAULT '',
  `version`     INT          NOT NULL DEFAULT 1,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fin_recv_no` (`doc_no`),
  KEY `idx_fin_recv_cust` (`customer_id`),
  KEY `idx_fin_recv_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='应收单';

DROP TABLE IF EXISTS `fin_payable`;
CREATE TABLE `fin_payable` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`      VARCHAR(40)  NOT NULL,
  `biz_type`    VARCHAR(30)  NOT NULL DEFAULT 'pur_order',
  `biz_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `biz_no`      VARCHAR(40)  NOT NULL DEFAULT '',
  `dept_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `supplier_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `bill_date`   DATE         NOT NULL,
  `due_date`    DATE         NULL,
  `contract_no` VARCHAR(40)  NOT NULL DEFAULT '' COMMENT '关联合同编号',
  `contract_expire_date` DATE NULL COMMENT '合同到期日(用于到期提醒)',
  `remind_days` INT          NOT NULL DEFAULT 30 COMMENT '到期前提醒天数',
  `source_module` VARCHAR(30) NOT NULL DEFAULT '' COMMENT '来源业务模块',
  `invoice_type` VARCHAR(20) NOT NULL DEFAULT 'general' COMMENT '发票类型 general=普票 vat_special=增值税专用发票',
  `invoice_no`   VARCHAR(40) NOT NULL DEFAULT '' COMMENT '发票号码',
  `tax_amount`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '对应进项税额(专票可抵扣成本费用)',
  `amount`      DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `paid_amount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `status`      ENUM('open','partial','settled','void') NOT NULL DEFAULT 'open',
  `remark`      VARCHAR(500) NOT NULL DEFAULT '',
  `version`     INT          NOT NULL DEFAULT 1,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fin_pay_no` (`doc_no`),
  KEY `idx_fin_pay_supp` (`supplier_id`),
  KEY `idx_fin_pay_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='应付单';

DROP TABLE IF EXISTS `fin_payment`;
CREATE TABLE `fin_payment` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`       VARCHAR(40)  NOT NULL,
  `payment_date` DATE         NOT NULL,
  `dept_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `direction`    TINYINT      NOT NULL DEFAULT 1      COMMENT '1收款 2付款',
  `partner_type` ENUM('customer','supplier') NOT NULL DEFAULT 'customer',
  `partner_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `account_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `amount`       DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `method`       VARCHAR(30)  NOT NULL DEFAULT 'bank' COMMENT 'bank/cash/other',
  `bill_no`      VARCHAR(60)  NOT NULL DEFAULT '',
  `target_type`  VARCHAR(30)  NOT NULL DEFAULT ''    COMMENT 'fin_receivable/fin_payable',
  `target_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`       ENUM('draft','confirmed','void') NOT NULL DEFAULT 'draft',
  `remark`       VARCHAR(500) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `confirmed_at` DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fin_pay_docno` (`doc_no`),
  KEY `idx_fin_pay_partner` (`partner_type`, `partner_id`),
  KEY `idx_fin_pay_target` (`target_type`, `target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收付款单';

DROP TABLE IF EXISTS `fin_expense`;
CREATE TABLE `fin_expense` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`       VARCHAR(40)  NOT NULL,
  `expense_date` DATE         NOT NULL,
  `dept_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `category`     VARCHAR(50)  NOT NULL DEFAULT '其他' COMMENT '费用类别',
  `amount`       DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '价税合计',
  `invoice_type` VARCHAR(20)  NOT NULL DEFAULT 'general' COMMENT '发票类型 general=普票 vat_special=增值税专用发票',
  `invoice_no`   VARCHAR(40)  NOT NULL DEFAULT '' COMMENT '发票号码',
  `tax_rate`     DECIMAL(6,2)  NOT NULL DEFAULT 0.00 COMMENT '税率(%)',
  `amount_excl_tax` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '不含税金额(可计入费用的金额)',
  `tax_amount`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '税额(专票可抵扣,普票不可抵扣)',
  `account_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `handler_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `payee`        VARCHAR(80)  NOT NULL DEFAULT '',
  `status`       ENUM('draft','confirmed','void') NOT NULL DEFAULT 'draft',
  `remark`       VARCHAR(500) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `confirmed_at` DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fin_exp_no` (`doc_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='费用单';

DROP TABLE IF EXISTS `fin_voucher`;
CREATE TABLE `fin_voucher` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`       VARCHAR(40)  NOT NULL,
  `voucher_date` DATE         NOT NULL,
  `dept_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `period`       CHAR(7)      NOT NULL                COMMENT '会计期间 YYYY-MM',
  `source_type`  VARCHAR(30)  NOT NULL DEFAULT '',
  `source_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `description`  VARCHAR(255) NOT NULL DEFAULT '',
  `total_debit`  DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `total_credit` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `remark`       VARCHAR(500) NOT NULL DEFAULT '' COMMENT '备注',
  `status`       ENUM('draft','posted','void') NOT NULL DEFAULT 'draft',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `posted_at`    DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fin_voucher_no` (`doc_no`),
  KEY `idx_fin_voucher_period` (`period`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='会计凭证';

DROP TABLE IF EXISTS `fin_voucher_item`;
CREATE TABLE `fin_voucher_item` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `voucher_id`  BIGINT UNSIGNED NOT NULL,
  `line_no`     INT          NOT NULL DEFAULT 0,
  `summary`     VARCHAR(200) NOT NULL DEFAULT '' COMMENT '摘要',
  `account_code` VARCHAR(30) NOT NULL DEFAULT '',
  `account_name` VARCHAR(80) NOT NULL DEFAULT '',
  `direction`   ENUM('debit','credit') NOT NULL DEFAULT 'debit',
  `amount`      DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `partner_type` VARCHAR(20) NOT NULL DEFAULT '',
  `partner_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `remark`      VARCHAR(500) NOT NULL DEFAULT '' COMMENT '行备注',
  PRIMARY KEY (`id`),
  KEY `idx_fin_voucher_item` (`voucher_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='凭证明细';

-- =============================================================
--  七、生产管理
-- =============================================================

DROP TABLE IF EXISTS `prd_bom`;
CREATE TABLE `prd_bom` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(40)  NOT NULL                COMMENT 'BOM 编码',
  `name`       VARCHAR(120) NOT NULL DEFAULT '',
  `product_id` BIGINT UNSIGNED NOT NULL                COMMENT '父件(产出物料)',
  `version_no` VARCHAR(20)  NOT NULL DEFAULT 'V1.0',
  `dept_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `output_qty` DECIMAL(18,4) NOT NULL DEFAULT 1.0000 COMMENT '基准产出数量',
  `status`     TINYINT      NOT NULL DEFAULT 1,
  `remark`     VARCHAR(500) NOT NULL DEFAULT '',
  `version`    INT          NOT NULL DEFAULT 1,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_prd_bom_code` (`code`),
  KEY `idx_prd_bom_product` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物料清单 BOM';

DROP TABLE IF EXISTS `prd_bom_item`;
CREATE TABLE `prd_bom_item` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `bom_id`     BIGINT UNSIGNED NOT NULL,
  `line_no`    INT          NOT NULL DEFAULT 0,
  `product_id` BIGINT UNSIGNED NOT NULL                COMMENT '子件(原料)',
  `qty`        DECIMAL(18,4) NOT NULL DEFAULT 0.0000    COMMENT '单位产出所需数量',
  `loss_rate`  DECIMAL(6,2)  NOT NULL DEFAULT 0.00      COMMENT '损耗率%',
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_prd_bom_item` (`bom_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='BOM 子件';

DROP TABLE IF EXISTS `prd_order`;
CREATE TABLE `prd_order` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`          VARCHAR(40)  NOT NULL,
  `title`           VARCHAR(120) NOT NULL DEFAULT '',
  `plan_start_date` DATE         NOT NULL,
  `dept_id`         BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `plan_end_date`   DATE         NULL,
  `product_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '产出物料',
  `bom_id`          BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `plan_qty`        DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  `finished_qty`    DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  `warehouse_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '成品入库仓',
  `status`          ENUM('draft','released','producing','finished','closed','void') NOT NULL DEFAULT 'draft',
  `remark`          VARCHAR(500) NOT NULL DEFAULT '',
  `version`         INT          NOT NULL DEFAULT 1,
  `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`      BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`      BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `released_at`     DATETIME     NULL,
  `closed_at`       DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_prd_order_no` (`doc_no`),
  KEY `idx_prd_order_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='生产工单';

DROP TABLE IF EXISTS `prd_order_item`;
CREATE TABLE `prd_order_item` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id`     BIGINT UNSIGNED NOT NULL,
  `line_no`      INT          NOT NULL DEFAULT 0,
  `product_id`   BIGINT UNSIGNED NOT NULL,
  `plan_qty`     DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  `finished_qty` DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  `remark`       VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_prd_order_item` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工单产出明细';

DROP TABLE IF EXISTS `prd_pick`;
CREATE TABLE `prd_pick` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`       VARCHAR(40)  NOT NULL,
  `pick_date`    DATE         NOT NULL,
  `dept_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `order_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `warehouse_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `handler_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`       ENUM('draft','posted','void') NOT NULL DEFAULT 'draft',
  `total_amount` DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `remark`       VARCHAR(500) NOT NULL DEFAULT '',
  `version`      INT          NOT NULL DEFAULT 1,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `posted_at`    DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_prd_pick_no` (`doc_no`),
  KEY `idx_prd_pick_order` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='生产领料单';

DROP TABLE IF EXISTS `prd_pick_item`;
CREATE TABLE `prd_pick_item` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `pick_id`    BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `qty`        DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  `price`      DECIMAL(18,4) NOT NULL DEFAULT 0.0000,
  `amount`     DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_prd_pick_item` (`pick_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='领料明细';

DROP TABLE IF EXISTS `prd_report`;
CREATE TABLE `prd_report` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`        VARCHAR(40)  NOT NULL,
  `report_date`   DATE         NOT NULL,
  `dept_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `order_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `product_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `qty`           DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '报工数量',
  `qualified_qty` DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '合格数',
  `scrap_qty`     DECIMAL(18,4) NOT NULL DEFAULT 0.0000 COMMENT '报废数',
  `operator_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `warehouse_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `status`        ENUM('draft','posted','void') NOT NULL DEFAULT 'draft',
  `remark`        VARCHAR(500) NOT NULL DEFAULT '',
  `version`       INT          NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `posted_at`     DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_prd_report_no` (`doc_no`),
  KEY `idx_prd_report_order` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='生产报工单';

-- =============================================================
--  八、资产管理
-- =============================================================

DROP TABLE IF EXISTS `fa_asset`;
CREATE TABLE `fa_asset` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`           VARCHAR(40)  NOT NULL                COMMENT '资产编号',
  `name`           VARCHAR(120) NOT NULL DEFAULT ''     COMMENT '资产名称',
  `category`       VARCHAR(40)  NOT NULL DEFAULT ''     COMMENT '资产类别',
  `model`          VARCHAR(120) NOT NULL DEFAULT ''     COMMENT '规格型号',
  `serial_no`      VARCHAR(80)  NOT NULL DEFAULT ''     COMMENT '出厂序列号',
  `supplier_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0   COMMENT '供应商',
  `dept_id`        BIGINT UNSIGNED NOT NULL DEFAULT 0   COMMENT '使用部门',
  `keeper_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0   COMMENT '责任人(系统用户)',
  `keeper_name`    VARCHAR(60)  NOT NULL DEFAULT ''     COMMENT '责任人(文本)',
  `location`       VARCHAR(120) NOT NULL DEFAULT ''     COMMENT '存放地点',
  `buy_date`       DATE         NULL                    COMMENT '购置日期',
  `original_value` DECIMAL(18,2) NOT NULL DEFAULT 0.00  COMMENT '资产原值',
  `salvage_value`  DECIMAL(18,2) NOT NULL DEFAULT 0.00  COMMENT '预计残值',
  `net_value`      DECIMAL(18,2) NOT NULL DEFAULT 0.00  COMMENT '资产净值',
  `use_years`      INT          NOT NULL DEFAULT 5      COMMENT '预计使用年限',
  `depreciation`   DECIMAL(18,2) NOT NULL DEFAULT 0.00  COMMENT '累计折旧',
  `asset_status`   VARCHAR(20)  NOT NULL DEFAULT 'in_use' COMMENT 'in_use/idle/repair/lent/scrapped',
  `status`         TINYINT      NOT NULL DEFAULT 1,
  `remark`         VARCHAR(500) NOT NULL DEFAULT '',
  `version`        INT          NOT NULL DEFAULT 1,
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fa_asset_code` (`code`),
  KEY `idx_fa_asset_status` (`asset_status`),
  KEY `idx_fa_asset_location` (`location`),
  KEY `idx_fa_asset_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='固定资产卡片';

DROP TABLE IF EXISTS `fa_check`;
CREATE TABLE `fa_check` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`      VARCHAR(40)  NOT NULL,
  `check_date`  DATE         NOT NULL,
  `dept_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `location`    VARCHAR(120) NOT NULL DEFAULT ''   COMMENT '盘点地点',
  `checker_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '盘点人',
  `status`      ENUM('draft','posted','void') NOT NULL DEFAULT 'draft',
  `total_count` INT          NOT NULL DEFAULT 0    COMMENT '应盘数量',
  `diff_count`  INT          NOT NULL DEFAULT 0    COMMENT '差异数量',
  `diff_amount` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '差异原值合计',
  `remark`      VARCHAR(500) NOT NULL DEFAULT '',
  `version`     INT          NOT NULL DEFAULT 1,
  `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `posted_at`   DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fa_check_no` (`doc_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='固定资产盘点单';

DROP TABLE IF EXISTS `fa_check_item`;
CREATE TABLE `fa_check_item` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `check_id`       BIGINT UNSIGNED NOT NULL,
  `asset_id`       BIGINT UNSIGNED NOT NULL,
  `book_status`    VARCHAR(20)  NOT NULL DEFAULT '' COMMENT '账面状态',
  `real_status`    VARCHAR(20)  NOT NULL DEFAULT '' COMMENT '实盘状态',
  `book_location`  VARCHAR(120) NOT NULL DEFAULT '' COMMENT '账面存放地点',
  `real_location`  VARCHAR(120) NOT NULL DEFAULT '' COMMENT '实盘存放地点',
  `book_keeper`    VARCHAR(60)  NOT NULL DEFAULT '' COMMENT '账面责任人',
  `real_keeper`    VARCHAR(60)  NOT NULL DEFAULT '' COMMENT '实盘责任人',
  `is_diff`        TINYINT      NOT NULL DEFAULT 0   COMMENT '是否差异',
  `diff_reason`    VARCHAR(255) NOT NULL DEFAULT '' COMMENT '差异原因',
  `original_value` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '资产原值(快照)',
  `remark`         VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_fa_check_item` (`check_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='固定资产盘点明细';

-- =============================================================
--  九、租赁与服务业务
-- =============================================================

-- 租赁合同:设备租赁 / 厂房租赁 / 汽车租赁,支持收入与支出两个方向
DROP TABLE IF EXISTS `biz_lease`;
CREATE TABLE `biz_lease` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`        VARCHAR(40)  NOT NULL,
  `title`         VARCHAR(120) NOT NULL DEFAULT '',
  `contract_no`   VARCHAR(60)  NOT NULL DEFAULT '' COMMENT '外部合同编号',
  `direction`     ENUM('income','expense') NOT NULL DEFAULT 'income' COMMENT 'income=租赁收入 expense=租赁支出',
  `lease_type`    ENUM('equipment','plant','vehicle') NOT NULL DEFAULT 'equipment' COMMENT 'equipment设备 plant厂房 vehicle汽车',
  `customer_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '承租方(收入方向)',
  `supplier_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '出租方(支出方向)',
  `dept_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `lease_date`    DATE         NOT NULL,
  `start_date`    DATE         NULL COMMENT '起租日',
  `end_date`      DATE         NULL COMMENT '止租日(合同到期日)',
  `settle_cycle`  ENUM('once','month','quarter','half','year') NOT NULL DEFAULT 'month' COMMENT '结算周期',
  `period_count`  INT          NOT NULL DEFAULT 1 COMMENT '结算期数',
  `period_amount` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '每期租金',
  `deposit`       DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '押金',
  `tax_rate`      DECIMAL(6,2)  NOT NULL DEFAULT 13.00,
  `total_qty`     DECIMAL(18,4) NOT NULL DEFAULT 0,
  `total_amount`  DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '租金总额',
  `status`        ENUM('draft','submitted','approved','active','closed','void') NOT NULL DEFAULT 'draft',
  `remark`        VARCHAR(500) NOT NULL DEFAULT '',
  `version`       INT          NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at`   DATETIME     NULL,
  `approved_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `active_at`     DATETIME     NULL,
  `closed_at`     DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_biz_lease_no` (`doc_no`),
  KEY `idx_biz_lease_status` (`status`),
  KEY `idx_biz_lease_customer` (`customer_id`),
  KEY `idx_biz_lease_supplier` (`supplier_id`),
  KEY `idx_biz_lease_dept` (`dept_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='租赁合同';

DROP TABLE IF EXISTS `biz_lease_item`;
CREATE TABLE `biz_lease_item` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lease_id`      BIGINT UNSIGNED NOT NULL,
  `line_no`       INT          NOT NULL DEFAULT 0,
  `product_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '租赁物料(可选)',
  `asset_id`      BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '关联固定资产(设备租赁)',
  `warehouse_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '关联场地(厂房租赁)',
  `subject_name`  VARCHAR(120) NOT NULL DEFAULT '' COMMENT '租赁标的名称',
  `spec`          VARCHAR(120) NOT NULL DEFAULT '' COMMENT '规格型号 / 车牌',
  `qty`           DECIMAL(18,4) NOT NULL DEFAULT 0,
  `unit_name`     VARCHAR(30)  NOT NULL DEFAULT '',
  `price`         DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `amount`        DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `remark`        VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_biz_lease_item` (`lease_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='租赁标的明细';

-- 服务合同:技术支持服务 / 电脑软件服务 / 消防安全服务等,支持收入与支出两个方向
DROP TABLE IF EXISTS `biz_service`;
CREATE TABLE `biz_service` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`        VARCHAR(40)  NOT NULL,
  `title`         VARCHAR(120) NOT NULL DEFAULT '',
  `contract_no`   VARCHAR(60)  NOT NULL DEFAULT '' COMMENT '外部合同编号',
  `direction`     ENUM('income','expense') NOT NULL DEFAULT 'income' COMMENT 'income=服务收入 expense=服务支出',
  `service_type`  ENUM('tech','software','fire','other') NOT NULL DEFAULT 'tech' COMMENT 'tech技术支持 software电脑软件 fire消防安全 other其他',
  `customer_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '接受方(收入方向)',
  `supplier_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '提供方(支出方向)',
  `dept_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `service_date`  DATE         NOT NULL,
  `start_date`    DATE         NULL COMMENT '服务开始日',
  `end_date`      DATE         NULL COMMENT '服务结束日(合同到期日)',
  `price_mode`    ENUM('once','month','year','project') NOT NULL DEFAULT 'once' COMMENT '计价方式',
  `period_count`  INT          NOT NULL DEFAULT 1 COMMENT '服务期数',
  `unit_price`    DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `tax_rate`      DECIMAL(6,2)  NOT NULL DEFAULT 6.00,
  `total_qty`     DECIMAL(18,4) NOT NULL DEFAULT 0,
  `total_amount`  DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `status`        ENUM('draft','submitted','approved','active','closed','void') NOT NULL DEFAULT 'draft',
  `remark`        VARCHAR(500) NOT NULL DEFAULT '',
  `version`       INT          NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at`   DATETIME     NULL,
  `approved_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `active_at`     DATETIME     NULL,
  `closed_at`     DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_biz_service_no` (`doc_no`),
  KEY `idx_biz_service_status` (`status`),
  KEY `idx_biz_service_customer` (`customer_id`),
  KEY `idx_biz_service_supplier` (`supplier_id`),
  KEY `idx_biz_service_dept` (`dept_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='服务合同';

DROP TABLE IF EXISTS `biz_service_item`;
CREATE TABLE `biz_service_item` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `service_id`   BIGINT UNSIGNED NOT NULL,
  `line_no`      INT          NOT NULL DEFAULT 0,
  `service_name` VARCHAR(120) NOT NULL DEFAULT '' COMMENT '服务项目名称',
  `service_desc` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '服务内容说明',
  `qty`          DECIMAL(18,4) NOT NULL DEFAULT 0,
  `price`        DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `amount`       DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `remark`       VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_biz_service_item` (`service_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='服务项目明细';

-- 委外加工单:本公司提供原材料,供应商负责生产加工
DROP TABLE IF EXISTS `prd_outsource`;
CREATE TABLE `prd_outsource` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`        VARCHAR(40)  NOT NULL,
  `title`         VARCHAR(120) NOT NULL DEFAULT '',
  `dept_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `contract_no`     VARCHAR(60)  NOT NULL DEFAULT '' COMMENT '关联合同编号',
  `contract_end_date` DATE       NULL COMMENT '合同到期日(到期提醒)',
  `supplier_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '委外供应商',
  `product_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '产出成品',
  `bom_id`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `plan_qty`      DECIMAL(18,4) NOT NULL DEFAULT 0 COMMENT '计划加工数量',
  `finished_qty`  DECIMAL(18,4) NOT NULL DEFAULT 0 COMMENT '实际收回数量',
  `outsource_date` DATE        NOT NULL COMMENT '发出日期',
  `expect_return_date` DATE     NULL COMMENT '预计返回日期',
  `from_warehouse_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '发料仓库',
  `to_warehouse_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '成品入库仓库',
  `total_material` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '发出材料成本合计',
  `process_fee`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '加工费单价',
  `total_amount`  DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '加工费合计',
  `status`        ENUM('draft','submitted','approved','released','returned','closed','void') NOT NULL DEFAULT 'draft',
  `remark`        VARCHAR(500) NOT NULL DEFAULT '',
  `version`       INT          NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at`   DATETIME     NULL,
  `approved_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `released_at`   DATETIME     NULL,
  `returned_at`   DATETIME     NULL,
  `closed_at`     DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_prd_outsource_no` (`doc_no`),
  KEY `idx_prd_outsource_status` (`status`),
  KEY `idx_prd_outsource_supplier` (`supplier_id`),
  KEY `idx_prd_outsource_dept` (`dept_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='委外加工单';

DROP TABLE IF EXISTS `prd_outsource_item`;
CREATE TABLE `prd_outsource_item` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `outsource_id` BIGINT UNSIGNED NOT NULL,
  `line_no`    INT          NOT NULL DEFAULT 0,
  `product_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '发出的原材料',
  `qty`        DECIMAL(18,4) NOT NULL DEFAULT 0,
  `price`      DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '单位成本',
  `amount`     DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `remark`     VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_prd_outsource_item` (`outsource_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='委外发出材料明细';

-- 来料加工单:客户提供原材料,本公司负责生产加工
DROP TABLE IF EXISTS `prd_supplied`;
CREATE TABLE `prd_supplied` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`        VARCHAR(40)  NOT NULL,
  `title`         VARCHAR(120) NOT NULL DEFAULT '',
  `dept_id`       BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `contract_no`     VARCHAR(60)  NOT NULL DEFAULT '' COMMENT '关联合同编号',
  `contract_end_date` DATE       NULL COMMENT '合同到期日(到期提醒)',
  `customer_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '委托客户(来料方)',
  `product_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '产出产品',
  `plan_qty`      DECIMAL(18,4) NOT NULL DEFAULT 0 COMMENT '计划加工数量',
  `finished_qty`  DECIMAL(18,4) NOT NULL DEFAULT 0 COMMENT '实际完工数量',
  `start_date`    DATE         NULL COMMENT '开工日期',
  `end_date`      DATE         NULL COMMENT '完工日期',
  `from_warehouse_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '客户来料入库仓',
  `to_warehouse_id`   BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '产出入库仓',
  `total_material` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '客户来料成本合计',
  `process_fee`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '加工费单价(向客户收取)',
  `total_amount`  DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '加工费合计',
  `status`        ENUM('draft','submitted','approved','released','posted','closed','void') NOT NULL DEFAULT 'draft',
  `remark`        VARCHAR(500) NOT NULL DEFAULT '',
  `version`       INT          NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at`   DATETIME     NULL,
  `approved_by`   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `released_at`   DATETIME     NULL,
  `posted_at`     DATETIME     NULL,
  `closed_at`     DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_prd_supplied_no` (`doc_no`),
  KEY `idx_prd_supplied_status` (`status`),
  KEY `idx_prd_supplied_customer` (`customer_id`),
  KEY `idx_prd_supplied_dept` (`dept_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='来料加工单';

DROP TABLE IF EXISTS `prd_supplied_item`;
CREATE TABLE `prd_supplied_item` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `supplied_id` BIGINT UNSIGNED NOT NULL,
  `line_no`     INT          NOT NULL DEFAULT 0,
  `product_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '客户提供的物料',
  `qty`         DECIMAL(18,4) NOT NULL DEFAULT 0,
  `price`       DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '单位成本',
  `amount`      DECIMAL(18,2) NOT NULL DEFAULT 0.00,
  `remark`      VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_prd_supplied_item` (`supplied_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户来料明细';

-- =============================================================
--  十、人力资源与工资考勤
-- =============================================================

DROP TABLE IF EXISTS `hr_employee_change`;
CREATE TABLE `hr_employee_change` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`         VARCHAR(40)  NOT NULL,
  `title`          VARCHAR(120) NOT NULL DEFAULT '',
  `change_date`    DATE         NOT NULL,
  `dept_id`        BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `employee_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '异动员工',
  `change_type`    VARCHAR(20)  NOT NULL DEFAULT 'transfer' COMMENT 'hire入职/transfer调岗/promotion晋升/resign离职/leave停薪留职',
  `before_dept_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `after_dept_id`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `before_position` VARCHAR(50) NOT NULL DEFAULT '',
  `after_position`  VARCHAR(50) NOT NULL DEFAULT '',
  `before_salary`  DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '异动前月薪',
  `after_salary`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '异动后月薪',
  `effective_date` DATE         NULL COMMENT '生效日期',
  `reason`         VARCHAR(500) NOT NULL DEFAULT '',
  `status`         ENUM('draft','submitted','approved','void') NOT NULL DEFAULT 'draft',
  `version`        INT          NOT NULL DEFAULT 1,
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `approved_at`    DATETIME     NULL,
  `approved_by`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_hr_change_no` (`doc_no`),
  KEY `idx_hr_change_emp` (`employee_id`),
  KEY `idx_hr_change_date` (`change_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='人事异动单';

DROP TABLE IF EXISTS `hr_attendance`;
CREATE TABLE `hr_attendance` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `employee_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `dept_id`        BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '归属部门',
  `attend_date`    DATE         NOT NULL,
  `day_type`       VARCHAR(20)  NOT NULL DEFAULT 'work' COMMENT 'work出勤/rest休息/holiday节假日/leave请假/absence缺勤',
  `work_hours`     DECIMAL(6,2) NOT NULL DEFAULT 8.00 COMMENT '出勤工时',
  `overtime_hours` DECIMAL(6,2) NOT NULL DEFAULT 0.00 COMMENT '加班工时',
  `late_minutes`   INT          NOT NULL DEFAULT 0 COMMENT '迟到分钟',
  `early_minutes`  INT          NOT NULL DEFAULT 0 COMMENT '早退分钟',
  `leave_type`     VARCHAR(20)  NOT NULL DEFAULT 'none' COMMENT 'none/sick病假/annual年假/personal事假/maternity产假/marriage婚假',
  `leave_hours`    DECIMAL(6,2) NOT NULL DEFAULT 0.00 COMMENT '请假时长(小时)',
  `absence_days`   DECIMAL(6,2) NOT NULL DEFAULT 0.00 COMMENT '缺勤天数',
  `pay_days`       DECIMAL(6,2) NOT NULL DEFAULT 1.00 COMMENT '计薪天数',
  `remark`         VARCHAR(255) NOT NULL DEFAULT '',
  `status`         ENUM('draft','confirmed','void') NOT NULL DEFAULT 'confirmed',
  `version`        INT          NOT NULL DEFAULT 1,
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_hr_att_emp_date` (`employee_id`,`attend_date`),
  KEY `idx_hr_att_date` (`attend_date`),
  KEY `idx_hr_att_dept` (`dept_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='考勤记录(考勤表)';

DROP TABLE IF EXISTS `hr_payroll`;
CREATE TABLE `hr_payroll` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`         VARCHAR(40)  NOT NULL,
  `payroll_month`  CHAR(7)      NOT NULL COMMENT '工资月份 YYYY-MM',
  `dept_id`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `employee_id`    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `base_salary`    DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '基本工资',
  `post_salary`    DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '岗位工资',
  `performance_salary` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '绩效工资',
  `allowance`      DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '津贴补贴',
  `overtime_pay`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '加班工资',
  `bonus`          DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '奖金',
  `gross_salary`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '应发合计',
  `insurance`      DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '社保公积金(个人部分)',
  `si_pension`     DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '养老保险(个人)',
  `si_medical`     DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '医疗保险(个人)',
  `si_unemployment` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '失业保险(个人)',
  `si_housing_fund` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '住房公积金(个人)',
  `special_deduct` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '专项附加扣除合计(元/月)',
  `taxable_income` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '当月应纳税所得额',
  `tax_rate_used`  DECIMAL(6,2)  NOT NULL DEFAULT 0.00 COMMENT '适用预扣率(%)',
  `tax_quick_deduct` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '速算扣除数',
  `cum_months`     INT          NOT NULL DEFAULT 0    COMMENT '累计计税月份数',
  `cum_gross`      DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '累计收入',
  `cum_insurance`  DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '累计专项扣除(五险一金)',
  `cum_special`    DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '累计专项附加扣除',
  `cum_deduction`  DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '累计减除费用',
  `cum_taxable`    DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '累计应纳税所得额',
  `cum_tax_due`    DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '累计应纳税额',
  `cum_tax_paid`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '累计已预扣税额',
  `tax`            DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '个人所得税',
  `other_deduct`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '其它扣款',
  `net_salary`     DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '实发合计',
  `work_days`      DECIMAL(6,2)  NOT NULL DEFAULT 0.00 COMMENT '出勤天数',
  `overtime_hours` DECIMAL(6,2)  NOT NULL DEFAULT 0.00 COMMENT '加班工时',
  `leave_days`     DECIMAL(6,2)  NOT NULL DEFAULT 0.00 COMMENT '请假天数',
  `status`         ENUM('draft','confirmed','paid','void') NOT NULL DEFAULT 'draft',
  `pay_date`       DATE         NULL COMMENT '发放日期',
  `remark`         VARCHAR(500) NOT NULL DEFAULT '',
  `version`        INT          NOT NULL DEFAULT 1,
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `confirmed_at`   DATETIME     NULL,
  `paid_at`        DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_hr_pay_emp_month` (`payroll_month`,`employee_id`),
  KEY `idx_hr_pay_month` (`payroll_month`),
  KEY `idx_hr_pay_dept` (`dept_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工资表(月度工资单)';

-- =============================================================
--  十一、发票与税额台账
-- =============================================================

DROP TABLE IF EXISTS `fin_tax_invoice`;
CREATE TABLE `fin_tax_invoice` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `doc_no`         VARCHAR(40)  NOT NULL COMMENT '台账单号',
  `invoice_type`   VARCHAR(20)  NOT NULL DEFAULT 'general' COMMENT 'general=普通发票 vat_special=增值税专用发票',
  `invoice_no`     VARCHAR(40)  NOT NULL DEFAULT '' COMMENT '发票号码',
  `invoice_date`   DATE         NOT NULL COMMENT '开票日期',
  `direction`      VARCHAR(10)  NOT NULL DEFAULT 'sales' COMMENT 'sales=销项(开具) purchase=进项(收到)',
  `partner_id`     BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '客户/供应商',
  `dept_id`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `biz_type`       VARCHAR(30)  NOT NULL DEFAULT '' COMMENT '来源业务',
  `biz_id`         BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `biz_no`         VARCHAR(40)  NOT NULL DEFAULT '',
  `tax_rate`       DECIMAL(6,2)  NOT NULL DEFAULT 0.00 COMMENT '税率(%)',
  `amount_total`   DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '价税合计',
  `amount_excl_tax` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '不含税金额',
  `tax_amount`     DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '税额',
  `deductible_tax` DECIMAL(18,2) NOT NULL DEFAULT 0.00 COMMENT '可抵扣税额(普票为0,专票=税额)',
  `status`         ENUM('valid','void') NOT NULL DEFAULT 'valid',
  `remark`         VARCHAR(500) NOT NULL DEFAULT '',
  `version`        INT          NOT NULL DEFAULT 1,
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by`     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fin_tax_invoice_no` (`doc_no`),
  KEY `idx_fin_tax_dir` (`direction`),
  KEY `idx_fin_tax_date` (`invoice_date`),
  KEY `idx_fin_tax_biz` (`biz_type`,`biz_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='发票台账(含进项/销项税额)';

-- =============================================================
--  十二、报表视图
-- =============================================================

CREATE OR REPLACE VIEW `v_stock_detail` AS
SELECT s.id, s.warehouse_id, w.code AS warehouse_code, w.name AS warehouse_name,
       s.product_id, p.code AS product_code, p.name AS product_name, p.spec, p.product_type,
       u.name AS unit_name, s.qty, s.locked_qty, s.avg_cost, s.total_amount,
       p.safety_stock, (s.qty - p.safety_stock) AS available_qty
FROM inv_stock s
LEFT JOIN md_warehouse w ON w.id = s.warehouse_id
LEFT JOIN md_product  p ON p.id = s.product_id
LEFT JOIN md_unit     u ON u.id = p.unit_id;

CREATE OR REPLACE VIEW `v_ar_aging` AS
SELECT r.id, r.doc_no, r.customer_id, c.name AS customer_name, r.bill_date, r.due_date,
       r.dept_id, r.created_by,
       r.amount, r.received_amount, (r.amount - r.received_amount) AS open_amount,
       DATEDIFF(CURDATE(), r.bill_date) AS age_days,
       CASE WHEN DATEDIFF(CURDATE(), r.bill_date) <= 30 THEN '0-30天'
            WHEN DATEDIFF(CURDATE(), r.bill_date) <= 60 THEN '31-60天'
            WHEN DATEDIFF(CURDATE(), r.bill_date) <= 90 THEN '61-90天'
            WHEN DATEDIFF(CURDATE(), r.bill_date) <= 180 THEN '91-180天'
            ELSE '180天以上' END AS age_bucket
FROM fin_receivable r
LEFT JOIN md_customer c ON c.id = r.customer_id
WHERE r.status IN ('open','partial');

CREATE OR REPLACE VIEW `v_ap_aging` AS
SELECT p.id, p.doc_no, p.supplier_id, s.name AS supplier_name, p.bill_date, p.due_date,
       p.dept_id, p.created_by,
       p.amount, p.paid_amount, (p.amount - p.paid_amount) AS open_amount,
       DATEDIFF(CURDATE(), p.bill_date) AS age_days,
       CASE WHEN DATEDIFF(CURDATE(), p.bill_date) <= 30 THEN '0-30天'
            WHEN DATEDIFF(CURDATE(), p.bill_date) <= 60 THEN '31-60天'
            WHEN DATEDIFF(CURDATE(), p.bill_date) <= 90 THEN '61-90天'
            WHEN DATEDIFF(CURDATE(), p.bill_date) <= 180 THEN '91-180天'
            ELSE '180天以上' END AS age_bucket
FROM fin_payable p
LEFT JOIN md_supplier s ON s.id = p.supplier_id
WHERE p.status IN ('open','partial');

CREATE OR REPLACE VIEW `v_sales_summary` AS
SELECT o.id, o.doc_no, o.order_date, o.customer_id, c.name AS customer_name,
       o.salesman_id, u.real_name AS salesman_name,
       o.total_qty, o.total_amount, o.tax_amount, o.status, o.delivery_date
FROM sal_order o
LEFT JOIN md_customer c ON c.id = o.customer_id
LEFT JOIN sys_user     u ON u.id = o.salesman_id;

-- 账款提醒视图:把未核销的应收/应付拉平成一张表,供「账款提醒」页面使用
-- remind_type:purchase_stock=原材料到货应付  sales_invoice=销售开票应收
--              contract_due=合同到期  overdue=已逾期  other=其他
CREATE OR REPLACE VIEW `v_fin_reminder` AS
SELECT
  'ar' AS direction,
  r.id,
  r.doc_no,
  r.biz_type,
  r.biz_no,
  r.dept_id,
  r.customer_id AS partner_id,
  r.contract_no,
  r.bill_date,
  r.due_date,
  r.contract_expire_date,
  r.remind_days,
  r.amount,
  r.received_amount AS settled_amount,
  (r.amount - r.received_amount) AS open_amount,
  r.status,
  r.remark,
  r.created_by AS created_by,
  DATEDIFF(r.due_date, CURDATE()) AS due_days,
  CASE WHEN r.contract_expire_date IS NOT NULL
        AND r.contract_expire_date <= DATE_ADD(CURDATE(), INTERVAL r.remind_days DAY)
       THEN 1 ELSE 0 END AS contract_due_soon
FROM fin_receivable r
WHERE r.status IN ('open','partial') AND (r.amount - r.received_amount) > 0.01
UNION ALL
SELECT
  'ap' AS direction,
  p.id,
  p.doc_no,
  p.biz_type,
  p.biz_no,
  p.dept_id,
  p.supplier_id AS partner_id,
  p.contract_no,
  p.bill_date,
  p.due_date,
  p.contract_expire_date,
  p.remind_days,
  p.amount,
  p.paid_amount AS settled_amount,
  (p.amount - p.paid_amount) AS open_amount,
  p.status,
  p.remark,
  p.created_by AS created_by,
  DATEDIFF(p.due_date, CURDATE()) AS due_days,
  CASE WHEN p.contract_expire_date IS NOT NULL
        AND p.contract_expire_date <= DATE_ADD(CURDATE(), INTERVAL p.remind_days DAY)
       THEN 1 ELSE 0 END AS contract_due_soon
FROM fin_payable p
WHERE p.status IN ('open','partial') AND (p.amount - p.paid_amount) > 0.01;

-- 月度考勤汇总:按员工×月份归集出勤、加班、请假与缺勤
CREATE OR REPLACE VIEW `v_hr_attendance_month` AS
SELECT e.id AS employee_id,
       e.code AS employee_code,
       e.name AS employee_name,
       e.dept_id,
       d.name AS dept_name,
       e.position,
       DATE_FORMAT(a.attend_date, '%Y-%m') AS attend_month,
       COUNT(*) AS record_days,
       SUM(CASE WHEN a.day_type = 'work' THEN 1 ELSE 0 END) AS attend_days,
       SUM(CASE WHEN a.day_type = 'leave' THEN 1 ELSE 0 END) AS leave_days_cnt,
       SUM(a.work_hours) AS work_hours,
       SUM(a.overtime_hours) AS overtime_hours,
       SUM(a.late_minutes) AS late_minutes,
       SUM(a.early_minutes) AS early_minutes,
       SUM(a.leave_hours) AS leave_hours,
       SUM(a.absence_days) AS absence_days,
       SUM(a.pay_days) AS pay_days,
       MAX(a.created_by) AS created_by
FROM hr_attendance a
JOIN md_employee e ON e.id = a.employee_id
LEFT JOIN sys_dept d ON d.id = e.dept_id
WHERE a.status <> 'void'
GROUP BY e.id, e.code, e.name, e.dept_id, d.name, e.position, DATE_FORMAT(a.attend_date, '%Y-%m');

-- 发票税额汇总:按方向(销项/进项)× 发票类型(普票/专票)归集
-- deductible_tax 仅增值税专用发票 > 0,可用于抵扣成本费用;普票不可抵扣
CREATE OR REPLACE VIEW `v_fin_tax_summary` AS
SELECT t.direction,
       t.invoice_type,
       COUNT(*) AS invoice_count,
       SUM(t.amount_total) AS amount_total,
       SUM(t.amount_excl_tax) AS amount_excl_tax,
       SUM(t.tax_amount) AS tax_amount,
       SUM(t.deductible_tax) AS deductible_tax
FROM fin_tax_invoice t
WHERE t.status = 'valid'
GROUP BY t.direction, t.invoice_type;

SET FOREIGN_KEY_CHECKS = 1;
SET SQL_MODE = @OLD_SQL_MODE;
