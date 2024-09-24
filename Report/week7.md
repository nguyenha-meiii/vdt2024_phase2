# BÁO CÁO TUẦN 7


## MỤC TIÊU
- Chốt kiến trúc hệ thống cho tính năng read/write splitting
- Viết luồng hoạt động cho kiến trúc hệ thống đề xuất
- Xác định định hướng phát triển tương lai


## KẾT QUẢ

### Kiến trúc hệ thống

- Có 3 kiến trúc hệ thống được dề xuất:
    - pgpool-II (LB + CP): hiệu suất không cao do pgPool-II không mạnh về tính năng connection pooling như pgbouncer
    - pgPool-II (LB) + pgBouncer (CP): triển khai khó do pgPool-II có cả hai tính năng LB + CP nên cần tắt tính năng CP ở pgPool-II và sau đó cần config để hoạt động được với pgBouncer ngoài ra pgPool-II chỉ tương thích với postgreSQL
    - HA proxy (LB) + pgBouncer (CP): HA proxy có thể dễ dàng config để hoạt động cùng với pgBouncer ngoài ra HA proxy còn tương thích với nhiều hệ CSDL khác nhau đang được sử dụng ở DBaaS của Viettel Cloud

- Phát triển phương án 3 hướng đến tự động hoá khi có sự thay đổi về role trong cụm database (khi failover/switchover) bằng cách kết hợp HA proxy + confd + etcd
- Mô hỉnh triển khai theo phương án 3:
![img](../assets/architecture_v1.png)


### Luồng hoạt động
- Yêu cầu từ người dùng sẽ được scheduler lập lịch và được task manager thực hiện
- HA proxy sẽ thực hiện load balancing các queries đến từ người dùng và được đưa đến port 5001 nếu là write queries và port 5002 nếu là read queries. Tại port 5002, các queries sẽ được chia tải đều cho các read-only nodes theo thuật toán round robin
- Mỗi node database sẽ gồm 2 dịch vụ là pgbouncer và postgreSQL, ở đây pgbouncer giúp giữ connection pooling đến node database giúp đảm bảo hiệu suất của hệ thống
- Luồng tự động hoá:
    - Khi có sự thay đổi role primary-slave hay thêm node trong cụm database, sẽ call API backend cập nhật thông tin cụm database vào etcd
    - Confd sẽ định kỳ lấy thông tin từ etcd và tự động update file haproxy,cfg cho load balancing tới cụm database


### 

## CÂU HỎI
#### 1. Ở HAproxy, ngoài thuật toán round robin có thể sử dụng các thuật toán khác không?
#### 2. Future work??
- Hiện tại đang có xử lý tình huống failover cho HA proxy bằng keepalived => Có 3 node HA prõxy