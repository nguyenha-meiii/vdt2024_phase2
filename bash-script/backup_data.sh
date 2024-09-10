#!/bin/bash

# Cấu hình các biến cần thiết
MINIO_BUCKET="myminio/demo1/backups"
BACKUP_FILE="test.tar.gz"
LOCAL_BACKUP_PATH="/home/hanthust/$BACKUP_FILE"
DATA_DIR="/var/lib/postgresql/14/main"

# Cài đặt MinIO Client nếu chưa cài đặt
if ! command -v mc &> /dev/null
then
    echo "MinIO Client (mc) không tìm thấy. Đang cài đặt..."
    wget https://dl.min.io/client/mc/release/linux-amd64/mc
    chmod +x mc
    sudo mv mc /usr/local/bin/
    echo "MinIO Client (mc) đã được cài đặt."
fi

# Cấu hình MinIO Client
mc alias set myminio http://10.61.220.133:9000 hanthust 123456abc --api S3v4

# Tải file backup từ MinIO
echo "Tải file backup từ MinIO..."
mc cp ${MINIO_BUCKET}/${BACKUP_FILE} $LOCAL_BACKUP_PATH

# Dừng dịch vụ PostgreSQL
echo "Dừng dịch vụ PostgreSQL..."
sudo systemctl stop postgresql

# Xóa dữ liệu trong thư mục data của PostgreSQL
echo "Xóa dữ liệu PostgreSQL hiện tại..."
sudo rm -rf $DATA_DIR/*

# Giải nén file backup vào thư mục data của PostgreSQL
echo "Giải nén file backup vào thư mục dữ liệu PostgreSQL..."
sudo -u postgres tar -xzf $LOCAL_BACKUP_PATH -C $DATA_DIR

# Đặt quyền cho thư mục dữ liệu PostgreSQL
echo "Đặt lại quyền cho thư mục dữ liệu..."
sudo chown -R postgres:postgres $DATA_DIR
sudo chmod 700 $DATA_DIR

# Khởi động lại dịch vụ PostgreSQL
echo "Khởi động lại dịch vụ PostgreSQL..."
sudo systemctl start postgresql

# Kiểm tra trạng thái PostgreSQL
echo "Kiểm tra trạng thái dịch vụ PostgreSQL..."
sudo systemctl status postgresql

echo "Hoàn tất quá trình tải backup và khôi phục dữ liệu."
