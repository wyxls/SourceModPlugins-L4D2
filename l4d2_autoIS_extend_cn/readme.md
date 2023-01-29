# Description

A rewritten vote manager like madcap's original version. 

Origin from : [[L4D &amp; L4D2] Auto Infected Spawner](https://forums.alliedmods.net/showpost.php?p=2685563&postcount=95)

I modified it based on my own needs for 4+ players dedicated server. Mainly added functions of changing Special Infected spawn amout and interval based on how many survivor players alive.

```
// [0=OFF|1=ON] Disable/Enable Spawning Special Infected while Tank is alive
l4d2_ais_spawn_si_with_tank

// "The amount of special infected spawned based on alive player? [0=off|1=on]"
l4d2_ais_spawn_size_on_player

// "The amount of special infected being added per alive player"
l4d2_ais_spawn_size_add_amount

// The maximum auto spawn time being reduced based on alive player? [0=off|1=on]
l4d2_ais_time_on_player

// The amount of auto spawn time being reduced per alive player
l4d2_ais_time_reduce_amount
```

Also fixed some warnings, roblems and added translations. The translations are hardcoded so it has simplified Chinese version and English version.
