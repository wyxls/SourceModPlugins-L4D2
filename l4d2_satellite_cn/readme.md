# Description

Three kind of vertical laser launches by shooting magnum. Switch mode by pushing zoom key.

Origin from : [[L4D2] Satellite Cannon](https://forums.alliedmods.net/showthread.php?t=131504)

I added admin flags function and convar to make it can be used by admin only or by everyone.

```
if sm_satellite_adminonly 0 + sm_satellite_adminunlimit 0, everyone can use satellite and energy is limited.

if sm_satellite_adminonly 0 + sm_satellite_adminunlimit 1, everyone can use satellite and energy is limited. But admin with "p" flag have unlimited energy

if sm_satellite_adminonly 1 + sm_satellite_adminunlimit 0, only admin with "o" flag can use satellite and energy is limited.

if sm_satellite_adminonly 1 + sm_satellite_adminunlimit 1, only admin with "o" flag can use satellite and with "p" flag have unlimited energy.
```
