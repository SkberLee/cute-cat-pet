#!/bin/bash
# usage: tools/shot.sh WxH out.png [scenario]
cd /workspace/cute-cat-pet
DISPLAY=${DISPLAY:-:7} timeout 120 /workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path . -s res://tools/shot.gd ${RD:+--rendering-driver $RD} --resolution $1 --position 0,0 -- "$2" "${3:-idle}" 2>&1 | grep -E "SHOT|DBG|ERROR|SCRIPT" 
