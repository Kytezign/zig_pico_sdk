# Overview
The goal here is mostly for me to have a reference for setting up the pico sdk build environment with zig.  
If it helps other people, I'll be happy but it's not necessarily the goal - I'm far from an expert. 
I'm not sure on the limitations of this method yet either but there probably are some.
All that being said please reach out with questions.
# Usage
The general idea is that we have a main header file relevant to the project that only includes the pico_sdk headers we are planning to use.   Those get translated into a zig module that can be imported as needed.  From what I can tell everything in the pico sdk compiles into a library or something hidden in the cmake stuff. 
Zig code compiles into a library file which is linked to the cmake output by cmake.  Zig implements main.
# Setup notes (Arch based)
## Install build tools for Archlinux

	`sudo pacman -Syu git cmake arm-none-eabi-binutils usbutils`
	`sudo pacman -Syu arm-none-eabi-gcc arm-none-eabi-newlib arm-none-eabi-gdb`
	
USB Utils is required to enable ttyusb devices but I'm not 100% sure how that works.  
Just make sure they show up and you are in the right group uucp for Arch 2024.  Reboot after adding the user to the group
## Clone SDK Repo
Get/generate personal access token from github to clone
`git clone https://github.com/raspberrypi/pico-sdk`

Add the sdk to env PICO_SDK_PATH
Using Systemd environment var system (as an example): 
`~/.config/environment.d/66-env.conf`
```
PICO_SDK_PATH=$HOME/path_to_sdk
PATH=$HOME/path_to_picotool:$PATH
```
Reference: https://wiki.archlinux.org/title/Systemd/User#Environment_variables
## picotool (for load step)
Picotool must be available in the path.  (can build it locally and add it see env above). 
https://github.com/raspberrypi/picotool
Arch specific udev rules (2024) check paths before running...: 
	`sudo cp udev/99-picotool.rules /etc/udev/rules.d/99-picotool.rules`
Reference: https://wiki.archlinux.org/title/Udev

## Other References
- https://github.com/nemuibanila/zig-pico-cmake
- https://zig.news/anders/run-zig-code-on-raspberry-pico-w-1oag

# Potential next steps
- Can we automate PICO_STDIO_USB_ENABLE_RESET_VIA_VENDOR_INTERFACE?
	- I'd like to use tinyusb also so might not work well.
- Build with zig.
	- https://dev.to/hamishmilne/zig-cmake-4pmc
	- https://github.com/ziglang/zig/issues/7342
- Or just link with zig?
- Can we add documentation to the zig translation?
	- Thinking just copy the previous comment as a /// comment in zig
- Optimization exploration
	- Link level optimizations come to mind
	- Also compiling in non-debug mode. 