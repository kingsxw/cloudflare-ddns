#!/bin/bash

# 需要解析的FQDN域名
name="ddns.example.com"

# Cloudflare 仪表板 => 网站 => 域名
# 在 API 栏目找到 区域 ID，复制并填入
zone_id="Put your zone ID here"

# 在上述API栏目单击获取您的 API 令牌 => 创建令牌 => 使用编辑区域 DNS模板
# 在 区域资源 栏中，选择包括所有区域，或者你想指定的特定区域
# 单击 继续以显示摘要 => 创建令牌
# 复制并填入
api_token="Put your API token here"

# IPv4更新开关 1=更新
v4_update_switch="1"
# IPv4代理开关（CloudFlare CDN服务，国内貌似被墙） true or false
v4_proxy_switch=false
# IPv4查询地址
v4_query_url="ipv4.whatismyip.akamai.com"

# IPv6更新开关 1=更新
v6_update_switch="1"
# IPv6代理开关（CloudFlare CDN服务，国内貌似被墙） true or false
v6_proxy_switch=false
# IPv6查询地址
v6_query_url="ipv6.whatismyip.akamai.com"

record_response="$(curl -klsX GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
    -H "Authorization: Bearer ${api_token}" \
    -H "Content-Type: application/json" | tr , '\n' | grep ${name} -A2 -B3 | tr -d '{\"}[' | sed 's/result://g')"

update_record() {
    local type="$1"
    local proxy_switch="$2"
    local current_value="$3"

    record="$(echo -E "${record_response}" | grep -E '^type:'${type}'$' -A1 -B4)"

    record_id="$(echo -E "${record}" | head -1 | cut -d: -f2-)"
    record_value="$(echo -E "${record}" | tail -1 | cut -d: -f2-)"

    if [ "$current_value" = "$record_value" ]; then
        echo "当前值未发生变更，跳过${type}记录更新"
    else
        response=$(curl -klsX PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "Authorization: Bearer ${api_token}" \
            -H "Content-Type: application/json" \
            --data '{
              "type": "'${type}'",
              "name": "'${name}'",
              "content": "'${current_value}'",
              "ttl": 1,
              "proxied": '${proxy_switch}'
            }')

        echo "$response" | tr , '\n' | grep -q '^"success":true$' && echo "${type}记录已更新，新的值为: $current_value" || echo "${type}记录更新失败！"
    fi
}

# 检查IPv4地址是否需要更新
if [ "$v4_update_switch" = "1" ]; then
    current_ip_v4="$(curl -klsL "$v4_query_url")"
    update_record "A" "$v4_proxy_switch" "$current_ip_v4"
fi

# 检查IPv6地址是否需要更新
if [ "$v6_update_switch" = "1" ]; then
    current_ip_v6="$(curl -klsL "$v6_query_url")"
    update_record "AAAA" "$v6_proxy_switch" "$current_ip_v6"
fi
