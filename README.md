# CodexVM Ansible project

This project builds a headless, isolated Ubuntu 24.04.4 LTS virtual machine for OpenAI Codex CLI work.

## Designed disk geometry

The guest uses legacy BIOS/SeaBIOS and an MSDOS/MBR partition table:

- `/dev/vda1`: fixed 8 GiB Linux swap
- `/dev/vda2`: ext4 `/`, using all remaining disk space

The root partition is last. Expanding the virtual disk therefore creates trailing free space immediately after `/dev/vda2`, allowing `growpart /dev/vda 2` followed by `resize2fs /dev/vda2`.

## Isolation choices

- Headless serial console; no SPICE clipboard or desktop integration
- No virtiofs, 9p, host bind mounts, or shared folders
- NAT through libvirt's `default` network
- SSH key authentication only
- SSH agent forwarding disabled
- Inbound firewall permits SSH only from the libvirt host
- Only repositories listed in `codex_projects` are cloned automatically

The VM isolates host files, but Codex still sends relevant prompts and project context to OpenAI. Only place approved project material in this VM.

## Host prerequisites

The playbook installs the KVM/libvirt tools it needs. Before running it:

1. Put the Ubuntu Server ISO at:

   `/var/lib/libvirt/boot/ubuntu-24.04.4-live-server-amd64.iso`

2. Ensure the public key configured by `codex_ssh_pubkey_path` exists.
3. Check that `192.168.122.60` is unused on the libvirt `default` network.
4. Review `group_vars/all.yml`.

The default disk is a sparse qcow2 image at `/var/lib/libvirt/images/codexvm.qcow2`. To use a raw LVM volume, set `vm_disk_backend: lvm` and create `/dev/vg_virtualmachines/codexvm` at 70 GiB first.

## Install

```bash
cd codexvm-ansible
./scripts/run-install.sh -vv
```

The script asks for the VM account password, generates a SHA-512 password hash, passes only the hash through a temporary mode-0600 variables file, and deletes that file afterward.

Watch the installer when needed:

```bash
sudo virsh console CodexVM
```

Exit the serial console with `Ctrl+]`.

## First Codex login

```bash
ssh codex@192.168.122.60
codex login --device-auth
cd ~/Projects
codex
```

The device-code flow lets you complete authentication in the browser on the host without installing a browser in the VM.

## Add specific projects

Edit `codex_projects` in `group_vars/all.yml`. Example:

```yaml
codex_projects:
  - name: xscreensaver
    repo: git@github.com:johngrimmreaper/xscreensaver.git
    version: feature/mystify
    dest: /home/codex/Projects/xscreensaver
```

Use a VM-specific GitHub key or token. Do not forward the host SSH agent into the VM.

## Maintenance

```bash
ansible-playbook -i inventory.ini maintain.yml -vv
```

This applies Ubuntu updates, upgrades Codex CLI by rerunning OpenAI's official standalone installer, and updates only repositories explicitly listed in `codex_projects`.

## Grow from 70 GiB to 100 GiB

Review `new_disk_size_gb` in `grow-disk.yml`, then run:

```bash
ansible-playbook -i inventory.ini grow-disk.yml -e new_disk_size_gb=100 -vv
```

After a successful growth, update `vm_disk_size_gb` in `group_vars/all.yml` to the new value.

## Recreate intentionally

Set `vm_force_recreate: true` only when you intend to destroy and reinstall the VM. For the qcow2 backend, this also deletes the old VM disk.
