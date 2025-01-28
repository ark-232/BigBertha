import socket
import base64
import requests

PORT = 9001
XOR_KEY = "bobbyb"
url = "http://localhost:9000"

# Create a UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(("", PORT))

print(f"Server listening on port {PORT}")

while True:
    # Receive message from client
    data, client_addr = sock.recvfrom(1024)
    print("Received message:", data.decode())

    # Decrypt the received message
    decrypted_data = bytes([char ^ ord(XOR_KEY[i % len(XOR_KEY)]) for i, char in enumerate(data)])

    # Decode the decrypted data
    decrypted_data = base64.b64decode(decrypted_data)

    # Process the decrypted data
    print("Decrypted message:", decrypted_data.decode())


    # curl_command = f"curl -X POST -d '{decrypted_data.decode()}' {url}"
    # os.system(curl_command)
sock.close()
