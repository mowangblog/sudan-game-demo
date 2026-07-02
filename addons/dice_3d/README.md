# Dice 3D

Dice 3D is a Godot 4.7 addon for modular 3D dice.

There are two main nodes:

- `DiceCinematicRoller3D` - an animation roll box for UI-friendly dice rolls. It can present a chosen result, or choose a random face when no result is supplied. It does not use physics.
- `DiceRollBox3D` - a physics roll box for real dice motion with gravity, collisions, friction, bounce, roll strength, and automatic top-face detection.

Both nodes use `DiceDieDefinition3D` resources. A dice definition describes the die shape, faces, materials, and roll defaults.

## Quick Start

Copy `addons/dice_3d` into a Godot 4.7 project, then enable **Dice 3D** from **Project > Project Settings > Plugins**.

The included demos live in `res://addons/dice_3d/demo/`:

- `animation_roll_demo.tscn`
- `physics_roll_demo.tscn`
- `pips_to_six_demo.tscn`
- `dice_definitions_example.gd`

For the full guide and API notes, see the repository README and API documentation.

## License

Dice 3D is released under CC0 1.0 Universal. See `LICENSE.md`.

## Support

Dice 3D is free to use. If it helps your project, donations are welcome on [Ko-fi](https://ko-fi.com/daniellewis56771).
