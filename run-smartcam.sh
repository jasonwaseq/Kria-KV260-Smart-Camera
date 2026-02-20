#!/bin/bash
# Run smartcam RTSP with encoder params that remove GDR/loop-filter/ScalingList warnings.
# Usage: ./run-smartcam.sh [USB_ID]
#   USB_ID defaults to 0 (e.g. /dev/video0). Run from host or inside the container.

USB_ID="${1:-0}"

if command -v smartcam &>/dev/null; then
  # Inside the container: run smartcam directly
  exec smartcam --usb "$USB_ID" -W 1280 -H 720 -r 30 --target rtsp \
    --control-rate low-latency \
    --gop-length 30 \
    --encodeEnhancedParam "gdr-mode=0, scaling-list=0, gop-mode=0"
fi

# On host: run smartcam inside the Docker container
CONTAINER=$(docker ps -q --filter ancestor=xilinx/smartcam:2022.1 | head -1)
if [ -z "$CONTAINER" ]; then
  echo "No xilinx/smartcam:2022.1 container running. Start it first, e.g.:"
  echo "  docker run --net=host --privileged -v /dev:/dev -v /sys:/sys -v /etc/vart.conf:/etc/vart.conf -v /lib/firmware/xilinx:/lib/firmware/xilinx -v /run:/run -it xilinx/smartcam:2022.1 bash"
  exit 1
fi
exec docker exec -it "$CONTAINER" smartcam --usb "$USB_ID" -W 1280 -H 720 -r 30 --target rtsp \
  --control-rate low-latency \
  --gop-length 30 \
  --encodeEnhancedParam "gdr-mode=0, scaling-list=0, gop-mode=0"
