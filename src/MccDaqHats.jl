module MccDaqHats

# from daqhats.jl
export hat_list

# from daqhats_utils.jl
export select_hat_device, enum_mask_to_string, chan_list_to_mask, validate_channels

# from daqhats172.jl
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

# from daqhats172_utils.jl
export mcc172_status_decode

include("daqhats.jl")           # general daqhats commands
include("daqhats_utils.jl")     # general daqhats commands
include("daqhats172.jl")        # MCC172 commands
include("daqhats172_utils.jl")  # MCC172 commands

end
