#!/bin/bash

# curl -sSL https://raw.githubusercontent.com/chihqiang/sh/main/mysql/monitor.sh | bash -s "/usr/bin/mysql -h127.0.0.1 -P3306 -uroot -p123456 mysql"
# bash monitor.sh "/usr/bin/mysql -h127.0.0.1 -P3306 -uroot -p123456 mysql"

sqlconnect="${1:-"/usr/bin/mysql -h127.0.0.1 -P3306 -uroot -p123456 mysql"}"

# 定义函数执行MySQL查询
mysql_query() {
    query=$1
    ${sqlconnect} -e "$query" 2>/dev/null | awk 'NR==2 {print $2}'
}

echo "========= 基本配置信息 ==========="

lower_case_table_names_val=$(mysql_query "show variables like 'lower_case_table_names';")
echo "不区分大小写：$lower_case_table_names_val"

_port_val=$(mysql_query "show variables like 'port';")
echo "端口：$_port_val"

socket_val=$(mysql_query "show variables like 'socket';")
echo "socket的值：$socket_val"

skip_name_resolve_val=$(mysql_query "show variables like 'skip_name_resolve';")
echo "域名解析skip_name_resolve：$skip_name_resolve_val"

character_set_server_val=$(mysql_query "show variables like 'character_set_server';")
echo "数据库字符集character_set_server：$character_set_server_val"

interactive_timeout_val=$(mysql_query "show variables like 'interactive_timeout';")
echo "交互式连接超时时间：$interactive_timeout_val 秒"

wait_timeout_val=$(mysql_query "show variables like 'wait_timeout';")
echo "非交互式连接超时时间：$wait_timeout_val 秒"

query_cache_type_val=$(mysql_query "show variables like 'query_cache_type';")
echo "查询缓存query_cache_type：$query_cache_type_val"

innodb_version_val=$(mysql_query "show variables like 'innodb_version';")
echo "数据库版本：$innodb_version_val"

trx_isolation_val=$(mysql_query "show variables like 'tx_isolation';")
echo "隔离级别trx_isolation：$trx_isolation_val"

datadir_val=$(mysql_query "show variables like '%datadir%';")
echo "mysql 数据文件存放位置：$datadir_val"

echo "========= 连接数配置信息 ==========="

max_connections_val=$(mysql_query "show variables like 'max_connections';")
echo "最大连接数：$max_connections_val"

Max_used_connections_val=$(mysql_query "show status like 'Max_used_connections';")
echo "当前连接数：$Max_used_connections_val"

max_connect_errors_val=$(mysql_query "show variables like 'max_connect_errors';")
echo "最大错误连接数：$max_connect_errors_val"

echo "========= binlog配置信息 ==========="

sync_binlog_val=$(mysql_query "show variables like 'sync_binlog';")
echo "sync_binlog：$sync_binlog_val"

binlog_format_val=$(mysql_query "show variables like 'binlog_format';")
echo "binlog格式：$binlog_format_val"

log_bin_val=$(mysql_query "show variables like 'log-bin';")
echo "binlog文件：$log_bin_val"

expire_logs_days_val=$(mysql_query "show variables like 'expire_logs_days';")
echo "binlog文件过期时间：$expire_logs_days_val"

echo "========= GTID配置信息 ==========="

gtid_mode_val=$(mysql_query "show variables like 'gtid_mode';")
echo "是否开启gtid_mode：$gtid_mode_val"

enforce_gtid_consistency_val=$(mysql_query "show variables like 'enforce_gtid_consistency';")
echo "enforce_gtid_consistency是否开启：$enforce_gtid_consistency_val"

log_slave_updates_val=$(mysql_query "show variables like 'log_slave_updates';")
echo "级联复制是否开启log_slave_updates：$log_slave_updates_val"

echo "======== InnoDB配置信息 ========="

innodb_buffer_pool_size_val=$(mysql_query "show variables like 'innodb_buffer_pool_size';")
echo "innodb_buffer_pool_size：$innodb_buffer_pool_size_val"

innodb_log_file_size_val=$(mysql_query "show variables like 'innodb_log_file_size';")
echo "innodb_log_file_size：$innodb_log_file_size_val"

innodb_flush_log_at_trx_commit_val=$(mysql_query "show variables like 'innodb_flush_log_at_trx_commit';")
echo "innodb_flush_log_at_trx_commit：$innodb_flush_log_at_trx_commit_val"

innodb_io_capacity_val=$(mysql_query "show variables like 'innodb_io_capacity';")
echo "innodb_io_capacity：$innodb_io_capacity_val"

# 新增监控指标
echo "================= 监控指标 ==============================="

# 监控内存使用情况
innodb_buffer_pool_size_mb=$(($innodb_buffer_pool_size_val / 1024 / 1024))
echo "InnoDB 数据和索引缓存：$innodb_buffer_pool_size_mb MB"

# 查询缓存命中率
query_cache_hits=$(mysql_query "show status like 'Qcache_hits';")
echo "查询缓存命中次数：$query_cache_hits"

query_cache_inserts=$(mysql_query "show status like 'Qcache_inserts';")
echo "查询缓存插入次数：$query_cache_inserts"

# 监控线程使用情况
threads_connected=$(mysql_query "show status like 'Threads_connected';")
echo "当前连接线程数：$threads_connected"

threads_running=$(mysql_query "show status like 'Threads_running';")
echo "当前运行线程数：$threads_running"

threads_created=$(mysql_query "show status like 'Threads_created';")
echo "创建的线程数：$threads_created"

threads_cached=$(mysql_query "show status like 'Threads_cached';")
echo "缓存的线程数：$threads_cached"

# 慢查询日志
slow_queries=$(mysql_query "show status like 'Slow_queries';")
echo "慢查询次数：$slow_queries"

# InnoDB 相关性能指标
innodb_rows_read=$(mysql_query "show status like 'Innodb_rows_read';")
echo "InnoDB 读取的行数：$innodb_rows_read"

innodb_rows_inserted=$(mysql_query "show status like 'Innodb_rows_inserted';")
echo "InnoDB 插入的行数：$innodb_rows_inserted"

innodb_rows_updated=$(mysql_query "show status like 'Innodb_rows_updated';")
echo "InnoDB 更新的行数：$innodb_rows_updated"

innodb_rows_deleted=$(mysql_query "show status like 'Innodb_rows_deleted';")
echo "InnoDB 删除的行数：$innodb_rows_deleted"
