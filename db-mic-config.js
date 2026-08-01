/**
 * MIC 数据库连接配置（仪器/仪表到期查询）
 *
 * 环境变量（可选，用于覆盖默认值）：
 *   MIC_HOST     默认 172.19.40.90
 *   MIC_PORT     默认 3306
 *   MIC_USER     默认 hansen
 *   MIC_PASSWORD 默认 hansen
 *   MIC_NAME     默认 mic00001
 */

const mysql = require('mysql2/promise');

const MIC_HOST = process.env.MIC_HOST || '172.19.40.90';
const MIC_PORT = parseInt(process.env.MIC_PORT || '3306', 10);
const MIC_USER = process.env.MIC_USER || 'hansen';
const MIC_NAME = process.env.MIC_NAME || 'mic00001';

console.log(`[db-mic-config] MIC 连接目标: ${MIC_HOST}:${MIC_PORT}/${MIC_NAME} (user=${MIC_USER})`);

const micPool = mysql.createPool({
  host: MIC_HOST,
  port: MIC_PORT,
  user: MIC_USER,
  password: process.env.MIC_PASSWORD || 'hansen',
  database: MIC_NAME,

  waitForConnections: true,
  connectionLimit: 5,
  queueLimit: 0,

  enableKeepAlive: true,
  keepAliveInitialDelay: 10000,

  // DATE / DATETIME 以字符串返回，避免 JSON 序列化后出现 T00:00:00.000Z
  dateStrings: true
});

/**
 * 测试 MIC 数据库连通性
 */
async function testMicConnection() {
  try {
    const [rows] = await micPool.execute('SELECT 1 AS ok');
    console.log('[db-mic-config] MIC 数据库连接成功:', rows[0]);
    return true;
  } catch (err) {
    console.error('[db-mic-config] MIC 数据库连接失败:', err.message);
    return false;
  }
}

module.exports = { micPool, testMicConnection };
