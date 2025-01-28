import time
import BigBertha.pyperclip as pyperclip

def read_lines_from_file(file, num_lines):
    lines = []
    for _ in range(num_lines):
        line = file.read_line()
        if not line:
            break
        lines.append(line)
    return lines

def copy_lines_to_clipboard(lines):
    text = ''.join(lines)
    text = text + '" >> newFile'
    pyperclip.copy('echo "' +  text)

def main():
    filename = '/usr/bin/strace'  # Replace with your file name
    num_lines = 500
    interval = 5  # seconds

    i = 0
    with open(filename, 'r') as file:
        while True:
            lines = read_lines_from_file(file, num_lines)
            if not lines:
                break
            copy_lines_to_clipboard(lines)
            print("Chunk " + str(i))
            time.sleep(interval)
            i = i + 1

if __name__ == '__main__':
    main()