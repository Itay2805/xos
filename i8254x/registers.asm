
; Intel i8254x-series Network Driver for xOS
; Heavily based on BareMetal i8254x driver, by Ian Seyler
; https://github.com/ReturnInfinity/BareMetal-OS

use32

; Register list
I8254X_REG_CTRL		= 0x0000 ; Control Register
I8254X_REG_STATUS	= 0x0008 ; Device Status Register
I8254X_REG_CTRLEXT	= 0x0018 ; Extended Control Register
I8254X_REG_MDIC		= 0x0020 ; MDI Control Register
I8254X_REG_FCAL		= 0x0028 ; Flow Control Address Low
I8254X_REG_FCAH		= 0x002C ; Flow Control Address High
I8254X_REG_FCT		= 0x0030 ; Flow Control Type
I8254X_REG_VET		= 0x0038 ; VLAN Ether Type
I8254X_REG_ICR		= 0x00C0 ; Interrupt Cause Read
I8254X_REG_ITR		= 0x00C4 ; Interrupt Throttling Register
I8254X_REG_ICS		= 0x00C8 ; Interrupt Cause Set Register
I8254X_REG_IMS		= 0x00D0 ; Interrupt Mask Set/Read Register
I8254X_REG_IMC		= 0x00D8 ; Interrupt Mask Clear Register
I8254X_REG_RCTL		= 0x0100 ; Receive Control Register
I8254X_REG_FCTTV	= 0x0170 ; Flow Control Transmit Timer Value
I8254X_REG_TXCW		= 0x0178 ; Transmit Configuration Word
I8254X_REG_RXCW		= 0x0180 ; Receive Configuration Word
I8254X_REG_TCTL		= 0x0400 ; Transmit Control Register
I8254X_REG_TIPG		= 0x0410 ; Transmit Inter Packet Gap

I8254X_REG_LEDCTL	= 0x0E00 ; LED Control
I8254X_REG_PBA		= 0x1000 ; Packet Buffer Allocation

I8254X_REG_RDBAL	= 0x2800 ; RX Descriptor Base Address Low
I8254X_REG_RDBAH	= 0x2804 ; RX Descriptor Base Address High
I8254X_REG_RDLEN	= 0x2808 ; RX Descriptor Length
I8254X_REG_RDH		= 0x2810 ; RX Descriptor Head
I8254X_REG_RDT		= 0x2818 ; RX Descriptor Tail
I8254X_REG_RDTR		= 0x2820 ; RX Delay Timer Register
I8254X_REG_RXDCTL	= 0x3828 ; RX Descriptor Control
I8254X_REG_RADV		= 0x282C ; RX Int. Absolute Delay Timer
I8254X_REG_RSRPD	= 0x2C00 ; RX Small Packet Detect Interrupt

I8254X_REG_TXDMAC	= 0x3000 ; TX DMA Control
I8254X_REG_TDBAL	= 0x3800 ; TX Descriptor Base Address Low
I8254X_REG_TDBAH	= 0x3804 ; TX Descriptor Base Address High
I8254X_REG_TDLEN	= 0x3808 ; TX Descriptor Length
I8254X_REG_TDH		= 0x3810 ; TX Descriptor Head
I8254X_REG_TDT		= 0x3818 ; TX Descriptor Tail
I8254X_REG_TIDV		= 0x3820 ; TX Interrupt Delay Value
I8254X_REG_TXDCTL	= 0x3828 ; TX Descriptor Control
I8254X_REG_TADV		= 0x382C ; TX Absolute Interrupt Delay Value
I8254X_REG_TSPMT	= 0x3830 ; TCP Segmentation Pad & Min Threshold

I8254X_REG_RXCSUM	= 0x5000 ; RX Checksum Control

; CTRL - Control Register (0x0000)
I8254X_CTRL_FD		= 0x00000001 ; Full Duplex
I8254X_CTRL_LRST	= 0x00000008 ; Link Reset
I8254X_CTRL_ASDE	= 0x00000020 ; Auto-speed detection
I8254X_CTRL_SLU		= 0x00000040 ; Set Link Up
I8254X_CTRL_ILOS	= 0x00000080 ; Invert Loss of Signal
I8254X_CTRL_SPEED_MASK	= 0x00000300 ; Speed selection
I8254X_CTRL_SPEED_SHIFT	= 8
I8254X_CTRL_FRCSPD	= 0x00000800 ; Force Speed
I8254X_CTRL_FRCDPLX	= 0x00001000 ; Force Duplex
I8254X_CTRL_SDP0_DATA	= 0x00040000 ; SDP0 data
I8254X_CTRL_SDP1_DATA	= 0x00080000 ; SDP1 data
I8254X_CTRL_SDP0_IODIR	= 0x00400000 ; SDP0 direction
I8254X_CTRL_SDP1_IODIR	= 0x00800000 ; SDP1 direction
I8254X_CTRL_RST		= 0x04000000 ; Device Reset
I8254X_CTRL_RFCE	= 0x08000000 ; RX Flow Ctrl Enable
I8254X_CTRL_TFCE	= 0x10000000 ; TX Flow Ctrl Enable
I8254X_CTRL_VME		= 0x40000000 ; VLAN Mode Enable
I8254X_CTRL_PHY_RST	= 0x80000000 ; PHY reset

; STATUS - Device Status Register (0x0008)
I8254X_STATUS_FD		= 0x00000001 ; Full Duplex
I8254X_STATUS_LU		= 0x00000002 ; Link Up
I8254X_STATUS_TXOFF		= 0x00000010 ; Transmit paused
I8254X_STATUS_TBIMODE		= 0x00000020 ; TBI Mode
I8254X_STATUS_SPEED_MASK	= 0x000000C0 ; Link Speed setting
I8254X_STATUS_SPEED_SHIFT	= 6
I8254X_STATUS_ASDV_MASK		= 0x00000300 ; Auto Speed Detection
I8254X_STATUS_ASDV_SHIFT	= 8
I8254X_STATUS_PCI66		= 0x00000800 ; PCI bus speed
I8254X_STATUS_BUS64		= 0x00001000 ; PCI bus width
I8254X_STATUS_PCIX_MODE		= 0x00002000 ; PCI-X mode
I8254X_STATUS_PCIXSPD_MASK	= 0x0000C000 ; PCI-X speed
I8254X_STATUS_PCIXSPD_SHIFT	= 14

; CTRL_EXT - Extended Device Control Register (0x0018)
I8254X_CTRLEXT_PHY_INT		= 0x00000020 ; PHY interrupt
I8254X_CTRLEXT_SDP6_DATA	= 0x00000040 ; SDP6 data
I8254X_CTRLEXT_SDP7_DATA	= 0x00000080 ; SDP7 data
I8254X_CTRLEXT_SDP6_IODIR	= 0x00000400 ; SDP6 direction
I8254X_CTRLEXT_SDP7_IODIR	= 0x00000800 ; SDP7 direction
I8254X_CTRLEXT_ASDCHK		= 0x00001000 ; Auto-Speed Detect Chk
I8254X_CTRLEXT_EE_RST		= 0x00002000 ; EEPROM reset
I8254X_CTRLEXT_SPD_BYPS		= 0x00008000 ; Speed Select Bypass
I8254X_CTRLEXT_RO_DIS		= 0x00020000 ; Relaxed Ordering Dis.
I8254X_CTRLEXT_LNKMOD_MASK	= 0x00C00000 ; Link Mode
I8254X_CTRLEXT_LNKMOD_SHIFT	= 22

; MDIC - MDI Control Register (0x0020)
I8254X_MDIC_DATA_MASK	= 0x0000FFFF ; Data
I8254X_MDIC_REG_MASK	= 0x001F0000 ; PHY Register
I8254X_MDIC_REG_SHIFT	= 16
I8254X_MDIC_PHY_MASK	= 0x03E00000 ; PHY Address
I8254X_MDIC_PHY_SHIFT	= 21
I8254X_MDIC_OP_MASK	= 0x0C000000 ; Opcode
I8254X_MDIC_OP_SHIFT	= 26
I8254X_MDIC_R		= 0x10000000 ; Ready
I8254X_MDIC_I		= 0x20000000 ; Interrupt Enable
I8254X_MDIC_E		= 0x40000000 ; Error

; ICR - Interrupt Cause Read (0x00c0)
I8254X_ICR_TXDW		= 0x00000001 ; TX Desc Written back
I8254X_ICR_TXQE		= 0x00000002 ; TX Queue Empty
I8254X_ICR_LSC		= 0x00000004 ; Link Status Change
I8254X_ICR_RXSEQ	= 0x00000008 ; RX S=ence Error
I8254X_ICR_RXDMT0	= 0x00000010 ; RX Desc min threshold reached
I8254X_ICR_RXO		= 0x00000040 ; RX Overrun
I8254X_ICR_RXT0		= 0x00000080 ; RX Timer Interrupt
I8254X_ICR_MDAC		= 0x00000200 ; MDIO Access Complete
I8254X_ICR_RXCFG	= 0x00000400
I8254X_ICR_PHY_INT	= 0x00001000 ; PHY Interrupt
I8254X_ICR_GPI_SDP6	= 0x00002000 ; GPI on SDP6
I8254X_ICR_GPI_SDP7	= 0x00004000 ; GPI on SDP7
I8254X_ICR_TXD_LOW	= 0x00008000 ; TX Desc low threshold hit
I8254X_ICR_SRPD		= 0x00010000 ; Small RX packet detected

; RCTL - Receive Control Register (0x0100)
I8254X_RCTL_EN		= 0x00000002 ; Receiver Enable
I8254X_RCTL_SBP		= 0x00000004 ; Store Bad Packets
I8254X_RCTL_UPE		= 0x00000008 ; Unicast Promiscuous Enabled
I8254X_RCTL_MPE		= 0x00000010 ; Xcast Promiscuous Enabled
I8254X_RCTL_LPE		= 0x00000020 ; Long Packet Reception Enable
I8254X_RCTL_LBM_MASK	= 0x000000C0 ; Loopback Mode
I8254X_RCTL_LBM_SHIFT	= 6
I8254X_RCTL_RDMTS_MASK	= 0x00000300 ; RX Desc Min Threshold Size
I8254X_RCTL_RDMTS_SHIFT	= 8
I8254X_RCTL_MO_MASK	= 0x00003000 ; Multicast Offset
I8254X_RCTL_MO_SHIFT	= 12
I8254X_RCTL_BAM		= 0x00008000 ; Broadcast Accept Mode
I8254X_RCTL_BSIZE_MASK	= 0x00030000 ; RX Buffer Size
I8254X_RCTL_BSIZE_SHIFT	= 16
I8254X_RCTL_VFE		= 0x00040000 ; VLAN Filter Enable
I8254X_RCTL_CFIEN	= 0x00080000 ; CFI Enable
I8254X_RCTL_CFI		= 0x00100000 ; Canonical Form Indicator Bit
I8254X_RCTL_DPF		= 0x00400000 ; Discard Pause Frames
I8254X_RCTL_PMCF	= 0x00800000 ; Pass MAC Control Frames
I8254X_RCTL_BSEX	= 0x02000000 ; Buffer Size Extension
I8254X_RCTL_SECRC	= 0x04000000 ; Strip Ethernet CRC

; TCTL - Transmit Control Register (0x0400)
I8254X_TCTL_EN		= 0x00000002 ; Transmit Enable
I8254X_TCTL_PSP		= 0x00000008 ; Pad short packets
I8254X_TCTL_SWXOFF	= 0x00400000 ; Software XOFF Transmission

; PBA - Packet Buffer Allocation (0x1000)
I8254X_PBA_RXA_MASK	= 0x0000FFFF ; RX Packet Buffer
I8254X_PBA_RXA_SHIFT	= 0
I8254X_PBA_TXA_MASK	= 0xFFFF0000 ; TX Packet Buffer
I8254X_PBA_TXA_SHIFT	= 16

; Flow Control Type
I8254X_FCT_TYPE_DEFAULT	= 0x8808

; === TX Descriptor fields ===

; TX Packet Length (word 2)
I8254X_TXDESC_LEN_MASK	= 0x0000ffff

; TX Descriptor CMD field (word 2)
I8254X_TXDESC_IDE	= 0x80000000 ; Interrupt Delay Enable
I8254X_TXDESC_VLE	= 0x40000000 ; VLAN Packet Enable
I8254X_TXDESC_DEXT	= 0x20000000 ; Extension
I8254X_TXDESC_RPS	= 0x10000000 ; Report Packet Sent
I8254X_TXDESC_RS	= 0x08000000 ; Report Status
I8254X_TXDESC_IC	= 0x04000000 ; Insert Checksum
I8254X_TXDESC_IFCS	= 0x02000000 ; Insert FCS
I8254X_TXDESC_EOP	= 0x01000000 ; End Of Packet

; TX Descriptor STA field (word 3)
I8254X_TXDESC_TU	= 0x00000008 ; Transmit Underrun
I8254X_TXDESC_LC	= 0x00000004 ; Late Collision
I8254X_TXDESC_EC	= 0x00000002 ; Excess Collisions
I8254X_TXDESC_DD	= 0x00000001 ; Descriptor Done

; === RX Descriptor fields ===

; RX Packet Length (word 2)
I8254X_RXDESC_LEN_MASK	= 0x0000ffff

; RX Descriptor STA field (word 3)
I8254X_RXDESC_PIF	= 0x00000080 ; Passed In-exact Filter
I8254X_RXDESC_IPCS	= 0x00000040 ; IP cksum calculated
I8254X_RXDESC_TCPCS	= 0x00000020 ; TCP cksum calculated
I8254X_RXDESC_VP	= 0x00000008 ; Packet is 802.1Q
I8254X_RXDESC_IXSM	= 0x00000004 ; Ignore cksum indication
I8254X_RXDESC_EOP	= 0x00000002 ; End Of Packet
I8254X_RXDESC_DD	= 0x00000001 ; Descriptor Done
