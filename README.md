# 上新
[中文说明](https://github.com/lzy-Jolly/ipderper-lite/blob/main/README.md)
[English](https://github.com/lzy-Jolly/ipderper-lite/blob/main/README_EN.md)
## ipderper-lite 
ipderper-lite — 轻量级一键脚本，可在 Ubuntu、Debian 和 Alpine Linux 系统上运行 ipderper for tailscale
## 前提条件
1.支持Alpine=>3.20,Ubuntu=20-24，debian=12-13。（没太测试过，但是都用很基础的sh功能）

    ps:建议基础的apt和apk 都 update一下
    
2.正确安装tailscale cli 命令行版本（linux）客户端，并登录tailscale up 正确登录到账户。安装可以参考下面官方一键脚本：
```sh
curl -fsSL https://tailscale.com/install.sh | sh
```

## 下面是一键脚本
安装后  ipderper 打开管理工具
```sh
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install_ipderper.sh)"
```

## 官网配置ACL添加ip derper节点
网站修改地址
https://login.tailscale.com/admin/acls/file

虽然tailscale官网支持，但是json一般不支持注释，写上它就emmm红了

实在不会，复制原本官网的文件还有新节点的文件，丢给gpt，让添加节点去重id和保留注释

<details>

```json
{
    "derpMap": {
        "OmitDefaultRegions": false,    // true表示只使用下面定义的节点，测试的时候可以true，正式用falseb
        "Regions": {
            "931": {                    // AAA 一般跟下面一样 注意多个自定义 derper 的 RegionID 不能一样 
                "RegionID": 931,        // tailscale 900-999 是保留给自定义 derper 的，tag--A
                "RegionCode": "SHK",    // 随便填 一般3个字母(英文数字ascii)
                "RegionName": "wy_CN2",  // 随便填 方便识(英文数字ascii)
                "Nodes": [              // 建议一个regionsid+一个node，不要多个nodes
                    {
                        "Name": "wyCOoOC",               // 随便填 方便识别(英文数字ascii)
                        "RegionID": 931,            // 与tag--A保持一致，
                        "IPv4": "123.1.1.1",        // 自定义derper服务器公网ip 比如 123.1.1.1
                        "DERPPort": 30000,          // 刚刚设置的端口 比如30000
                        "InsecureForTests": true    // 如果是自签证书默认true，小白保留这个。
                    }
                ]
            },   //<<--------------------------------注意这个regions之间的逗号（json语法）
            "933": {                                // 这是第二个derper的示例
                "RegionID": 933,
                "RegionCode": "AHK",
                "RegionName": "KAHK",
                "Nodes": [
                    {
                        "Name": "wyCN22",
                        "RegionID": 933,
                        "IPv4": "321.1.1.1",
                        "DERPPort": 30001,
                        "InsecureForTests": true
                    }
                ]
            }
        }
    },
    "grants": [----这部分留着别管----],
    "ssh": [----这部分留着别管----],
    "nodeAttrs":  [----这部分留着别管----]

}
```

