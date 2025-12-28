#!/bin/bash

# 交互式获取用户输入的平台名称
read -p "请输入平台需要修改的名称: " platform_name

# 检查输入是否为空
if [ -z "$platform_name" ]; then
    echo "错误：平台名称不能为空！"
    exit 1
fi

echo "正在设置平台名称为: $platform_name"

# 1. 创建SQL文件
cat > /root/a.sql << EOF
update t_common_config set configValue = '$platform_name' where prefix = 'style' and configKey = 'title';
EOF

echo "✓ SQL文件创建完成"

# 2. 进入mirror pod获取MySQL密码
echo "正在获取MySQL密码..."

# 获取mirror pod名称（获取第一个mirror开头的pod）
mirror_pod=$(kubectl get pods -n ailpha-xdr | grep ^mirror- | head -1 | awk '{print $1}')

if [ -z "$mirror_pod" ]; then
    echo "错误：未找到mirror pod！"
    exit 1
fi

# 获取MySQL密码
mysql_password=$(kubectl exec -it -n ailpha-xdr $mirror_pod -- env | grep MYSQL | grep PASSWORD | head -1 | awk -F'=' '{print $2}')

if [ -z "$mysql_password" ]; then
    echo "错误：未找到MySQL密码！"
    exit 1
fi

echo "✓ MySQL密码获取完成"

# 3. 拷贝SQL文件到MySQL pod
echo "正在拷贝SQL文件到MySQL pod..."
kubectl cp /root/a.sql mysql-primary-0:/tmp/ -n mysql

if [ $? -ne 0 ]; then
    echo "错误：文件拷贝失败！"
    exit 1
fi

echo "✓ SQL文件拷贝完成"

# 4. 执行SQL语句
echo "正在执行SQL更新..."
kubectl exec -ti -n mysql mysql-primary-0 -- bash -c "mysql -udbapp -p'$mysql_password' -e \"use bigdata-web; source /tmp/a.sql;\""

if [ $? -eq 0 ]; then
    echo "✓ 平台名称更新成功！"
    echo "新平台名称: $platform_name"
else
    echo "错误：SQL执行失败！"
    exit 1
fi

# 5. 清理临时文件
rm -f /root/a.sql
echo "✓ 临时文件清理完成"
