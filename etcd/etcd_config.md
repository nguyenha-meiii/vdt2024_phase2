# SET UP ETCD TUTORIAL
## Step 1: Set up and config etcd
ETCD_LISTEN_PEER_URLS="http://172.16.149.138:2380"
ETCD_LISTEN_CLIENT_URLS="http://localhost:2379,http://172.16.149.138:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://172.16.149.138:2380"
ETCD_INITIAL_CLUSTER="default=http://172.16.149.138:2380,"
ETCD_ADVERTISE_CLIENT_URLS="http://172.16.149.138:2379"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"

etcdctl put service/dbcluster/members/node1 '{"conn_url":"postgres://172.16.149.134","role":"primary"}'


global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log global
    mode http
    option httplog
    option dontlognull
    timeout connect 5000
    timeout client 50000
    timeout server 50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend stats
    bind *:8404
    option http-use-htx
    http-request use-service prometheus-exporter if { path /metrics }
    stats enable
    stats uri /stats
    stats refresh 10s

# Frontend for write traffic
frontend pgsql_write
    bind *:5001
    mode tcp
    default_backend pgsql_write_backend

# Frontend for read traffic
frontend pgsql_read
    bind *:5002
    mode tcp
    default_backend pgsql_read_backend

# Backend for write traffic (primary database)
backend pgsql_write_backend
    mode tcp
    option pgsql-check user haproxy
    server postgresql_127.0.0.1_5432 127.0.0.1:5432 maxconn 100 check port 8008

# Backend for read traffic (replica databases)
backend pgsql_read_backend
    mode tcp
    balance roundrobin
    option pgsql-check user haproxy
{{range gets "/members/*"}}{{ $data := json .Value }}
{{ if eq $data.role "slave" }}
    server {{base .Key}} {{(index (split $data.conn_url "/") 2)}} maxconn 100 check
{{end}}{{end}}


etcdctl put /service/dbcluster/members/node2 '{"conn_url":"postgres://172.16.149.136:5432/postgres","role":"slave"}'

etcdctl put /service/dbcluster/members/node1 '{"conn_url":"postgres://172.16.149.134:5432/postgres","role":"slave"}'

etcdctl put /service/dbcluster/members/node3 '{"conn_url":"postgres://172.16.149.137:5432/postgres","role":"primary"}'

apt-get update
apt-get install procps

## Step 3: Set up API backend for etcd
- Config file in this link[]
- Set up environment to run backend
```shell
    $ python3 -m venv myenv
    $ source myenv/bin/activate

    # Install these packages for the first time
    $ pip3 install Flask etcd3
    $ pip install "protobuf==3.20.*"
    
    # Run API backend to update etcd
    $ python3 auto_api.py
    $ curl -X POST http://127.0.0.1:5005/update_cluster_info \
  -H "Content-Type: application/json" \
  -d '{
        "nodes": [
          {"name": "node1", "conn_url": "postgres://172.16.149.134:5432/postgres", "role": "slave"},
          {"name": "node2", "conn_url": "postgres://172.16.149.136:5432/postgres", "role": "primary"},
          {"name": "node3", "conn_url": "postgres://172.16.149.137:5432/postgres", "role": "slave"}
        ]
      }'
```
