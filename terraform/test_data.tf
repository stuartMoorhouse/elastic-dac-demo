# Create test data in both Development and Local Elasticsearch for C2 detection demo
resource "null_resource" "create_test_data" {
  depends_on = [
    ec_deployment.development,
    ec_deployment.local
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Creating ECS-compliant test data in Development and Local Elasticsearch..."
      
      # Wait for API keys to be available
      sleep 5
      
      # Get Development credentials
      DEV_ES_ENDPOINT="${ec_deployment.development.elasticsearch.https_endpoint}"
      DEV_ES_USERNAME="${ec_deployment.development.elasticsearch_username}"
      DEV_ES_PASSWORD="${ec_deployment.development.elasticsearch_password}"
      
      # Get Local credentials
      LOCAL_ES_ENDPOINT="${ec_deployment.local.elasticsearch.https_endpoint}"
      LOCAL_ES_USERNAME="${ec_deployment.local.elasticsearch_username}"
      LOCAL_ES_PASSWORD="${ec_deployment.local.elasticsearch_password}"
      
      # Function to create index and load data into a cluster
      load_test_data() {
        local ES_ENDPOINT=$1
        local ES_USERNAME=$2
        local ES_PASSWORD=$3
        local CLUSTER_NAME=$4
        
        echo ""
        echo "Loading data into $${CLUSTER_NAME} cluster..."
        echo "Endpoint: $${ES_ENDPOINT}"
        
        # Create component template and data stream for network traffic
        echo "Creating component template for logs-network_traffic in $${CLUSTER_NAME}..."
        
        # First create the component template with mappings
        curl -k -X PUT "$${ES_ENDPOINT}/_component_template/logs-network_traffic-mappings" \
          -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
          -H "Content-Type: application/json" \
          -d '{
          "template": {
            "mappings": {
            "properties": {
              "@timestamp": { "type": "date" },
              "ecs": {
                "properties": {
                  "version": { "type": "keyword" }
                }
              },
              "event": {
                "properties": {
                  "category": { "type": "keyword" },
                  "type": { "type": "keyword" },
                  "kind": { "type": "keyword" },
                  "module": { "type": "keyword" },
                  "dataset": { "type": "keyword" },
                  "outcome": { "type": "keyword" },
                  "created": { "type": "date" },
                  "ingested": { "type": "date" }
                }
              },
              "network": {
                "properties": {
                  "direction": { "type": "keyword" },
                  "type": { "type": "keyword" },
                  "transport": { "type": "keyword" },
                  "protocol": { "type": "keyword" },
                  "bytes": { "type": "long" },
                  "packets": { "type": "long" },
                  "community_id": { "type": "keyword" }
                }
              },
              "source": {
                "properties": {
                  "ip": { "type": "ip" },
                  "port": { "type": "long" },
                  "mac": { "type": "keyword" },
                  "address": { "type": "keyword" },
                  "bytes": { "type": "long" },
                  "packets": { "type": "long" }
                }
              },
              "destination": {
                "properties": {
                  "ip": { "type": "ip" },
                  "port": { "type": "long" },
                  "mac": { "type": "keyword" },
                  "address": { "type": "keyword" },
                  "bytes": { "type": "long" },
                  "packets": { "type": "long" }
                }
              },
              "client": {
                "properties": {
                  "ip": { "type": "ip" },
                  "port": { "type": "long" },
                  "bytes": { "type": "long" },
                  "packets": { "type": "long" }
                }
              },
              "server": {
                "properties": {
                  "ip": { "type": "ip" },
                  "port": { "type": "long" },
                  "bytes": { "type": "long" },
                  "packets": { "type": "long" }
                }
              },
              "host": {
                "properties": {
                  "name": { "type": "keyword" },
                  "hostname": { "type": "keyword" },
                  "id": { "type": "keyword" },
                  "ip": { "type": "ip" },
                  "mac": { "type": "keyword" },
                  "architecture": { "type": "keyword" },
                  "os": {
                    "properties": {
                      "family": { "type": "keyword" },
                      "kernel": { "type": "keyword" },
                      "name": { "type": "keyword" },
                      "platform": { "type": "keyword" },
                      "version": { "type": "keyword" }
                    }
                  }
                }
              },
              "agent": {
                "properties": {
                  "type": { "type": "keyword" },
                  "version": { "type": "keyword" },
                  "hostname": { "type": "keyword" },
                  "ephemeral_id": { "type": "keyword" },
                  "id": { "type": "keyword" },
                  "name": { "type": "keyword" }
                }
              },
              "user": {
                "properties": {
                  "name": { "type": "keyword" },
                  "id": { "type": "keyword" },
                  "domain": { "type": "keyword" }
                }
              },
              "user_agent": {
                "properties": {
                  "original": { "type": "keyword" },
                  "name": { "type": "keyword" },
                  "version": { "type": "keyword" }
                }
              },
              "process": {
                "properties": {
                  "name": { "type": "keyword" },
                  "executable": { "type": "keyword" },
                  "pid": { "type": "long" }
                }
              },
              "related": {
                "properties": {
                  "ip": { "type": "ip" },
                  "user": { "type": "keyword" }
                }
              },
              "data_stream": {
                "properties": {
                  "dataset": { "type": "keyword" },
                  "namespace": { "type": "keyword" },
                  "type": { "type": "keyword" }
                }
              }
            }
          }
        }
      }
    }'
        
        # Create index template that uses the component template
        echo "Creating index template for logs-network_traffic in $${CLUSTER_NAME}..."
        curl -k -X PUT "$${ES_ENDPOINT}/_index_template/logs-network_traffic" \
          -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
          -H "Content-Type: application/json" \
          -d '{
          "index_patterns": ["logs-network_traffic"],
          "data_stream": {},
          "composed_of": ["logs-network_traffic-mappings"],
          "priority": 500
        }'
        
        # Create the data stream
        echo "Creating data stream logs-network_traffic in $${CLUSTER_NAME}..."
        curl -k -X PUT "$${ES_ENDPOINT}/_data_stream/logs-network_traffic" \
          -u "$${ES_USERNAME}:$${ES_PASSWORD}"
        
        # Generate timestamps for the last hour with milliseconds
        # Using hardcoded milliseconds for cross-platform compatibility
        BASE_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
        BASE_1M=$(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-1M +%Y-%m-%dT%H:%M:%S)
        BASE_2M=$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-2M +%Y-%m-%dT%H:%M:%S)
        BASE_3M=$(date -u -d '3 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-3M +%Y-%m-%dT%H:%M:%S)
        BASE_5M=$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-5M +%Y-%m-%dT%H:%M:%S)
        BASE_10M=$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-10M +%Y-%m-%dT%H:%M:%S)
        BASE_15M=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-15M +%Y-%m-%dT%H:%M:%S)
        BASE_30M=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-30M +%Y-%m-%dT%H:%M:%S)
        
        CURRENT_TIME="$${BASE_TIME}.013Z"
        TIME_1M_AGO="$${BASE_1M}.123Z"
        TIME_2M_AGO="$${BASE_2M}.456Z"
        TIME_3M_AGO="$${BASE_3M}.789Z"
        TIME_5M_AGO="$${BASE_5M}.234Z"
        TIME_10M_AGO="$${BASE_10M}.567Z"
        TIME_15M_AGO="$${BASE_15M}.890Z"
        TIME_30M_AGO="$${BASE_30M}.012Z"
        
        # Bulk upload MALICIOUS C2 traffic (will trigger detection)
        # These represent beaconing behavior to known C2 infrastructure
        echo "Uploading malicious C2 beacon traffic (ECS format) to $${CLUSTER_NAME}..."
        curl -k -X POST "$${ES_ENDPOINT}/_bulk" \
          -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
        -H "Content-Type: application/x-ndjson" \
        -d '{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_30M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_30M_AGO}'","ingested":"'$${TIME_30M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":512,"packets":3,"community_id":"1:LQU9qZlK+B5F3KDmev6m5PMibrg="},"source":{"ip":"10.0.1.50","port":58234,"bytes":256,"packets":2,"address":"10.0.1.50"},"destination":{"ip":"185.220.101.45","port":443,"bytes":256,"packets":1,"address":"185.220.101.45"},"client":{"ip":"10.0.1.50","port":58234,"bytes":256,"packets":2},"server":{"ip":"185.220.101.45","port":443,"bytes":256,"packets":1},"host":{"name":"workstation-001","hostname":"workstation-001","id":"7c21f5ed-9e32-4b9a-8e17-4e8c5e6c5a1b","ip":["10.0.1.50"],"mac":["00:11:22:33:44:55"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"workstation-001","ephemeral_id":"7bca8f60-8e9e-4c9d-9e43-40a1d9fb19c2","id":"f25d13cd-18e5-4e73-822c-c4f0b533c8b0","name":"workstation-001"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","name":"Chrome","version":"120.0.0.0"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","name":"Chrome","version":"120.0.0.0"},"process":{"name":"chrome.exe","executable":"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe","pid":4532},"related":{"ip":["10.0.1.50","185.220.101.45"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_15M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_15M_AGO}'","ingested":"'$${TIME_15M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":623,"packets":4,"community_id":"1:X3bcg2545F3KDmev6m5PMibrg="},"source":{"ip":"10.0.2.15","port":49823,"bytes":312,"packets":2,"address":"10.0.2.15"},"destination":{"ip":"185.220.101.67","port":8443,"bytes":311,"packets":2,"address":"185.220.101.67"},"client":{"ip":"10.0.2.15","port":49823,"bytes":312,"packets":2},"server":{"ip":"185.220.101.67","port":8443,"bytes":311,"packets":2},"host":{"name":"workstation-002","hostname":"workstation-002","id":"8d32f6fe-0f43-5c0b-9f28-5f9d6f7d6b2c","ip":["10.0.2.15"],"mac":["00:11:22:33:44:66"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"workstation-002","ephemeral_id":"8cdb9g71-9faf-5dae-af54-51b2e0gb20d3","id":"g36e24de-29f6-5f84-933d-d5g1c644d9c1","name":"workstation-002"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0","name":"Edge","version":"120.0.0.0"},"process":{"name":"edge.exe","executable":"C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe","pid":5643},"related":{"ip":["10.0.2.15","185.220.101.67"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_10M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_10M_AGO}'","ingested":"'$${TIME_10M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":445,"packets":3,"community_id":"1:Y4cdh3656G4LEpfw7n6QNjcsh="},"source":{"ip":"10.0.2.15","port":51234,"bytes":223,"packets":2,"address":"10.0.2.15"},"destination":{"ip":"194.147.78.23","port":443,"bytes":222,"packets":1,"address":"194.147.78.23"},"client":{"ip":"10.0.2.15","port":51234,"bytes":223,"packets":2},"server":{"ip":"194.147.78.23","port":443,"bytes":222,"packets":1},"host":{"name":"workstation-002","hostname":"workstation-002","id":"8d32f6fe-0f43-5c0b-9f28-5f9d6f7d6b2c","ip":["10.0.2.15"],"mac":["00:11:22:33:44:66"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"workstation-002","ephemeral_id":"8cdb9g71-9faf-5dae-af54-51b2e0gb20d3","id":"g36e24de-29f6-5f84-933d-d5g1c644d9c1","name":"workstation-002"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0","name":"Edge","version":"120.0.0.0"},"process":{"name":"edge.exe","executable":"C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe","pid":5643},"related":{"ip":["10.0.2.15","194.147.78.23"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_5M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_5M_AGO}'","ingested":"'$${TIME_5M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":892,"packets":5,"community_id":"1:Z5dej4767H5MFqgx8o7ROkdti="},"source":{"ip":"10.0.3.75","port":60123,"bytes":446,"packets":3,"address":"10.0.3.75"},"destination":{"ip":"185.220.101.100","port":443,"bytes":446,"packets":2,"address":"185.220.101.100"},"client":{"ip":"10.0.3.75","port":60123,"bytes":446,"packets":3},"server":{"ip":"185.220.101.100","port":443,"bytes":446,"packets":2},"host":{"name":"server-web-01","hostname":"server-web-01","id":"9e43g7gf-1g54-6d1c-ag39-6gae7g8e7c3d","ip":["10.0.3.75"],"mac":["00:11:22:33:44:77"],"os":{"family":"windows","kernel":"10.0.17763.1234","name":"Windows Server","platform":"windows","version":"2019"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"server-web-01","ephemeral_id":"9dec0h82-0gbg-6ebf-bg65-62c3f1hc31e4","id":"h47f35ef-30g7-6g95-a44e-e6h2d755e0d2","name":"server-web-01"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","name":"Chrome","version":"120.0.0.0"},"process":{"name":"svchost.exe","executable":"C:\\Windows\\System32\\svchost.exe","pid":1234},"related":{"ip":["10.0.3.75","185.220.101.100"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_3M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_3M_AGO}'","ingested":"'$${TIME_3M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":756,"packets":4,"community_id":"1:A6efk5878I6NGrhy9p8SPle="},"source":{"ip":"10.0.3.75","port":61234,"bytes":378,"packets":2,"address":"10.0.3.75"},"destination":{"ip":"194.147.78.155","port":8443,"bytes":378,"packets":2,"address":"194.147.78.155"},"client":{"ip":"10.0.3.75","port":61234,"bytes":378,"packets":2},"server":{"ip":"194.147.78.155","port":8443,"bytes":378,"packets":2},"host":{"name":"server-web-01","hostname":"server-web-01","id":"9e43g7gf-1g54-6d1c-ag39-6gae7g8e7c3d","ip":["10.0.3.75"],"mac":["00:11:22:33:44:77"],"os":{"family":"windows","kernel":"10.0.17763.1234","name":"Windows Server","platform":"windows","version":"2019"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"server-web-01","ephemeral_id":"9dec0h82-0gbg-6ebf-bg65-62c3f1hc31e4","id":"h47f35ef-30g7-6g95-a44e-e6h2d755e0d2","name":"server-web-01"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","name":"Chrome","version":"120.0.0.0"},"process":{"name":"svchost.exe","executable":"C:\\Windows\\System32\\svchost.exe","pid":1234},"related":{"ip":["10.0.3.75","194.147.78.155"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_2M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_2M_AGO}'","ingested":"'$${TIME_2M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":234,"packets":2,"community_id":"1:B7fgl6989J7OHsiz0q9TQmf="},"source":{"ip":"10.0.4.100","port":62345,"bytes":117,"packets":1,"address":"10.0.4.100"},"destination":{"ip":"185.220.101.200","port":443,"bytes":117,"packets":1,"address":"185.220.101.200"},"client":{"ip":"10.0.4.100","port":62345,"bytes":117,"packets":1},"server":{"ip":"185.220.101.200","port":443,"bytes":117,"packets":1},"host":{"name":"laptop-exec-05","hostname":"laptop-exec-05","id":"0f54h8hg-2h65-7e2d-bh40-7hbf8h9f8d4e","ip":["10.0.4.100"],"mac":["00:11:22:33:44:88"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"laptop-exec-05","ephemeral_id":"0efd1i93-1hch-7fcg-ch76-73d4g2id42f5","id":"i58g46fg-41h8-7h06-b55f-f7i3e866f1e3","name":"laptop-exec-05"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0","name":"Firefox","version":"121.0"},"process":{"name":"firefox.exe","executable":"C:\\Program Files\\Mozilla Firefox\\firefox.exe","pid":6754},"related":{"ip":["10.0.4.100","185.220.101.200"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_1M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_1M_AGO}'","ingested":"'$${TIME_1M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":567,"packets":3,"community_id":"1:C8ghm7090K8PItkj1r0URng="},"source":{"ip":"10.0.4.101","port":63456,"bytes":284,"packets":2,"address":"10.0.4.101"},"destination":{"ip":"185.220.101.201","port":443,"bytes":283,"packets":1,"address":"185.220.101.201"},"client":{"ip":"10.0.4.101","port":63456,"bytes":284,"packets":2},"server":{"ip":"185.220.101.201","port":443,"bytes":283,"packets":1},"host":{"name":"laptop-exec-06","hostname":"laptop-exec-06","id":"1g65i9ih-3i76-8f3e-ci51-8icg9i0g9e5f","ip":["10.0.4.101"],"mac":["00:11:22:33:44:99"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"laptop-exec-06","ephemeral_id":"1fge2ja4-2idi-8gdh-di87-84e5h3je53g6","id":"j69h57gh-52i9-8i17-c66g-g8j4f977g2f4","name":"laptop-exec-06"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","name":"Chrome","version":"120.0.0.0"},"process":{"name":"chrome.exe","executable":"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe","pid":7865},"related":{"ip":["10.0.4.101","185.220.101.201"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${CURRENT_TIME}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${CURRENT_TIME}'","ingested":"'$${CURRENT_TIME}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":912,"packets":5,"community_id":"1:D9hno8101L9QJulk2s1VSoh="},"source":{"ip":"10.0.5.50","port":64567,"bytes":456,"packets":3,"address":"10.0.5.50"},"destination":{"ip":"194.147.78.250","port":443,"bytes":456,"packets":2,"address":"194.147.78.250"},"client":{"ip":"10.0.5.50","port":64567,"bytes":456,"packets":3},"server":{"ip":"194.147.78.250","port":443,"bytes":456,"packets":2},"host":{"name":"desktop-fin-01","hostname":"desktop-fin-01","id":"2h76jaji-4j87-9g4f-dj62-9jdh0j1h0f6g","ip":["10.0.5.50"],"mac":["00:11:22:33:44:AA"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"desktop-fin-01","ephemeral_id":"2ghf3kb5-3jej-9hei-ej98-95f6i4kf64h7","id":"k70i68hi-63ja-9j28-d77h-h9k5ga88h3g5","name":"desktop-fin-01"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0","name":"Edge","version":"120.0.0.0"},"process":{"name":"edge.exe","executable":"C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe","pid":8976},"related":{"ip":["10.0.5.50","194.147.78.250"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${CURRENT_TIME}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${CURRENT_TIME}'","ingested":"'$${CURRENT_TIME}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":345,"packets":2,"community_id":"1:E0iop9212M0RKvml3t2WTpi="},"source":{"ip":"10.0.5.51","port":65678,"bytes":173,"packets":1,"address":"10.0.5.51"},"destination":{"ip":"185.220.101.5","port":8443,"bytes":172,"packets":1,"address":"185.220.101.5"},"client":{"ip":"10.0.5.51","port":65678,"bytes":173,"packets":1},"server":{"ip":"185.220.101.5","port":8443,"bytes":172,"packets":1},"host":{"name":"desktop-fin-02","hostname":"desktop-fin-02","id":"3i87kbkj-5k98-0h5g-ek73-0kei1k2i1g7h","ip":["10.0.5.51"],"mac":["00:11:22:33:44:BB"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"desktop-fin-02","ephemeral_id":"3hig4lc6-4kfk-0ifj-fka9-06g7j5lg75i8","id":"l81j79ij-74kb-0k39-e88i-i0l6hb99i4h6","name":"desktop-fin-02"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","name":"Chrome","version":"120.0.0.0"},"process":{"name":"chrome.exe","executable":"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe","pid":9087},"related":{"ip":["10.0.5.51","185.220.101.5"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
'
        
        # Bulk upload LEGITIMATE traffic (will NOT trigger detection)
        echo "Uploading legitimate traffic (ECS format) to $${CLUSTER_NAME}..."
        curl -k -X POST "$${ES_ENDPOINT}/_bulk" \
          -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
        -H "Content-Type: application/x-ndjson" \
        -d '{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_30M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_30M_AGO}'","ingested":"'$${TIME_30M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":5234,"packets":15,"community_id":"1:F1jqp0323N1SLwnm4u3XUrj="},"source":{"ip":"10.0.1.50","port":50234,"bytes":2617,"packets":8,"address":"10.0.1.50"},"destination":{"ip":"142.250.185.46","port":443,"bytes":2617,"packets":7,"address":"142.250.185.46"},"client":{"ip":"10.0.1.50","port":50234,"bytes":2617,"packets":8},"server":{"ip":"142.250.185.46","port":443,"bytes":2617,"packets":7},"host":{"name":"workstation-001","hostname":"workstation-001","id":"7c21f5ed-9e32-4b9a-8e17-4e8c5e6c5a1b","ip":["10.0.1.50"],"mac":["00:11:22:33:44:55"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"workstation-001","ephemeral_id":"7bca8f60-8e9e-4c9d-9e43-40a1d9fb19c2","id":"f25d13cd-18e5-4e73-822c-c4f0b533c8b0","name":"workstation-001"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","name":"Chrome","version":"120.0.0.0"},"process":{"name":"chrome.exe","executable":"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe","pid":4532},"related":{"ip":["10.0.1.50","142.250.185.46"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_15M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_15M_AGO}'","ingested":"'$${TIME_15M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":8912,"packets":22,"community_id":"1:G2krq1434O2TMxon5v4YVsk="},"source":{"ip":"10.0.1.51","port":51345,"bytes":4456,"packets":11,"address":"10.0.1.51"},"destination":{"ip":"52.88.151.22","port":443,"bytes":4456,"packets":11,"address":"52.88.151.22"},"client":{"ip":"10.0.1.51","port":51345,"bytes":4456,"packets":11},"server":{"ip":"52.88.151.22","port":443,"bytes":4456,"packets":11},"host":{"name":"workstation-003","hostname":"workstation-003","id":"4j98lclk-6l09-1i6h-fl84-1lfj2l3j2h8i","ip":["10.0.1.51"],"mac":["00:11:22:33:44:CC"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"workstation-003","ephemeral_id":"4ijh5md7-5lgl-1jhk-glb0-17h8k6mh86j9","id":"m92k80kl-85lc-1l40-f99j-j1m7ic00j5i7","name":"workstation-003"},"process":{"name":"teams.exe","executable":"C:\\Users\\user\\AppData\\Local\\Microsoft\\Teams\\current\\Teams.exe","pid":10198},"related":{"ip":["10.0.1.51","52.88.151.22"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_10M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_10M_AGO}'","ingested":"'$${TIME_10M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":15678,"packets":35,"community_id":"1:H3lsr2545P3UNypo6w5ZWtl="},"source":{"ip":"10.0.2.20","port":52456,"bytes":7839,"packets":18,"address":"10.0.2.20"},"destination":{"ip":"13.107.42.14","port":443,"bytes":7839,"packets":17,"address":"13.107.42.14"},"client":{"ip":"10.0.2.20","port":52456,"bytes":7839,"packets":18},"server":{"ip":"13.107.42.14","port":443,"bytes":7839,"packets":17},"host":{"name":"laptop-dev-01","hostname":"laptop-dev-01","id":"5ka0mdml-7m10-2j7i-gm95-2mgk3m4k3i9j","ip":["10.0.2.20"],"mac":["00:11:22:33:44:DD"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"laptop-dev-01","ephemeral_id":"5jki6ne8-6mhm-2kil-hmc1-28i9l7ni97ka","id":"n03l91lm-96md-2m51-gaak-k2n8jd11k6j8","name":"laptop-dev-01"},"process":{"name":"outlook.exe","executable":"C:\\Program Files\\Microsoft Office\\root\\Office16\\OUTLOOK.EXE","pid":11209},"related":{"ip":["10.0.2.20","13.107.42.14"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_5M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_5M_AGO}'","ingested":"'$${TIME_5M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":892,"packets":5,"community_id":"1:I4mts3656Q4VOzqp7x6aXum="},"source":{"ip":"10.0.3.75","port":53567,"bytes":446,"packets":3,"address":"10.0.3.75"},"destination":{"ip":"185.220.101.100","port":443,"bytes":446,"packets":2,"address":"185.220.101.100"},"client":{"ip":"10.0.3.75","port":53567,"bytes":446,"packets":3},"server":{"ip":"185.220.101.100","port":443,"bytes":446,"packets":2},"host":{"name":"server-web-01","hostname":"server-web-01","id":"9e43g7gf-1g54-6d1c-ag39-6gae7g8e7c3d","ip":["10.0.3.75"],"mac":["00:11:22:33:44:77"],"os":{"family":"windows","kernel":"10.0.17763.1234","name":"Windows Server","platform":"windows","version":"2019"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"server-web-01","ephemeral_id":"9dec0h82-0gbg-6ebf-bg65-62c3f1hc31e4","id":"h47f35ef-30g7-6g95-a44e-e6h2d755e0d2","name":"server-web-01"},"user":{"name":"backup_service","id":"S-1-5-21-123456789-1234567890-1234567890-1001","domain":"CORP"},"process":{"name":"backup.exe","executable":"C:\\Program Files\\BackupSoft\\backup.exe","pid":2345},"related":{"ip":["10.0.3.75","185.220.101.100"],"user":["backup_service"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_3M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_3M_AGO}'","ingested":"'$${TIME_3M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":3456,"packets":12,"community_id":"1:J5nut4767R5WParq8y7bYvn="},"source":{"ip":"10.0.3.80","port":54678,"bytes":1728,"packets":6,"address":"10.0.3.80"},"destination":{"ip":"151.101.1.140","port":443,"bytes":1728,"packets":6,"address":"151.101.1.140"},"client":{"ip":"10.0.3.80","port":54678,"bytes":1728,"packets":6},"server":{"ip":"151.101.1.140","port":443,"bytes":1728,"packets":6},"host":{"name":"server-app-01","hostname":"server-app-01","id":"6lb1nenm-8n21-3k8j-hn06-3nhl4n5l4jal","ip":["10.0.3.80"],"mac":["00:11:22:33:44:EE"],"os":{"family":"linux","kernel":"5.10.0-19-amd64","name":"Debian GNU/Linux","platform":"debian","version":"11"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"server-app-01","ephemeral_id":"6mlj7of9-7nin-3ljm-ind2-39j0m8oj08lb","id":"o14m02mn-07ne-3n62-hbbl-l3o9ke22l7k9","name":"server-app-01"},"process":{"name":"node","executable":"/usr/bin/node","pid":12320},"related":{"ip":["10.0.3.80","151.101.1.140"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_2M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_2M_AGO}'","ingested":"'$${TIME_2M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":6789,"packets":18,"community_id":"1:K6ovu5878S6XQbsr9z8cZwo="},"source":{"ip":"10.0.4.100","port":55789,"bytes":3395,"packets":9,"address":"10.0.4.100"},"destination":{"ip":"172.217.16.142","port":443,"bytes":3394,"packets":9,"address":"172.217.16.142"},"client":{"ip":"10.0.4.100","port":55789,"bytes":3395,"packets":9},"server":{"ip":"172.217.16.142","port":443,"bytes":3394,"packets":9},"host":{"name":"laptop-exec-05","hostname":"laptop-exec-05","id":"0f54h8hg-2h65-7e2d-bh40-7hbf8h9f8d4e","ip":["10.0.4.100"],"mac":["00:11:22:33:44:88"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"laptop-exec-05","ephemeral_id":"0efd1i93-1hch-7fcg-ch76-73d4g2id42f5","id":"i58g46fg-41h8-7h06-b55f-f7i3e866f1e3","name":"laptop-exec-05"},"user_agent":{"original":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","name":"Chrome","version":"120.0.0.0"},"process":{"name":"chrome.exe","executable":"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe","pid":13431},"related":{"ip":["10.0.4.100","172.217.16.142"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${TIME_1M_AGO}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${TIME_1M_AGO}'","ingested":"'$${TIME_1M_AGO}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":734,"packets":4,"community_id":"1:L7pwv6989T7YRcts0a9daxp="},"source":{"ip":"10.0.4.100","port":56890,"bytes":367,"packets":2,"address":"10.0.4.100"},"destination":{"ip":"185.220.101.200","port":443,"bytes":367,"packets":2,"address":"185.220.101.200"},"client":{"ip":"10.0.4.100","port":56890,"bytes":367,"packets":2},"server":{"ip":"185.220.101.200","port":443,"bytes":367,"packets":2},"host":{"name":"laptop-exec-05","hostname":"laptop-exec-05","id":"0f54h8hg-2h65-7e2d-bh40-7hbf8h9f8d4e","ip":["10.0.4.100"],"mac":["00:11:22:33:44:88"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"laptop-exec-05","ephemeral_id":"0efd1i93-1hch-7fcg-ch76-73d4g2id42f5","id":"i58g46fg-41h8-7h06-b55f-f7i3e866f1e3","name":"laptop-exec-05"},"user":{"name":"security_scanner","id":"S-1-5-21-123456789-1234567890-1234567890-1002","domain":"CORP"},"process":{"name":"nessus.exe","executable":"C:\\Program Files\\Tenable\\Nessus\\nessus.exe","pid":14542},"related":{"ip":["10.0.4.100","185.220.101.200"],"user":["security_scanner"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${CURRENT_TIME}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${CURRENT_TIME}'","ingested":"'$${CURRENT_TIME}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":4567,"packets":14,"community_id":"1:M8qxw7090U8ZSdut1b0ebyq="},"source":{"ip":"10.0.5.50","port":57901,"bytes":2284,"packets":7,"address":"10.0.5.50"},"destination":{"ip":"20.190.159.70","port":443,"bytes":2283,"packets":7,"address":"20.190.159.70"},"client":{"ip":"10.0.5.50","port":57901,"bytes":2284,"packets":7},"server":{"ip":"20.190.159.70","port":443,"bytes":2283,"packets":7},"host":{"name":"desktop-fin-01","hostname":"desktop-fin-01","id":"2h76jaji-4j87-9g4f-dj62-9jdh0j1h0f6g","ip":["10.0.5.50"],"mac":["00:11:22:33:44:AA"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"desktop-fin-01","ephemeral_id":"2ghf3kb5-3jej-9hei-ej98-95f6i4kf64h7","id":"k70i68hi-63ja-9j28-d77h-h9k5ga88h3g5","name":"desktop-fin-01"},"process":{"name":"excel.exe","executable":"C:\\Program Files\\Microsoft Office\\root\\Office16\\EXCEL.EXE","pid":15653},"related":{"ip":["10.0.5.50","20.190.159.70"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
{"create":{"_index":"logs-network_traffic"}}
{"@timestamp":"'$${CURRENT_TIME}'","ecs":{"version":"8.11.0"},"event":{"category":"network","type":"connection","kind":"event","module":"network_traffic","dataset":"network.flow","outcome":"success","created":"'$${CURRENT_TIME}'","ingested":"'$${CURRENT_TIME}'"},"network":{"direction":"outbound","type":"ipv4","transport":"tcp","protocol":"https","bytes":8901,"packets":24,"community_id":"1:N9ryx8101V9ATfvu2c1fcyr="},"source":{"ip":"10.0.5.60","port":59012,"bytes":4451,"packets":12,"address":"10.0.5.60"},"destination":{"ip":"104.18.14.101","port":443,"bytes":4450,"packets":12,"address":"104.18.14.101"},"client":{"ip":"10.0.5.60","port":59012,"bytes":4451,"packets":12},"server":{"ip":"104.18.14.101","port":443,"bytes":4450,"packets":12},"host":{"name":"desktop-hr-01","hostname":"desktop-hr-01","id":"7mc2ofpn-9o32-4l9k-io87-4ogi5o7o5k0m","ip":["10.0.5.60"],"mac":["00:11:22:33:44:FF"],"os":{"family":"windows","kernel":"10.0.19041.1415","name":"Windows","platform":"windows","version":"10"}},"agent":{"type":"packetbeat","version":"8.11.0","hostname":"desktop-hr-01","ephemeral_id":"7ndk8pg0-8oio-4mjl-jpe3-40h9k7ph97n1","id":"p25n13on-18oe-4o73-iccm-n4p0lf44n8l0","name":"desktop-hr-01"},"process":{"name":"slack.exe","executable":"C:\\Users\\user\\AppData\\Local\\slack\\app-4.29.149\\slack.exe","pid":16764},"related":{"ip":["10.0.5.60","104.18.14.101"]},"data_stream":{"dataset":"network_traffic","namespace":"default","type":"logs"}}
'
        
        # Wait for indexing
        sleep 2
        
        # Refresh the index
        curl -k -X POST "$${ES_ENDPOINT}/logs-network_traffic/_refresh" \
          -u "$${ES_USERNAME}:$${ES_PASSWORD}"
        
        echo ""
        echo "ECS-compliant test data created successfully in $${CLUSTER_NAME}!"
        echo "- Malicious C2 beacons: 10 documents (to IPs in 185.220.101.0/24 and 194.147.78.0/24 with <1KB payload)"
        echo "- Legitimate traffic: 10 documents (normal web traffic with larger payloads or excluded users)"
        echo ""
        echo "Data format matches Elastic Network Packet Capture integration with:"
        echo "- Full ECS field mappings"
        echo "- Proper event categorization"
        echo "- Network community IDs"
        echo "- Process and host enrichment"
        echo "- Agent metadata"
        
        # Verify the data
        echo ""
        echo "Verifying test data in $${CLUSTER_NAME}..."
        TOTAL_DOCS=$(curl -sk -X GET "$${ES_ENDPOINT}/logs-network_traffic/_count" \
          -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
          -H "Content-Type: application/json" | jq -r '.count')
        
        echo "Total documents in logs-network_traffic index: $${TOTAL_DOCS}"
        
        # Count malicious traffic that should trigger the rule
        MALICIOUS_COUNT=$(curl -sk -X GET "$${ES_ENDPOINT}/logs-network_traffic/_count" \
          -u "$${ES_USERNAME}:$${ES_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{
          "query": {
            "bool": {
              "must": [
                {"term": {"event.category": "network"}},
                {"term": {"network.direction": "outbound"}},
                {"range": {"network.bytes": {"lt": 1024}}},
                {"bool": {
                  "should": [
                    {"prefix": {"destination.ip": "185.220.101."}},
                    {"prefix": {"destination.ip": "194.147.78."}}
                  ]
                }}
              ],
              "must_not": [
                {"terms": {"user.name": ["security_scanner", "backup_service"]}}
              ]
            }
          }
        }' | jq -r '.count')
        
        echo "Documents that should trigger C2 detection: $${MALICIOUS_COUNT}"
        echo "--------------------------------------------"
      }
      
      # Load data into Development cluster
      load_test_data "$${DEV_ES_ENDPOINT}" "$${DEV_ES_USERNAME}" "$${DEV_ES_PASSWORD}" "Development"
      
      # Load data into Local cluster  
      load_test_data "$${LOCAL_ES_ENDPOINT}" "$${LOCAL_ES_USERNAME}" "$${LOCAL_ES_PASSWORD}" "Local"
      
      echo ""
      echo "======================================"
      echo "Test data loaded into both clusters successfully!"
      echo "======================================"
    EOT
  }

  triggers = {
    dev_deployment_id = ec_deployment.development.id
    local_deployment_id = ec_deployment.local.id
    timestamp         = timestamp()
  }
}

# Output information about test data
output "test_data_info" {
  value = {
    data_stream_name = "logs-network_traffic"
    data_stream_pattern = "logs-network_traffic"
    clusters_loaded = ["Development", "Local"]
    query_example = <<-QUERY
      # Query to find C2 beacons (what your rule should detect):
      event.category:network and 
      network.direction:outbound and 
      destination.ip:(
        185.220.101.0/24 OR
        194.147.78.0/24
      ) and 
      network.bytes < 1024 and
      NOT user.name:(security_scanner OR backup_service)
    QUERY
    test_data = {
      malicious_ips = [
        "185.220.101.45", "185.220.101.67", "185.220.101.100",
        "185.220.101.200", "185.220.101.201", "185.220.101.5",
        "194.147.78.23", "194.147.78.155", "194.147.78.250"
      ]
      legitimate_ips = [
        "142.250.185.46 (Google)",
        "52.88.151.22 (AWS)", 
        "13.107.42.14 (Microsoft)",
        "172.217.16.142 (Google)",
        "20.190.159.70 (Azure)",
        "151.101.1.140 (Fastly CDN)",
        "104.18.14.101 (Cloudflare)"
      ]
      expected_alerts = "10 (C2 beacons with <1KB, excludes backup_service and security_scanner)"
      expected_false_positives = "0 (legitimate traffic has larger payloads or excluded users)"
    }
  }
  description = "ECS-compliant test data loaded into both Development and Local clusters for C2 detection demo"
  
  depends_on = [null_resource.create_test_data]
}