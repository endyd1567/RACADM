import os
import sys

# Parse the provided logs to extract the "Message" values and compare them.

def extract_messages_with_metadata(file_path):
    """Extracts 'Message' along with 'Severity' and 'Timestamp' values from a log file."""
    messages = set()
    metadata = {}
    with open(file_path, 'r', encoding='utf-8') as file:
        current_message = None
        current_severity = None
        current_timestamp = None
        for line in file:
            if line.strip().startswith("Message  "):
                key, value = line.split("=", 1)
                current_message = value.strip()
            elif line.strip().startswith("Severity"):
                key, value = line.split("=", 1)
                current_severity = value.strip()
            elif line.strip().startswith("Timestamp"):
                key, value = line.split("=", 1)
                current_timestamp = value.strip()

            if current_message:
                messages.add(current_message)
                metadata[current_message] = {
                    "Severity": current_severity,
                    "Timestamp": current_timestamp
                }
                current_message = None
                current_severity = None
                current_timestamp = None
    return messages, metadata

def find_logs_by_ip(directory1, directory2):
    """Finds and pairs logs by IP addresses between two directories."""
    logs_by_ip = {}
    for directory, index in zip([directory1, directory2], [0, 1]):
        for root, _, files in os.walk(directory):
            for file in files:
                if file.endswith(".log"):
                    ip = file.split("_")[0]  # Assuming IP is the first part of the filename
                    logs_by_ip.setdefault(ip, [None, None])[index] = os.path.join(root, file)
    return logs_by_ip

def process_logs(directory1_path, directory2_path):
    logs_by_ip = find_logs_by_ip(directory1_path, directory2_path)
    output_lines = []

    for ip, log_files in logs_by_ip.items():
        if not all(log_files):
            continue

        last_log_path, recent_log_path = log_files
        last_log_messages, last_log_metadata = extract_messages_with_metadata(last_log_path)
        recent_log_messages, recent_log_metadata = extract_messages_with_metadata(recent_log_path)

        new_messages = recent_log_messages - last_log_messages
        overlapping_messages = recent_log_messages & last_log_messages

        def format_messages(messages, metadata):
            sorted_messages = sorted(messages, key=lambda m: metadata[m]['Timestamp'], reverse=True)
            return "\n".join([
                f"{metadata[message]['Timestamp']} {metadata[message]['Severity']}: {message}"
                for message in sorted_messages
            ])

        output_lines.extend([
            f"\n\n-----------------------------------New Log Messages for {ip}-----------------------------------------", 
            "\n[New Warnings]", format_messages(
                [m for m in new_messages if recent_log_metadata[m]['Severity'] == 'Warning'], recent_log_metadata
            ),
            "\n[New Criticals]", format_messages(
                [m for m in new_messages if recent_log_metadata[m]['Severity'] == 'Critical'], recent_log_metadata
            ),
            f"\n\n-----------------------------------Last Log Messages for {ip}----------------------------------------",
            "\n[Last Warnings]", format_messages(
                [m for m in overlapping_messages if recent_log_metadata[m]['Severity'] == 'Warning'], recent_log_metadata
            ),
            "\n[Last Criticals]", format_messages(
                [m for m in overlapping_messages if recent_log_metadata[m]['Severity'] == 'Critical'], recent_log_metadata
            )
        ])

    return "\n".join(output_lines)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python new_log_filter.py <Last_directory_path> <New_directory_path>")
        print("Example: python new_log_filter.py 20241101 20241201")
        sys.exit(1)

    directory1_path, directory2_path = sys.argv[1], sys.argv[2]
    save_output = input("Do you want to save the output messages to a file? (y/n): ").strip().lower() in ["y", "yes"]

    result = process_logs(directory1_path, directory2_path)
    print(result)

    if save_output:
        output_file_path = os.path.join(directory2_path, "new_messages_output.txt")
        with open(output_file_path, 'w', encoding='utf-8') as output_file:
            output_file.write(result)
        print(f"Output saved to {output_file_path}")
