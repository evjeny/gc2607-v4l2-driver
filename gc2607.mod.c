#include <linux/module.h>
#include <linux/export-internal.h>
#include <linux/compiler.h>

MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};



static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0xd8b288f3, "clk_enable" },
	{ 0x33d0c686, "clk_unprepare" },
	{ 0x876af9d1, "i2c_del_driver" },
	{ 0x33d0c686, "clk_disable" },
	{ 0xe4de56b4, "__ubsan_handle_load_invalid_value" },
	{ 0xd6cb9fcd, "v4l2_async_unregister_subdev" },
	{ 0x8864d17b, "v4l2_ctrl_handler_free" },
	{ 0x9b95ee6a, "__pm_runtime_disable" },
	{ 0x41fccad9, "__pm_runtime_set_status" },
	{ 0xbd03ed67, "__ref_stack_chk_guard" },
	{ 0x3b675296, "i2c_transfer" },
	{ 0xd272d446, "__stack_chk_fail" },
	{ 0xa28d1cf7, "devm_kmalloc" },
	{ 0x92b017c0, "devm_regulator_bulk_get" },
	{ 0x73eba06a, "devm_gpiod_get_optional" },
	{ 0x3504ca61, "devm_clk_get_optional" },
	{ 0xa0928e7c, "clk_get_rate" },
	{ 0x0fd72716, "v4l2_i2c_subdev_init" },
	{ 0x4f4e08ea, "media_entity_pads_init" },
	{ 0xf1bf057d, "v4l2_ctrl_handler_init_class" },
	{ 0x3c273f3c, "v4l2_ctrl_new_int_menu" },
	{ 0xd1930daf, "v4l2_ctrl_new_std" },
	{ 0xb0956fd2, "pm_runtime_enable" },
	{ 0x1cdf42a8, "__pm_runtime_idle" },
	{ 0x1cdf42a8, "__pm_runtime_resume" },
	{ 0xf6a0e5c7, "__v4l2_async_register_subdev" },
	{ 0x978f8d4b, "_dev_warn" },
	{ 0x5ccc5612, "i2c_transfer_buffer_flags" },
	{ 0x8864d17b, "__v4l2_ctrl_handler_setup" },
	{ 0xb2d2cf69, "pm_runtime_get_if_in_use" },
	{ 0x90a48d82, "__ubsan_handle_out_of_bounds" },
	{ 0xd272d446, "__fentry__" },
	{ 0xd272d446, "__x86_return_thunk" },
	{ 0x12fa36a3, "i2c_register_driver" },
	{ 0x978f8d4b, "_dev_info" },
	{ 0x8e1f9219, "regulator_bulk_enable" },
	{ 0x0feb1e94, "usleep_range_state" },
	{ 0xd8b288f3, "clk_prepare" },
	{ 0x978f8d4b, "_dev_err" },
	{ 0x8e1f9219, "regulator_bulk_disable" },
	{ 0x48e624a2, "__dynamic_dev_dbg" },
	{ 0x9f7d21ca, "gpiod_set_value_cansleep" },
	{ 0x67628f51, "msleep" },
	{ 0x0fd7a18e, "module_layout" },
};

static const u32 ____version_ext_crcs[]
__used __section("__version_ext_crcs") = {
	0xd8b288f3,
	0x33d0c686,
	0x876af9d1,
	0x33d0c686,
	0xe4de56b4,
	0xd6cb9fcd,
	0x8864d17b,
	0x9b95ee6a,
	0x41fccad9,
	0xbd03ed67,
	0x3b675296,
	0xd272d446,
	0xa28d1cf7,
	0x92b017c0,
	0x73eba06a,
	0x3504ca61,
	0xa0928e7c,
	0x0fd72716,
	0x4f4e08ea,
	0xf1bf057d,
	0x3c273f3c,
	0xd1930daf,
	0xb0956fd2,
	0x1cdf42a8,
	0x1cdf42a8,
	0xf6a0e5c7,
	0x978f8d4b,
	0x5ccc5612,
	0x8864d17b,
	0xb2d2cf69,
	0x90a48d82,
	0xd272d446,
	0xd272d446,
	0x12fa36a3,
	0x978f8d4b,
	0x8e1f9219,
	0x0feb1e94,
	0xd8b288f3,
	0x978f8d4b,
	0x8e1f9219,
	0x48e624a2,
	0x9f7d21ca,
	0x67628f51,
	0x0fd7a18e,
};
static const char ____version_ext_names[]
__used __section("__version_ext_names") =
	"clk_enable\0"
	"clk_unprepare\0"
	"i2c_del_driver\0"
	"clk_disable\0"
	"__ubsan_handle_load_invalid_value\0"
	"v4l2_async_unregister_subdev\0"
	"v4l2_ctrl_handler_free\0"
	"__pm_runtime_disable\0"
	"__pm_runtime_set_status\0"
	"__ref_stack_chk_guard\0"
	"i2c_transfer\0"
	"__stack_chk_fail\0"
	"devm_kmalloc\0"
	"devm_regulator_bulk_get\0"
	"devm_gpiod_get_optional\0"
	"devm_clk_get_optional\0"
	"clk_get_rate\0"
	"v4l2_i2c_subdev_init\0"
	"media_entity_pads_init\0"
	"v4l2_ctrl_handler_init_class\0"
	"v4l2_ctrl_new_int_menu\0"
	"v4l2_ctrl_new_std\0"
	"pm_runtime_enable\0"
	"__pm_runtime_idle\0"
	"__pm_runtime_resume\0"
	"__v4l2_async_register_subdev\0"
	"_dev_warn\0"
	"i2c_transfer_buffer_flags\0"
	"__v4l2_ctrl_handler_setup\0"
	"pm_runtime_get_if_in_use\0"
	"__ubsan_handle_out_of_bounds\0"
	"__fentry__\0"
	"__x86_return_thunk\0"
	"i2c_register_driver\0"
	"_dev_info\0"
	"regulator_bulk_enable\0"
	"usleep_range_state\0"
	"clk_prepare\0"
	"_dev_err\0"
	"regulator_bulk_disable\0"
	"__dynamic_dev_dbg\0"
	"gpiod_set_value_cansleep\0"
	"msleep\0"
	"module_layout\0"
;

MODULE_INFO(depends, "v4l2-async,videodev,mc");

MODULE_ALIAS("i2c:gc2607");
MODULE_ALIAS("acpi*:GCTI2607:*");

MODULE_INFO(srcversion, "FE094A8473AEA6F5F7555BD");
