#!/bin/bash
# 一键配置

# 检查系统是否有 IPv6 地址
check_ipv6_support() {
    if ip -6 addr | grep -q "inet6"; then
        echo "1"  # 支持 IPv6
    else
        echo "0"  # 不支持 IPv6
    fi
}

add_node_config() {
    echo -e "${green}请选择节点核心类型：${plain}"
    echo -e "${green}1. xray${plain}"
    echo -e "${green}2. singbox${plain}"
    echo -e "${green}3. hysteria2${plain}"
    read -rp "请输入：" core_type
    if [ "$core_type" == "1" ]; then
        core="xray"
        core_xray=true
    elif [ "$core_type" == "2" ]; then
        core="sing"
        core_sing=true
    elif [ "$core_type" == "3" ]; then
        core="hysteria2"
        core_hysteria2=true
    else
        echo "无效的选择。请选择 1 2 3。"
        continue
    fi
    while true; do
        read -rp "请输入节点Node ID：" NodeID
        # 判断NodeID是否为正整数
        if [[ "$NodeID" =~ ^[0-9]+$ ]]; then
            break  # 输入正确，退出循环
        else
            echo "错误：请输入正确的数字作为Node ID。"
        fi
    done

    if [ "$core_hysteria2" = true ] && [ "$core_xray" = false ] && [ "$core_sing" = false ]; then
        NodeType="hysteria2"
    else
        echo -e "${yellow}请选择节点传输协议：${plain}"
        echo -e "${green}1. Shadowsocks${plain}"
        echo -e "${green}2. Vless${plain}"
        echo -e "${green}3. Vmess${plain}"
        if [ "$core_sing" == true ]; then
            echo -e "${green}4. Hysteria${plain}"
            echo -e "${green}5. Hysteria2${plain}"
        fi
        if [ "$core_hysteria2" == true ] && [ "$core_sing" = false ]; then
            echo -e "${green}5. Hysteria2${plain}"
        fi
        echo -e "${green}6. Trojan${plain}"  
        if [ "$core_sing" == true ]; then
            echo -e "${green}7. Tuic${plain}"
            echo -e "${green}8. AnyTLS${plain}"
        fi
        read -rp "请输入：" NodeType
        case "$NodeType" in
            1 ) NodeType="shadowsocks" ;;
            2 ) NodeType="vless" ;;
            3 ) NodeType="vmess" ;;
            4 ) NodeType="hysteria" ;;
            5 ) NodeType="hysteria2" ;;
            6 ) NodeType="trojan" ;;
            7 ) NodeType="tuic" ;;
            8 ) NodeType="anytls" ;;
            * ) NodeType="shadowsocks" ;;
        esac
    fi
    fastopen=true
    enable_reality_antisteal=false
    reality_internal_port=4431

    if [ "$NodeType" == "vless" ]; then
        read -rp "请选择是否为reality节点？(y/n)" isreality

        # 新增：防偷跑选项
        if [[ "$isreality" == "y" || "$isreality" == "Y" ]]; then
            echo -e "${yellow}检测到REALITY节点！${plain}"
            echo -e "${green}是否启用防偷跑功能？${plain}"
            echo -e "${yellow}防偷跑功能说明：${plain}"
            echo -e "  - 防止非法扫描和流量偷跑"
            echo -e "  - 使用双入站+路由过滤机制"
            echo -e "  - 只允许匹配serverNames的合法请求"
            echo -e "  - 其他请求将被阻断"
            echo ""
            read -rp "是否启用REALITY防偷跑？(y/n): " enable_anti_steal

            if [[ "$enable_anti_steal" =~ ^[Yy]$ ]]; then
                enable_reality_antisteal=true
                echo -e "${green}已启用REALITY防偷跑功能${plain}"

                read -rp "请输入REALITY内网端口 (默认4431): " input_port
                if [[ -n "$input_port" && "$input_port" =~ ^[0-9]+$ ]]; then
                    reality_internal_port=$input_port
                fi

                echo -e "${green}防偷跑配置：${plain}"
                echo -e "  - 内网端口：$reality_internal_port"
                echo -e "  - 路由过滤：启用"
            else
                echo -e "${yellow}使用标准REALITY配置${plain}"
            fi
        fi
    elif [ "$NodeType" == "hysteria" ] || [ "$NodeType" == "hysteria2" ] || [ "$NodeType" == "tuic" ] || [ "$NodeType" == "anytls" ]; then
        fastopen=false
        istls="y"
    fi

    if [[ "$isreality" != "y" && "$isreality" != "Y" &&  "$istls" != "y" ]]; then
        read -rp "请选择是否进行TLS配置？(y/n)" istls
    fi

    certmode="none"
    certdomain="example.com"
    if [[ "$isreality" != "y" && "$isreality" != "Y" && ( "$istls" == "y" || "$istls" == "Y" ) ]]; then
        echo -e "${yellow}请选择证书申请模式：${plain}"
        echo -e "${green}1. http模式自动申请，节点域名已正确解析${plain}"
        echo -e "${green}2. dns模式自动申请，需填入正确域名服务商API参数${plain}"
        echo -e "${green}3. self模式，自签证书或提供已有证书文件${plain}"
        read -rp "请输入：" certmode
        case "$certmode" in
            1 ) certmode="http" ;;
            2 ) certmode="dns" ;;
            3 ) certmode="self" ;;
        esac
        read -rp "请输入节点证书域名(example.com)：" certdomain
        if [ "$certmode" != "http" ]; then
            echo -e "${red}请手动修改配置文件后重启V2bX！${plain}"
        fi
    fi
    ipv6_support=$(check_ipv6_support)
    listen_ip="0.0.0.0"
    if [ "$ipv6_support" -eq 1 ]; then
        listen_ip="::"
    fi

    # 为启用防偷跑的REALITY节点设置特殊配置
    if [ "$enable_reality_antisteal" = true ]; then
        listen_ip="::1"
        # 当启用防偷跑时，将节点类型改为shadowsocks以避免V2bX自动生成REALITY入站
        # 因为我们会在custom_inbound.json中生成完整的REALITY配置
        original_node_type="$NodeType"
        NodeType="shadowsocks"
        echo -e "${yellow}防偷跑模式：禁用V2bX自动REALITY入站生成${plain}"
    fi

    node_config=""
    if [ "$core_type" == "1" ]; then
    node_config=$(cat <<EOF
{
            "Core": "$core",
            "ApiHost": "$ApiHost",
            "ApiKey": "$ApiKey",
            "NodeID": $NodeID,
            "NodeType": "$NodeType",
            "Timeout": 30,
            "ListenIP": "$listen_ip",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 200,
            "EnableProxyProtocol": false,
            "EnableUot": true,
            "EnableTFO": true,
            "DNSType": "UseIPv4",
            "CertConfig": {
                "CertMode": "$certmode",
                "RejectUnknownSni": false,
                "CertDomain": "$certdomain",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        },
EOF
)
    elif [ "$core_type" == "2" ]; then
    node_config=$(cat <<EOF
{
            "Core": "$core",
            "ApiHost": "$ApiHost",
            "ApiKey": "$ApiKey",
            "NodeID": $NodeID,
            "NodeType": "$NodeType",
            "Timeout": 30,
            "ListenIP": "$listen_ip",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 200,
            "TCPFastOpen": $fastopen,
            "SniffEnabled": true,
            "CertConfig": {
                "CertMode": "$certmode",
                "RejectUnknownSni": false,
                "CertDomain": "$certdomain",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        },
EOF
)
    elif [ "$core_type" == "3" ]; then
    node_config=$(cat <<EOF
{
            "Core": "$core",
            "ApiHost": "$ApiHost",
            "ApiKey": "$ApiKey",
            "NodeID": $NodeID,
            "NodeType": "$NodeType",
            "Hysteria2ConfigPath": "/etc/V2bX/hy2config.yaml",
            "Timeout": 30,
            "ListenIP": "",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 200,
            "CertConfig": {
                "CertMode": "$certmode",
                "RejectUnknownSni": false,
                "CertDomain": "$certdomain",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        },
EOF
)
    fi
    nodes_config+=("$node_config")
}

generate_config_file() {
    echo -e "${yellow}V2bX 配置文件生成向导${plain}"
    echo -e "${red}请阅读以下注意事项：${plain}"
    echo -e "${red}1. 目前该功能正处测试阶段${plain}"
    echo -e "${red}2. 生成的配置文件会保存到 /etc/V2bX/config.json${plain}"
    echo -e "${red}3. 原来的配置文件会保存到 /etc/V2bX/config.json.bak${plain}"
    echo -e "${red}4. 目前仅部分支持TLS${plain}"
    echo -e "${red}5. 使用此功能生成的配置文件会自带精简版审计规则（仅包含恶意域名、私有IP和BT协议阻断），确定继续？(y/n)${plain}"
    read -rp "请输入：" continue_prompt
    if [[ "$continue_prompt" =~ ^[Nn][Oo]? ]]; then
        exit 0
    fi
    
    nodes_config=()
    first_node=true
    core_xray=false
    core_sing=false
    core_hysteria2=false
    fixed_api_info=false
    check_api=false
    
    while true; do
        if [ "$first_node" = true ]; then
            read -rp "请输入机场网址(https://example.com)：" ApiHost
            read -rp "请输入面板对接API Key：" ApiKey
            read -rp "是否设置固定的机场网址和API Key？(y/n)" fixed_api
            if [ "$fixed_api" = "y" ] || [ "$fixed_api" = "Y" ]; then
                fixed_api_info=true
                echo -e "${red}成功固定地址${plain}"
            fi
            first_node=false
            add_node_config
        else
            read -rp "是否继续添加节点配置？(回车继续，输入n或no退出)" continue_adding_node
            if [[ "$continue_adding_node" =~ ^[Nn][Oo]? ]]; then
                break
            elif [ "$fixed_api_info" = false ]; then
                read -rp "请输入机场网址(https://example.com)：" ApiHost
                read -rp "请输入面板对接API Key：" ApiKey
            fi
            add_node_config
        fi
    done

    # 初始化核心配置数组
    cores_config="["

    # 检查并添加xray核心配置
    if [ "$core_xray" = true ]; then
        cores_config+="
    {
        \"Type\": \"xray\",
        \"Log\": {
            \"Level\": \"error\",
            \"ErrorPath\": \"/etc/V2bX/error.log\"
        },
        \"OutboundConfigPath\": \"/etc/V2bX/custom_outbound.json\",
        \"RouteConfigPath\": \"/etc/V2bX/route.json\"
    },"
    fi

    # 检查并添加sing核心配置
    if [ "$core_sing" = true ]; then
        cores_config+="
    {
        \"Type\": \"sing\",
        \"Log\": {
            \"Level\": \"error\",
            \"Timestamp\": true
        },
        \"NTP\": {
            \"Enable\": false,
            \"Server\": \"time.apple.com\",
            \"ServerPort\": 0
        },
        \"OriginalPath\": \"/etc/V2bX/sing_origin.json\"
    },"
    fi

    # 检查并添加hysteria2核心配置
    if [ "$core_hysteria2" = true ]; then
        cores_config+="
    {
        \"Type\": \"hysteria2\",
        \"Log\": {
            \"Level\": \"error\"
        }
    },"
    fi

    # 移除最后一个逗号并关闭数组
    cores_config+="]"
    cores_config=$(echo "$cores_config" | sed 's/},]$/}]/')

    # 切换到配置文件目录
    cd /etc/V2bX
    
    # 备份旧的配置文件
    mv config.json config.json.bak
    nodes_config_str="${nodes_config[*]}"
    formatted_nodes_config="${nodes_config_str%,}"

    # 创建 config.json 文件
    cat <<EOF > /etc/V2bX/config.json
{
    "Log": {
        "Level": "error",
        "Output": ""
    },
    "Cores": $cores_config,
    "Nodes": [$formatted_nodes_config]
}
EOF
    
    # 创建 custom_outbound.json 文件
    cat <<EOF > /etc/V2bX/custom_outbound.json
[
    {
        "tag": "direct",
        "protocol": "freedom",
        "settings": {
            "domainStrategy": "UseIPv4v6"
        }
    },
    {
        "tag": "IPv4_out",
        "protocol": "freedom",
        "settings": {
            "domainStrategy": "UseIPv4v6"
        }
    },
    {
        "tag": "IPv6_out",
        "protocol": "freedom",
        "settings": {
            "domainStrategy": "UseIPv6"
        }
    },
    {
        "protocol": "blackhole",
        "tag": "block"
    }
]
EOF
    
    # 创建 route.json 文件 - 精简版（只保留核心安全规则）
    cat <<EOF > /etc/V2bX/route.json
{
    "domainStrategy": "IPIfNonMatch",
    "rules": [
        {
            "type": "field",
            "outboundTag": "block",
            "domain": [
                "geosite:category-ads-all"
            ]
        },
        {
            "type": "field",
            "outboundTag": "block",
            "ip": [
                "127.0.0.1/32",
                "10.0.0.0/8",
                "172.16.0.0/12",
                "192.168.0.0/16",
                "fc00::/7",
                "fe80::/10"
            ]
        },
        {
            "type": "field",
            "outboundTag": "block",
            "protocol": [
                "bittorrent"
            ]
        },
        {
            "type": "field",
            "outboundTag": "IPv4_out",
            "network": "udp,tcp"
        }
    ]
}
EOF
    ipv6_support=$(check_ipv6_support)
    dnsstrategy="ipv4_only"
    if [ "$ipv6_support" -eq 1 ]; then
        dnsstrategy="prefer_ipv4"
    fi
    # 创建 sing_origin.json 文件
    cat <<EOF > /etc/V2bX/sing_origin.json
{
  "dns": {
    "servers": [
      {
        "tag": "cf",
        "address": "1.1.1.1"
      }
    ],
    "strategy": "$dnsstrategy"
  },
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct",
      "domain_strategy": "prefer_ipv4"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "geosite": [
          "category-ads-all"
        ],
        "outbound": "block"
      },
      {
        "ip_is_private": true,
        "outbound": "block"
      },
      {
        "protocol": "bittorrent",
        "outbound": "block"
      },
      {
        "outbound": "direct",
        "network": [
          "udp","tcp"
        ]
      }
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true
    }
  }
}
EOF

    # 创建 hy2config.yaml 文件           
    cat <<EOF > /etc/V2bX/hy2config.yaml
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false
ignoreClientBandwidth: false
disableUDP: false
udpIdleTimeout: 60s
resolver:
  type: system
acl:
  inline:
    - direct(geosite:google)
    - reject(geosite:cn)
    - reject(geoip:cn)
masquerade:
  type: 404
EOF

    # 生成防偷跑配置（如果启用）
    generate_reality_antisteal_config

    echo -e "${green}V2bX 配置文件生成完成,正在重新启动服务${plain}"
    v2bx restart
}

# 生成防偷跑配置函数
generate_reality_antisteal_config() {
    # 检查是否有启用防偷跑的节点
    local has_antisteal=false
    local antisteal_nodes=()

    # 检查全局变量
    if [ "$enable_reality_antisteal" = true ]; then
        has_antisteal=true
        antisteal_nodes+=("$NodeID|$ApiHost|$ApiKey|$reality_internal_port")
    fi

    if [ "$has_antisteal" = false ]; then
        return 0
    fi

    echo -e "${yellow}正在生成防偷跑配置...${plain}"

    # 确保 xray 核心配置包含 InboundConfigPath
    if ! grep -q "InboundConfigPath" /etc/V2bX/config.json; then
        echo -e "${yellow}正在更新 xray 核心配置以支持防偷跑...${plain}"

        # 使用 Python3 或 sed 来更新配置
        if command -v python3 >/dev/null 2>&1; then
            python3 << 'EOF'
import json
import sys

try:
    with open('/etc/V2bX/config.json', 'r') as f:
        config = json.load(f)

    # 更新 xray 核心配置
    for core in config.get('Cores', []):
        if core.get('Type') == 'xray':
            core['InboundConfigPath'] = '/etc/V2bX/custom_inbound.json'
            break

    with open('/etc/V2bX/config.json', 'w') as f:
        json.dump(config, f, indent=4)

    print("xray 核心配置更新成功")

except Exception as e:
    print(f"更新配置失败: {e}", file=sys.stderr)
    sys.exit(1)
EOF
        else
            echo -e "${yellow}未安装 Python3，请手动在 /etc/V2bX/config.json 的 xray 核心配置中添加：${plain}"
            echo -e '  "InboundConfigPath": "/etc/V2bX/custom_inbound.json"'
        fi
    fi

    # 生成防偷跑的 custom_inbound.json
    local custom_inbound_content="["
    local first_inbound=true

    for node_info in "${antisteal_nodes[@]}"; do
        IFS='|' read -r node_id api_host api_key internal_port <<< "$node_info"

        echo -e "${yellow}正在获取节点 $node_id 的配置信息...${plain}"

        # 从API获取完整的REALITY节点配置
        echo -e "${yellow}正在获取完整的REALITY配置...${plain}"
        local node_response=$(curl -s "${api_host}/api/v1/server/UniProxy/config?token=${api_key}&node_id=${node_id}&node_type=vless" --connect-timeout 30 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$node_response" ]; then
            # 调试：显示API响应结构（仅显示字段名，不显示敏感值）
            echo -e "${yellow}API响应字段：${plain}"
            if command -v python3 >/dev/null 2>&1; then
                echo "$node_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    def show_keys(obj, prefix=''):
        if isinstance(obj, dict):
            for key in obj.keys():
                print(f'  {prefix}{key}')
                if isinstance(obj[key], dict):
                    show_keys(obj[key], prefix + '  ')
                elif isinstance(obj[key], list) and obj[key] and isinstance(obj[key][0], dict):
                    print(f'  {prefix}  [0]:')
                    show_keys(obj[key][0], prefix + '    ')
    show_keys(data)
except:
    print('  无法解析JSON结构')
" 2>/dev/null
            fi
            # 解析完整的REALITY配置信息
            local server_port=""
            local server_name=""
            local uuid=""
            local private_key=""
            local short_ids=""
            local dest=""
            local server_names=""

            if command -v python3 >/dev/null 2>&1; then
                # 使用Python解析JSON获取完整REALITY配置
                eval $(echo "$node_response" | python3 -c "
import sys, json, uuid as uuid_module
try:
    data = json.load(sys.stdin)

    # 基本配置
    server_port = data.get('server_port', 443)

    # REALITY配置 - 尝试多种可能的字段名和嵌套结构
    # 支持 Xboard/V2board 等不同面板的API格式
    reality_settings = (data.get('reality_settings', {}) or
                       data.get('realitySettings', {}) or
                       data.get('reality', {}) or {})

    tls_settings = (data.get('tls_settings', {}) or
                   data.get('tlsSettings', {}) or
                   data.get('tls', {}) or {})

    stream_settings = (data.get('stream_settings', {}) or
                      data.get('streamSettings', {}) or
                      data.get('stream', {}) or {})

    # 检查嵌套的 realitySettings
    if stream_settings and 'realitySettings' in stream_settings:
        reality_settings = stream_settings['realitySettings']
    elif stream_settings and 'reality_settings' in stream_settings:
        reality_settings = stream_settings['reality_settings']

    # 提取REALITY参数 - 支持更多字段名变体
    server_name = (reality_settings.get('server_name') or
                  reality_settings.get('serverName') or
                  reality_settings.get('sni') or
                  tls_settings.get('server_name') or
                  tls_settings.get('serverName') or
                  tls_settings.get('sni') or
                  data.get('sni') or
                  'speed.cloudflare.com')

    dest = (reality_settings.get('dest') or
           reality_settings.get('destination') or
           reality_settings.get('target') or
           f'{server_name}:443')

    # 私钥获取 - 支持多种字段名
    private_key = (reality_settings.get('private_key') or
                  reality_settings.get('privateKey') or
                  reality_settings.get('key') or
                  reality_settings.get('private') or
                  data.get('private_key') or
                  data.get('privateKey') or '')

    # 短ID获取 - 支持多种格式
    short_ids = (reality_settings.get('short_ids') or
                reality_settings.get('shortIds') or
                reality_settings.get('shortId') or
                reality_settings.get('short_id') or
                data.get('short_ids') or
                data.get('shortIds') or
                ['', '0123456789abcdef'])

    # 服务器名称列表
    server_names = (reality_settings.get('server_names') or
                   reality_settings.get('serverNames') or
                   reality_settings.get('sni_list') or
                   data.get('server_names') or
                   data.get('serverNames') or
                   [server_name])

    # 用户配置 - 支持 Xboard/V2board 等不同面板的UUID字段格式
    uuid = ''

    # 尝试不同的UUID字段位置和命名方式
    # 1. 检查 settings.clients 结构（Xboard常用）
    if 'settings' in data and isinstance(data['settings'], dict):
        settings = data['settings']
        if 'clients' in settings and isinstance(settings['clients'], list) and settings['clients']:
            client = settings['clients'][0]
            uuid = client.get('uuid', '') or client.get('id', '') or client.get('user_id', '')
        elif 'users' in settings and isinstance(settings['users'], list) and settings['users']:
            user = settings['users'][0]
            uuid = user.get('uuid', '') or user.get('id', '') or user.get('user_id', '')

    # 2. 检查顶级 users/clients 数组
    if not uuid and 'users' in data and isinstance(data['users'], list) and data['users']:
        user = data['users'][0]
        uuid = user.get('uuid', '') or user.get('id', '') or user.get('user_id', '')
    elif not uuid and 'clients' in data and isinstance(data['clients'], list) and data['clients']:
        client = data['clients'][0]
        uuid = client.get('uuid', '') or client.get('id', '') or client.get('user_id', '')

    # 3. 检查单个用户对象
    if not uuid and 'user' in data and isinstance(data['user'], dict):
        user = data['user']
        uuid = user.get('uuid', '') or user.get('id', '') or user.get('user_id', '')
    elif not uuid and 'client' in data and isinstance(data['client'], dict):
        client = data['client']
        uuid = client.get('uuid', '') or client.get('id', '') or client.get('user_id', '')

    # 4. 检查顶级字段
    if not uuid:
        uuid = (data.get('uuid', '') or
               data.get('id', '') or
               data.get('user_id', '') or
               data.get('client_id', ''))

    # 5. 如果仍然没有UUID，生成一个随机UUID
    if not uuid:
        uuid = str(uuid_module.uuid4())
        print(f'# 警告：未从API获取到UUID，已生成随机UUID: {uuid}', file=sys.stderr)
    else:
        print(f'# 成功从API获取UUID: {uuid}', file=sys.stderr)

    # 输出解析状态信息
    print(f'# REALITY配置解析状态：', file=sys.stderr)
    print(f'#   私钥状态: {\"已获取\" if private_key else \"未获取（将使用占位符）\"}', file=sys.stderr)
    print(f'#   UUID状态: {\"已获取\" if uuid else \"未获取\"}', file=sys.stderr)
    print(f'#   服务器名称: {server_name}', file=sys.stderr)
    print(f'#   目标地址: {dest}', file=sys.stderr)

    # 输出shell变量
    print(f'server_port={server_port}')
    print(f'server_name=\"{server_name}\"')
    print(f'uuid=\"{uuid}\"')
    print(f'private_key=\"{private_key}\"')
    print(f'dest=\"{dest}\"')

    # 处理数组
    if isinstance(short_ids, list):
        short_ids_str = ','.join([f'\"{sid}\"' for sid in short_ids])
    else:
        short_ids_str = f'\"{short_ids}\"'

    if isinstance(server_names, list):
        server_names_str = ','.join([f'\"{sn}\"' for sn in server_names])
    else:
        server_names_str = f'\"{server_names}\"'

    print(f'short_ids_array=({short_ids_str})')
    print(f'server_names_array=({server_names_str})')

except Exception as e:
    import uuid as uuid_module
    random_uuid = str(uuid_module.uuid4())
    print(f'# API解析失败: {e}，使用随机UUID', file=sys.stderr)
    print('server_port=443')
    print('server_name=\"speed.cloudflare.com\"')
    print(f'uuid=\"{random_uuid}\"')
    print('private_key=\"\"')
    print('dest=\"speed.cloudflare.com:443\"')
    print('short_ids_array=(\"\" \"0123456789abcdef\")')
    print('server_names_array=(\"speed.cloudflare.com\")')
" 2>/dev/null)
            else
                # 备用grep解析方法（基本配置）
                server_port=$(echo "$node_response" | grep -o '"server_port":[0-9]*' | cut -d':' -f2 | head -1)
                server_name=$(echo "$node_response" | grep -o '"server_name":"[^"]*"' | cut -d'"' -f4 | head -1)

                # 尝试多种UUID字段名
                uuid=$(echo "$node_response" | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4 | head -1)
                if [ -z "$uuid" ]; then
                    uuid=$(echo "$node_response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -1)
                fi

                # 设置默认值
                if [ -z "$server_port" ]; then server_port=443; fi
                if [ -z "$server_name" ]; then server_name="speed.cloudflare.com"; fi
                if [ -z "$uuid" ]; then
                    # 生成随机UUID而不是使用全零
                    uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(openssl rand -hex 16 | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/')")
                    echo -e "${yellow}生成随机UUID: ${uuid:0:8}...${plain}"
                fi
                dest="${server_name}:443"
                private_key=""
                short_ids_array=("" "0123456789abcdef")
                server_names_array=("$server_name")

                echo -e "${yellow}使用grep解析，REALITY配置可能不完整${plain}"
            fi

            # 验证UUID格式
            if [[ ! "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
                echo -e "${red}警告：UUID格式不正确，生成新的随机UUID${plain}"
                uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(openssl rand -hex 16 | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2\3\4-\5\6-\7\8-\9\10-\11\12\13\14\15\16/')")
            fi

            if [ -z "$private_key" ]; then
                echo -e "${yellow}警告：未获取到REALITY私钥，将使用示例密钥${plain}"
                private_key="your-private-key-here"
            fi

            # 生成short_ids JSON数组
            local short_ids_json="["
            for i in "${!short_ids_array[@]}"; do
                if [ $i -gt 0 ]; then short_ids_json+=","; fi
                short_ids_json+="\"${short_ids_array[$i]}\""
            done
            short_ids_json+="]"

            # 生成server_names JSON数组
            local server_names_json="["
            for i in "${!server_names_array[@]}"; do
                if [ $i -gt 0 ]; then server_names_json+=","; fi
                server_names_json+="\"${server_names_array[$i]}\""
            done
            server_names_json+="]"

            # 添加逗号分隔符
            if [ "$first_inbound" = false ]; then
                custom_inbound_content+=","
            fi
            first_inbound=false

            # 生成完整的双入站配置
            custom_inbound_content+="
        {
            \"tag\": \"dokodemo-antisteal-${node_id}\",
            \"port\": ${server_port},
            \"protocol\": \"dokodemo-door\",
            \"settings\": {
                \"address\": \"::1\",
                \"port\": ${internal_port},
                \"network\": \"tcp\"
            },
            \"sniffing\": {
                \"enabled\": true,
                \"destOverride\": [\"tls\"],
                \"routeOnly\": true
            }
        },
        {
            \"tag\": \"vless-reality-antisteal-${node_id}\",
            \"listen\": \"::1\",
            \"port\": ${internal_port},
            \"protocol\": \"vless\",
            \"settings\": {
                \"clients\": [
                    {
                        \"id\": \"${uuid}\"
                    }
                ],
                \"decryption\": \"none\"
            },
            \"streamSettings\": {
                \"network\": \"tcp\",
                \"security\": \"reality\",
                \"realitySettings\": {
                    \"dest\": \"${dest}\",
                    \"serverNames\": ${server_names_json},
                    \"privateKey\": \"${private_key:-your-private-key-from-panel}\",
                    \"shortIds\": ${short_ids_json}
                }
            },
            \"sniffing\": {
                \"enabled\": true,
                \"destOverride\": [
                    \"http\",
                    \"tls\",
                    \"quic\"
                ],
                \"routeOnly\": true
            }
        }"

            echo -e "${green}节点 $node_id 完整防偷跑配置生成成功${plain}"
            echo -e "  - 外部端口：$server_port"
            echo -e "  - 内网端口：$internal_port"
            echo -e "  - 服务器名：$server_name"
            echo -e "  - UUID：${uuid:0:8}..."
            echo -e "  - 目标地址：$dest"
            echo -e "  - 私钥状态：$([ -n "$private_key" ] && [ "$private_key" != "your-private-key-from-panel" ] && echo "✅ 已从API获取" || echo "⚠️  需要手动配置")"

            # 添加防偷跑路由规则（使用所有server_names）
            for server_name_item in "${server_names_array[@]}"; do
                add_antisteal_routing_rules "$node_id" "$server_name_item"
            done
        else
            echo -e "${red}获取节点 $node_id 配置失败，跳过防偷跑配置${plain}"
        fi
    done

    custom_inbound_content+="
    ]"

    # 写入custom_inbound.json文件
    echo "$custom_inbound_content" > /etc/V2bX/custom_inbound.json

    echo -e "${green}完整防偷跑配置生成完成！${plain}"
    echo ""
    echo -e "${yellow}=== 防偷跑配置说明 ===${plain}"
    echo -e "${green}配置文件：${plain}"
    echo -e "  - 防偷跑入站：/etc/V2bX/custom_inbound.json（完整双入站配置）"
    echo -e "  - 路由规则：/etc/V2bX/route.json"
    echo -e "  - 出站配置：/etc/V2bX/custom_outbound.json"
    echo ""
    echo -e "${green}防偷跑架构：${plain}"
    echo -e "  1. dokodemo-door监听外部端口（如443）"
    echo -e "  2. 转发到完整的VLESS+REALITY入站（内网端口）"
    echo -e "  3. 路由规则：只允许匹配serverNames的域名通过"
    echo -e "  4. 其他请求被阻断，防止流量偷跑"
    echo ""
    echo -e "${green}关键改进：${plain}"
    echo -e "  ✅ 完整的REALITY配置（包含streamSettings）"
    echo -e "  ✅ 从面板API获取真实的REALITY参数"
    echo -e "  ✅ 双入站架构，完全自主控制"
    echo -e "  ✅ 避免与V2bX自动生成冲突"
    echo ""
    echo -e "${yellow}重要提醒：${plain}"
    echo -e "  - 请确保面板中已正确配置REALITY参数"
    echo -e "  - 如果私钥显示'需要配置'，请在面板中生成REALITY密钥"
    echo -e "  - 重启V2bX后防偷跑功能即可生效"
    echo ""
    echo -e "${yellow}=== Xboard 面板配置指南 ===${plain}"
    echo -e "${green}1. 节点配置：${plain}"
    echo -e "  - 协议：VLESS"
    echo -e "  - 传输：TCP"
    echo -e "  - 安全：REALITY"
    echo -e "  - 端口：443（或其他端口）"
    echo ""
    echo -e "${green}2. REALITY 设置：${plain}"
    echo -e "  - 目标网站：选择可信的HTTPS网站（如 speed.cloudflare.com）"
    echo -e "  - 服务器名称：与目标网站一致"
    echo -e "  - 私钥/公钥：在面板中生成或使用 xray x25519 命令生成"
    echo -e "  - 短ID：留空或设置为随机16进制字符串"
    echo ""
    echo -e "${green}3. API 字段映射：${plain}"
    echo -e "  - privateKey: reality_settings.privateKey 或 realitySettings.privateKey"
    echo -e "  - UUID: settings.clients[0].uuid 或 users[0].uuid"
    echo -e "  - serverNames: reality_settings.serverNames"
    echo -e "  - shortIds: reality_settings.shortIds"
}

# 添加防偷跑路由规则
add_antisteal_routing_rules() {
    local node_id=$1
    local server_name=$2

    # 读取现有的route.json
    local route_file="/etc/V2bX/route.json"
    local temp_file="/tmp/route_temp.json"

    if [ -f "$route_file" ]; then
        # 在现有规则前添加防偷跑规则
        if command -v python3 >/dev/null 2>&1; then
            python3 << EOF
import json
import sys

try:
    with open('$route_file', 'r') as f:
        route_config = json.load(f)

    # 确保rules数组存在
    if 'rules' not in route_config:
        route_config['rules'] = []

    # 添加防偷跑规则到规则列表开头
    antisteal_rules = [
        {
            "type": "field",
            "inboundTag": ["dokodemo-antisteal-$node_id"],
            "domain": ["$server_name"],
            "outboundTag": "direct"
        },
        {
            "type": "field",
            "inboundTag": ["dokodemo-antisteal-$node_id"],
            "outboundTag": "block"
        }
    ]

    # 将防偷跑规则插入到开头
    route_config['rules'] = antisteal_rules + route_config['rules']

    with open('$temp_file', 'w') as f:
        json.dump(route_config, f, indent=4)

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
EOF

            if [ $? -eq 0 ]; then
                mv "$temp_file" "$route_file"
                echo -e "${green}节点 $node_id 防偷跑路由规则添加成功${plain}"
            else
                echo -e "${red}节点 $node_id 防偷跑路由规则添加失败${plain}"
            fi
        else
            echo -e "${yellow}未安装Python3，请手动在 $route_file 中添加以下规则：${plain}"
            echo -e "  - 允许 $server_name 域名通过 dokodemo-antisteal-$node_id"
            echo -e "  - 阻断其他通过 dokodemo-antisteal-$node_id 的请求"
        fi
    fi
}
