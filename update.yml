---
- name: Upgrade packages and manage reboots
  hosts: all
  become: true

  tasks:
    - name: Install common dependencies (if needed - RedHat based)
      ansible.builtin.package:
        name:
          - dnf-utils
        state: latest
      when: ansible_facts['os_family'] == 'RedHat'

    - name: Install common dependencies (if needed - Debian based)
      ansible.builtin.package:
        name:
          - apt-utils
        state: latest
      when: ansible_facts['os_family'] == 'Debian'

    - name: Update all packages
      ansible.builtin.package:
        name: "*"
        state: latest
        update_cache: yes

    - name: Remove unused packages and kernels
      ansible.builtin.package:
        autoremove: yes

    - name: Check if a reboot is required
      ansible.builtin.stat:
        path: /var/run/reboot-required
      register: reboot_required_file

    - name: Reboot if required
      reboot:
        msg: "Reboot initiated by Ansible for updates"
        connect_timeout: 5
        reboot_timeout: 300
        pre_reboot_delay: 0
        post_reboot_delay: 30
        test_command: uptime
      when: reboot_required_file.stat.exists