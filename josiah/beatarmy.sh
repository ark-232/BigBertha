#!/bin/bash

# Block army's implant
touch /tmp/.lock
chmod 000 /tmp/.lock
chattr +i /tmp/.lock

# Undo suid bits
chmod -s g-s /usr/bin/vim /usr/bin/vi /usr/bin/nano /bin/ed

# Remove army's ssh key
sed -i '?ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDf+adep5YH3IcKGkkj9IbFn1Ua1S20hKCF+fULaI5cXahITxdh89URSpQ0sMtDolL+VMVzsayq/RCeJT032RicXGLq7wKDXt6eXfyY/fjvph21t014X41whzYz+U8m1wZb/96o09xqkG2rUfACKn0iOK9ukhTFy7/H7vkRpoA8NVEzrcKUZ/x5vzh3fX8nJwHqhfYjd8BLAwuGupWpipFiUMtPWwATgVLv9qQWSXPp4TtK1URCR0aHo7/4MW15OQ4WeU1xZOltaRBMQMigPnUHZNgv8iRgoIPpDBnAgX4SswMggwQNTUIR3fNT9CDxv78VEUGO9GpaLny2EdlXF+xdMngRZHFNias7TaxjeUoydj2sFIK14HAgchT2XdkEObw9/g/vMFfEz7/j/7aFi9QOO5amZ5q2Oqw8H6YX9oYL8aQqVDv4cL3rFzLDTfzWL+Fft32OfFOJPoBtpvrSzyvvZMFNsgdsT5m1w18D1tb4dqt95RuinZ3l/h+m5WHMRWJU3WS1qhVcHeCy9jNIXp/Hf066ZOvYXwpTzkc4/FwCHag4fK4ZcmzJG4Hg8iyRLQEHlDF37epq7IdrN7Y3Q+bYeWQ25KBzSBjjMfjwwi6qE2rfhSnMeSK3mqECWjB/sBpttZn7GDHgbtKzhJKKcLae4tJkiORmdYV10HSkMpOjgw== justin@box1?d' /root/.ssh/authorized_keys

# Lock authorized_keys
chattr +i /root/.ssh/authorized_keys

# Clean up extra users
deluser systemd-timesyncd
deluser _backup
deluser rsync
deluser dhcp
