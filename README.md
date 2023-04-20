# `opencraft`
An open-source Minecraft reimplementation.

NOTE: This project is HIGHLY EXPERIMENTAL! Most things won't work; bugs are expected. Don't even think for a second about using this in production. You'd be insane.

## The Goal
The goal is to achieve a high performance, multi-version, cleanroom reimplementation of a Minecraft server (and potentially client).

A non-goal is to achieve 100% compatibility. Protocol implementations will be 100% compatible, but some behavior may be different from vanilla Minecraft.

## Features
- Multi-version support (like ViaVersion).
    - We aim to support all versions from 1.7.2 to the latest.
- Multi-threading.
- Disables 1.19 chat reporting.
- Uses open-source alternatives to Mojang's private code.
    - Protocol implementations are based on info from [wiki.vg](https://wiki.vg/).
    - Light engine is based on [PaperMC](https://github.com/PaperMC)'s [Starlight](https://github.com/PaperMC/Starlight).
    - Redstone engine is based on [Space Walker](https://github.com/SpaceWalkerRS)'s [Alternate Current](https://github.com/SpaceWalkerRS/alternate-current).
    - In theory, `opencraft` is entirely insusceptible to attacks from Mojang.
    - And yes, I'm practically freeloading off of everyone to make this project. Please support the maintainers of the projects listed above. They're the reason this may not take me an entire year.
