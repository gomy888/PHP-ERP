-- 绿色版默认账号(仅用于本机/局域网开发环境)
-- root@localhost 由 --initialize-insecure 生成,密码为空
CREATE USER IF NOT EXISTS 'erp'@'%' IDENTIFIED BY 'erp_dev_2024';
CREATE USER IF NOT EXISTS 'erp'@'127.0.0.1' IDENTIFIED BY 'erp_dev_2024';
GRANT ALL PRIVILEGES ON erp_php.* TO 'erp'@'%';
GRANT ALL PRIVILEGES ON erp_php.* TO 'erp'@'127.0.0.1';
FLUSH PRIVILEGES;
