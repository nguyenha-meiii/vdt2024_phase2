# BÁO CÁO TUẦN 5

## MỤC TIÊU
- Triển khai backup và restore data trên storage (MinIO)
    - Lưu backup data dưới dạng 1 file nén
    - Dịch chuyển data dứới dạng 1 stream (tích hợp sẵn ở S3)

- Config manual failover
    - Khi node primary down, sẽ đẩy 1 node replica có data sát nhất với primary lên thay thế
    - Cần cơ chế xác nhận dữ liệu của replica gần nhất với primary
    - Tìm hiểu cơ chế phục hồi node từ backup

- 1 cluster 2 nodes

## NGHIÊN CỨU

### Overview 
- Nếu sử dụng MinIO/S3 để lưu backup trong trường hợp sử dụng pg_basebackup:
    - pg_basebackup không hỗ trợ tích hợp với MinIO/S3
    - Cần các công cụ như MinIO Client/AWS CLI để tải bản sao lưu lên MinIO sau khi đã taọ bản sao lưu cục bọo trên máy chủ

- Nếu sử dụng MinIO/S3 để lưu backup trong trường hợp sử dụng pgBackRest:
    - pgBackrest hỗ trợ tích hợp với MinIO/S3

### Comparison
    - Compress backup data as a file
        - Nếu backup data lớn sẽ tốn dung lượng ổ cứng
        - Sau mỗi lần backup cần phải xoá file backup
    - Upload and restore data as a stream
        - 

- Upload and restore data as a stream using mc pipe
    ```shell
        # Stream backup using mc pipe
        $ sudo -u postgres pg_basebackup -h  /var/run/postgresql -U postgres -Ft -z --wal-method=fetch --pgdata=- | mc pipe myminio/mybucket/backup.tar.gz

        # Stream backup fỏ restoration 
        $ mc cat myminio/mybucket/backup.tar.gz | sudo -u postgres tar -xzvf - -C /var/lib/postgresql/14/main/
    ```

## Kết quả

### Back up & Restore dưới dạng file nén sử dụng MinIO
- Cấu hình MinIO:


- Đẩy file backup lên MinIO
``shell
    # Tải và cài đặt quyền cho MinIO Client
    $ sudo wget https://dl.min.io/client/mc/release/linux-amd64/mc
    $ sudo chmod +x mc

    # Di chuyển câu lệnh mc về directory /usr/local/bin/
    $ sudo mv mc /usr/local/bin/

    # Kiểm tra cài đặt MinIO client thành công chưa
    $ mc --version
    mc version RELEASE.2024-08-26T10-49-58Z (commit-id=a55d9a8d17dae78d0373691ba676170172765883)
    Runtime: go1.22.6 linux/amd64
    Copyright (c) 2015-2024 MinIO, Inc.
    License GNU AGPLv3 <https://www.gnu.org/licenses/agpl-3.0.html>

    # Cấu hình MinIO client với MinIO server(ở đây là địa chỉ của máy cục bộ chạy MinIO container)
    $ mc alias set myminio http://10.61.220.133:9000 hanthust 123456abc --api S3v4

    # Upload file backup lên bucket demo1
    $ mc cp /home/hanthust/test.tar.gz myminio/demo1/backups/

    # Kiểm tra file backup được upload backup thành công
    $ mc ls myminio/demo1/backups/
    [2024-09-04 09:48:33 UTC] 3.2MiB STANDARD test.tar.gz
```
- Kết quả khi truy cập vào địa chỉ http://127.0.0.1:9001:
    ![img](../assets/week%205/minIO_UI.png)

- Sau khi upload file backup lên MinIO cần phải xoá file lưu trữ ở local => Một trong những nhược điểm của việc lưu trữ backup bằng file
``shell
    $ sudo rm /home/hanthust/test.tar.gz
```

- Restore với file backup đã upload lên MinIO:
``shell
   # Tải bản sao lưu về từ MinIO
   $ mc cp myminio/your-bucket-name/backups/test.tar.gz /home/hanthust/
   # Các bước còn lại tương tự quá trình backup thông thường
```