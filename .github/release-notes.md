## OpenWrt Firmware for CMCC PZ-L8

OpenWrt firmware with Wi-Fi support for CMCC PZ-L8 router.

### Patches

- [PR #21495](https://github.com/openwrt/openwrt/pull/21495) PZ-L8 device support + ath11k-smallbuffers
- [FM25LS01 Support](https://github.com/immortalwrt/immortalwrt/blob/cec44a8d851230dff1807d616f264593f4fa13ae/target/linux/generic/hack-6.12/400-mtd-spinand-Support-fmsh.patch#L187-L195) V2 batches use FMSH FM25LS01 SPI NAND flash chip instead of ESMT F50D1G41LB within V1.
- [WiFi Board Data Files](https://github.com/openwrt/firmware_qca-wireless/pull/106) Extracted from official CMCC PZ-L8 firmware 501.11.

### Files

| File | Mode | Description |
|------|------|-------------|
| `openwrt-pz-l8-initramfs-ap.itb` | AP | Initramfs FIT image (TFTP boot) |
| `openwrt-pz-l8-factory-ap.ubi` | AP | Factory UBI image (SSH/U-Boot) |
| `openwrt-pz-l8-sysupgrade-ap.bin` | AP | Sysupgrade image |
| `openwrt-pz-l8-initramfs-router.itb` | Router | Initramfs FIT image (TFTP boot) |
| `openwrt-pz-l8-factory-router.ubi` | Router | Factory UBI image (SSH/U-Boot) |
| `openwrt-pz-l8-sysupgrade-router.bin` | Router | Sysupgrade image |

### AP Mode

- All ports bridged (lan1, lan2, lan3, wan)
- DHCP client with 192.168.10.1 fallback
- 802.11s mesh support + usteer
- No firewall, no DHCP server

### Router Mode

- Full router features
- WAN: wan port (DHCP or PPPoE)
- LAN: lan1, lan2, lan3 bridged
- Firewall, NAT, IPv6 support

### Common Features

- WiFi: 2.4GHz (IPQ5000) + 5GHz (QCN6102)
- Driver: ath11k-smallbuffers (256MB RAM optimized)
- ZRAM: lzo-rle (default) / zstd (optional)

### ZRAM Compression

- Supported: lzo, lzo-rle, zstd
- Default: lzo-rle (low CPU usage)
- Switch: `echo zstd > /sys/block/zram0/comp_algorithm`
- UCI: `option zram_comp_algo zstd`

### Installation

#### Method 1: SSH (from stock firmware)

1. Enable SSH on stock firmware
2. Upload `factory.ubi` to `/tmp`
3. Run:
   ```sh
   export rootfs=$(cat /proc/mtd | grep rootfs | grep -v _ | cut -d: -f1)
   ubidetach -f -p /dev/${rootfs}
   ubiformat /dev/${rootfs} -y -f /tmp/factory.ubi
   reboot
   ```

#### Method 2: U-Boot TFTP
> **Note:** Requires a serial (UART) connection to enter U-Boot CLI.

**2a. Direct flash**

1. Place `factory.ubi` on TFTP server
2. Enter U-Boot CLI and run:
   ```
   tftpboot <server_ip>:factory.ubi
   flash rootfs
   reset
   ```

**2b. Boot initramfs then sysupgrade**

1. Place `initramfs.itb` on TFTP server
2. Enter U-Boot CLI and run:
   ```
   tftpboot <server_ip>:initramfs.itb
   bootm
   ```
3. Upload the `sysupgrade.bin` to `/tmp` on the initramfs system
4. Run:
   ```sh
   sysupgrade /tmp/sysupgrade.bin
   ```

#### Method 3: Sysupgrade (from existing OpenWrt)

```sh
sysupgrade /tmp/sysupgrade.bin
```

Use `sysupgrade -n` only if you want to reset all settings to defaults.

---

## CMCC PZ-L8 OpenWrt 固件

为中国移动 PZ-L8 路由器编译的带 Wi-Fi 支持的 OpenWrt 固件。

### 补丁

- [PR #21495](https://github.com/openwrt/openwrt/pull/21495) PZ-L8 设备支持 + ath11k-smallbuffers
- [FM25LS01 支持](https://github.com/immortalwrt/immortalwrt/blob/cec44a8d851230dff1807d616f264593f4fa13ae/target/linux/generic/hack-6.12/400-mtd-spinand-Support-fmsh.patch#L187-L195) V2 批次使用 FMSH FM25LS01 SPI NAND 闪存芯片，替代 V1 中的 ESMT F50D1G41LB。
- [WiFi Board Data 文件](https://github.com/openwrt/firmware_qca-wireless/pull/106) 提取自 CMCC PZ-L8 官方固件 501.11。

### 文件

| 文件 | 模式 | 说明 |
|------|------|------|
| `openwrt-pz-l8-initramfs-ap.itb` | AP | Initramfs FIT 镜像（TFTP 启动） |
| `openwrt-pz-l8-factory-ap.ubi` | AP | 出厂 UBI 镜像（SSH/U-Boot 刷写） |
| `openwrt-pz-l8-sysupgrade-ap.bin` | AP | 升级镜像 |
| `openwrt-pz-l8-initramfs-router.itb` | 路由 | Initramfs FIT 镜像（TFTP 启动） |
| `openwrt-pz-l8-factory-router.ubi` | 路由 | 出厂 UBI 镜像（SSH/U-Boot 刷写） |
| `openwrt-pz-l8-sysupgrade-router.bin` | 路由 | 升级镜像 |

### AP 模式

- 所有端口桥接（lan1、lan2、lan3、wan）
- DHCP 客户端，兜底 IP 192.168.10.1
- 802.11s mesh 支持 + usteer
- 无防火墙，无 DHCP 服务

### 路由模式

- 完整路由功能
- WAN：wan 口（DHCP 或 PPPoE）
- LAN：lan1、lan2、lan3 桥接
- 防火墙、NAT、IPv6 支持

### 通用特性

- WiFi：2.4GHz（IPQ5000）+ 5GHz（QCN6102）
- 驱动：ath11k-smallbuffers（256MB 内存优化）
- ZRAM：lzo-rle（默认）/ zstd（可选）

### ZRAM 压缩

- 支持：lzo、lzo-rle、zstd
- 默认：lzo-rle（低 CPU 占用）
- 切换：`echo zstd > /sys/block/zram0/comp_algorithm`
- UCI 配置：`option zram_comp_algo zstd`

### 安装

#### 方式一：SSH（从原厂固件）
> **注意：** 需要串口（UART）连接以进入 U-Boot 命令行。

1. 在原厂固件上启用 SSH
2. 上传 `factory.ubi` 到 `/tmp`
3. 执行：
   ```sh
   export rootfs=$(cat /proc/mtd | grep rootfs | grep -v _ | cut -d: -f1)
   ubidetach -f -p /dev/${rootfs}
   ubiformat /dev/${rootfs} -y -f /tmp/factory.ubi
   reboot
   ```

#### 方式二：U-Boot TFTP

**2a. 直接刷入**

1. 将 `factory.ubi` 放到 TFTP 服务器
2. 进入 U-Boot 命令行并执行：
   ```
   tftpboot <server_ip>:factory.ubi
   flash rootfs
   reset
   ```

**2b. 启动 initramfs 后 sysupgrade**

1. 将 `initramfs.itb` 放到 TFTP 服务器
2. 进入 U-Boot 命令行并执行：
   ```
   tftpboot <server_ip>:initramfs.itb
   bootm
   ```
3. 将 `sysupgrade.bin` 上传到 initramfs 系统的 `/tmp` 目录
4. 执行：
   ```sh
   sysupgrade /tmp/sysupgrade.bin
   ```

#### 方式三：Sysupgrade（从已有 OpenWrt）

```sh
sysupgrade /tmp/sysupgrade.bin
```

仅在需要恢复默认设置时使用 `sysupgrade -n`。
