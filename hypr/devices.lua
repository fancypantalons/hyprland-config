-- Device-specific configurations
-- Based on UserConfigs/Laptops.conf

local devices = {}

-- ============================================
-- CONSTANTS
-- ============================================

-- Laptop touchpad device identifier
devices.TOUCHPAD_DEVICE = "asue1209:00-04f3:319f-touchpad"

-- ============================================
-- DEVICE CONFIGURATION
-- ============================================

-- Touchpad device configuration
hl.device({
  name = devices.TOUCHPAD_DEVICE,
  enabled = true
})

return devices
