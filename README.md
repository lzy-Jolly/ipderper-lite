# 项目仍在更新中版本功能尚未完备 20251021
# ipderper-lite
ipderper-lite — 轻量级一键脚本，可在 Ubuntu、Debian 和 Alpine Linux 系统上运行 ipderper for tailscale
```sh
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install_ipderper.sh)"
```
<details>
<summary>derpmap.json 示例</summary>

```json
{
    "derpMap": {
        "OmitDefaultRegions": false,    // true表示只使用下面定义的节点，测试的时候可以true，正式用falseb
        "Regions": {
            "931": {                    // 一般跟下面一样 注意多个自定义 derper 的 RegionID 不能一样 
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
            },  //<<--------------------------------注意这个regions之间的逗号（json语法）
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
</details> 
