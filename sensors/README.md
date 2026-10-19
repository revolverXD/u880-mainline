# U880 sensors (accelerometer / auto-rotate) - how the pieces fit

Sensors sit behind the ADSP sensors core (SSC), reached over QRTR (service 400 SNS_CLIENT) with libssc.
The sensors PD on the ADSP loads its configs and registry from the main OS over FastRPC; hexagonrpcd serves them.

- vendor/  : /vendor/etc/sensors from the stock 0311 vendor.img (debugfs rdump; not redistributable firmware data - keep local)
- persist/ : sensors/ from the persist partition (Android-generated registry, device calibration)
- stage/   : what goes to /usr/share/qcom/u880 on the tablet (sensors/config incl. json.lst, sensors/sns_reg.conf)
  plus socinfo/ (static: hw_platform=QRD soc_id=643 ...) and persist-sensors -> /var/lib/hexagonrpcd/persist-sensors (writable copy)
- tablet-config/ : udev rules + systemd drop-in installed on the tablet
- hexagonrpcd: upstream linux-msm/hexagonrpc + patches/u880/hexagonrpc-0001 (fwrite/fsync/fremove/frename for the
  registry, large input buffers via adsp_listener get_in_bufs2), built on the tablet in /root/hexagonrpc, /usr/local.
