
`let ICACHE_SIZE_KBYTE = 8

`let N_ICACHE_WAY = 2

`let N_ICACHE_PREFETCH = 4

`let N_ICACHE_LINE_SET = ICACHE_SIZE_KBYTE * 1024 / CACHE_LINE_BYTE / N_ICACHE_WAY
`let N_ICACHE_DATA_BANK = CACHE_LINE_BYTE * 8 / 32

`let ICACHE_OFFSET_WIDTH = CEIL(LOG2(CACHE_LINE_BYTE))
`let ICACHE_INDEX_WIDTH = CEIL(LOG2(N_ICACHE_LINE_SET))
`let ICACHE_TAG_WIDTH = PHY_ADDR_WIDTH - ICACHE_OFFSET_WIDTH - ICACHE_INDEX_WIDTH
`let ICACHE_DRAM_TAG_WIDTH = DRAM_ADDR_WIDTH - ICACHE_OFFSET_WIDTH - ICACHE_INDEX_WIDTH

`let ICACHE_TAG_MSB = PHY_ADDR_WIDTH - 1
`let ICACHE_TAG_LSB = ICACHE_TAG_MSB - ICACHE_TAG_WIDTH + 1

`let ICACHE_INDEX_MSB = ICACHE_TAG_LSB - 1
`let ICACHE_INDEX_LSB = ICACHE_INDEX_MSB - ICACHE_INDEX_WIDTH + 1

`let ICACHE_DATA_BANK_ID_WIDTH = CEIL(LOG2(N_ICACHE_DATA_BANK))

`let ICACHE_DATA_BANK_ID_MSB = ICACHE_INDEX_LSB - 1
`let ICACHE_DATA_BANK_ID_LSB = ICACHE_DATA_BANK_ID_MSB - ICACHE_DATA_BANK_ID_WIDTH + 1

`let DCACHE_TAG_MSB = ICACHE_TAG_MSB
`let DCACHE_TAG_LSB = ICACHE_TAG_LSB
`let DCACHE_TAG_WIDTH = ICACHE_TAG_WIDTH

`let DCACHE_INDEX_MSB = ICACHE_INDEX_MSB
`let DCACHE_INDEX_LSB = ICACHE_INDEX_LSB
`let DCACHE_INDEX_WIDTH = ICACHE_INDEX_WIDTH

`let DCACHE_DATA_OFFSET_WIDTH = CEIL(LOG2(CACHE_LINE_BYTE * 8 / 64))
`let DCACHE_DATA_OFFSET_MSB = DCACHE_INDEX_LSB - 1
`let DCACHE_DATA_OFFSET_LSB = DCACHE_INDEX_MSB - DCACHE_DATA_OFFSET_WIDTH + 1

`let N_DMA_CHNL = 4
`let N_DMA_SIZE_BIT = 64 - 40 - 1 - CEIL(LOG2(N_DMA_CHNL))

`let N_CYCLE_INT_MUL = 33
`let N_CYCLE_INT_DIV = 33

`let N_CYCLE_INT_MUL_FPGA = 33
`let N_CYCLE_INT_DIV_FPGA = 70

`let N_CYCLE_FP_ADD_S = 16
`let N_CYCLE_FP_ADD_D = 16

`let N_CYCLE_FP_MAC_S = 16
`let N_CYCLE_FP_MAC_D = 16

`let N_CYCLE_FP_DIV_S = 16
`let N_CYCLE_FP_DIV_D = 16

`let N_CYCLE_FP_SQRT_S = 16
`let N_CYCLE_FP_SQRT_D = 16

`let N_CYCLE_FP_MISC = 16
