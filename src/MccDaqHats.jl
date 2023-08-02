module MccDaqHats

# from daqhats.jl
# constants 
export HAT_ID_ANY, HAT_ID_MCC_118, HAT_ID_MCC_118_BOOTLOADER
export HAT_ID_MCC_128, HAT_ID_MCC_134, HAT_ID_MCC_152, HAT_ID_MCC_172
export hat_list, hat_list_count, hat_error_message
export HatIDs, ResultCode, HatInfo, HatInfoTemp, TriggerMode

# from daqhats_utils.jl
export select_hat_device, enum_mask_to_string, chan_list_to_mask, validate_channels

# from mcc172_utils.jl
export deinterleave, wait_for_trigger

# from mcc172.jl
#Constants
export TRIG_RISING_EDGE, TRIG_FALLING_EDGE, TRIG_ACTIVE_HIGH, TRIG_ACTIVE_LOW
export SOURCE_LOCAL, SOURCE_MASTER, SOURCE_SLAVE
export OPTS_DEFAULT, OPTS_NOSCALEDATA, OPTS_NOCALIBRATEDATA, OPTS_EXTCLOCK, OPTS_EXTTRIGGER, OPTS_CONTINUOUS
#functions
export mcc172_status_decode
export mcc172_open, mcc172_close, mcc172_is_open, mcc172_info, mcc172_blink_led
export mcc172_firmware_version, mcc172_serial
export mcc172_calibration_date, mcc172_calibration_coefficient_read, mcc172_calibration_coefficient_write
export mcc172_iepe_config_read, mcc172_iepe_config_write
export mcc172_a_in_sensitivity_read, mcc172_a_in_sensitivity_write
export mcc172_a_in_clock_config_read, mcc172_a_in_clock_config_write
export mcc172_trigger_config
export mcc172_a_in_scan_start, mcc172_a_in_scan_buffer_size, mcc172_a_in_scan_status
export mcc172_a_in_scan_read, mcc172_a_in_scan_channel_count
export mcc172_a_in_scan_stop, mcc172_a_in_scan_cleanup

# from trigger.jl
export trigger

include("daqhats_utils.jl")     # general daqhats commands
include("daqhats.jl")           # general daqhats commands
include("mcc172.jl")            # MCC172 commands
include("mcc172_utils.jl")
include("trigger.jl")           # trigger source for synchronous scans on MCC172

# The remainder of the hat files have been converted to Julia by Clang, now need manual editing

end # module