const hal = @import("pico_sdk");

// Blinky example
// The sdk zig module is not perfect but it's pretty good...
const LED_PIN = 25;

export fn main() void {
    hal.gpio_init(LED_PIN);
    hal.gpio_set_dir(LED_PIN, true);
    while (true) {
        hal.gpio_put(LED_PIN, !hal.gpio_get(LED_PIN));
        hal.sleep_ms(500);
    }
}
