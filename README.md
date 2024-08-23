# Viettel Digital Talent 2024 - PHASE 2 - Project
Author: **Nguyen Thu Ha**

## Table of Contents 
- [0. Project Description](#0-project-description)
- [1. Reaserch](#1-research)
- [2. PgBouncer](#2-pgbouncer)
- [3. Pgpool-II](#3-pgpool-ii)
- [4. Xây dựng mô hình](#4-xây-dựng-mô-hình-đảm-bảo-load-balancing--connection-pooling-kết-hợp-pgbouncer-và-pgpool-ii)
- [5. Set up PostgreSQL HA](#5-set-up-postgresql-ha)

## 0. Project description

### Đề bài
- Xây dựng tính năng read/write splitting cho dịch vụ Database as a service
    - Cho phép ứng dụng điều hướng các write traffic (insert, update, delete queries) đến read-write instances (thường là primary node)
    - Cho phép ứng dụng điều hướng các read traffic (select queries) đến read-only instances. 
- Requirements: 
    - Xây dựng các read-only nodes chỉ làm nhiệm vụ xử lý các select queries và replicate data từ primary node (không làm nhiệm vụ thay thế khi primary node bị sập => đã có 1 standby làm nhiệm vụ này)
    - Tự động điều chỉnh số lượng read-only nodes theo yêu cầu của người dùng
    - 
- anc

## 1. PgBouncer

### Tổng quan
- PgBouncer:
    - connection pooling in PostgreSQL
    - Không hỗ trợ load balancing (LB) và high-availability => Dùng HAProxy hoặc Pgbool II

- Khi nhận được 1 yêu cầu kết nối từ người dùng, PgBouncer làm nhiệm vụ xác thực người dùng thay cho PostgreSQL server. PgBouncer hỗ trợ mọi cơ chế xác thực của PostgreSQL. Có 2 phương thức xác thực:
    - PgBouncer check userlist.txt file lưu dưới dạng các set tuples (username, md5 encrypted, passwords) => nếu có username trong file => check password => nếu password trùng thì không tạo kết nối mới tới SQL server
    - Xác lập passthrough authentication & không tìm thấy user trong userlist.txt => PgBouncer tìm kiếm auth_query => Kết nối đến PostgreSQL dưới dạng predefined user (người dùng đã được xác định trước với password đã có trong file userlist.txt) => Thực hiện truy vấn xác thực để tìm mật khẩu và khớp với giá trị đã được cấp
    => 1 trong những ưu điểm của PgBouncer so với Pgpool-II vì thực hiện chuyển tiếp yêu cầu xác thực qua PostgreSQL server, không cần config lại PgBouncer khi có sự điều chỉnh (vd:password) ở PostgreSQL server

- Sau khi xác thực client, PgBouncer thực hiện thiết lập kết nối.

- Sau khi đã kết nối, PgBouncer dựa vào pooling mode để trả lại connecttion cho database. Trước khi trả lại kết nối, PgBouncer chạy reset query thực hiện xoá các thông tin phiên (đảm bảo an toàn khi chia sẻ connections giữa các clients khác nhau) 

### Setup PgBouncer 
- Tutorial: [Document](https://www.linkedin.com/pulse/efficient-postgresql-management-complete-guide-installing-configuring-rxkzc/)
- Tutorial youtube: [Youtube](https://www.youtube.com/watch?v=ddKm7a7xOpk&t=196s&pp=ygUoc2V0IHVwIGFuZCBjb25maWd1cmUgcGdib3VuY2VyIG9uIHVidW50dQ%3D%3D)
- https://severalnines.com/blog/guide-using-pgbouncer/

## 2. Pgpool-II

### Tổng quan
- Pgpool-II hỗ trợ 
    - Automated load balancing => cân bằng tải giữa masters và slaves => write loads được đưa đến master + read loads được đưa đến slaves
    - High-availability => Tạo logical replication (option cho phiên bản cũ của PosrgreSQL còn với phiên bản mới của PostgreSQL đã có inbuilt replication)
    - Connection pooling

![img](./assets/Pgpool_architecture.png)

### Cách thức hoạt động của Connection pooling

 ![img](./assets/Pgpool_connection_pooling.png)
- Tiến chính cha của Pgpool-II forks 32 tiến trình con (dùng cho việc kết nối với database) => tương tự với kiến trúc của PostgreSQL: 1 process = 1 connection
- Kernel điều hướng các kết nối mới tới 1 trong các tiến trình con (cả Pgpool-II và end users đều không thể quyết định tiến trình con nào sẽ nhận kết nối). Nếu không có tiến trình con nào nhận yêu cầu kết nối thì yêu cầu kết nối sẽ được đẩy vào hàng đợi
- Nhận xét:
    - Pgpool không thực sự tốt trong connnection pooling đặc biệt với số lượng client nhỏ. Do mỗi tiến trình con có 1 pool riêng và không có cách kiểm soát yêu cầu kết nối nào sẽ đến tiến trình con nào.
    - Pgpool làm rất tốt việc load balancing và là tool xây dựng cho postgreSQL

### Load balancing in PgPool-II
- Hiện tại Pgpool-II đã có version 4.5.3

### Config Pgpool-II
- [Tutorial](https://elroydevops.tech/postgresql-high-availability-master-slave/)

## 3. HAproxy

### Tổng quan

### Setup and config HAproxy cho load balancing

## 4. Xây dựng mô hình
- Connection pooling: pgBouncer

- Load balancing
    - Pgpool-II:
        - Đảm nhận Automatic failover cho cluster=> viết script để khi primary node gặp lỗi sẽ chuyển sang standby 
        - High availability => PgBouncer có các watchdog (giống các replica) để thay thế khi gặp failover
        - Load balancing: sau khi xem xét 4 lựa chọn cho PostgreSQL database ở [link](https://www.heatware.net/postgresql/postgresql-load-balancing-options-ha/) thì Pgpool-II là tối ưu nhất => Có thể config Pgpool-II để gửi write requests đến primary node và read requests đến replicas.
Hoặc
    - HAproxy

- Automatic failover and backup: repmgr

- PostgreSQL built-in streaming replication: sync data giữa primary và replicas


- Mô hình đơn giản như sau:

    - Sử dụng HAproxy cho load balancing:
    ![img](./assets/model_HAproxy.png)

    - Sử dụng pgpool-II cho load balancing:

## 5. Set up postgreSQL HA

### Tổng quan
- Triển khai database trên 3 server khác nhau trong đó có 1 node là master 2 node còn lại là slave. 
    - Server 1: 172.16.149.134 - Server master
    - Server 2: 172.16.149.136 - Server slave 1
    - Server 3: 172.16.149.137 - Server slave 2 (standby replica)
    - Server 4: 172.16.149.139 - HAproxy 
- Các bước cấu hình
    - Thiết lập master-slave
    - Thiết lập PostgreSQL HA
    - Thiết lập automatic failover và backup
- [Chi tiết các bước cấu hình](https://github.com/nguyenha-meiii/vdt2024_phase2/tree/main/PostgresSQL%20HA)

### Mục tiêu
- Xây dựng hệ thống master - slave với node slave chỉ phục vụ read queries còn master node phục vụ cả read-write queries và nếu master node bị hỏng 1 node slave lên thay thế làm node master
- Thiết lập high availability (HA) cho PostgreSQL với HAproxy
    - Kết nối 3 servers PostgreSQL thành 1 connection duy nhất
    - Thực hiện load balancing giữa các servers (mục tiêu của mình là đẩy hết các read queries qua slave và để master chỉ nhận các write queries nhưng hiện tại em chưa tìm ra được tutorial nào, kết quả đầu ra hiện tại sẽ là chia tải về 3 servers)
