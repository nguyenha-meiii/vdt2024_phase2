# BÁO CÁO TUẦN 5

## MỤC TIÊU
- Triển khai backup và restore data trên storage (MinIO)
    - Lưu backup data dưới dạng 1 file nén
    - Dịch chuyển data dứới dạng 1 stream (tích hợp sẵn ở S3)

- Config manual failover (Chưa làm làm:>>)
    - Khi node primary down, sẽ đẩy 1 node replica có data sát nhất với primary lên thay thế
    - Cần cơ chế xác nhận dữ liệu của replica gần nhất với primary
    - Tìm hiểu cơ chế phục hồi node từ backup

- Xây dựng dựng node mới từ file backup trên MinIO của node primary và follow đến node primary
    - File backup sẽ ko up to date vs data của node primary nếu sau khi backup file primary có chỉnh sửa => So sánh

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
    - Không cần lưu file backup về local, tiết kiếm dung lượng ổ cứng, tiết kiệm thời gian khi backup/restore
    - Tốn RAM

    - Upload and restore data as a stream using `mc pipe`

        ```shell
            # Stream backup using mc pipe
            $ sudo -u postgres pg_basebackup -h  /var/run/postgresql -U postgres -Ft -z --wal-method=fetch --pgdata=- | mc pipe myminio/mybucket/backup.tar.gz

            # Stream backup for restoration 
            $ mc cat myminio/mybucket/backup.tar.gz | sudo -u postgres tar -xzvf - -C /var/lib/postgresql/14/main/
        ```

## Kết quả

### Back up & Restore dưới dạng file nén sử dụng MinIO
- Cấu hình MinIO:


- Đẩy file backup lên MinIO
    ```shell
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
    ```shell
    $ sudo rm /home/hanthust/test.tar.gz
    ```

- Restore với file backup đã upload lên MinIO:
    ```shell
    # Tải bản sao lưu về từ MinIO
    $ mc cp myminio/your-bucket-name/backups/test.tar.gz /home/hanthust/
    # Các bước còn lại tương tự quá trình backup thông thường
    ```

### Tạo node slave mới với backup file từ node primary
- Ở bài lab thực hiện backup và restore ở tuần 4, sau khi thực hiện ở cả 3 node như sau [link](https://github.com/nguyenha-meiii/vdt2024_phase2/blob/main/Report/week4.md) thì gặp vấn đề mất nội dung file cấu hình master-slave ở các node. Và sẽ cần tiến hành config lại cấu hình slave ở các node như hình dưới đây:
    ![img](../assets/week%205/img1.png)

=> Do sau khi thực hiên lệnh `rm -rf /var/lib/postgresql/14/main/*`, ta sẽ xoá cả hai file config là signal.stanby và postgresql.auto.conf nên cấu hình master-slave sẽ bị xoá theo. Tuy nhiên, `pg_basebackup` chỉ có khả năng sao lưu các file dữ liệu và file WALs nên khi hồi phục, hai file trên sẽ không được hồi phục như ban đầu và dẫn đến vấn đề như hình trên.

- Khi tạo 1 node mới với yêu cầu backup data từ node primary thì ta sẽ có những giải pháp sau:
    - Cần config slave role ở node mới bằng tay hoặc bằng script
        - Step 1: Install postgreSQL database: Cài đặt file bash script ở [link](https://github.com/nguyenha-meiii/vdt2024_phase2/blob/main/bash-script/install_postgresql.sh) sau và thực hiện các câu lệnh
        ```shell
        $ sudo chmod +x install_postgresql.sh
        $ ./install_postgresql.sh
        ```
        - Step 3: Thực hiện backup data từ minIO storage bằng file bash script ở [link](https://github.com/nguyenha-meiii/vdt2024_phase2/blob/main/bash-script/backup_data.sh)
           ```shell
        $ sudo chmod +x backup_data.sh
        $ ./backup_data.sh
        ```
        - Step 2: Config slave role: Config bằng file bash script ở [link](https://github.com/nguyenha-meiii/vdt2024_phase2/blob/main/bash-script/config_slave.sh) sau và thực hiện các câu lệnh
        ```shell
        $ sudo chmod +x config_slave.sh
        $ ./config_slave.sh
        ```

        - Note: cần config sao cho IP của node mới nằm trong file `/etc/postgresql/14/main/pg_hba.conf` của node primary
        - Kết quả: Tạo được 1 node mới với nội dung data là data của node primary khi thực hiện backup => xuất hiện inconsistency nếu sau khi thực hiện backup node primary có những thay đổi về dữ liệu
        ![img](../assets/week%205/img2.png)

    - Sử dụng `pgBackRest` hoặc `Barman`, hai tool này hỗ trợ sao lưu và phục hồi cả các file cấu hình


## CÂU HỎI

#### 1. Khi muốn thêm 1 node mới thì sẽ cần thêm IP của node đó vào trong file  `/etc/postgresql/14/main/pg_hba.conf` của node primary,điều này sẽ ảnh hưởng đến quá trình tự động hoá?
- Gỉải pháp 1: Config ở node primary như sau:

```shell
    # Các bước trước vẫn được giữ nguyên
    ...
    # Chuyển qua user postgres
    $ sudo vi /etc/postgresql/14/main/pg_hba.conf

    # Thêm các địa chỉ IP của các node slave vào cuối file
    host    replication     replicator      0.0.0.0/0               md5
    host    replication     replicator      ::/0                    md5

    # Khởi động lại PostgreSQL
    $ systemctl restart postgresql
```
=> Phát sinh vấn đề liên quan đến failover khi node primary down, config lại từ đầu cho nút lên thay thế vị trí primary. Nếu lấy 1 node slave sẵn có sẽ phải làm ntn???
    - Như với cụm patroni thì việc config ở file pg_hba.conf tất cả các node là như nhau, các file slave sẽ có thêm file signal.standby và việc này được tự động hoá bởi patroni với sự hỗ trợ của các tool như etcd, ZooKeeper, or Consul. VD: etcd quản lý trạng thái của cụm postgreSQL, khi có 1 sự thay đổi nào(vd: node primart down) sẽ update ETCD key-value store => Patroni sử dụng thông tin này để bình chọn ra node master