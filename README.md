# Kria KV260 Smart Camera + See3CAM_CU27 Setup Guide

Your **See3CAM_CU27** is a USB 3.1 UVC camera, so it works as a USB webcam with the KV260 Smart Camera Vision AI application (no special driver needed).

## 1. Find your camera device

After connecting the See3CAM_CU27, list video devices:

```bash
ls -la /dev/video*
v4l2-ctl --list-devices
```

Note the **device number** (e.g. `/dev/video0` → use `0`, `/dev/video2` → use `2`) for the `--usb` option below.

## 2. Install and load Smart Camera firmware

```bash
# Install firmware (if not already installed)
sudo apt update
sudo apt install -y xlnx-firmware-kv260-smartcam

# Disable desktop (monitor may go blank; use SSH/UART to continue)
sudo xmutil desktop_disable

# List apps and load Smart Camera
sudo xmutil listapps
sudo xmutil unloadapp    # if another app is loaded
sudo xmutil loadapp kv260-smartcam
```

## 3. Run Smart Camera with Docker (recommended)

```bash
# Pull the Smart Camera Docker image
docker pull xilinx/smartcam:2022.1

# Run container with device access (replace VIDEO_ID with your device number, e.g. 0 or 2)
docker run --env="DISPLAY" -h "xlnx-docker" --env="XDG_SESSION_TYPE" \
  --net=host --privileged \
  --volume="$HOME/.Xauthority:/root/.Xauthority:rw" \
  -v /tmp:/tmp -v /dev:/dev -v /sys:/sys \
  -v /etc/vart.conf:/etc/vart.conf \
  -v /lib/firmware/xilinx:/lib/firmware/xilinx -v /run:/run \
  -it xilinx/smartcam:2022.1 bash
```

Inside the container:

```bash
# Install Jupyter notebooks (optional, for GUI control)
smartcam-install.py

# Run Smart Camera with USB camera (use your video device ID)
# Display to monitor (DP/HDMI):
smartcam --usb VIDEO_ID -W 1920 -H 1080 -r 30 --target dp

# Or stream via RTSP (then on another PC: ffplay rtsp://KV260_IP:5000/test)
smartcam --usb VIDEO_ID -W 1920 -H 1080 -r 30 --target rtsp
```

**See3CAM_CU27** supports FHD (1920×1080) and up to 60 fps (UYVY) / 100 fps (MJPEG). If 1080p30 fails, try:

```bash
smartcam --usb VIDEO_ID -W 1280 -H 720 -r 30 --target dp
```

## 4. Run without Docker (if app is installed on host)

If the smartcam binary is on the board (e.g. from a full Kria image):

```bash
# From /opt/xilinx/kv260-smartcam/bin/ or PATH
smartcam --usb VIDEO_ID -W 1920 -H 1080 -r 30 --target dp
```

## 5. Re-enable desktop when finished

```bash
sudo xmutil desktop_enable
```

## AI tasks

- **Face detection** (default): `--aitask facedetect`
- **Pedestrian (RefineDet)**: `--aitask refinedet`
- **ADAS / vehicles (SSD)**: `--aitask ssd`

Example with face detection to DisplayPort:

```bash
smartcam --usb 0 -W 1920 -H 1080 -r 30 --target dp --aitask facedetect
```

## HDMI display (RTSP works but monitor is black)

HDMI is supported; the app’s `--target dp` means “display” (DP or HDMI). If RTSP works but the connected HDMI monitor stays black, try the following in order.

### 1. Run smartcam on the host (not in Docker)

Display output often fails from inside Docker. Use the host so DRM/KMS can drive the monitor directly.

```bash
# Exit the Docker container first
exit

# On the host, run smartcam (use your USB device number, e.g. 2)
sudo /opt/xilinx/kv260-smartcam/bin/smartcam --usb 2 -W 1920 -H 1080 -r 30 --target dp
```

If the binary is not at that path, your image may only provide the app inside Docker; then try steps 2–3.

### 2. Single display, connected before boot

- Connect **only** the HDMI monitor (no DisplayPort).
- Power **off** the board, connect HDMI, then power **on** (per AMD docs, monitor should be connected before boot for proper detection).

### 3. Force the HDMI connector (if step 1 still shows black)

The app uses `kmssink` without a connector ID, so it may pick the wrong output. Find the HDMI connector and test it:

```bash
# List DRM connectors (driver name is usually xlnx on KV260)
modetest -M xlnx -c
```

Note the **connector id** for the HDMI output that is **connected** (e.g. `42`). Then test that connector with a simple pipeline (on the host):

```bash
# Replace 42 with your HDMI connector id from modetest
gst-launch-1.0 videotestsrc ! kmssink driver-name=xlnx connector-id=42 fullscreen-overlay=true
```

If the test pattern appears on the HDMI monitor, the connector ID is correct. The stock smartcam binary does not expose `connector-id`; to use it you would need to build smartcam from source and add `connector-id=42` (or your id) to the kmssink element in the DP branch, or use a custom GStreamer pipeline that mimics smartcam with that connector-id.

---

## Troubleshooting

| Issue | Check |
|-------|--------|
| No `/dev/video*` | Cable, USB port, `dmesg \| tail` for UVC messages |
| Wrong resolution | Use `v4l2-ctl -d /dev/video0 --list-formats-ext` to see supported formats |
| "No MIPI" or wrong input | Ensure you use `--usb VIDEO_ID`, not `--mipi` |
| Display blank | Normal after `xmutil desktop_disable`; use SSH or UART for commands |
| RTSP works, HDMI black | Run smartcam on **host** (not Docker); connect only HDMI before boot; see “HDMI display” above |
| **RTSP stream glitching** | Use **30 fps**; see "RTSP glitching" below |

### RTSP glitching

If the RTSP picture is glitchy or stuttering, the H.264 encoder is usually overloaded. The messages `Loop filter is not allowed with GDR enabled`, `CABAC ... CAVLC`, and `Level is too low` often appear with unstable output.

**Fix 1: use 30 fps.** High fps (120 or 80) can overload the encoder. Use a supported resolution at **30 fps**.

**Fix 2: disable GDR and use basic GOP** so the encoder doesn’t hit “loop filter not allowed with GDR” and scaling-list adjustments. This often removes the warnings and stabilizes the stream:

```bash
# 720p @ 30 fps with encoder params to reduce glitching (recommended)
smartcam --usb 0 -W 1280 -H 720 -r 30 --target rtsp \
  --control-rate low-latency --gop-length 30 \
  --encodeEnhancedParam "gdr-mode=0, scaling-list=0, gop-mode=0"
```

From the host via Docker:

```bash
docker exec -it $(docker ps -q --filter ancestor=xilinx/smartcam:2022.1 | head -1) \
  smartcam --usb 0 -W 1280 -H 720 -r 30 --target rtsp \
  --control-rate low-latency --gop-length 30 \
  --encodeEnhancedParam "gdr-mode=0, scaling-list=0, gop-mode=0"
```

Other resolutions at 30 fps (with same encoder params if needed):

```bash
# 1080p @ 30 fps
smartcam --usb 0 -W 1920 -H 1080 -r 30 --target rtsp \
  --control-rate low-latency --gop-length 30 \
  --encodeEnhancedParam "gdr-mode=0, scaling-list=0, gop-mode=0"

# 640×480 @ 30 fps
smartcam --usb 0 -W 640 -H 480 -r 30 --target rtsp \
  --control-rate low-latency --gop-length 30 \
  --encodeEnhancedParam "gdr-mode=0, scaling-list=0, gop-mode=0"
```
