package config

import rl "vendor:raylib"

NODE_SEPARATION :: 40
NODE_COLOR :: rl.RED
BEGIN_NODE_COLOR :: rl.ORANGE
NODE_BEING_EDITED_COLOR :: rl.BLUE
NODE_RADIUS :: NODE_SEPARATION / 4

NODE_NOTE_TEXT_SIZE :: 8
NODE_NOTE_TEXT_OFFSET :: 2

MAX_ZOOM :: 2.0
MIN_ZOOM :: 0.5
ZOOM_SPEED :: 0.1

ZOOM_OFFSET_GRID :: 500.0

LINES_COLOR :: rl.BLUE

POINTS_SIZE :: 2
POINTS_COLOR :: rl.BLACK

BG_COLOR :: rl.WHITE

ACTIVE_PATH_COLOR :: rl.GREEN
UNACTIVE_PATH_COLOR :: rl.LIME
TRANSFER_PATH_COLOR :: rl.LIGHTGRAY

PATH_THICKNESS :: 3.5

MAX_BPM :: 800
MAX_SUBDIVISION :: 32
