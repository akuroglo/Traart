#!/bin/bash
# Reset Traart to fresh state (run in Terminal)
echo "Resetting Traart..."

killall TraartApp 2>/dev/null

defaults delete com.traart.app 2>/dev/null
echo "  Settings cleared"

rm -rf ~/Library/Application\ Support/Traart
echo "  App data deleted"

rm -rf ~/.cache/huggingface/hub/models--waveletdeboshir--gigaam-rnnt
rm -rf ~/.cache/huggingface/hub/models--pyannote--segmentation-3.0
echo "  Model caches deleted"

echo "Done. Launch Traart to start fresh."
