"""Render a rotating, bouncing cube with Blender's bundled Python.

Usage: blender --background --factory-startup --python-exit-code 1 \
    --python scripts/examples/blender-animation.py -- /tmp/blender-demo
Outputs: animation.blend, frames/*.png and verification.json.
Encode a video: ffmpeg -framerate 24 -i frames/%04d.png -pix_fmt yuv420p animation.mp4
"""
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = Path(args[0] if args else "blender-demo").resolve()
(out / "frames").mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 12
scene.render.resolution_x = 384
scene.render.resolution_y = 288
scene.render.resolution_percentage = 100
scene.render.fps = 24
scene.frame_start, scene.frame_end = 1, 48
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(out / "frames") + "/"
scene.world.color = (0.15, 0.15, 0.15)


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    return mat


bpy.ops.mesh.primitive_plane_add(size=200)
bpy.context.object.data.materials.append(material("Ground", (0.07, 0.10, 0.16)))
bpy.ops.mesh.primitive_cube_add(size=1.5, location=(0, 0, 1))
cube = bpy.context.object
cube.name = "AnimatedCube"
cube.data.materials.append(material("Orange", (0.95, 0.23, 0.04)))
bevel = cube.modifiers.new("Soft edges", "BEVEL")
bevel.width, bevel.segments = 0.08, 3
for frame, height, angle in [(1, 1, 0), (13, 2.5, 90), (25, 1, 180),
                             (37, 2.5, 270), (48, 1, 360)]:
    cube.location.z = height
    cube.rotation_euler = (0, 0, math.radians(angle))
    cube.keyframe_insert(data_path="location", frame=frame)
    cube.keyframe_insert(data_path="rotation_euler", frame=frame)

bpy.ops.object.camera_add(location=(7, -9, 6))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 1.3)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type, camera.data.ortho_scale = "ORTHO", 7
scene.camera = camera
bpy.ops.object.light_add(type="AREA", location=(2, -4, 7))
bpy.context.object.data.energy = 1300
bpy.context.object.data.shape = "DISK"
bpy.context.object.data.size = 5

scene.frame_set(1)
start = tuple(cube.location)
scene.frame_set(13)
peak = tuple(cube.location)
assert peak[2] > start[2] + 1, "Python keyframe evaluation failed"
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(out / "animation.blend"))
bpy.ops.render.render(animation=True)
frames = sorted((out / "frames").glob("*.png"))
assert len(frames) == 48, f"Expected 48 rendered frames, got {len(frames)}"
assert frames[0].read_bytes() != frames[12].read_bytes(), "Animation frames did not change"
report = {"blender": bpy.app.version_string, "engine": scene.render.engine,
          "device": scene.cycles.device, "frames": len(frames), "fps": 24,
          "resolution": [384, 288], "start": start, "peak": peak}
(out / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
print("BLENDER_ANIMATION_OK", json.dumps(report))
