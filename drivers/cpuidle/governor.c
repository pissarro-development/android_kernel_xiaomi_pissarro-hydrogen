/*
 * governor.c - governor support
 *
 * (C) 2006-2007 Venkatesh Pallipadi <venkatesh.pallipadi@intel.com>
 *               Shaohua Li <shaohua.li@intel.com>
 *               Adam Belay <abelay@novell.com>
 *
 * This code is licenced under the GPL.
 */

#include <linux/cpu.h>
#include <linux/cpuidle.h>
#include <linux/mutex.h>
#include <linux/pm_qos.h>

#include "cpuidle.h"

LIST_HEAD(cpuidle_governors);
struct cpuidle_governor *cpuidle_curr_governor;

/**
 * __cpuidle_find_governor - finds a governor of the specified name
 * @str: the name
 *
 * Must be called with cpuidle_lock acquired.
 */
static struct cpuidle_governor * __cpuidle_find_governor(const char *str)
{
	struct cpuidle_governor *gov;

	list_for_each_entry(gov, &cpuidle_governors, governor_list)
		if (!strncasecmp(str, gov->name, CPUIDLE_NAME_LEN))
			return gov;

	return NULL;
}

/**
 * cpuidle_switch_governor - changes the governor
 * @gov: the new target governor
 * Must be called with cpuidle_lock acquired.
 */
int cpuidle_switch_governor(struct cpuidle_governor *gov)
{
	struct cpuidle_device *dev;

	if (!gov)
		return -EINVAL;

	if (gov == cpuidle_curr_governor)
		return 0;

	cpuidle_uninstall_idle_handler();

	if (cpuidle_curr_governor) {
		list_for_each_entry(dev, &cpuidle_detected_devices, device_list)
			cpuidle_disable_device(dev);
	}

	cpuidle_curr_governor = gov;

	if (gov) {
		list_for_each_entry(dev, &cpuidle_detected_devices, device_list)
			cpuidle_enable_device(dev);
		cpuidle_install_idle_handler();
		printk(KERN_INFO "cpuidle: using governor %s\n", gov->name);
	}

	return 0;
}

/**
 * cpuidle_register_governor - registers a governor
 * @gov: the governor
 */
int cpuidle_register_governor(struct cpuidle_governor *gov)
{
	int ret = -EEXIST;

	if (!gov || !gov->select)
		return -EINVAL;

	if (cpuidle_disabled())
		return -ENODEV;

	mutex_lock(&cpuidle_lock);
	if (__cpuidle_find_governor(gov->name) == NULL) {
		ret = 0;
		list_add_tail(&gov->governor_list, &cpuidle_governors);
		if (!cpuidle_curr_governor ||
		    cpuidle_curr_governor->rating < gov->rating)
			cpuidle_switch_governor(gov);
	}
	mutex_unlock(&cpuidle_lock);

	return ret;
}

/**
 * cpuidle_governor_latency_req - Compute a latency constraint for CPU
 * @cpu: Target CPU
 */
int cpuidle_governor_latency_req(unsigned int cpu)
{
	int global_req = pm_qos_request(PM_QOS_CPU_DMA_LATENCY);
	struct device *device = get_cpu_device(cpu);
	int device_req = dev_pm_qos_raw_read_value(device);

	/*
	 * This helper comes from a kernel that carries the device resume
	 * latency PM QoS rework, where an unconstrained device reports
	 * PM_QOS_RESUME_LATENCY_NO_CONSTRAINT.  Here that rework is not
	 * present (commit 0cc2b4e5a020 was reverted by commit d5919dcc349d),
	 * so PM_QOS_RESUME_LATENCY_DEFAULT_VALUE is 0 and a value of 0 means
	 * "no restriction" rather than "no latency tolerated at all".  Taking
	 * it literally clamps the constraint to 0 for every CPU and pins the
	 * governor to the shallowest idle state.  Handle it the same way
	 * menu_select() does.
	 */
	if (!device_req)
		return global_req;

	return device_req < global_req ? device_req : global_req;
}
