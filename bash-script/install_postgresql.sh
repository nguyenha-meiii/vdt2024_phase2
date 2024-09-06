#!/bin/bash

# Cập nhật danh sách gói và nâng cấp các gói đã cài đặt
echo "Cập nhật danh sách gói và nâng cấp các gói..."
sudo apt update
sudo apt upgrade -y

# Cài đặt khóa kho lưu trữ PostgreSQL
echo "Cài đặt khóa kho lưu trữ PostgreSQL..."
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Thêm kho lưu trữ PostgreSQL
echo "Thêm kho lưu trữ PostgreSQL..."
RELEASE=$(lsb_release -cs)
echo "deb http://apt.postgresql.org/pub/repos/apt/ $RELEASE-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

# Cập nhật lại danh sách gói
echo "Cập nhật danh sách gói sau khi thêm kho lưu trữ PostgreSQL..."
sudo apt update

# Cài đặt PostgreSQL 14
echo "Cài đặt PostgreSQL 14..."
sudo apt install -y postgresql-14

# Cài đặt các gói bổ sung cho PostgreSQL (tuỳ chọn)
echo "Cài đặt các gói bổ sung cho PostgreSQL..."
sudo apt install -y postgresql-contrib-14

# Khởi động và kích hoạt dịch vụ PostgreSQL
echo "Khởi động và kích hoạt dịch vụ PostgreSQL..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Cập nhật cấu hình PostgreSQL để nhận kết nối từ các server khác
echo "Cập nhật cấu hình PostgreSQL để nhận kết nối từ các server khác..."
sudo bash -c "echo \"listen_addresses = '*'\" >> /etc/postgresql/14/main/postgresql.conf"

# Cập nhật cấu hình pg_hba.conf để cho phép kết nối từ xa
echo "Cập nhật cấu hình pg_hba.conf để cho phép kết nối từ xa..."
sudo bash -c "cat <<EOF >> /etc/postgresql/14/main/pg_hba.conf
# Allow connections from any IP address
host    all             all             0.0.0.0/0               scram-sha-256
host    all             all             ::1/128                 scram-sha-256
# Allow replication connections
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
EOF"

# Khởi động lại dịch vụ PostgreSQL để áp dụng các thay đổi
echo "Khởi động lại dịch vụ PostgreSQL để áp dụng các thay đổi..."
sudo systemctl restart postgresql

# Mở firewall và cổng 5432
echo "Mở firewall và cổng 5432..."
sudo ufw enable
sudo ufw allow 5432/tcp

# Kiểm tra và mở cổng 22 nếu cần
echo "Kiểm tra và mở cổng 22..."
sudo ufw status | grep '22/tcp' || sudo ufw allow 22/tcp

# Kiểm tra trạng thái của dịch vụ PostgreSQL
echo "Kiểm tra trạng thái của dịch vụ PostgreSQL..."
sudo systemctl status postgresql

echo "Cài đặt và cấu hình PostgreSQL 14 đã hoàn tất."
