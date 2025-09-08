create_ip -name system_cache -vendor xilinx.com -library ip -version 5.0 -module_name $::env(IP_NAME)

set_property -dict [list \
  CONFIG.C_FREQ {300.0} \
  CONFIG.C_NUM_OPTIMIZED_PORTS {0} \
  CONFIG.C_NUM_GENERIC_PORTS {1} \
  CONFIG.C_S0_AXI_GEN_DATA_WIDTH {512} \
  CONFIG.C_M0_AXI_GEN_DATA_WIDTH {512} \
] [get_ips $::env(IP_NAME)]

set_property CONFIG.C_S0_AXI_GEN_ADDR_WIDTH $::env(MBUS_ADDR_WIDTH)  [get_ips $::env(IP_NAME)]
set_property CONFIG.C_S0_AXI_GEN_ID_WIDTH $::env(MBUS_ID_WIDTH)  [get_ips $::env(IP_NAME)]


