from flask import Flask, request, jsonify
import etcd3
import json

# Initialize the Flask app
app = Flask(__name__)

# Initialize etcd client
etcd_client = etcd3.client(host='172.16.149.138', port=2379)

# Helper function to store node information in etcd
def update_node_info(node_name, conn_url, role):
    key = f"/service/dbcluster/members/{node_name}"
    value = json.dumps({"conn_url": conn_url, "role": role})
    etcd_client.put(key, value)

@app.route('/')
def index():
    return "Welcome to the PostgreSQL Cluster API", 200

# Route to update the entire cluster information
@app.route('/update_cluster_info', methods=['POST'])
def update_cluster_info():
    try:
        # Get data from POST request
        data = request.get_json()
        nodes = data['nodes']  # List of nodes with their roles and connection URLs
        
        # Save each node info to etcd
        for node in nodes:
            node_name = node['name']
            conn_url = node['conn_url']
            role = node['role']
            update_node_info(node_name, conn_url, role)

        return jsonify({"message": "Cluster info updated successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Route to get the entire cluster information
@app.route('/get_cluster_info', methods=['GET'])
def get_cluster_info():
    try:
        # Get all nodes under /service/dbcluster/members/
        nodes = etcd_client.get_prefix("/service/dbcluster/members/")
        cluster_info = {}
        for value, metadata in nodes:
            cluster_info[metadata.key.decode('utf-8')] = json.loads(value.decode('utf-8'))
        
        # Return the cluster information
        return jsonify(cluster_info), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Start the Flask application
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5005)
