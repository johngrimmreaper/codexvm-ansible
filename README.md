# Codex VM Ansible

Ansible project for creating and maintaining an isolated Ubuntu VM for OpenAI Codex CLI work.

The goal is to keep Codex work inside a dedicated virtual machine instead of giving Codex direct access to the user's personal workstation environment.

## Current release

Latest milestones:

- `v0.1.0` — first working Ubuntu 24.04.4 netboot-based Codex VM
- `v0.1.1` — passwordless sudo and clean guest automation
- `v0.1.2` — host-only Samba/SCP file sharing workflow

## What this project builds

The playbook creates or reuses a libvirt VM named `codexvm`.

Current VM design:

- Ubuntu 24.04.4
- legacy BIOS / MBR boot
- raw LVM-backed disk
- 70 GiB disk
- 8 GiB swap partition
- ext4 root partition
- headless serial console
- static/reserved VM address: `192.168.122.60`
- dedicated user: `codex`
- project workspace: `/home/codex/Projects`

## Installation method

The VM is installed through Ubuntu netboot plus autoinstall.

The host stores the small Ubuntu netboot tarball under libvirt boot storage instead of keeping a full live-server ISO locally.

The installer kernel receives a live-server ISO URL and downloads the live environment during installation.

Important generated installer artifacts live under:

```text
/var/lib/libvirt/boot/
```

The NoCloud autoinstall seed is also generated under libvirt boot storage so QEMU can read it without permission problems.

## What gets installed inside the VM

The VM is configured as a practical Codex work environment.

Installed/configured inside the VM:

- OpenSSH server
- Vim
- Nano
- Alpine Pico
- Midnight Commander
- Git
- Git LFS
- baseline command-line development tools
- OpenAI Codex CLI
- UFW firewall
- unattended upgrades
- host-only Samba file sharing

Codex CLI is installed for the `codex` user and exposed system-wide through:

```text
/usr/local/bin/codex -> /home/codex/.local/bin/codex
```

## Security model

The VM is intentionally isolated from the host.

Network access is restricted with UFW.

Allowed inbound access:

```text
22/tcp   from 192.168.122.1
445/tcp  from 192.168.122.1
```

That means SSH/SCP/SFTP and Samba are reachable only from the libvirt host.

The `codex` user has passwordless sudo because this VM is an automation environment.

## SSH, SCP, and SFTP

SSH access:

```bash
ssh codexvm
```

Copy a file into the VM:

```bash
scp file.txt codexvm:~/Projects/
```

Copy a directory into the VM:

```bash
scp -r my-project/ codexvm:~/Projects/
```

Copy a file back from the VM:

```bash
scp codexvm:~/Projects/file.txt .
```

SFTP also works through OpenSSH:

```bash
sftp codexvm
```

## Samba file sharing

Samba exposes the Codex project workspace to the libvirt host only.

Share:

```text
//192.168.122.60/CodexProjects
```

Guest write access is enabled, but Samba forces filesystem writes to the Linux user `codex`.

The Samba server is minimal:

- no printer shares
- no `print$`
- NetBIOS disabled
- SMB port 445 only
- access restricted to `192.168.122.1`

List shares from the host:

```bash
smbclient -L //192.168.122.60 -N -m SMB3
```

Mount the share from the host:

```bash
mkdir -p ~/mnt/codexvm-projects

sudo mount -t cifs //192.168.122.60/CodexProjects ~/mnt/codexvm-projects \
  -o guest,uid=$(id -u),gid=$(id -g),vers=3.0
```

Unmount:

```bash
sudo umount ~/mnt/codexvm-projects
```

## Fresh VM creation

Example fresh install using an LVM-backed disk:

```bash
cd ~/Projects/codexvm-ansible

ANSIBLE_FORCE_COLOR=1 ansible-playbook -K -i inventory.ini site.yml \
  -e '{"vm_disk_backend":"lvm","vm_lvm_path":"/dev/vg_workstation02/lv_codex","vm_disk_size_gb":70,"vm_force_recreate":true}' \
  -e "codex_password_crypted=$HASH" \
  -e "codex_ssh_pubkey_path=$HOME/.ssh/id_ansible_ed25519.pub" \
  -vv
```

The `-K` option is needed for host-side sudo operations such as libvirt/LVM/installer artifact setup.

## Re-run provisioning on an existing VM

After the VM exists and passwordless sudo has been configured inside it, guest provisioning can be rerun without `-K`:

```bash
cd ~/Projects/codexvm-ansible

ANSIBLE_FORCE_COLOR=1 ansible-playbook -i inventory.ini site.yml \
  --limit codexvm \
  -e "codex_ssh_pubkey_path=$HOME/.ssh/id_ansible_ed25519.pub" \
  -vv
```

A clean run should finish with:

```text
changed=0
failed=0
```

## Codex login

Log into the VM:

```bash
ssh codexvm
```

Then authenticate Codex CLI:

```bash
codex login --device-auth
```

## Important variables

Most defaults live in:

```text
group_vars/all.yml
```

Important variables include:

```yaml
vm_name: codexvm
vm_disk_size_gb: 70
codex_user: codex
codex_projects_dir: /home/codex/Projects
codex_passwordless_sudo: true
codex_enable_samba_share: true
codex_samba_share_name: CodexProjects
codex_samba_allow_from: 192.168.122.1
```

## File sharing design

There are two supported file movement paths:

1. SSH-based transfer:
   - `scp`
   - `sftp`

2. Host-only Samba:
   - useful for mounting `/home/codex/Projects` directly on the host
   - restricted to the libvirt host
   - guest writable
   - forced to the `codex` Linux user

## Project policy

Keep this project focused.

This playbook should remain a Codex VM builder and provisioner.

Avoid adding:

- host helper scripts
- Makefile targets
- desktop environments
- broad workstation personalization
- unrelated services
- unrelated development stacks
