#!/bin/bash

# build_cert.sh
# 用途：生成自签名证书和私钥，并保存到指定目录
# 使用方法：
# ./build_cert.sh <CERT_HOST> <CERT_DIR> <CONF_FILE>
# <CERT_HOST> -->  自签域名或者ip
# <CERT_DIR> --> 生成证书的文件夹

CERT_HOST=$1
CERT_DIR=$2
CONF_FILE=$3

# 生成 openssl 配置文件
echo "[req]
default_bits  = 2048
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
countryName = XX
stateOrProvinceName = N/A
localityName = N/A
organizationName = Self-signed certificate
commonName = $CERT_HOST: Self-signed certificate

[req_ext]
subjectAltName = @alt_names

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = $CERT_HOST
" > "$CONF_FILE"

# 创建证书目录
mkdir -p "$CERT_DIR"

# 生成自签名证书和私钥
openssl req -x509 -nodes -days 730 -newkey rsa:2048 \
  -keyout "$CERT_DIR/$CERT_HOST.key" \
  -out "$CERT_DIR/$CERT_HOST.crt" \
  -config "$CONF_FILE"

# 设置私钥权限为 600，只有所有者可读写
chmod 600 "$CERT_DIR/$CERT_HOST.key"

