# V2bX REALITY 防偷跑版

A V2board node server based on Xray-Core with REALITY anti-theft protection.

一个基于Xray的V2board节点服务端，支持V2ay,Trojan,Shadowsocks协议，**增加了REALITY防偷跑功能**。

Find the source code here: [InazumaV/V2bX](https://github.com/InazumaV/V2bX)

如对脚本不放心，可使用此沙箱先测一遍再使用：https://killercoda.com/playgrounds/scenario/ubuntu

## 🛡️ 防偷跑功能特色

基于 [XTLS/Xray-examples](https://github.com/XTLS/Xray-examples/tree/main/VLESS-TCP-REALITY%20(without%20being%20stolen)) 的防偷跑方案，为 V2bX 提供原生的 REALITY 防偷跑支持。

### 解决的问题
- **传统REALITY偷跑问题**：非法请求被无脑转发到 dest，服务器变成免费端口转发
- **完全保持V2bX功能**：用户管理、流量统计、动态配置更新等所有功能正常工作
- **智能防护机制**：只允许匹配 serverNames 的合法请求，其他请求直接阻断

### 防偷跑原理
```
外部请求 → dokodemo-door (端口443) → 检查SNI域名 → 合法？
                                                    ↙    ↘
                                                  是      否
                                                  ↓       ↓
                                            转发到REALITY  阻断
                                            (端口4431)   (block)
```

## 🚀 一键安装

```bash
wget -N https://raw.githubusercontent.com/jieziz/V2bX-script/master/install.sh && bash install.sh
```

## 🔧 防偷跑配置生成

### 使用 initconfig.sh 生成防偷跑配置

```bash
# 运行配置生成脚本
bash initconfig.sh
```

### 配置流程
1. 选择核心类型：**1** (xray)
2. 输入节点 ID：**33**
3. 选择传输协议：**2** (Vless)
4. 是否为 reality 节点：**y**
5. **[新增]** 是否启用防偷跑功能：**y**
6. **[新增]** 输入 REALITY 内网端口：**4431** (默认)
7. 继续完成其他配置...

### 自动生成的配置文件
- `/etc/V2bX/config.json` - V2bX 主配置（自动添加 InboundConfigPath）
- `/etc/V2bX/custom_inbound.json` - 防偷跑入站配置
- `/etc/V2bX/route.json` - 防偷跑路由规则
- `/etc/V2bX/custom_outbound.json` - 出站配置

## 📊 配置示例

### V2bX 配置文件
```json
{
    "Cores": [{
        "Type": "xray",
        "InboundConfigPath": "/etc/V2bX/custom_inbound.json",
        "OutboundConfigPath": "/etc/V2bX/custom_outbound.json",
        "RouteConfigPath": "/etc/V2bX/route.json"
    }],
    "Nodes": [{
        "NodeType": "vless",
        "ListenIP": "::1"  // 防偷跑节点只监听本地
    }]
}
```

### custom_inbound.json（防偷跑入站）
```json
[
    {
        "tag": "dokodemo-antisteal-33",
        "port": 443,
        "protocol": "dokodemo-door",
        "settings": {
            "address": "::1",
            "port": 4431,
            "network": "tcp"
        },
        "sniffing": {
            "enabled": true,
            "destOverride": ["tls"],
            "routeOnly": true
        }
    }
]
```

### route.json（防偷跑路由）
```json
{
    "rules": [
        {
            "type": "field",
            "inboundTag": ["dokodemo-antisteal-33"],
            "domain": ["www.cityline.com"],
            "outboundTag": "direct"
        },
        {
            "type": "field",
            "inboundTag": ["dokodemo-antisteal-33"],
            "outboundTag": "block"
        }
    ]
}
```

## ✨ 核心特性

- ✅ **完全保持V2bX功能**：用户管理、流量统计、动态更新
- ✅ **智能API集成**：自动从面板API获取节点配置信息
- ✅ **动态配置生成**：根据实际节点信息生成防偷跑配置
- ✅ **自动配置管理**：自动更新xray核心配置和路由规则
- ✅ **完整保护**：双入站+路由过滤，有效防止偷跑
- ✅ **向后兼容**：不影响现有的V2bX配置和功能

## 📞 技术要求

- 基本的Linux命令行操作
- 有效的面板API访问权限
- 理解V2bX配置结构（可选）

## 🎯 适用场景

### 推荐使用防偷跑功能的场景
- ✅ 使用REALITY协议的节点
- ✅ 担心被扫描和偷跑流量
- ✅ 需要保持V2bX完整功能
- ✅ 希望配置简单易维护

## 🔧 技术实现详情

### V2bX 架构理解
```
V2bX 主配置 (config.json) → 定义节点信息和文件路径
custom_inbound.json → 直接作为 Xray 的 inbounds 配置
custom_outbound.json → 直接作为 Xray 的 outbounds 配置
route.json → 直接作为 Xray 的 routing 配置
```

### 修改的文件

#### initconfig.sh 主要修改
1. **增强 REALITY 节点配置**（第74-106行）
   - 检测到 VLESS 协议且为 REALITY 节点时，询问是否启用防偷跑功能
   - 提供详细的防偷跑功能说明
   - 询问 REALITY 内网端口（默认4431）

2. **修改 ListenIP 设置**（第136-147行）
   - 为启用防偷跑的 REALITY 节点设置本地监听 `::1`

3. **新增防偷跑配置生成函数**（第547-746行）
   - `generate_reality_antisteal_config()`: 主配置生成函数
   - `add_antisteal_routing_rules()`: 路由规则添加函数

### 智能功能特性

#### 1. API 自动集成
- 自动从面板 API 获取节点配置（server_port, server_name）
- 支持 Python3 和 grep/sed 两种 JSON 解析方式
- 完善的错误处理和回退机制

#### 2. 配置自动管理
- 自动检测并更新 xray 核心配置添加 `InboundConfigPath`
- 智能更新现有 route.json，防偷跑规则优先级处理
- 自动生成 custom_inbound.json 防偷跑入站配置

#### 3. 用户体验优化
- 在现有配置生成流程中自然集成防偷跑选项
- 不破坏原有的交互逻辑
- 提供详细的功能说明和配置原理

## 🛠️ 验证和测试

### 功能验证
```bash
# 检查新增函数
grep -n "generate_reality_antisteal_config" initconfig.sh
grep -n "add_antisteal_routing_rules" initconfig.sh

# 检查防偷跑选项
grep -n "是否启用防偷跑功能" initconfig.sh

# 检查配置文件
cat /etc/V2bX/config.json | grep InboundConfigPath
cat /etc/V2bX/custom_inbound.json
cat /etc/V2bX/route.json | head -20
```

### 测试防偷跑效果
```bash
# 测试合法请求（应该成功）
curl -H "Host: www.cityline.com" https://your-server:443

# 测试非法请求（应该被阻断）
curl -H "Host: evil.com" https://your-server:443
```

## 🎯 与原版对比

| 特性 | 原版 V2bX | 防偷跑版 V2bX |
|------|-----------|---------------|
| 基础功能 | ✅ 完整 | ✅ 完全保持 |
| REALITY支持 | ✅ 标准 | ✅ 标准+防偷跑 |
| 用户管理 | ✅ 支持 | ✅ 完全支持 |
| 流量统计 | ✅ 支持 | ✅ 完全支持 |
| 动态配置 | ✅ 支持 | ✅ 完全支持 |
| 安全性 | ⚠️ 可被偷跑 | ✅ 防偷跑保护 |
| 配置复杂度 | ✅ 简单 | ✅ 几乎无变化 |

## 📞 故障排除

### API 连接失败
```bash
# 检查网络连接
curl -I https://your-panel.com

# 检查API密钥
curl -s "https://your-panel.com/api/v1/server/UniProxy/config?token=your-api-key&node_id=1&node_type=vless"
```

### 配置测试失败
```bash
# 检查配置语法
xray -test -config /etc/xray/config.json

# 查看V2bX日志
journalctl -u v2bx -f
```

## 📖 详细使用教程

[教程](https://v2bx.v-50.me/)

## 🙏 致谢

- [XTLS/Xray-examples](https://github.com/XTLS/Xray-examples) - 防偷跑方案
- [InazumaV/V2bX](https://github.com/InazumaV/V2bX) - 多协议后端

## 📄 许可证

MIT License
