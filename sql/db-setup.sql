-- ============================================
-- MariaDB / MySQL 数据库初始化脚本
-- 数据库: pdf_print_db
-- 表: users（用户认证表）
-- ============================================

-- 1. 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS pdf_print_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE pdf_print_db;

-- 2. 创建用户表
CREATE TABLE IF NOT EXISTS users (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
  username    VARCHAR(50)  NOT NULL UNIQUE COMMENT '用户名',
  password_hash VARCHAR(64) NOT NULL COMMENT 'SHA256 密码哈希（hex）',
  status      TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '账号状态: 1=启用, 0=禁用',
  chinese_name   VARCHAR(50)  NULL COMMENT '中文名',
  department     VARCHAR(100) NULL COMMENT '部门',
  direct_manager VARCHAR(50)  NULL COMMENT '直接上级',
  email          VARCHAR(100) NULL COMMENT 'Email',
  position       VARCHAR(100) NULL COMMENT '岗位',
  hire_date      DATE         NULL COMMENT '入职日期',
  last_login  DATETIME     NULL COMMENT '上次登录时间',
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统用户表';

-- 3. 创建员工培训记录表
CREATE TABLE IF NOT EXISTS training_records (
  id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
  username          VARCHAR(50)  NOT NULL COMMENT '用户名，关联 users 表',
  training_date     DATE         NOT NULL COMMENT '培训日期',
  training_content  TEXT         NOT NULL COMMENT '培训内容',
  training_hours    DECIMAL(5,2) NULL COMMENT '培训课时',
  training_form     VARCHAR(50)  NULL COMMENT '培训形式，如：线上、线下、内部、外部',
  assessment_method VARCHAR(100) NULL COMMENT '考核方法',
  assessment_result VARCHAR(50)  NULL COMMENT '考核结果，如：通过、未通过、优秀',
  trainer           VARCHAR(100) NULL COMMENT '培训讲师/负责人',
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录创建时间',
  updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '记录更新时间',
  KEY idx_username (username),
  KEY idx_training_date (training_date),
  CONSTRAINT fk_training_records_username
    FOREIGN KEY (username) REFERENCES users(username)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='员工培训记录表';

-- 4. 创建年度培训计划表
CREATE TABLE IF NOT EXISTS annual_training_plans (
  id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
  `year`             INT UNSIGNED NULL COMMENT '年度',
  department         VARCHAR(100) NOT NULL COMMENT '部门',
  training_content   TEXT         NOT NULL COMMENT '培训项目/课程/内容',
  target_trainees    VARCHAR(255) NULL COMMENT '目标学员',
  training_method    VARCHAR(100) NULL COMMENT '培训方式',
  training_type      VARCHAR(50)  NULL COMMENT '内训/外训',
  trainer            VARCHAR(100) NULL COMMENT '讲师',
  price              DECIMAL(10,2) NULL COMMENT '价格',
  training_hours     DECIMAL(5,2) NULL COMMENT '培训课时',
  training_schedule  VARCHAR(255) NULL COMMENT '培训日程',
  need_assessment    TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '是否考核：1=是，0=否',
  tracking           TEXT         NULL COMMENT '跟踪',
  is_notified        TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '是否通知：1=是，0=否',
  created_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录创建时间',
  updated_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '记录更新时间',
  KEY idx_department (department),
  KEY idx_training_type (training_type),
  KEY idx_year (`year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='年度培训计划表';

-- 5. 插入默认管理员账号
-- 密码: admin123
-- SHA256(admin123) = 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
INSERT INTO users (username, password_hash, status, last_login)
VALUES ('admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 1, NULL)
ON DUPLICATE KEY UPDATE username = username;
