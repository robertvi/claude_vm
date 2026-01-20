This repo is to develop code to create a VM to run claude code inside of.
It only needs CLI no graphical output.
GPU passthrough is probably a future add on as it seems quite complex.
Maybe a podman container would be just as good as a VM?
Key things:
- allow running claude without any verification before bash commands are run
- use tinyproxy to limit network connections to minimum required to run claude
- vm os updated runs while claude is not running by putting tinyproxy into permissive mode temporarily
- access via ssh into cli claude code
- shared folder allows using large storage of host but only in the intended folder
