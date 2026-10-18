// SPDX-License-Identifier: GPL-2.0
/* Debug: enable/disable a q6prm LPASS clock by (id, attribute) and optionally set its rate.
 * echo "<id> <attr> <rate|0> <1|0>" > /sys/module/clkpoke/parameters/req
 */
#include <linux/clk.h>
#include <linux/clk-provider.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/slab.h>

static char req[64];

static int req_set(const char *val, const struct kernel_param *kp)
{
	struct of_phandle_args a = { .args_count = 2 };
	unsigned int id, attr, en;
	unsigned long rate;
	struct device_node *np;
	struct clk *c;
	int ret;

	if (sscanf(val, "%u %u %lu %u", &id, &attr, &rate, &en) != 4)
		return -EINVAL;
	np = of_find_compatible_node(NULL, NULL, "qcom,q6prm-lpass-clocks");
	if (!np)
		return -ENODEV;
	a.np = np; a.args[0] = id; a.args[1] = attr;
	c = of_clk_get_from_provider(&a);
	of_node_put(np);
	if (IS_ERR(c))
		return PTR_ERR(c);
	pr_info("clkpoke: id %u attr %u rate %lu en %u (%s)\n", id, attr, rate, en, __clk_get_name(c));
	if (rate) {
		ret = clk_set_rate(c, rate);
		pr_info("clkpoke: set_rate -> %d\n", ret);
	}
	ret = en ? clk_prepare_enable(c) : (clk_disable_unprepare(c), 0);
	pr_info("clkpoke: %s -> %d\n", en ? "enable" : "disable", ret);
	return ret;
}

static const struct kernel_param_ops ops = { .set = req_set };
module_param_cb(req, &ops, &req, 0200);
MODULE_LICENSE("GPL");
