# opencraft
An open-source Minecraft reimplementation.

## ⚠️ opencraft is NOT production ready. ⚠️

If you use opencraft, *expect to encounter issues*, and please report them.

## Goals
- [ ] Performance
    - opencraft should be faster than standard Minecraft.
    - As we're using Zig, this is already easier out of the gate than if we used Java, but we still have to keep it in mind.
    - Asynchronous execution & multi-threading should be used wherever possible *and sensible.*
- [ ] Minimalism
    - It should be easy to understand how opencraft functions.
- [ ] Multi-version support
    - opencraft should support *all* versions from 1.7.10 - 1.12.2.
    - Snapshots and older versions can be added once these are stable.
    - 1.13+ is currently not planned.
    - Currently, best-effort support is provided for 1.8.x & 1.12.2.

## Non-Goals
- [ ] 100% vanilla gameplay parity
    - Protocol implementations should absolutely be 100% accurate. Gameplay is a different story.

## Credits
opencraft would not be possible without the following projects.

- Protocol implementations are based on info from [wiki.vg](https://wiki.vg/).
- Light engine is based on [Starlight](https://github.com/PaperMC/Starlight).
- Redstone engine is based on [Alternate Current](https://github.com/SpaceWalkerRS/alternate-current).
