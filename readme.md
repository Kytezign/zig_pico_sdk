# Overview 
The goal here is mostly for me to have a reference for setting up the pico sdk build environment with zig.  
If it helps other people, I'll be happy but it's not necessarily the goal - I'm far from an expert. 
I'm not sure on the limitations of this method yet either but there probably are some.
All that being said the general Idea is that a main .h file will include the needed API references from the pico_sdk.  Then that would get translated into a module that can be imported in the implementation code.   Additionally, there are convenience functions for automating cmake calls as part of the zig build flow.  It also can create a picotool load step to automatically load the generated file into the device.
See this USB KVM project for a more complicated usage example: https://github.com/Kytezign/USBKVM
# Usage
Import pico_build.zig into a build.zig script.  Then use the provided functions to setup a zig/ pico-sdk build flow.  
It should also work for autocomplete with zls but it's been a little fickle so your mileage may vary. 
See comments in example for more details around usage or ask and I'm happy to try to help. 

# Other Setup notes (Arch based)
## Install build tools for Archlinux

	`sudo pacman -Syu git cmake arm-none-eabi-binutils usbutils`
	`sudo pacman -Syu arm-none-eabi-gcc arm-none-eabi-newlib arm-none-eabi-gdb`

### cdc device communication	
USB Utils is apparently required to enable ttyusb devices but I'm not 100% sure how that works.  Just make sure they show up and you are in the right group uucp for Arch 2024.  Reboot after adding the user to the group
## Clone SDK Repo
Get/generate personal access token from github to clone
`git clone https://github.com/raspberrypi/pico-sdk`

Add the sdk path to env PICO_SDK_PATH
Done using Systemd environment var controls (as an example): 
`~/.config/environment.d/66-env.conf`
```
PICO_SDK_PATH=$HOME/path_to_sdk
PATH=$HOME/path_to_picotool_binary:$PATH
```
Reference: https://wiki.archlinux.org/title/Systemd/User#Environment_variables
## picotool (for load step)
Picotool must be available in the path.  (can be built locally - see env above to add to path). 
https://github.com/raspberrypi/picotool
Arch specific udev rules (2024) verify before running...: 
	`sudo cp udev/99-picotool.rules /etc/udev/rules.d/99-picotool.rules`
Reference: https://wiki.archlinux.org/title/Udev

## Other References
- https://github.com/nemuibanila/zig-pico-cmake
- https://zig.news/anders/run-zig-code-on-raspberry-pico-w-1oag

# Potential next steps
- Build with zig cc.
	- https://dev.to/hamishmilne/zig-cmake-4pmc
	- https://github.com/ziglang/zig/issues/7342
- Or just link with zig?
- Can we add documentation to the zig translation?
	- Thinking just copy the previous c comment as a /// comment in zig could work well enough
	- Might be best to update this in translate-c directly
- Optimization exploration
	- Link level optimization
	- Controlling compiling in non-debug mode in both zig and cmake