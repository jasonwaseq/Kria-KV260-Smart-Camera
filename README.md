# Kria KV260 Smart Camera + See3CAM_CU27

USB camera setup for the KV260 Smart Camera Vision AI app. No special driver needed.

---

## Setup

### 1. Find your camera

```bash
ls -la /dev/video*
```

Use the device number as `VIDEO_ID` (e.g. `/dev/video0` → `0`).

### 2. Load Smart Camera firmware

```bash
sudo apt update
sudo apt install -y xlnx-firmware-kv260-smartcam
sudo xmutil desktop_disable
sudo xmutil unloadapp || true
sudo xmutil loadapp kv260-smartcam
```

### 3. Start the Docker container

```bash
docker pull xilinx/smartcam:2022.1

docker run --net=host --privileged \
  -v /dev:/dev -v /sys:/sys \
  -v /etc/vart.conf:/etc/vart.conf \
  -v /lib/firmware/xilinx:/lib/firmware/xilinx -v /run:/run \
  -it xilinx/smartcam:2022.1 bash
```

---

## Run without glitching

Use this command so the RTSP stream is stable (no encoder warnings, no glitches).

**From the host** (container already running):

```bash
docker exec -it $(docker ps -q --filter ancestor=xilinx/smartcam:2022.1 | head -1) \
  smartcam --usb 0 -W 1280 -H 720 -r 30 --target rtsp \
  --control-rate low-latency --gop-length 30 \
  --encodeEnhancedParam "gdr-mode=0, scaling-list=0, gop-mode=0"
```

Replace `0` with your camera’s `VIDEO_ID` if different.

**Or use the script** (from host, same directory as the script):

```bash
./smartcam-rtsp-no-glitch.sh
# or with a different camera:  ./smartcam-rtsp-no-glitch.sh 1
```

**Inside the container** (after `docker run ... bash`):

```bash
smartcam --usb 0 -W 1280 -H 720 -r 30 --target rtsp \
  --control-rate low-latency --gop-length 30 \
  --encodeEnhancedParam "gdr-mode=0, scaling-list=0, gop-mode=0"
```

**Watch the stream** (on another PC on the same network):

```bash
ffplay rtsp://KV260_IP:554/test
```

Or in VLC: **Media → Open Network Stream** → `rtsp://KV260_IP:554/test`

---

## Other options

- **Display (HDMI/DP)** instead of RTSP: use `--target dp` and the same encoder params if you see glitches:
  ```bash
  smartcam --usb 0 -W 1280 -H 720 -r 30 --target dp \
    --control-rate low-latency --gop-length 30 \
    --encodeEnhancedParam "gdr-mode=0, scaling-list=0, gop-mode=0"
  ```
- **AI tasks**: add `--aitask facedetect` (or `ssd`, `refinedet`) to the command.
- **Re-enable desktop when done**: `sudo xmutil desktop_enable`
