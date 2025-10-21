# New Release!  
## ipderper-lite  
**ipderper-lite** — A lightweight one-click script to run **ipderper** for Tailscale on Ubuntu, Debian, and Alpine Linux systems.

---

## Prerequisites
1. Supported systems: Alpine ≥ 3.20, Ubuntu 20–24, Debian 11–13.  
   *(Not extensively tested, but relies on basic `sh` functionality.)*  
   **Tip:** It's recommended to update your package manager first:
   ```sh
   # Ubuntu / Debian
   sudo apt update && sudo apt upgrade -y

   # Alpine
   sudo apk update && sudo apk upgrade
   ```
2. Properly installed Tailscale CLI (Linux) and logged in using `tailscale up`.  
   You can install it using the official one-liner:
   ```sh
   curl -fsSL https://tailscale.com/install.sh | sh
   ```

---

## One-Click Installation Script
After installation, **ipderper** will launch the management tool:
```sh
sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/lzy-Jolly/ipderper-lite/main/install_ipderper.sh)"
```

---

## Configuring ACL on Tailscale Website to Add ipderper Nodes
Modify ACL JSON at:  
[Tailscale Admin ACL File](https://login.tailscale.com/admin/acls/file)

⚠️ Note: Tailscale JSON does **not** support comments. Including comments will cause errors.  

If unsure, copy your original ACL JSON and the new node JSON, then use a tool (like GPT) to merge nodes, remove duplicate IDs, and preserve comments.

<details>
<summary>Example derpMap JSON for custom nodes</summary>

```json
{
    "derpMap": {
        "OmitDefaultRegions": false,    // true = only use custom nodes; false = include default regions
        "Regions": {
            "931": {                    
                "RegionID": 931,        
                "RegionCode": "SHK",    
                "RegionName": "wy_CN2",  
                "Nodes": [              
                    {
                        "Name": "wyCOoOC",               
                        "RegionID": 931,            
                        "IPv4": "123.1.1.1",        
                        "DERPPort": 30000,          
                        "InsecureForTests": true    
                    }
                ]
            },   
            "933": {                                
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
    "grants": [----leave as is----],
    "ssh": [----leave as is----],
    "nodeAttrs":  [----leave as is----]
}
```

</details>
