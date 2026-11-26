# U880 sensors (accelerometer / auto-rotate) - how the pieces fit

Sensors sit behind the ADSP sensors core (SSC), reached over QRTR (service 400 SNS_CLIENT) with libssc.
The sensors PD on the ADSP loads its configs and registry from the main OS over FastRPC; hexagonrpcd serves them.

- vendor/  : /vendor/etc/sensors from the stock 0311 vendor.img (debugfs rdump; not redistributable firmware data - keep local)
- persist/ : sensors/ from the persist partition (Android-generated registry, device calibration)
- stage/   : what goes to /usr/share/qcom/u880 on the tablet (sensors/config incl. json.lst, sensors/sns_reg.conf)
  plus socinfo/ (static: hw_platform=QRD soc_id=643 ...) and persist-sensors -> /var/lib/hexagonrpcd/persist-sensors (writable copy)
- tablet-config/ : udev rules + systemd drop-in installed on the tablet
- hexagonrpcd: upstream https://github.com/linux-msm/hexagonrpc (the tree that was built on the reference tablet, `/root/hexagonrpc`, `origin https://github.com/linux-msm/hexagonrpc.git`, branch `main`, was at commit `da7a3742ab8d5273a281b70ee11f16fb2cb6a690`; the patch was applied on top of it, so check out that commit first and expect a rebase for anything newer) + `patches/u880/hexagonrpc-0001-u880-writable-registry-large-buffers.patch` (fwrite/fsync/fremove/frename for the
  registry, large input buffers via adsp_listener get_in_bufs2), built ON the booted tablet (meson + ninja; base-devel from the Arch ARM repos) into /usr/local: `hexagonrpcd`, `libhexagonrpc.so.0.5`, `chrecd`. It is a second pass after the first boot, not something the first root image can contain.
  Needs `/etc/ld.so.conf.d/usr-local.conf` (`/usr/local/lib`), the `fastrpc` user (uid 961) and the data under /usr/share/qcom/u880 (`sensors/` from the stock vendor image, `socinfo/`, `persist-sensors`) plus the writable /var/lib/hexagonrpcd/persist-sensors.
