"""Publish a test MQTT message to the local broker used by Homegenie.

Run with the project's venv Python so requirements (paho-mqtt) are available.
"""
import time
import json
import sys
try:
    import paho.mqtt.publish as publish
except Exception as exc:
    print('paho-mqtt not installed:', exc)
    raise

topic = 'home/light/living_room/state'
payload = {
    'state': 'on',
    'brightness': 80,
    'timestamp': time.strftime('%Y-%m-%dT%H:%M:%S')
}

print('Publishing to', topic)
publish.single(topic, json.dumps(payload), hostname='localhost', port=1883)
print('Published payload:', json.dumps(payload))
