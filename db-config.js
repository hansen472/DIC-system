/**
 * 数据库连接配置
 *
 * 1. MariaDB / MySQL：用于用户认证、打印日志等应用级数据
 * 2. MSSQL：用于查询 ERP1 生产数据（替代原 Dify 工作流）
 *
 * 环境变量（可选，用于覆盖默认值）：
 *   DB_HOST     默认 localhost
 *   DB_PORT     默认 3306
 *   DB_USER     默认 pdfapp
 *   DB_PASSWORD 默认 ahypdfapp123
 *   DB_NAME     默认 pdf_print_db
 */

const mysql = require('mysql2/promise');
const mssql = require('mssql');

// ========== MariaDB / MySQL 连接池 ==========
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = parseInt(process.env.DB_PORT || '3306', 10);
const DB_USER = process.env.DB_USER || 'pdfapp';
const DB_NAME = process.env.DB_NAME || 'pdf_print_db';

console.log(`[db-config] MariaDB 连接目标: ${DB_HOST}:${DB_PORT}/${DB_NAME} (user=${DB_USER})`);

const pool = mysql.createPool({
  host: DB_HOST,
  port: DB_PORT,
  user: DB_USER,
  password: process.env.DB_PASSWORD || 'ahypdfapp123',
  database: DB_NAME,

  // 连接池配置
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,

  // 启用 prepared statement 缓存
  enableKeepAlive: true,
  keepAliveInitialDelay: 10000,

  // DATE / DATETIME 以字符串返回，避免 JSON 序列化后出现 T00:00:00.000Z
  dateStrings: true
});

/**
 * 测试 MariaDB 连通性
 */
async function testConnection() {
  try {
    const [rows] = await pool.execute('SELECT 1 AS ok');
    console.log('数据库连接成功:', rows[0]);
    return true;
  } catch (err) {
    console.error('数据库连接失败:', err.message);
    return false;
  }
}

// ========== MSSQL 连接池（ERP1） ==========
// 用于替代原 Dify 工作流，直接查询 ERP 生产数据
const mssqlConfig = {
  server: process.env.MSSQL_SERVER || 'sweisql01',
  port: parseInt(process.env.MSSQL_PORT || '1433', 10),
  database: process.env.MSSQL_DATABASE || 'ERP1',
  user: process.env.MSSQL_USER || 'ERPHengyu',
  password: process.env.MSSQL_PASSWORD || 'Hengyu@#88$&Diy',
  options: {
    encrypt: false,
    trustServerCertificate: true
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000
  }
};

const mssqlPool = new mssql.ConnectionPool(mssqlConfig);

/**
 * 测试 MSSQL 连通性
 */
async function testMssqlConnection() {
  try {
    await mssqlPool.connect();
    const result = await mssqlPool.request().query('SELECT 1 AS ok');
    console.log('MSSQL 连接成功:', result.recordset[0]);
    return true;
  } catch (err) {
    console.error('MSSQL 连接失败:', err.message);
    return false;
  }
}

module.exports = { pool, mssqlPool, testConnection, testMssqlConnection };
