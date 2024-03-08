#!/usr/bin/python3

def update_needrestart_config():
    config_file_path = "/etc/needrestart/needrestart.conf"
    new_line = "$nrconf{restart} = 'a';\n"

    try:
        # Read existing config contents
        with open(config_file_path, "r") as file:
            lines = file.readlines()

        # Find and replace the line
        for i, line in enumerate(lines):
            if line.startswith("#$nrconf{restart}"):
                lines[i] = new_line
                break

        # Write the modified content back to the file (requires root privileges)
        with open(config_file_path, "w") as file:
            file.writelines(lines)

    except (IOError, PermissionError) as e:
        print(f"Error modifying config file: {e}")

# Call the function to execute the change
update_needrestart_config()
