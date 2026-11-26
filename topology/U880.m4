# Alldocube iPlay 70 mini Ultra (U880, SM7675/Cliffs): MultiMedia1 into the quinary MI2S port (2x AW88261 smart PAs),
# MultiMedia2 into DisplayPort 0 (USB-C alt mode).
include(`audioreach/audioreach.m4')
include(`audioreach/stream-subgraph.m4')
include(`audioreach/device-subgraph.m4')
include(`util/route.m4')
include(`util/mixer.m4')
include(`audioreach/tokens.m4')
#
# Stream SubGraph for PCM playback: [WR_SH] -> [PCM DEC] -> [PCM CONV] -> [VOL] -> [LOG]
STREAM_SG_PCM_ADD(audioreach/u880-stream-playback.m4, FRONTEND_DAI_MULTIMEDIA1,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004001, 0x00004001, 0x00006001, `110000')
#
# Device SubGraph for the speaker backend: stock resourcemanager says MI2S-LPAIF_VA-RX-PRIMARY. [LOG] -> [I2S EP]
DEVICE_SG_ADD(audioreach/u880-device-i2s-playback.m4, `Primary', PRIMARY_MI2S_RX,
	`S16_LE', 48000, 48000, 2, 2,
	LPAIF_INTF_TYPE_VA, I2S_INTF_TYPE_PRIMARY, SD_LINE_IDX_I2S_SD1, DATA_FORMAT_FIXED_POINT,
	0x00004005, 0x00004005, 0x00006050, `PRIMARY_MI2S_RX')
dnl
STREAM_DEVICE_PLAYBACK_MIXER(PRIMARY_MI2S_RX, ``PRIMARY_MI2S_RX'', ``MultiMedia1'')
dnl
STREAM_DEVICE_PLAYBACK_ROUTE(PRIMARY_MI2S_RX, ``PRIMARY_MI2S_RX Audio Mixer'', ``MultiMedia1, stream0.mfc1'')
dnl
dnl DisplayPort 0 playback (MultiMedia2 -> DISPLAY_PORT_RX_0); no LOG modules, like the speaker graph.
STREAM_SG_PCM_ADD(audioreach/u880-stream-playback.m4, FRONTEND_DAI_MULTIMEDIA2,
	`S16_LE', 48000, 48000, 2, 2,
	0x00004002, 0x00004002, 0x00006020, `110000')
DEVICE_SG_ADD(audioreach/u880-device-dp-playback.m4, `DISPLAY_PORT_RX_0', DISPLAY_PORT_RX_0,
	`S16_LE', 48000, 48000, 2, 2,
	0, 0, 0, DATA_FORMAT_FIXED_POINT,
	0x00004010, 0x00004010, 0x000060B0, `DISPLAY_PORT_RX_0')
dnl
STREAM_DEVICE_PLAYBACK_MIXER(DISPLAY_PORT_RX_0, ``DISPLAY_PORT_RX_0'', ``MultiMedia2'')
dnl
STREAM_DEVICE_PLAYBACK_ROUTE(DISPLAY_PORT_RX_0, ``DISPLAY_PORT_RX_0 Audio Mixer'', ``MultiMedia2, stream1.mfc1'')
dnl
dnl WCD9395 microphone capture (TX_CODEC_DMA_TX_3 -> MultiMedia3); no LOG modules.
STREAM_SG_PCM_ADD(audioreach/u880-stream-capture.m4, FRONTEND_DAI_MULTIMEDIA3,
	`S16_LE', 48000, 48000, 1, 2,
	0x00004003, 0x00004003, 0x00006030, `110000')
DEVICE_SG_ADD(audioreach/u880-device-codec-dma-capture.m4, `TX_CODEC_DMA_TX_3', TX_CODEC_DMA_TX_3,
	`S16_LE', 48000, 48000, 1, 2,
	LPAIF_INTF_TYPE_RXTX, CODEC_INTF_IDX_TX3, 0, DATA_FORMAT_FIXED_POINT,
	0x00004009, 0x00004009, 0x00006090)
dnl
STREAM_DEVICE_CAPTURE_MIXER(FRONTEND_DAI_MULTIMEDIA3, ``TX_CODEC_DMA_TX_3'')
dnl
STREAM_DEVICE_CAPTURE_ROUTE(FRONTEND_DAI_MULTIMEDIA3, ``MultiMedia3 Mixer'', ``TX_CODEC_DMA_TX_3, device120.codec_dma_tx1'')
