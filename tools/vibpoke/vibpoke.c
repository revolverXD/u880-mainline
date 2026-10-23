// SPDX-License-Identifier: GPL-2.0
/* Debug: write one byte of a PMIC register over SPMI (default pm7550ba, sid 7, where the vibrator LDO lives).
 * echo "<hex addr> <hex val>" > /sys/module/vibpoke/parameters/req
 */
#include <linux/device.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/regmap.h>
#include <linux/spmi.h>

static char req[64];
static int usid = 7;
module_param(usid, int, 0644);

static int req_set(const char *val, const struct kernel_param *kp)
{
	unsigned int addr, v;
	struct regmap *map;
	int ret;

	if (sscanf(val, "%x %x", &addr, &v) != 2)
		return -EINVAL;
	struct device_node *np;
	struct spmi_device *sdev = NULL;

	for_each_compatible_node(np, NULL, "qcom,spmi-pmic") {
		sdev = spmi_device_from_of(np);
		if (sdev && sdev->usid == usid) {
			of_node_put(np);
			break;
		}
		if (sdev)
			put_device(&sdev->dev);
		sdev = NULL;
	}
	if (!sdev)
		return -ENODEV;
	map = dev_get_regmap(&sdev->dev, NULL);
	put_device(&sdev->dev);
	if (!map)
		return -ENODEV;
	ret = regmap_write(map, addr, v);
	pr_info("vibpoke: sid %d %04x = %02x -> %d\n", usid, addr, v, ret);
	return ret;
}

static const struct kernel_param_ops req_ops = { .set = req_set };
module_param_cb(req, &req_ops, &req, 0200);

MODULE_DESCRIPTION("write a PMIC register over SPMI (debug)");
MODULE_LICENSE("GPL");
