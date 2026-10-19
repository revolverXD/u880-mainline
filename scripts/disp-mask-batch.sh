#!/usr/bin/env bash
# Boot each msm.u880_dbg mask on the DISP=4 test kernel N times (RAM boot via fastboot, slot A untouched), capture a
# camera photo (cropped), the DSI/PHY/INTF "live" registers and the DSI FIFO probe per boot. Stops at the first boot
# that never comes up (a hung tablet needs a power-button restart; nothing can be done remotely).
# usage: N=3 scripts/disp-mask-batch.sh 0x1108f00 0x108f00 ...   (tablet in normal Linux over Wi-Fi, PC data cable in,
#        stage1/dtb2-disp4-nousb3.dtb + stage1/initramfs-u880c.cpio.gz present, kernel Image built)
# Output: photos/mb-<mask>-<n>.jpg (full), $OUT/<mask>-<n>.{jpg,regs,fifo}, and a summary line per boot in $OUT/summary.log
# Review photos YOURSELF (crop 62%x50%+150+170 of the webcam frame = the tablet; landscape: top half = DSI0/INTF_1,
# bottom half = DSI1/INTF_2). Optional: scripts/vlm.py classifies with the local Qwen VLM (cheap, but it misreads).
set -u
M=/home/USER/External/work/src/mainline; cd $M
OUT=${OUT:-/tmp/disp-mask-batch}; mkdir -p $OUT photos
export U880_HOST=${U880_HOST:-192.168.X.Y}
N=${N:-3}
for m in "$@"; do
  img=stage1/u880-boot-disp4-$m.img
  python3 /home/USER/External/work/src/LineageOS/system/tools/mkbootimg/mkbootimg.py --header_version 2 --os_version 14.0.0 \
    --os_patch_level 2024-03 --kernel linux-7.2.9/arch/arm64/boot/Image --ramdisk stage1/initramfs-u880c.cpio.gz \
    --dtb stage1/dtb2-disp4-nousb3.dtb --base 0x0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 \
    --dtb_offset 0x1f00000 --pagesize 4096 --cmdline "console=tty0 fbcon=font:TER16x32 clk_ignore_unused pd_ignore_unused loglevel=6 rdinit=/init regulator_ignore_unused g_cdc.idProduct=0xa4a7 u880root=ufs cpufreq.default_governor=schedutil arm-smmu.disable_bypass=0 msm.u880_dbg=$m" -o $img || exit 1
  for n in $(seq 1 $N); do
    timeout 20 scripts/rssh.sh 'pkill -x modetest; sync; reboot bootloader' >/dev/null 2>&1
    for i in $(seq 1 45); do timeout 5 fastboot devices 2>/dev/null | grep -q fastboot && break; sleep 2; done; sleep 2
    timeout 60 fastboot boot $img >/dev/null 2>&1
    ok=0; for i in $(seq 1 50); do timeout 10 scripts/rssh.sh true 2>/dev/null && { ok=1; break; }; sleep 3; done
    [ $ok = 0 ] && { echo "$m #$n HANG (power-button restart needed)" | tee -a $OUT/summary.log; exit 1; }
    sleep 28
    timeout 40 scripts/rssh.sh 'cat /sys/kernel/debug/u880-display/live' > $OUT/$m-$n.regs 2>/dev/null
    timeout 40 scripts/rssh.sh 'cat /sys/kernel/debug/u880-dsi/fifo' > $OUT/$m-$n.fifo 2>/dev/null
    p=$(bash scripts/cam.sh photos/mb-$m-$n.jpg 2>/dev/null | tail -1)
    nix-shell -p imagemagick --run "magick $p -crop 62%x50%+150+170 +repage -resize 430x $OUT/$m-$n.jpg" >/dev/null 2>&1
    echo "$m #$n INTF_TE=$(grep -E '^0ae3(6|7)000 ' $OUT/$m-$n.regs | awk '{print $2}' | tr '\n' ',') PLL0cal=$(grep -m1 '^0ae956b8 ' $OUT/$m-$n.regs | awk '{print $2}')" | tee -a $OUT/summary.log
  done
done
echo "done; montage: nix-shell -p imagemagick --run 'magick montage $OUT/*.jpg -tile 4x -geometry +4+4 $OUT/montage.jpg'"
