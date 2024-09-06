#!/bin/bash

# Cấu hình các biến cần thiết
PRIMARY_HOST="172.16.149.134"
REPLICATOR_USER="replicator"
PASSWORD="123456"
MINIO_BUCKET="myminio/demo1/backups"
BACKUP_FILE="test.tar.gz"
LOCAL_BACKUP_PATH="/home/hanthust/$BACKUP_FILE"
DATA_DIR="/var/lib/postgresql/14/main"
POSTGRES_CONF="/etc/postgresql/14/main/postgresql.auto.conf" 

# Cài đặt MinIO Client 
if ! command -v mc &> /dev/null
then
    echo "MinIO Client (mc) không tìm thấy. Đang cài đặt..."
    wget https://dl.min.io/client/mc/release/linux-amd64/mc
    chmod +x mc
    mv mc /usr/local/bin/
    echo "MinIO Client (mc) đã được cài đặt."
fi

# Cấu hình MinIO Client
mc alias set myminio http://10.61.220.133:9000 hanthust 123456abc --api S3v4

# Tải file backup từ MinIO
echo "Tải file backup từ MinIO..."
mc cp myminio/$MINIO_BUCKET/$BACKUP_FILE $LOCAL_BACKUP_PATH

# Dừng dịch vụ PostgreSQL
echo "Dừng dịch vụ PostgreSQL..."
sudo systemctl stop postgresql

# Xóa dữ liệu hiện tại
echo "Xóa dữ liệu PostgreSQL hiện tại..."
sudo rm -rf $DATA_DIR/*

# Giải nén file backup vào thư mục dữ liệu PostgreSQL
echo "Giải nén file backup vào thư mục dữ liệu PostgreSQL..."
sudo tar -xzf $LOCAL_BACKUP_PATH -C $DATA_DIR

# Đặt quyền cho thư mục dữ liệu
echo "Đặt quyền cho thư mục dữ liệu..."
sudo chown -R postgres:postgres $DATA_DIR
sudo chmod 700 $DATA_DIR

# Tạo file standby.signal
echo "Tạo file standby.signal..."
sudo touch $DATA_DIR/standby.signal

# Cập nhật cấu hình PostgreSQL (file postgresql.auto.conf sẽ được cập nhật qua ALTER SYSTEM)
echo "Cập nhật cấu hình PostgreSQL..."

# Thêm đầy đủ các trường vào primary_conninfo
sudo -u postgres psql -c "ALTER SYSTEM SET primary_conninfo = 'user=$REPLICATOR_USER password=$PASSWORD channel_binding=prefer host=$PRIMARY_HOST port=5432 sslmode=prefer sslcompression=0 sslcertmode=allow sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres gssdelegation=0 target_session_attrs=any load_balance_hosts=disable';"

# Cập nhật primary_slot_name
sudo -u postgres psql -c "ALTER SYSTEM SET primary_slot_name = 'slave_3';"

# Khởi động lại dịch vụ PostgreSQL
echo "Khởi động lại dịch vụ PostgreSQL..."
sudo systemctl start postgresql

# Kiểm tra trạng thái PostgreSQL
echo "Kiểm tra trạng thái dịch vụ PostgreSQL..."
sudo systemctl status postgresql

echo "Cấu hình node slave hoàn tất."
