# Alldocube iPlay 70 mini Ultra (U880, SM7675/Cliffs): one playback stream into the quinary MI2S port (2x AW88261 smart PAs).
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
