# ai-hallo3
Hallo3: Highly Dynamic and Realistic Portrait Image Animation with Diffusion Transformer Networks

## Overview
This project provides a highly dynamic and realistic portrait image animation using diffusion transformer networks. 

## Usage Instructions
To build the Docker image, run the following command:
```bash
docker build -t olilanz/ai-hallo3 .
```

To run the container, use:
```bash
docker run -it --rm --name ai-hallo3 \
  --shm-size 24g --gpus '"device=0"' \
  -p 7862:7860 \
  -v /mnt/cache/appdata/ai-hallo3:/workspace \
  -e H3_AUTO_UPDATE=1 \
  olilanz/ai-hallo3
```
