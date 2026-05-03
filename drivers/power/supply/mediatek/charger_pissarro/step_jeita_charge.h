/* SPDX-License-Identifier: GPL-2.0 */
/*
 * step/jeita charge controller
 *
 * published by the Free Software Foundation.
 *
 * THIS PACKAGE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 * WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

/*	date			author			comment
 *	2021-06-01		chenyichun@xiaomi.com	create
 */

#ifndef __STEP_JEITA_CHARGE_H
#define __STEP_JEITA_CHARGE_H

#define STEP_JEITA_TUPLE_COUNT	6
#define THERMAL_LIMIT_COUNT	16
#define THERMAL_LIMIT_TUPLE	6

#define FCC_DESCENT_DELAY	350
#define JEITA_FCC_DESCENT_STEP	250
#define SW_CV_COUNT		3

#define TYPEC_BURN_TEMP		750
#define TYPEC_BURN_HYST		100

#define MAX_THERMAL_FCC		12400
#define MIN_THERMAL_FCC		200

struct step_jeita_cfg0 {
	int low_threshold;
	int high_threshold;
	int value;
};

struct step_jeita_cfg1 {
	int low_threshold;
	int high_threshold;
	int extra_threshold;
	int low_value;
	int high_value;
};

enum cycle_count_status {
	CYCLE_COUNT_0_100,
	CYCLE_COUNT_101_600,
	CYCLE_COUNT_601_800,
	CYCLE_COUNT_801_9999,
};

void reset_mi_charge_alg(struct charger_manager *info);
int step_jeita_init(struct charger_manager *info, struct device *dev, int product_name);

#endif /* __STEP_JEITA_CHARGE_H */