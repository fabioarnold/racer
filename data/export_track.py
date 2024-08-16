import bpy
track = bpy.data.curves['track']
spline = track.splines[0]

for point in spline.bezier_points:
    left = point.handle_left - point.co
    right = point.handle_right - point.co
    print(".{")
    print(".pos = Vec3.init(%.3f, %.3f, %.3f), " % (point.co.x, point.co.y, point.co.z))
    print(".left_handle = Vec3.init(%.3f, %.3f, %.3f), " % (left.x, left.y, left.z))
    print(".right_handle = Vec3.init(%.3f, %.3f, %.3f), " % (right.x, right.y, right.z))
    print(".tilt = %.2f" % point.tilt)
    print("},")