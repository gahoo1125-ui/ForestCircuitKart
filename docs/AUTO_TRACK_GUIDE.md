# AutoTrackTemplate

1. Open `scenes/AutoTrackTemplate.tscn`.
2. Select the root Path3D.
3. Use the Path3D curve editing tool in the 3D viewport to add/move points.
4. The asphalt road, left/right guardrails and collision are rebuilt automatically in editor mode.
5. For a loop track, enable Curve3D > Closed.
6. Recommended:
   - Normal circuit: sample_distance 0.7-1.0
   - Hairpins/S-curves: sample_distance 0.4-0.65
   - Road width: 10-14
7. Avoid a hairpin radius smaller than roughly half the road width. Add more Bezier control points instead of forcing one point into a 180-degree bend.
8. Use Curve3D point tilt for banking. Keep use_curve_tilt enabled.
9. This system is independent from the current Forest Circuit runtime TrackBuilder, so existing race logic is unchanged.
