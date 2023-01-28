/**
 * Mutant Tanks: a L4D/L4D2 SourceMod Plugin
 * Copyright (C) 2022  Alfred "Psyk0tik" Llagas
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

#define MT_ABILITIES_MAIN2
#define MT_ABILITIES_GROUP2 3 // 0: NONE, 1: Only include first half (1-19), 2: Only include second half (20-38), 3: ALL
#define MT_ABILITIES_COMPILER_MESSAGE2 1 // 0: NONE, 1: Display warning messages about excluded abilities, 2: Display error messages about excluded abilities

#include <sourcemod>
#include <mutant_tanks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[MT] Abilities Set #2",
	author = MT_AUTHOR,
	description = "Provides several abilities for Mutant Tanks.",
	version = MT_VERSION,
	url = MT_URL
};

#define MT_GAMEDATA "mutant_tanks"
#define MT_GAMEDATA_TEMP "mutant_tanks_temp"

bool g_bDedicated, g_bLateLoad, g_bSecondGame;

#undef REQUIRE_PLUGIN
#if MT_ABILITIES_GROUP2 == 1 || MT_ABILITIES_GROUP2 == 3
	#tryinclude "mutant_tanks/abilities2/mt_medic.sp"
	#tryinclude "mutant_tanks/abilities2/mt_meteor.sp"
	#tryinclude "mutant_tanks/abilities2/mt_minion.sp"
	#tryinclude "mutant_tanks/abilities2/mt_necro.sp"
	#tryinclude "mutant_tanks/abilities2/mt_nullify.sp"
	#tryinclude "mutant_tanks/abilities2/mt_omni.sp"
	#tryinclude "mutant_tanks/abilities2/mt_panic.sp"
	#tryinclude "mutant_tanks/abilities2/mt_pimp.sp"
	#tryinclude "mutant_tanks/abilities2/mt_puke.sp"
	#tryinclude "mutant_tanks/abilities2/mt_pyro.sp"
	#tryinclude "mutant_tanks/abilities2/mt_quiet.sp"
	#tryinclude "mutant_tanks/abilities2/mt_recoil.sp"
	#tryinclude "mutant_tanks/abilities2/mt_regen.sp"
	#tryinclude "mutant_tanks/abilities2/mt_respawn.sp"
	#tryinclude "mutant_tanks/abilities2/mt_restart.sp"
	#tryinclude "mutant_tanks/abilities2/mt_rock.sp"
	#tryinclude "mutant_tanks/abilities2/mt_rocket.sp"
	#tryinclude "mutant_tanks/abilities2/mt_shake.sp"
	#tryinclude "mutant_tanks/abilities2/mt_shield.sp"
#endif
#if MT_ABILITIES_GROUP2 == 2 || MT_ABILITIES_GROUP2 == 3
	#tryinclude "mutant_tanks/abilities2/mt_shove.sp"
	#tryinclude "mutant_tanks/abilities2/mt_slow.sp"
	#tryinclude "mutant_tanks/abilities2/mt_smash.sp"
	#tryinclude "mutant_tanks/abilities2/mt_smite.sp"
	#tryinclude "mutant_tanks/abilities2/mt_spam.sp"
	#tryinclude "mutant_tanks/abilities2/mt_splash.sp"
	#tryinclude "mutant_tanks/abilities2/mt_splatter.sp"
	#tryinclude "mutant_tanks/abilities2/mt_throw.sp"
	#tryinclude "mutant_tanks/abilities2/mt_track.sp"
	#tryinclude "mutant_tanks/abilities2/mt_ultimate.sp"
	#tryinclude "mutant_tanks/abilities2/mt_undead.sp"
	#tryinclude "mutant_tanks/abilities2/mt_vampire.sp"
	#tryinclude "mutant_tanks/abilities2/mt_vision.sp"
	#tryinclude "mutant_tanks/abilities2/mt_warp.sp"
	#tryinclude "mutant_tanks/abilities2/mt_whirl.sp"
	#tryinclude "mutant_tanks/abilities2/mt_witch.sp"
	#tryinclude "mutant_tanks/abilities2/mt_xiphos.sp"
	#tryinclude "mutant_tanks/abilities2/mt_yell.sp"
	#tryinclude "mutant_tanks/abilities2/mt_zombie.sp"
#endif
#define REQUIRE_PLUGIN

#if MT_ABILITIES_COMPILER_MESSAGE2 == 1
	#if !defined MT_MENU_MEDIC
		#warning The "Medic" (mt_medic.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_METEOR
		#warning The "Meteor" (mt_meteor.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_MINION
		#warning The "Minion" (mt_minion.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_NECRO
		#warning The "Necro" (mt_necro.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_NULLIFY
		#warning The "Nullify" (mt_nullify.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_OMNI
		#warning The "Omni" (mt_omni.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_PANIC
		#warning The "Panic" (mt_panic.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_PIMP
		#warning The "Pimp" (mt_pimp.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_PUKE
		#warning The "Puke" (mt_puke.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_PYRO
		#warning The "Pyro" (mt_pyro.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_QUIET
		#warning The "Quiet" (mt_quiet.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_RECOIL
		#warning The "Recoil" (mt_recoil.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_REGEN
		#warning The "Regen" (mt_regen.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_RESPAWN
		#warning The "Respawn" (mt_respawn.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_RESTART
		#warning The "Restart" (mt_restart.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_ROCK
		#warning The "Rock" (mt_rock.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_ROCKET
		#warning The "Rocket" (mt_rocket.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SHAKE
		#warning The "Shake" (mt_shake.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SHIELD
		#warning The "Shield" (mt_shield.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SHOVE
		#warning The "Shove" (mt_shove.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SLOW
		#warning The "Slow" (mt_slow.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SMASH
		#warning The "Smash" (mt_smash.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SMITE
		#warning The "Smite" (mt_smite.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SPAM
		#warning The "Spam" (mt_spam.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SPLASH
		#warning The "Splash" (mt_splash.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SPLATTER
		#warning The "Splatter" (mt_splatter.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_THROW
		#warning The "Throw" (mt_throw.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_TRACK
		#warning The "Track" (mt_track.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_ULTIMATE
		#warning The "Ultimate" (mt_ultimate.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_UNDEAD
		#warning The "Undead" (mt_undead.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_VAMPIRE
		#warning The "Vampire" (mt_vampire.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_VISION
		#warning The "Vision" (mt_vision.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_WARP
		#warning The "Warp" (mt_warp.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_WHIRL
		#warning The "Whirl" (mt_whirl.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_WITCH
		#warning The "Witch" (mt_witch.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_XIPHOS
		#warning The "Xiphos" (mt_xiphos.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_YELL
		#warning The "Yell" (mt_yell.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_ZOMBIE
		#warning The "Zombie" (mt_zombie.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
#endif
#if MT_ABILITIES_COMPILER_MESSAGE2 == 2
	#if !defined MT_MENU_MEDIC
		#error The "Medic" (mt_medic.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_METEOR
		#error The "Meteor" (mt_meteor.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_MINION
		#error The "Minion" (mt_minion.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_NECRO
		#error The "Necro" (mt_necro.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_NULLIFY
		#error The "Nullify" (mt_nullify.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_OMNI
		#error The "Omni" (mt_omni.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_PANIC
		#error The "Panic" (mt_panic.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_PIMP
		#error The "Pimp" (mt_pimp.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_PUKE
		#error The "Puke" (mt_puke.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_PYRO
		#error The "Pyro" (mt_pyro.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_QUIET
		#error The "Quiet" (mt_quiet.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_RECOIL
		#error The "Recoil" (mt_recoil.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_REGEN
		#error The "Regen" (mt_regen.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_RESPAWN
		#error The "Respawn" (mt_respawn.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_RESTART
		#error The "Restart" (mt_restart.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_ROCK
		#error The "Rock" (mt_rock.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_ROCKET
		#error The "Rocket" (mt_rocket.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SHAKE
		#error The "Shake" (mt_shake.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SHIELD
		#error The "Shield" (mt_shield.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SHOVE
		#error The "Shove" (mt_shove.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SLOW
		#error The "Slow" (mt_slow.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SMASH
		#error The "Smash" (mt_smash.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SMITE
		#error The "Smite" (mt_smite.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SPAM
		#error The "Spam" (mt_spam.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SPLASH
		#error The "Splash" (mt_splash.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_SPLATTER
		#error The "Splatter" (mt_splatter.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_THROW
		#error The "Throw" (mt_throw.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_TRACK
		#error The "Track" (mt_track.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_ULTIMATE
		#error The "Ultimate" (mt_ultimate.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_UNDEAD
		#error The "Undead" (mt_undead.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_VAMPIRE
		#error The "Vampire" (mt_vampire.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_VISION
		#error The "Vision" (mt_vision.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_WARP
		#error The "Warp" (mt_warp.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_WHIRL
		#error The "Whirl" (mt_whirl.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_WITCH
		#error The "Witch" (mt_witch.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_XIPHOS
		#error The "Xiphos" (mt_xiphos.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_YELL
		#error The "Yell" (mt_yell.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
	#if !defined MT_MENU_ZOMBIE
		#error The "Zombie" (mt_zombie.sp) ability is missing from the "scripting/mutant_tanks/abilities2" folder.
	#endif
#endif

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bSecondGame = false;
		case Engine_Left4Dead2: g_bSecondGame = true;
		default:
		{
			strcopy(error, err_max, "\"[MT] Abilities Set #2\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	GameData gdMutantTanks = new GameData(MT_GAMEDATA);
	if (gdMutantTanks == null)
	{
		LogError("%s Unable to load the \"%s\" gamedata file.", MT_TAG, MT_GAMEDATA);

		return;
	}
#if defined MT_MENU_RESTART
	vRestartAllPluginsLoaded(gdMutantTanks);
#endif
#if defined MT_MENU_WARP
	vWarpAllPluginsLoaded(gdMutantTanks);
#endif
	delete gdMutantTanks;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_ability2", cmdAbilityInfo2, "View information about each ability (M-Z).");

	vAbilitySetup(0);

	if (g_bLateLoad)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
			{
				OnClientPutInServer(iPlayer);
			}
		}
#if defined MT_MENU_SHIELD
		vShieldLateLoad();
#endif
		g_bLateLoad = false;
	}
}

public void OnMapStart()
{
	vAbilitySetup(1);
}

public void OnClientPutInServer(int client)
{
	vAbilityPlayer(0, client);
}

public void OnClientDisconnect(int client)
{
	vAbilityPlayer(1, client);
}

public void OnClientDisconnect_Post(int client)
{
	vAbilityPlayer(2, client);
}

public void OnMapEnd()
{
	vAbilitySetup(2);
}

public void MT_OnPluginEnd()
{
	vAbilitySetup(3);
}

public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}

public void OnEntityCreated(int entity, const char[] classname)
{
#if defined MT_MENU_METEOR
	vMeteorEntityCreated(entity, classname);
#endif
#if defined MT_MENU_ROCKET
	vRocketEntityCreated(entity, classname);
#endif
#if defined MT_MENU_SHIELD
	vShieldEntityCreated(entity, classname);
#endif
#if defined MT_MENU_SMASH
	vSmashEntityCreated(entity, classname);
#endif
#if defined MT_MENU_SMITE
	vSmiteEntityCreated(entity, classname);
#endif
}

Action cmdAbilityInfo2(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);

	if (!MT_IsCorePluginEnabled())
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG5, "PluginDisabled");

		return Plugin_Handled;
	}

	if (!bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG, "Command is in-game only");

		return Plugin_Handled;
	}

	switch (args)
	{
		case 1:
		{
			switch (IsVoteInProgress())
			{
				case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
				case false:
				{
					char sName[32];
					GetCmdArg(1, sName, sizeof sName);
					vAbilityMenu(client, sName);
				}
			}
		}
		default:
		{
			char sCmd[15];
			GetCmdArg(0, sCmd, sizeof sCmd);
			MT_ReplyToCommand(client, "%s %t", MT_TAG2, "CommandUsage2", sCmd);
		}
	}

	return Plugin_Handled;
}

public void MT_OnDisplayMenu(Menu menu)
{
#if defined MT_MENU_MEDIC
	vMedicDisplayMenu(menu);
#endif
#if defined MT_MENU_METEOR
	vMeteorDisplayMenu(menu);
#endif
#if defined MT_MENU_MINION
	vMinionDisplayMenu(menu);
#endif
#if defined MT_MENU_NECRO
	vNecroDisplayMenu(menu);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyDisplayMenu(menu);
#endif
#if defined MT_MENU_OMNI
	vOmniDisplayMenu(menu);
#endif
#if defined MT_MENU_PANIC
	vPanicDisplayMenu(menu);
#endif
#if defined MT_MENU_PIMP
	vPimpDisplayMenu(menu);
#endif
#if defined MT_MENU_PUKE
	vPukeDisplayMenu(menu);
#endif
#if defined MT_MENU_PYRO
	vPyroDisplayMenu(menu);
#endif
#if defined MT_MENU_QUIET
	vQuietDisplayMenu(menu);
#endif
#if defined MT_MENU_RECOIL
	vRecoilDisplayMenu(menu);
#endif
#if defined MT_MENU_REGEN
	vRegenDisplayMenu(menu);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnDisplayMenu(menu);
#endif
#if defined MT_MENU_RESTART
	vRestartDisplayMenu(menu);
#endif
#if defined MT_MENU_ROCK
	vRockDisplayMenu(menu);
#endif
#if defined MT_MENU_ROCKET
	vRocketDisplayMenu(menu);
#endif
#if defined MT_MENU_SHAKE
	vShakeDisplayMenu(menu);
#endif
#if defined MT_MENU_SHIELD
	vShieldDisplayMenu(menu);
#endif
#if defined MT_MENU_SHOVE
	vShoveDisplayMenu(menu);
#endif
#if defined MT_MENU_SLOW
	vSlowDisplayMenu(menu);
#endif
#if defined MT_MENU_SMASH
	vSmashDisplayMenu(menu);
#endif
#if defined MT_MENU_SMITE
	vSmiteDisplayMenu(menu);
#endif
#if defined MT_MENU_SPAM
	vSpamDisplayMenu(menu);
#endif
#if defined MT_MENU_SPLASH
	vSplashDisplayMenu(menu);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterDisplayMenu(menu);
#endif
#if defined MT_MENU_THROW
	vThrowDisplayMenu(menu);
#endif
#if defined MT_MENU_TRACK
	vTrackDisplayMenu(menu);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateDisplayMenu(menu);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadDisplayMenu(menu);
#endif
#if defined MT_MENU_VAMPIRE
	vVampireDisplayMenu(menu);
#endif
#if defined MT_MENU_VISION
	vVisionDisplayMenu(menu);
#endif
#if defined MT_MENU_WARP
	vWarpDisplayMenu(menu);
#endif
#if defined MT_MENU_WHIRL
	vWhirlDisplayMenu(menu);
#endif
#if defined MT_MENU_WITCH
	vWitchDisplayMenu(menu);
#endif
#if defined MT_MENU_XIPHOS
	vXiphosDisplayMenu(menu);
#endif
#if defined MT_MENU_YELL
	vYellDisplayMenu(menu);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieDisplayMenu(menu);
#endif
}

public void MT_OnMenuItemSelected(int client, const char[] info)
{
#if defined MT_MENU_MEDIC
	vMedicMenuItemSelected(client, info);
#endif
#if defined MT_MENU_METEOR
	vMeteorMenuItemSelected(client, info);
#endif
#if defined MT_MENU_MINION
	vMinionMenuItemSelected(client, info);
#endif
#if defined MT_MENU_NECRO
	vNecroMenuItemSelected(client, info);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyMenuItemSelected(client, info);
#endif
#if defined MT_MENU_OMNI
	vOmniMenuItemSelected(client, info);
#endif
#if defined MT_MENU_PANIC
	vPanicMenuItemSelected(client, info);
#endif
#if defined MT_MENU_PIMP
	vPimpMenuItemSelected(client, info);
#endif
#if defined MT_MENU_PUKE
	vPukeMenuItemSelected(client, info);
#endif
#if defined MT_MENU_PYRO
	vPyroMenuItemSelected(client, info);
#endif
#if defined MT_MENU_QUIET
	vQuietMenuItemSelected(client, info);
#endif
#if defined MT_MENU_RECOIL
	vRecoilMenuItemSelected(client, info);
#endif
#if defined MT_MENU_REGEN
	vRegenMenuItemSelected(client, info);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnMenuItemSelected(client, info);
#endif
#if defined MT_MENU_RESTART
	vRestartMenuItemSelected(client, info);
#endif
#if defined MT_MENU_ROCK
	vRockMenuItemSelected(client, info);
#endif
#if defined MT_MENU_ROCKET
	vRocketMenuItemSelected(client, info);
#endif
#if defined MT_MENU_SHAKE
	vShakeMenuItemSelected(client, info);
#endif
#if defined MT_MENU_SHIELD
	vShieldMenuItemSelected(client, info);
#endif
#if defined MT_MENU_SHOVE
	vShoveMenuItemSelected(client, info);
#endif
#if defined MT_MENU_SLOW
	vSlowMenuItemSelected(client, info);
#endif
#if defined MT_MENU_SMASH
	vSmashMenuItemSelected(client, info);
#endif
#if defined MT_MENU_SMITE
	vSmiteMenuItemSelected(client, info);
#endif
#if defined MT_MENU_SPAM
	vSpamMenuItemSelected(client, info);
#endif
#if defined MT_MENU_SPLASH
	vSplashMenuItemSelected(client, info);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterMenuItemSelected(client, info);
#endif
#if defined MT_MENU_THROW
	vThrowMenuItemSelected(client, info);
#endif
#if defined MT_MENU_TRACK
	vTrackMenuItemSelected(client, info);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateMenuItemSelected(client, info);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadMenuItemSelected(client, info);
#endif
#if defined MT_MENU_VAMPIRE
	vVampireMenuItemSelected(client, info);
#endif
#if defined MT_MENU_VISION
	vVisionMenuItemSelected(client, info);
#endif
#if defined MT_MENU_WARP
	vWarpMenuItemSelected(client, info);
#endif
#if defined MT_MENU_WHIRL
	vWhirlMenuItemSelected(client, info);
#endif
#if defined MT_MENU_WITCH
	vWitchMenuItemSelected(client, info);
#endif
#if defined MT_MENU_XIPHOS
	vXiphosMenuItemSelected(client, info);
#endif
#if defined MT_MENU_YELL
	vYellMenuItemSelected(client, info);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieMenuItemSelected(client, info);
#endif
}

public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
{
#if defined MT_MENU_MEDIC
	vMedicMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_METEOR
	vMeteorMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_MINION
	vMinionMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_NECRO
	vNecroMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_OMNI
	vOmniMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_PANIC
	vPanicMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_PIMP
	vPimpMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_PUKE
	vPukeMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_PYRO
	vPyroMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_QUIET
	vQuietMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_RECOIL
	vRecoilMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_REGEN
	vRegenMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_RESTART
	vRestartMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_ROCK
	vRockMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_ROCKET
	vRocketMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_SHAKE
	vShakeMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_SHIELD
	vShieldMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_SHOVE
	vShoveMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_SLOW
	vSlowMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_SMASH
	vSmashMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_SMITE
	vSmiteMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_SPAM
	vSpamMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_SPLASH
	vSplashMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_THROW
	vThrowMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_TRACK
	vTrackMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_VAMPIRE
	vVampireMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_VISION
	vVisionMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_WARP
	vWarpMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_WHIRL
	vWhirlMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_WITCH
	vWitchMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_XIPHOS
	vXiphosMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_YELL
	vYellMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieMenuItemDisplayed(client, info, buffer, size);
#endif
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!MT_IsCorePluginEnabled())
	{
		return Plugin_Continue;
	}
#if defined MT_MENU_NECRO
	vNecroPlayerRunCmd(client);
#endif
#if defined MT_MENU_OMNI
	vOmniPlayerRunCmd(client);
#endif
#if defined MT_MENU_PYRO
	vPyroPlayerRunCmd(client);
#endif
#if defined MT_MENU_SHIELD
	vShieldPlayerRunCmd(client);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimatePlayerRunCmd(client);
#endif
	return Plugin_Continue;
}

public void MT_OnPluginCheck(ArrayList list)
{
#if defined MT_MENU_MEDIC
	vMedicPluginCheck(list);
#endif
#if defined MT_MENU_METEOR
	vMeteorPluginCheck(list);
#endif
#if defined MT_MENU_MINION
	vMinionPluginCheck(list);
#endif
#if defined MT_MENU_NECRO
	vNecroPluginCheck(list);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyPluginCheck(list);
#endif
#if defined MT_MENU_OMNI
	vOmniPluginCheck(list);
#endif
#if defined MT_MENU_PANIC
	vPanicPluginCheck(list);
#endif
#if defined MT_MENU_PIMP
	vPimpPluginCheck(list);
#endif
#if defined MT_MENU_PUKE
	vPukePluginCheck(list);
#endif
#if defined MT_MENU_PYRO
	vPyroPluginCheck(list);
#endif
#if defined MT_MENU_QUIET
	vQuietPluginCheck(list);
#endif
#if defined MT_MENU_RECOIL
	vRecoilPluginCheck(list);
#endif
#if defined MT_MENU_REGEN
	vRegenPluginCheck(list);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnPluginCheck(list);
#endif
#if defined MT_MENU_RESTART
	vRestartPluginCheck(list);
#endif
#if defined MT_MENU_ROCK
	vRockPluginCheck(list);
#endif
#if defined MT_MENU_ROCKET
	vRocketPluginCheck(list);
#endif
#if defined MT_MENU_SHAKE
	vShakePluginCheck(list);
#endif
#if defined MT_MENU_SHIELD
	vShieldPluginCheck(list);
#endif
#if defined MT_MENU_SHOVE
	vShovePluginCheck(list);
#endif
#if defined MT_MENU_SLOW
	vSlowPluginCheck(list);
#endif
#if defined MT_MENU_SMASH
	vSmashPluginCheck(list);
#endif
#if defined MT_MENU_SMITE
	vSmitePluginCheck(list);
#endif
#if defined MT_MENU_SPAM
	vSpamPluginCheck(list);
#endif
#if defined MT_MENU_SPLASH
	vSplashPluginCheck(list);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterPluginCheck(list);
#endif
#if defined MT_MENU_THROW
	vThrowPluginCheck(list);
#endif
#if defined MT_MENU_TRACK
	vTrackPluginCheck(list);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimatePluginCheck(list);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadPluginCheck(list);
#endif
#if defined MT_MENU_VAMPIRE
	vVampirePluginCheck(list);
#endif
#if defined MT_MENU_VISION
	vVisionPluginCheck(list);
#endif
#if defined MT_MENU_WARP
	vWarpPluginCheck(list);
#endif
#if defined MT_MENU_WHIRL
	vWhirlPluginCheck(list);
#endif
#if defined MT_MENU_WITCH
	vWitchPluginCheck(list);
#endif
#if defined MT_MENU_XIPHOS
	vXiphosPluginCheck(list);
#endif
#if defined MT_MENU_YELL
	vYellPluginCheck(list);
#endif
#if defined MT_MENU_ZOMBIE
	vZombiePluginCheck(list);
#endif
}

public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
{
#if defined MT_MENU_MEDIC
	vMedicAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_METEOR
	vMeteorAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_MINION
	vMinionAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_NECRO
	vNecroAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_OMNI
	vOmniAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_PANIC
	vPanicAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_PIMP
	vPimpAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_PUKE
	vPukeAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_PYRO
	vPyroAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_QUIET
	vQuietAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_RECOIL
	vRecoilAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_REGEN
	vRegenAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_RESTART
	vRestartAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_ROCK
	vRockAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_ROCKET
	vRocketAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_SHAKE
	vShakeAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_SHIELD
	vShieldAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_SHOVE
	vShoveAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_SLOW
	vSlowAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_SMASH
	vSmashAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_SMITE
	vSmiteAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_SPAM
	vSpamAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_SPLASH
	vSplashAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_THROW
	vThrowAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_TRACK
	vTrackAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_VAMPIRE
	vVampireAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_VISION
	vVisionAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_WARP
	vWarpAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_WHIRL
	vWhirlAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_WITCH
	vWitchAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_XIPHOS
	vXiphosAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_YELL
	vYellAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieAbilityCheck(list, list2, list3, list4);
#endif
}

public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
{
#if defined MT_MENU_MEDIC
	vMedicCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_METEOR
	vMeteorCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_MINION
	vMinionCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_NECRO
	vNecroCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_OMNI
	vOmniCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_PANIC
	vPanicCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_PIMP
	vPimpCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_PUKE
	vPukeCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_PYRO
	vPyroCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_QUIET
	vQuietCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_RECOIL
	vRecoilCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_REGEN
	vRegenCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_RESTART
	vRestartCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_ROCK
	vRockCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_ROCKET
	vRocketCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_SHAKE
	vShakeCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_SHIELD
	vShieldCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_SHOVE
	vShoveCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_SLOW
	vSlowCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_SMASH
	vSmashCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_SMITE
	vSmiteCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_SPAM
	vSpamCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_SPLASH
	vSplashCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_THROW
	vThrowCombineAbilities(tank, type, random, combo, weapon);
#endif
#if defined MT_MENU_TRACK
	vTrackCombineAbilities(tank, type, random, combo, weapon);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_VISION
	vVisionCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_WARP
	vWarpCombineAbilities(tank, type, random, combo, survivor, weapon, classname);
#endif
#if defined MT_MENU_WHIRL
	vWhirlCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_WITCH
	vWitchCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_YELL
	vYellCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieCombineAbilities(tank, type, random, combo);
#endif
}

public void MT_OnConfigsLoad(int mode)
{
#if defined MT_MENU_MEDIC
	vMedicConfigsLoad(mode);
#endif
#if defined MT_MENU_METEOR
	vMeteorConfigsLoad(mode);
#endif
#if defined MT_MENU_MINION
	vMinionConfigsLoad(mode);
#endif
#if defined MT_MENU_NECRO
	vNecroConfigsLoad(mode);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyConfigsLoad(mode);
#endif
#if defined MT_MENU_OMNI
	vOmniConfigsLoad(mode);
#endif
#if defined MT_MENU_PANIC
	vPanicConfigsLoad(mode);
#endif
#if defined MT_MENU_PIMP
	vPimpConfigsLoad(mode);
#endif
#if defined MT_MENU_PUKE
	vPukeConfigsLoad(mode);
#endif
#if defined MT_MENU_PYRO
	vPyroConfigsLoad(mode);
#endif
#if defined MT_MENU_QUIET
	vQuietConfigsLoad(mode);
#endif
#if defined MT_MENU_RECOIL
	vRecoilConfigsLoad(mode);
#endif
#if defined MT_MENU_REGEN
	vRegenConfigsLoad(mode);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnConfigsLoad(mode);
#endif
#if defined MT_MENU_RESTART
	vRestartConfigsLoad(mode);
#endif
#if defined MT_MENU_ROCK
	vRockConfigsLoad(mode);
#endif
#if defined MT_MENU_ROCKET
	vRocketConfigsLoad(mode);
#endif
#if defined MT_MENU_SHAKE
	vShakeConfigsLoad(mode);
#endif
#if defined MT_MENU_SHIELD
	vShieldConfigsLoad(mode);
#endif
#if defined MT_MENU_SHOVE
	vShoveConfigsLoad(mode);
#endif
#if defined MT_MENU_SLOW
	vSlowConfigsLoad(mode);
#endif
#if defined MT_MENU_SMASH
	vSmashConfigsLoad(mode);
#endif
#if defined MT_MENU_SMITE
	vSmiteConfigsLoad(mode);
#endif
#if defined MT_MENU_SPAM
	vSpamConfigsLoad(mode);
#endif
#if defined MT_MENU_SPLASH
	vSplashConfigsLoad(mode);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterConfigsLoad(mode);
#endif
#if defined MT_MENU_THROW
	vThrowConfigsLoad(mode);
#endif
#if defined MT_MENU_TRACK
	vTrackConfigsLoad(mode);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateConfigsLoad(mode);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadConfigsLoad(mode);
#endif
#if defined MT_MENU_VAMPIRE
	vVampireConfigsLoad(mode);
#endif
#if defined MT_MENU_VISION
	vVisionConfigsLoad(mode);
#endif
#if defined MT_MENU_WARP
	vWarpConfigsLoad(mode);
#endif
#if defined MT_MENU_WHIRL
	vWhirlConfigsLoad(mode);
#endif
#if defined MT_MENU_WITCH
	vWitchConfigsLoad(mode);
#endif
#if defined MT_MENU_XIPHOS
	vXiphosConfigsLoad(mode);
#endif
#if defined MT_MENU_YELL
	vYellConfigsLoad(mode);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieConfigsLoad(mode);
#endif
}

public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
{
#if defined MT_MENU_MEDIC
	vMedicConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_METEOR
	vMeteorConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_MINION
	vMinionConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_NECRO
	vNecroConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_OMNI
	vOmniConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_PANIC
	vPanicConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_PIMP
	vPimpConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_PUKE
	vPukeConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_PYRO
	vPyroConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_QUIET
	vQuietConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_RECOIL
	vRecoilConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_REGEN
	vRegenConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_RESTART
	vRestartConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_ROCK
	vRockConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_ROCKET
	vRocketConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_SHAKE
	vShakeConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_SHIELD
	vShieldConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_SHOVE
	vShoveConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_SLOW
	vSlowConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_SMASH
	vSmashConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_SMITE
	vSmiteConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_SPAM
	vSpamConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_SPLASH
	vSplashConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_THROW
	vThrowConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_TRACK
	vTrackConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_VAMPIRE
	vVampireConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_VISION
	vVisionConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_WARP
	vWarpConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_WHIRL
	vWhirlConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_WITCH
	vWitchConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_XIPHOS
	vXiphosConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_YELL
	vYellConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
}

public void MT_OnSettingsCached(int tank, bool apply, int type)
{
#if defined MT_MENU_MEDIC
	vMedicSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_METEOR
	vMeteorSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_MINION
	vMinionSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_NECRO
	vNecroSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_NULLIFY
	vNullifySettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_OMNI
	vOmniSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_PANIC
	vPanicSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_PIMP
	vPimpSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_PUKE
	vPukeSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_PYRO
	vPyroSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_QUIET
	vQuietSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_RECOIL
	vRecoilSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_REGEN
	vRegenSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_RESTART
	vRestartSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_ROCK
	vRockSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_ROCKET
	vRocketSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_SHAKE
	vShakeSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_SHIELD
	vShieldSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_SHOVE
	vShoveSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_SLOW
	vSlowSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_SMASH
	vSmashSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_SMITE
	vSmiteSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_SPAM
	vSpamSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_SPLASH
	vSplashSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_THROW
	vThrowSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_TRACK
	vTrackSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_VAMPIRE
	vVampireSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_VISION
	vVisionSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_WARP
	vWarpSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_WHIRL
	vWhirlSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_WITCH
	vWitchSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_XIPHOS
	vXiphosSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_YELL
	vYellSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieSettingsCached(tank, apply, type);
#endif
}

public void MT_OnCopyStats(int oldTank, int newTank)
{
#if defined MT_MENU_MEDIC
	vMedicCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_METEOR
	vMeteorCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_MINION
	vMinionCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_NECRO
	vNecroCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_OMNI
	vOmniCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_PANIC
	vPanicCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_PIMP
	vPimpCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_PUKE
	vPukeCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_PYRO
	vPyroCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_QUIET
	vQuietCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_RECOIL
	vRecoilCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_REGEN
	vRegenCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_RESTART
	vRestartCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_ROCK
	vRockCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_ROCKET
	vRocketCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_SHAKE
	vShakeCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_SHIELD
	vShieldCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_SHOVE
	vShoveCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_SLOW
	vSlowCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_SMASH
	vSmashCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_SMITE
	vSmiteCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_SPAM
	vSpamCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_SPLASH
	vSplashCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_THROW
	vThrowCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_TRACK
	vTrackCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_VISION
	vVisionCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_WARP
	vWarpCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_WHIRL
	vWhirlCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_WITCH
	vWitchCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_YELL
	vYellCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieCopyStats(oldTank, newTank);
#endif
}

public void MT_OnHookEvent(bool hooked)
{
#if defined MT_MENU_RECOIL
	vRecoilHookEvent(hooked);
#endif
#if defined MT_MENU_RESTART
	vRestartHookEvent(hooked);
#endif
}

public void MT_OnEventFired(Event event, const char[] name, bool dontBroadcast)
{
#if defined MT_MENU_MEDIC
	vMedicEventFired(event, name);
#endif
#if defined MT_MENU_METEOR
	vMeteorEventFired(event, name);
#endif
#if defined MT_MENU_MINION
	vMinionEventFired(event, name);
#endif
#if defined MT_MENU_NECRO
	vNecroEventFired(event, name);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyEventFired(event, name);
#endif
#if defined MT_MENU_OMNI
	vOmniEventFired(event, name);
#endif
#if defined MT_MENU_PANIC
	vPanicEventFired(event, name);
#endif
#if defined MT_MENU_PIMP
	vPimpEventFired(event, name);
#endif
#if defined MT_MENU_PUKE
	vPukeEventFired(event, name);
#endif
#if defined MT_MENU_PYRO
	vPyroEventFired(event, name);
#endif
#if defined MT_MENU_QUIET
	vQuietEventFired(event, name);
#endif
#if defined MT_MENU_RECOIL
	vRecoilEventFired(event, name);
#endif
#if defined MT_MENU_REGEN
	vRegenEventFired(event, name);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnEventFired(event, name);
#endif
#if defined MT_MENU_RESTART
	vRestartEventFired(event, name);
#endif
#if defined MT_MENU_ROCK
	vRockEventFired(event, name);
#endif
#if defined MT_MENU_ROCKET
	vRocketEventFired(event, name);
#endif
#if defined MT_MENU_SHAKE
	vShakeEventFired(event, name);
#endif
#if defined MT_MENU_SHIELD
	vShieldEventFired(event, name);
#endif
#if defined MT_MENU_SHOVE
	vShoveEventFired(event, name);
#endif
#if defined MT_MENU_SLOW
	vSlowEventFired(event, name);
#endif
#if defined MT_MENU_SMASH
	vSmashEventFired(event, name);
#endif
#if defined MT_MENU_SMITE
	vSmiteEventFired(event, name);
#endif
#if defined MT_MENU_SPAM
	vSpamEventFired(event, name);
#endif
#if defined MT_MENU_SPLASH
	vSplashEventFired(event, name);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterEventFired(event, name);
#endif
#if defined MT_MENU_THROW
	vThrowEventFired(event, name);
#endif
#if defined MT_MENU_TRACK
	vTrackEventFired(event, name);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateEventFired(event, name);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadEventFired(event, name);
#endif
#if defined MT_MENU_VISION
	vVisionEventFired(event, name);
#endif
#if defined MT_MENU_WARP
	vWarpEventFired(event, name);
#endif
#if defined MT_MENU_WHIRL
	vWhirlEventFired(event, name);
#endif
#if defined MT_MENU_WITCH
	vWitchEventFired(event, name);
#endif
#if defined MT_MENU_YELL
	vYellEventFired(event, name);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieEventFired(event, name);
#endif
}

public void MT_OnAbilityActivated(int tank)
{
	vAbilityPlayer(3, tank);
}

public void MT_OnButtonPressed(int tank, int button)
{
#if defined MT_MENU_MEDIC
	vMedicButtonPressed(tank, button);
#endif
#if defined MT_MENU_METEOR
	vMeteorButtonPressed(tank, button);
#endif
#if defined MT_MENU_MINION
	vMinionButtonPressed(tank, button);
#endif
#if defined MT_MENU_NECRO
	vNecroButtonPressed(tank, button);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyButtonPressed(tank, button);
#endif
#if defined MT_MENU_OMNI
	vOmniButtonPressed(tank, button);
#endif
#if defined MT_MENU_PANIC
	vPanicButtonPressed(tank, button);
#endif
#if defined MT_MENU_PIMP
	vPimpButtonPressed(tank, button);
#endif
#if defined MT_MENU_PUKE
	vPukeButtonPressed(tank, button);
#endif
#if defined MT_MENU_PYRO
	vPyroButtonPressed(tank, button);
#endif
#if defined MT_MENU_QUIET
	vQuietButtonPressed(tank, button);
#endif
#if defined MT_MENU_RECOIL
	vRecoilButtonPressed(tank, button);
#endif
#if defined MT_MENU_REGEN
	vRegenButtonPressed(tank, button);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnButtonPressed(tank, button);
#endif
#if defined MT_MENU_RESTART
	vRestartButtonPressed(tank, button);
#endif
#if defined MT_MENU_ROCK
	vRockButtonPressed(tank, button);
#endif
#if defined MT_MENU_ROCKET
	vRocketButtonPressed(tank, button);
#endif
#if defined MT_MENU_SHAKE
	vShakeButtonPressed(tank, button);
#endif
#if defined MT_MENU_SHIELD
	vShieldButtonPressed(tank, button);
#endif
#if defined MT_MENU_SHOVE
	vShoveButtonPressed(tank, button);
#endif
#if defined MT_MENU_SLOW
	vSlowButtonPressed(tank, button);
#endif
#if defined MT_MENU_SMASH
	vSmashButtonPressed(tank, button);
#endif
#if defined MT_MENU_SMITE
	vSmiteButtonPressed(tank, button);
#endif
#if defined MT_MENU_SPAM
	vSpamButtonPressed(tank, button);
#endif
#if defined MT_MENU_SPLASH
	vSplashButtonPressed(tank, button);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterButtonPressed(tank, button);
#endif
#if defined MT_MENU_THROW
	vThrowButtonPressed(tank, button);
#endif
#if defined MT_MENU_TRACK
	vTrackButtonPressed(tank, button);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateButtonPressed(tank, button);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadButtonPressed(tank, button);
#endif
#if defined MT_MENU_VISION
	vVisionButtonPressed(tank, button);
#endif
#if defined MT_MENU_WARP
	vWarpButtonPressed(tank, button);
#endif
#if defined MT_MENU_WHIRL
	vWhirlButtonPressed(tank, button);
#endif
#if defined MT_MENU_WITCH
	vWitchButtonPressed(tank, button);
#endif
#if defined MT_MENU_YELL
	vYellButtonPressed(tank, button);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieButtonPressed(tank, button);
#endif
}

public void MT_OnButtonReleased(int tank, int button)
{
#if defined MT_MENU_MEDIC
	vMedicButtonReleased(tank, button);
#endif
#if defined MT_MENU_METEOR
	vMeteorButtonReleased(tank, button);
#endif
#if defined MT_MENU_NECRO
	vNecroButtonReleased(tank, button);
#endif
#if defined MT_MENU_OMNI
	vOmniButtonReleased(tank, button);
#endif
#if defined MT_MENU_PANIC
	vPanicButtonReleased(tank, button);
#endif
#if defined MT_MENU_PYRO
	vPyroButtonReleased(tank, button);
#endif
#if defined MT_MENU_REGEN
	vRegenButtonReleased(tank, button);
#endif
#if defined MT_MENU_ROCK
	vRockButtonReleased(tank, button);
#endif
#if defined MT_MENU_SHIELD
	vShieldButtonReleased(tank, button);
#endif
#if defined MT_MENU_SPAM
	vSpamButtonReleased(tank, button);
#endif
#if defined MT_MENU_SPLASH
	vSplashButtonReleased(tank, button);
#endif
#if defined MT_MENU_WARP
	vWarpButtonReleased(tank, button);
#endif
#if defined MT_MENU_YELL
	vYellButtonReleased(tank, button);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieButtonReleased(tank, button);
#endif
}

public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
{
#if defined MT_MENU_MEDIC
	vMedicChangeType(tank, oldType);
#endif
#if defined MT_MENU_METEOR
	vMeteorChangeType(tank, oldType);
#endif
#if defined MT_MENU_MINION
	vMinionChangeType(tank, oldType);
#endif
#if defined MT_MENU_NECRO
	vNecroChangeType(tank, oldType);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyChangeType(tank, oldType);
#endif
#if defined MT_MENU_PANIC
	vPanicChangeType(tank, oldType);
#endif
#if defined MT_MENU_PIMP
	vPimpChangeType(tank, oldType);
#endif
#if defined MT_MENU_PUKE
	vPukeChangeType(tank, oldType);
#endif
#if defined MT_MENU_PYRO
	vPyroChangeType(tank, oldType);
#endif
#if defined MT_MENU_QUIET
	vQuietChangeType(tank, oldType);
#endif
#if defined MT_MENU_RECOIL
	vRecoilChangeType(tank, oldType);
#endif
#if defined MT_MENU_REGEN
	vRegenChangeType(tank, oldType);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnChangeType(tank, oldType, revert);
#endif
#if defined MT_MENU_RESTART
	vRestartChangeType(tank, oldType);
#endif
#if defined MT_MENU_ROCK
	vRockChangeType(tank, oldType);
#endif
#if defined MT_MENU_ROCKET
	vRocketChangeType(tank, oldType);
#endif
#if defined MT_MENU_SHAKE
	vShakeChangeType(tank, oldType);
#endif
#if defined MT_MENU_SHIELD
	vShieldChangeType(tank, oldType);
#endif
#if defined MT_MENU_SHOVE
	vShoveChangeType(tank, oldType);
#endif
#if defined MT_MENU_SLOW
	vSlowChangeType(tank, oldType);
#endif
#if defined MT_MENU_SMASH
	vSmashChangeType(tank, oldType);
#endif
#if defined MT_MENU_SMITE
	vSmiteChangeType(tank, oldType);
#endif
#if defined MT_MENU_SPAM
	vSpamChangeType(tank, oldType);
#endif
#if defined MT_MENU_SPLASH
	vSplashChangeType(tank, oldType);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterChangeType(tank, oldType);
#endif
#if defined MT_MENU_THROW
	vThrowChangeType(tank, oldType);
#endif
#if defined MT_MENU_TRACK
	vTrackChangeType(tank, oldType);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateChangeType(tank, oldType);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadChangeType(tank, oldType);
#endif
#if defined MT_MENU_VISION
	vVisionChangeType(tank, oldType);
#endif
#if defined MT_MENU_WARP
	vWarpChangeType(tank, oldType);
#endif
#if defined MT_MENU_WHIRL
	vWhirlChangeType(tank, oldType);
#endif
#if defined MT_MENU_WITCH
	vWitchChangeType(tank, oldType);
#endif
#if defined MT_MENU_YELL
	vYellChangeType(tank, oldType);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieChangeType(tank, oldType);
#endif
}

public void MT_OnPostTankSpawn(int tank)
{
	vAbilityPlayer(4, tank);
}

public void MT_OnPlayerEventKilled(int victim, int attacker)
{
#if defined MT_MENU_NECRO
	vNecroPlayerEventKilled(victim);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnPlayerEventKilled(victim);
#endif
}

public Action MT_OnPlayerHitByVomitJar(int player, int thrower)
{
	Action aReturn = Plugin_Continue;
#if defined MT_MENU_SHIELD
	Action aResult = aShieldPlayerHitByVomitJar(player, thrower);
	if (aResult != Plugin_Continue)
	{
		aReturn = aResult;
	}
#endif
	return aReturn;
}

public Action MT_OnPlayerShovedBySurvivor(int player, int survivor, const float direction[3])
{
	Action aReturn = Plugin_Continue;
#if defined MT_MENU_SHIELD
	Action aResult = aShieldPlayerShovedBySurvivor(player, survivor);
	if (aResult != Plugin_Continue)
	{
		aReturn = aResult;
	}
#endif
	return aReturn;
}

public Action MT_OnRewardSurvivor(int survivor, int tank, int &type, int priority, float &duration, bool apply)
{
	Action aReturn = Plugin_Continue;
#if defined MT_MENU_RESPAWN
	Action aResult = aRespawnRewardSurvivor(tank, priority, apply);
	if (aResult != Plugin_Continue)
	{
		aReturn = aResult;
	}
#endif
#if defined MT_MENU_SLOW
	vSlowRewardSurvivor(survivor, type, apply);
#endif
	return aReturn;
}

public void MT_OnRockThrow(int tank, int rock)
{
#if defined MT_MENU_SHIELD
	vShieldRockThrow(tank, rock);
#endif
#if defined MT_MENU_THROW
	vThrowRockThrow(tank, rock);
#endif
#if defined MT_MENU_TRACK
	vTrackRockThrow(tank, rock);
#endif
}

public void MT_OnRockBreak(int tank, int rock)
{
#if defined MT_MENU_TRACK
	vTrackRockBreak(rock);
#endif
#if defined MT_MENU_WARP
	vWarpRockBreak(tank, rock);
#endif
}

void vAbilityMenu(int client, const char[] name)
{
#if defined MT_MENU_MEDIC
	vMedicMenu(client, name, 0);
#endif
#if defined MT_MENU_METEOR
	vMeteorMenu(client, name, 0);
#endif
#if defined MT_MENU_MINION
	vMinionMenu(client, name, 0);
#endif
#if defined MT_MENU_NECRO
	vNecroMenu(client, name, 0);
#endif
#if defined MT_MENU_NULLIFY
	vNullifyMenu(client, name, 0);
#endif
#if defined MT_MENU_OMNI
	vOmniMenu(client, name, 0);
#endif
#if defined MT_MENU_PANIC
	vPanicMenu(client, name, 0);
#endif
#if defined MT_MENU_PIMP
	vPimpMenu(client, name, 0);
#endif
#if defined MT_MENU_PUKE
	vPukeMenu(client, name, 0);
#endif
#if defined MT_MENU_PYRO
	vPyroMenu(client, name, 0);
#endif
#if defined MT_MENU_QUIET
	vQuietMenu(client, name, 0);
#endif
#if defined MT_MENU_RECOIL
	vRecoilMenu(client, name, 0);
#endif
#if defined MT_MENU_REGEN
	vRegenMenu(client, name, 0);
#endif
#if defined MT_MENU_RESPAWN
	vRespawnMenu(client, name, 0);
#endif
#if defined MT_MENU_RESTART
	vRestartMenu(client, name, 0);
#endif
#if defined MT_MENU_ROCK
	vRockMenu(client, name, 0);
#endif
#if defined MT_MENU_ROCKET
	vRocketMenu(client, name, 0);
#endif
#if defined MT_MENU_SHAKE
	vShakeMenu(client, name, 0);
#endif
#if defined MT_MENU_SHIELD
	vShieldMenu(client, name, 0);
#endif
#if defined MT_MENU_SHOVE
	vShoveMenu(client, name, 0);
#endif
#if defined MT_MENU_SLOW
	vSlowMenu(client, name, 0);
#endif
#if defined MT_MENU_SMASH
	vSmashMenu(client, name, 0);
#endif
#if defined MT_MENU_SMITE
	vSmiteMenu(client, name, 0);
#endif
#if defined MT_MENU_SPAM
	vSpamMenu(client, name, 0);
#endif
#if defined MT_MENU_SPLASH
	vSplashMenu(client, name, 0);
#endif
#if defined MT_MENU_SPLATTER
	vSplatterMenu(client, name, 0);
#endif
#if defined MT_MENU_THROW
	vThrowMenu(client, name, 0);
#endif
#if defined MT_MENU_TRACK
	vTrackMenu(client, name, 0);
#endif
#if defined MT_MENU_ULTIMATE
	vUltimateMenu(client, name, 0);
#endif
#if defined MT_MENU_UNDEAD
	vUndeadMenu(client, name, 0);
#endif
#if defined MT_MENU_VAMPIRE
	vVampireMenu(client, name, 0);
#endif
#if defined MT_MENU_VISION
	vVisionMenu(client, name, 0);
#endif
#if defined MT_MENU_WARP
	vWarpMenu(client, name, 0);
#endif
#if defined MT_MENU_WHIRL
	vWhirlMenu(client, name, 0);
#endif
#if defined MT_MENU_WITCH
	vWitchMenu(client, name, 0);
#endif
#if defined MT_MENU_XIPHOS
	vXiphosMenu(client, name, 0);
#endif
#if defined MT_MENU_YELL
	vYellMenu(client, name, 0);
#endif
#if defined MT_MENU_ZOMBIE
	vZombieMenu(client, name, 0);
#endif
	bool bLog = false;
	if (bLog)
	{
		MT_LogMessage(-1, "%s Ability Menu (%i, %s) - This should never fire.", MT_TAG, client, name);
	}
}

void vAbilityPlayer(int type, int client)
{
#if defined MT_MENU_MEDIC
	switch (type)
	{
		case 0: vMedicClientPutInServer(client);
		case 2: vMedicClientDisconnect_Post(client);
		case 3: vMedicAbilityActivated(client);
	}
#endif
#if defined MT_MENU_METEOR
	switch (type)
	{
		case 0: vMeteorClientPutInServer(client);
		case 2: vMeteorClientDisconnect_Post(client);
		case 3: vMeteorAbilityActivated(client);
	}
#endif
#if defined MT_MENU_MINION
	switch (type)
	{
		case 0: vMinionClientPutInServer(client);
		case 1: vMinionClientDisconnect(client);
		case 2: vMinionClientDisconnect_Post(client);
		case 3: vMinionAbilityActivated(client);
	}
#endif
#if defined MT_MENU_NECRO
	switch (type)
	{
		case 0: vNecroClientPutInServer(client);
		case 2: vNecroClientDisconnect_Post(client);
		case 3: vNecroAbilityActivated(client);
	}
#endif
#if defined MT_MENU_NULLIFY
	switch (type)
	{
		case 0: vNullifyClientPutInServer(client);
		case 2: vNullifyClientDisconnect_Post(client);
		case 3: vNullifyAbilityActivated(client);
	}
#endif
#if defined MT_MENU_OMNI
	switch (type)
	{
		case 0: vOmniClientPutInServer(client);
		case 2: vOmniClientDisconnect_Post(client);
		case 3: vOmniAbilityActivated(client);
		case 4: vOmniPostTankSpawn(client);
	}
#endif
#if defined MT_MENU_PANIC
	switch (type)
	{
		case 0: vPanicClientPutInServer(client);
		case 2: vPanicClientDisconnect_Post(client);
		case 3: vPanicAbilityActivated(client);
		case 4: vPanicPostTankSpawn(client);
	}
#endif
#if defined MT_MENU_PIMP
	switch (type)
	{
		case 0: vPimpClientPutInServer(client);
		case 2: vPimpClientDisconnect_Post(client);
		case 3: vPimpAbilityActivated(client);
	}
#endif
#if defined MT_MENU_PUKE
	switch (type)
	{
		case 0: vPukeClientPutInServer(client);
		case 2: vPukeClientDisconnect_Post(client);
		case 3: vPukeAbilityActivated(client);
		case 4: vPukePostTankSpawn(client);
	}
#endif
#if defined MT_MENU_PYRO
	switch (type)
	{
		case 0: vPyroClientPutInServer(client);
		case 2: vPyroClientDisconnect_Post(client);
		case 3: vPyroAbilityActivated(client);
	}
#endif
#if defined MT_MENU_QUIET
	switch (type)
	{
		case 0: vQuietClientPutInServer(client);
		case 2: vQuietClientDisconnect_Post(client);
		case 3: vQuietAbilityActivated(client);
	}
#endif
#if defined MT_MENU_RECOIL
	switch (type)
	{
		case 0: vRecoilClientPutInServer(client);
		case 2: vRecoilClientDisconnect_Post(client);
		case 3: vRecoilAbilityActivated(client);
	}
#endif
#if defined MT_MENU_REGEN
	switch (type)
	{
		case 0: vRegenClientPutInServer(client);
		case 2: vRegenClientDisconnect_Post(client);
		case 3: vRegenAbilityActivated(client);
	}
#endif
#if defined MT_MENU_RESPAWN
	switch (type)
	{
		case 0: vRespawnClientPutInServer(client);
		case 2: vRespawnClientDisconnect_Post(client);
	}
#endif
#if defined MT_MENU_RESTART
	switch (type)
	{
		case 0: vRestartClientPutInServer(client);
		case 2: vRestartClientDisconnect_Post(client);
		case 3: vRestartAbilityActivated(client);
	}
#endif
#if defined MT_MENU_ROCK
	switch (type)
	{
		case 0: vRockClientPutInServer(client);
		case 2: vRockClientDisconnect_Post(client);
		case 3: vRockAbilityActivated(client);
	}
#endif
#if defined MT_MENU_ROCKET
	switch (type)
	{
		case 0: vRocketClientPutInServer(client);
		case 2: vRocketClientDisconnect_Post(client);
		case 3: vRocketAbilityActivated(client);
	}
#endif
#if defined MT_MENU_SHAKE
	switch (type)
	{
		case 0: vShakeClientPutInServer(client);
		case 2: vShakeClientDisconnect_Post(client);
		case 3: vShakeAbilityActivated(client);
		case 4: vShakePostTankSpawn(client);
	}
#endif
#if defined MT_MENU_SHIELD
	switch (type)
	{
		case 0: vShieldClientPutInServer(client);
		case 2: vShieldClientDisconnect_Post(client);
		case 3: vShieldAbilityActivated(client);
	}
#endif
#if defined MT_MENU_SHOVE
	switch (type)
	{
		case 0: vShoveClientPutInServer(client);
		case 2: vShoveClientDisconnect_Post(client);
		case 3: vShoveAbilityActivated(client);
		case 4: vShovePostTankSpawn(client);
	}
#endif
#if defined MT_MENU_SLOW
	switch (type)
	{
		case 0: vSlowClientPutInServer(client);
		case 2: vSlowClientDisconnect_Post(client);
		case 3: vSlowAbilityActivated(client);
	}
#endif
#if defined MT_MENU_SMASH
	switch (type)
	{
		case 0: vSmashClientPutInServer(client);
		case 2: vSmashClientDisconnect_Post(client);
		case 3: vSmashAbilityActivated(client);
	}
#endif
#if defined MT_MENU_SMITE
	switch (type)
	{
		case 0: vSmiteClientPutInServer(client);
		case 2: vSmiteClientDisconnect_Post(client);
		case 3: vSmiteAbilityActivated(client);
	}
#endif
#if defined MT_MENU_SPAM
	switch (type)
	{
		case 0: vSpamClientPutInServer(client);
		case 2: vSpamClientDisconnect_Post(client);
		case 3: vSpamAbilityActivated(client);
	}
#endif
#if defined MT_MENU_SPLASH
	switch (type)
	{
		case 0: vSplashClientPutInServer(client);
		case 2: vSplashClientDisconnect_Post(client);
		case 3: vSplashAbilityActivated(client);
	}
#endif
#if defined MT_MENU_SPLATTER
	switch (type)
	{
		case 0: vSplatterClientPutInServer(client);
		case 2: vSplatterClientDisconnect_Post(client);
		case 3: vSplatterAbilityActivated(client);
	}
#endif
#if defined MT_MENU_THROW
	switch (type)
	{
		case 0: vThrowClientPutInServer(client);
		case 2: vThrowClientDisconnect_Post(client);
	}
#endif
#if defined MT_MENU_TRACK
	switch (type)
	{
		case 0: vTrackClientPutInServer(client);
		case 2: vTrackClientDisconnect_Post(client);
	}
#endif
#if defined MT_MENU_ULTIMATE
	switch (type)
	{
		case 0: vUltimateClientPutInServer(client);
		case 2: vUltimateClientDisconnect_Post(client);
		case 3: vUltimateAbilityActivated(client);
	}
#endif
#if defined MT_MENU_UNDEAD
	switch (type)
	{
		case 0: vUndeadClientPutInServer(client);
		case 2: vUndeadClientDisconnect_Post(client);
		case 3: vUndeadAbilityActivated(client);
	}
#endif
#if defined MT_MENU_VAMPIRE
	if (type == 0)
	{
		vVampireClientPutInServer(client);
	}
#endif
#if defined MT_MENU_VISION
	switch (type)
	{
		case 0: vVisionClientPutInServer(client);
		case 2: vVisionClientDisconnect_Post(client);
		case 3: vVisionAbilityActivated(client);
	}
#endif
#if defined MT_MENU_WARP
	switch (type)
	{
		case 0: vWarpClientPutInServer(client);
		case 2: vWarpClientDisconnect_Post(client);
		case 3: vWarpAbilityActivated(client);
		case 4: vWarpPostTankSpawn(client);
	}
#endif
#if defined MT_MENU_WHIRL
	switch (type)
	{
		case 0: vWhirlClientPutInServer(client);
		case 2: vWhirlClientDisconnect_Post(client);
		case 3: vWhirlAbilityActivated(client);
	}
#endif
#if defined MT_MENU_WITCH
	switch (type)
	{
		case 0: vWitchClientPutInServer(client);
		case 2: vWitchClientDisconnect_Post(client);
		case 3: vWitchAbilityActivated(client);
		case 4: vWitchPostTankSpawn(client);
	}
#endif
#if defined MT_MENU_XIPHOS
	if (type == 0)
	{
		vXiphosClientPutInServer(client);
	}
#endif
#if defined MT_MENU_YELL
	switch (type)
	{
		case 0: vYellClientPutInServer(client);
		case 2: vYellClientDisconnect_Post(client);
		case 3: vYellAbilityActivated(client);
	}
#endif
#if defined MT_MENU_ZOMBIE
	switch (type)
	{
		case 0: vZombieClientPutInServer(client);
		case 2: vZombieClientDisconnect_Post(client);
		case 3: vZombieAbilityActivated(client);
		case 4: vZombiePostTankSpawn(client);
	}
#endif
	bool bLog = false;
	if (bLog)
	{
		MT_LogMessage(-1, "%s Ability Player (%i, %i) - This should never fire.", MT_TAG, type, client);
	}
}

void vAbilitySetup(int type)
{
#if defined MT_MENU_MEDIC
	switch (type)
	{
		case 1: vMedicMapStart();
		case 2: vMedicMapEnd();
	}
#endif
#if defined MT_MENU_METEOR
	switch (type)
	{
		case 1: vMeteorMapStart();
		case 2: vMeteorMapEnd();
	}
#endif
#if defined MT_MENU_MINION
	switch (type)
	{
		case 1: vMinionMapStart();
		case 2: vMinionMapEnd();
		case 3: vMinionPluginEnd();
	}
#endif
#if defined MT_MENU_NECRO
	switch (type)
	{
		case 1: vNecroMapStart();
		case 2: vNecroMapEnd();
	}
#endif
#if defined MT_MENU_NULLIFY
	switch (type)
	{
		case 1: vNullifyMapStart();
		case 2: vNullifyMapEnd();
	}
#endif
#if defined MT_MENU_OMNI
	switch (type)
	{
		case 1: vOmniMapStart();
		case 2: vOmniMapEnd();
	}
#endif
#if defined MT_MENU_PANIC
	switch (type)
	{
		case 1: vPanicMapStart();
		case 2: vPanicMapEnd();
	}
#endif
#if defined MT_MENU_PIMP
	switch (type)
	{
		case 1: vPimpMapStart();
		case 2: vPimpMapEnd();
	}
#endif
#if defined MT_MENU_PUKE
	switch (type)
	{
		case 1: vPukeMapStart();
		case 2: vPukeMapEnd();
	}
#endif
#if defined MT_MENU_PYRO
	switch (type)
	{
		case 1: vPyroMapStart();
		case 2: vPyroMapEnd();
		case 3: vPyroPluginEnd();
	}
#endif
#if defined MT_MENU_QUIET
	switch (type)
	{
		case 1: vQuietMapStart();
		case 2: vQuietMapEnd();
	}
#endif
#if defined MT_MENU_RECOIL
	switch (type)
	{
		case 1: vRecoilMapStart();
		case 2: vRecoilMapEnd();
	}
#endif
#if defined MT_MENU_REGEN
	switch (type)
	{
		case 1: vRegenMapStart();
		case 2: vRegenMapEnd();
	}
#endif
#if defined MT_MENU_RESPAWN
	switch (type)
	{
		case 1: vRespawnMapStart();
		case 2: vRespawnMapEnd();
	}
#endif
#if defined MT_MENU_RESTART
	switch (type)
	{
		case 1: vRestartMapStart();
		case 2: vRestartMapEnd();
	}
#endif
#if defined MT_MENU_ROCK
	switch (type)
	{
		case 1: vRockMapStart();
		case 2: vRockMapEnd();
	}
#endif
#if defined MT_MENU_ROCKET
	switch (type)
	{
		case 1: vRocketMapStart();
		case 2: vRocketMapEnd();
		case 3: vRocketPluginEnd();
	}
#endif
#if defined MT_MENU_SHAKE
	switch (type)
	{
		case 1: vShakeMapStart();
		case 2: vShakeMapEnd();
	}
#endif
#if defined MT_MENU_SHIELD
	switch (type)
	{
		case 0: vShieldPluginStart();
		case 1: vShieldMapStart();
		case 2: vShieldMapEnd();
		case 3: vShieldPluginEnd();
	}
#endif
#if defined MT_MENU_SHOVE
	switch (type)
	{
		case 1: vShoveMapStart();
		case 2: vShoveMapEnd();
	}
#endif
#if defined MT_MENU_SLOW
	switch (type)
	{
		case 1: vSlowMapStart();
		case 2: vSlowMapEnd();
		case 3: vSlowPluginEnd();
	}
#endif
#if defined MT_MENU_SMASH
	switch (type)
	{
		case 1: vSmashMapStart();
		case 2: vSmashMapEnd();
	}
#endif
#if defined MT_MENU_SMITE
	switch (type)
	{
		case 1: vSmiteMapStart();
		case 2: vSmiteMapEnd();
	}
#endif
#if defined MT_MENU_SPAM
	switch (type)
	{
		case 1: vSpamMapStart();
		case 2: vSpamMapEnd();
	}
#endif
#if defined MT_MENU_SPLASH
	switch (type)
	{
		case 1: vSplashMapStart();
		case 2: vSplashMapEnd();
	}
#endif
#if defined MT_MENU_SPLATTER
	switch (type)
	{
		case 1: vSplatterMapStart();
		case 2: vSplatterMapEnd();
	}
#endif
#if defined MT_MENU_THROW
	switch (type)
	{
		case 0: vThrowPluginStart();
		case 1: vThrowMapStart();
		case 2: vThrowMapEnd();
		case 3: vThrowPluginEnd();
	}
#endif
#if defined MT_MENU_TRACK
	switch (type)
	{
		case 1: vTrackMapStart();
		case 2: vTrackMapEnd();
	}
#endif
#if defined MT_MENU_ULTIMATE
	switch (type)
	{
		case 1: vUltimateMapStart();
		case 2: vUltimateMapEnd();
		case 3: vUltimatePluginEnd();
	}
#endif
#if defined MT_MENU_UNDEAD
	switch (type)
	{
		case 1: vUndeadMapStart();
		case 2: vUndeadMapEnd();
	}
#endif
#if defined MT_MENU_VISION
	switch (type)
	{
		case 1: vVisionMapStart();
		case 2: vVisionMapEnd();
		case 3: vVisionPluginEnd();
	}
#endif
#if defined MT_MENU_WARP
	switch (type)
	{
		case 1: vWarpMapStart();
		case 2: vWarpMapEnd();
	}
#endif
#if defined MT_MENU_WHIRL
	switch (type)
	{
		case 1: vWhirlMapStart();
		case 2: vWhirlMapEnd();
		case 3: vWhirlPluginEnd();
	}
#endif
#if defined MT_MENU_WITCH
	switch (type)
	{
		case 1: vWitchMapStart();
		case 2: vWitchMapEnd();
	}
#endif
#if defined MT_MENU_YELL
	switch (type)
	{
		case 1: vYellMapStart();
		case 2: vYellMapEnd();
	}
#endif
#if defined MT_MENU_ZOMBIE
	switch (type)
	{
		case 1: vZombieMapStart();
		case 2: vZombieMapEnd();
	}
#endif
	bool bLog = false;
	if (bLog)
	{
		MT_LogMessage(-1, "%s Ability Setup (%i) - This should never fire.", MT_TAG, type);
	}
}