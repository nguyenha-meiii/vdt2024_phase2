# BÁO CÁO TUẦN 6


## MỤC TIÊU
- Các chức năng của cụm database:
    - Read/write splitting
    - Backup & Restore
    - Add node RO
    - Failover/ switchover

- Tự động hoá các quy trình trên bằng 1 dịch vụ với 3 thành phần cơ bản => service = API + task manager + scheduler (Đã có)
    - API: lưu trữ, biểu diễn các thông tin cluster và các thành phần liên quan trong hệ thống (users, phân quyền, authentication)
    - Task manager: thực hiện các long-term tasks (tác vụ kéo dài)
    - Scheduler: lập lịch cho các tác vụ
    - Thông thường luồng sẽ là: User => API => scheduler => task manager
    - VD: với backup thì task manager sẽ monitor quá trình back up còn scheduler đảm bảo task manager sẽ lập lịch cho quá trình backup (vd: backup định kỳ trên node promary)

- Ngoài 3 thành phần cơ bản trên còn có: message queue, caching, LB(dùng cho servive, khác với LB cho daatabase)

- Yêu cầu:
    - Quá trình set up các chức năng trên 
    - Kết hợp với các dịch vụ khác như thế nào

## NGHIÊN CỨU

### SCheduler
- Scheduler: pgAgent,cron jobs, Active Batch
    - crucial role in automating tasks and streamlining processes

## CÂU HỎI

 # TYPE  DATABASE        USER            ADDRESS                 METHOD
    local   all             all                                     peer
    # IPv4 local connections:
    host    all             all             0.0.0.0/0               scram-sha-256
    # IPv6 local connections:
    host    all             all             ::1/128                 scram-sha-256
    # Allow replication connections from localhost, by a user with the
    # replication privilege.
    local   replication     all                                     peer
    host    replication     all             127.0.0.1/32            scram-sha-256
    host    replication     all             ::1/128                 scram-sha-256
    host    replication     replicator      all                     md5
    host    all     all      true