# container-manifest
A cli app i created to help build distrobox containers using yaml files as i found distrobox-assemble to be insufficient.

Most values used in this program should also work with other container manager as long as the sh calls to distrobox are altered to whatever you choose to call instead like toolbx.

# Deps
- bash
- yq
- distrobox
- podman

# Doc
- [how to write manifest file](./doc/manifest-structure.md)
- [how to use manifest.sh](./doc/usage.md)

# Why
i found distrobox-assemble command to be lacking for my needs and made this. Distrobox-assemble uses ini files which down allow me to write and place files inside just a single file which made the setup less desirable for me but also there were no options to perform container home setup before the container was even created, ive also had some issues with --init-hooks and --pre-init-hooks creating files not as user but as current run id which caused some issues it also lead to my host home getting polluted so ive created this. I dont plan on maintaining this any further and will most likely put it on archive as soon as it works reliably, modifications changes or whatever you wish to do to this tool is more than welcome you can fork off and maintain it yourself if you wish to do so.