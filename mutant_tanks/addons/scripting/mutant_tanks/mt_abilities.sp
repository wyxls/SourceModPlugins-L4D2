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

#define MT_ABILITIES_MAIN
#define MT_ABILITIES_GROUP 3 // 0: NONE, 1: Only include first half (1-20), 2: Only include second half (21-38), 3: ALL
#define MT_ABILITIES_COMPILER_MESSAGE 1 // 0: NONE, 1: Display warning messages about excluded abilities, 2: Display error messages about excluded abilities

#include <sourcemod>
#include <mutant_tanks>
#include <mt_clone>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[MT] Abilities Set #1",
	author = MT_AUTHOR,
	description = "Provides several abilities for Mutant Tanks.",
	version = MT_VERSION,
	url = MT_URL
};

#define MT_GAMEDATA "mutant_tanks"
#define MT_GAMEDATA_TEMP "mutant_tanks_temp"

bool g_bDedicated, g_bLateLoad, g_bSecondGame;

#undef REQUIRE_PLUGIN
#if MT_ABILITIES_GROUP == 1 || MT_ABILITIES_GROUP == 3
	#tryinclude "mutant_tanks/abilities/mt_absorb.sp"
	#tryinclude "mutant_tanks/abilities/mt_acid.sp"
	#tryinclude "mutant_tanks/abilities/mt_aimless.sp"
	#tryinclude "mutant_tanks/abilities/mt_ammo.sp"
	#tryinclude "mutant_tanks/abilities/mt_blind.sp"
	#tryinclude "mutant_tanks/abilities/mt_bomb.sp"
	#tryinclude "mutant_tanks/abilities/mt_bury.sp"
	#tryinclude "mutant_tanks/abilities/mt_car.sp"
	#tryinclude "mutant_tanks/abilities/mt_choke.sp"
	#tryinclude "mutant_tanks/abilities/mt_clone.sp"
	#tryinclude "mutant_tanks/abilities/mt_cloud.sp"
	#tryinclude "mutant_tanks/abilities/mt_drop.sp"
	#tryinclude "mutant_tanks/abilities/mt_drug.sp"
	#tryinclude "mutant_tanks/abilities/mt_drunk.sp"
	#tryinclude "mutant_tanks/abilities/mt_electric.sp"
	#tryinclude "mutant_tanks/abilities/mt_enforce.sp"
	#tryinclude "mutant_tanks/abilities/mt_fast.sp"
	#tryinclude "mutant_tanks/abilities/mt_fire.sp"
	#tryinclude "mutant_tanks/abilities/mt_fling.sp"
	#tryinclude "mutant_tanks/abilities/mt_fly.sp"
#endif
#if MT_ABILITIES_GROUP == 2 || MT_ABILITIES_GROUP == 3
	#tryinclude "mutant_tanks/abilities/mt_fragile.sp"
	#tryinclude "mutant_tanks/abilities/mt_ghost.sp"
	#tryinclude "mutant_tanks/abilities/mt_god.sp"
	#tryinclude "mutant_tanks/abilities/mt_gravity.sp"
	#tryinclude "mutant_tanks/abilities/mt_gunner.sp"
	#tryinclude "mutant_tanks/abilities/mt_heal.sp"
	#tryinclude "mutant_tanks/abilities/mt_hit.sp"
	#tryinclude "mutant_tanks/abilities/mt_hurt.sp"
	#tryinclude "mutant_tanks/abilities/mt_hypno.sp"
	#tryinclude "mutant_tanks/abilities/mt_ice.sp"
	#tryinclude "mutant_tanks/abilities/mt_idle.sp"
	#tryinclude "mutant_tanks/abilities/mt_invert.sp"
	#tryinclude "mutant_tanks/abilities/mt_item.sp"
	#tryinclude "mutant_tanks/abilities/mt_jump.sp"
	#tryinclude "mutant_tanks/abilities/mt_kamikaze.sp"
	#tryinclude "mutant_tanks/abilities/mt_lag.sp"
	#tryinclude "mutant_tanks/abilities/mt_laser.sp"
	#tryinclude "mutant_tanks/abilities/mt_leech.sp"
	#tryinclude "mutant_tanks/abilities/mt_lightning.sp"
#endif
#define REQUIRE_PLUGIN

#if MT_ABILITIES_COMPILER_MESSAGE == 1
	#if !defined MT_MENU_ABSORB
		#warning The "Absorb" (mt_absorb.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ACID
		#warning The "Acid" (mt_acid.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_AIMLESS
		#warning The "Aimless" (mt_aimless.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_AMMO
		#warning The "Ammo" (mt_ammo.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_BLIND
		#warning The "Blind" (mt_blind.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_BOMB
		#warning The "Bomb" (mt_bomb.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_BURY
		#warning The "Bury" (mt_bury.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_CAR
		#warning The "Car" (mt_car.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_CHOKE
		#warning The "Choke" (mt_choke.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_CLONE
		#warning The "Clone" (mt_clone.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_CLOUD
		#warning The "Cloud" (mt_cloud.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_DROP
		#warning The "Drop" (mt_drop.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_DRUG
		#warning The "Drug" (mt_drug.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_DRUNK
		#warning The "Drunk" (mt_drunk.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ELECTRIC
		#warning The "Electric" (mt_electric.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ENFORCE
		#warning The "Enforce" (mt_enforce.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FAST
		#warning The "Fast" (mt_fast.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FIRE
		#warning The "Fire" (mt_fire.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FLING
		#warning The "Fling" (mt_fling.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FLY
		#warning The "Fly" (mt_fly.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FRAGILE
		#warning The "Fragile" (mt_fragile.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_GHOST
		#warning The "Ghost" (mt_ghost.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_GOD
		#warning The "God" (mt_god.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_GRAVITY
		#warning The "Gravity" (mt_gravity.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_GUNNER
		#warning The "Gunner" (mt_gunner.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_HEAL
		#warning The "Heal" (mt_heal.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_HIT
		#warning The "Hit" (mt_hit.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_HURT
		#warning The "Hurt" (mt_hurt.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_HYPNO
		#warning The "Hypno" (mt_hypno.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ICE
		#warning The "Ice" (mt_ice.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_IDLE
		#warning The "Idle" (mt_idle.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_INVERT
		#warning The "Invert" (mt_invert.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ITEM
		#warning The "Item" (mt_item.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_JUMP
		#warning The "Jump" (mt_jump.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_KAMIKAZE
		#warning The "Kamikaze" (mt_kamikaze.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_LAG
		#warning The "Lag" (mt_lag.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_LASER
		#warning The "Laser" (mt_laser.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_LEECH
		#warning The "Leech" (mt_leech.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_LIGHTNING
		#warning The "Lightning" (mt_lightning.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
#endif
#if MT_ABILITIES_COMPILER_MESSAGE == 2
	#if !defined MT_MENU_ABSORB
		#error The "Absorb" (mt_absorb.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ACID
		#error The "Acid" (mt_acid.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_AIMLESS
		#error The "Aimless" (mt_aimless.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_AMMO
		#error The "Ammo" (mt_ammo.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_BLIND
		#error The "Blind" (mt_blind.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_BOMB
		#error The "Bomb" (mt_bomb.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_BURY
		#error The "Bury" (mt_bury.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_CAR
		#error The "Car" (mt_car.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_CHOKE
		#error The "Choke" (mt_choke.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_CLONE
		#error The "Clone" (mt_clone.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_CLOUD
		#error The "Cloud" (mt_cloud.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_DROP
		#error The "Drop" (mt_drop.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_DRUG
		#error The "Drug" (mt_drug.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_DRUNK
		#error The "Drunk" (mt_drunk.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ELECTRIC
		#error The "Electric" (mt_electric.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ENFORCE
		#error The "Enforce" (mt_enforce.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FAST
		#error The "Fast" (mt_fast.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FIRE
		#error The "Fire" (mt_fire.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FLING
		#error The "Fling" (mt_fling.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FLY
		#error The "Fly" (mt_fly.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_FRAGILE
		#error The "Fragile" (mt_fragile.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_GHOST
		#error The "Ghost" (mt_ghost.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_GOD
		#error The "God" (mt_god.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_GRAVITY
		#error The "Gravity" (mt_gravity.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_GUNNER
		#error The "Gunner" (mt_gunner.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_HEAL
		#error The "Heal" (mt_heal.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_HIT
		#error The "Hit" (mt_hit.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_HURT
		#error The "Hurt" (mt_hurt.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_HYPNO
		#error The "Hypno" (mt_hypno.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ICE
		#error The "Ice" (mt_ice.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_IDLE
		#error The "Idle" (mt_idle.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_INVERT
		#error The "Invert" (mt_invert.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_ITEM
		#error The "Item" (mt_item.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_JUMP
		#error The "Jump" (mt_jump.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_KAMIKAZE
		#error The "Kamikaze" (mt_kamikaze.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_LAG
		#error The "Lag" (mt_lag.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_LASER
		#error The "Laser" (mt_laser.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_LEECH
		#error The "Leech" (mt_leech.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
	#endif
	#if !defined MT_MENU_LIGHTNING
		#error The "Lightning" (mt_lightning.sp) ability is missing from the "scripting/mutant_tanks/abilities" folder.
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
			strcopy(error, err_max, "\"[MT] Abilities Set #1\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}
#if defined MT_MENU_CLONE
	CreateNative("MT_IsCloneSupported", aNative_IsCloneSupported);
	CreateNative("MT_IsTankClone", aNative_IsTankClone);

	RegPluginLibrary("mt_clone");
#endif
	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}

#if defined MT_MENU_CLONE
any aNative_IsCloneSupported(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && g_esClonePlayer[iTank].g_bCloned && g_esClonePlayer[iTank].g_bFiltered)
	{
		return false;
	}

	return true;
}

any aNative_IsTankClone(Handle plugin, int numParams)
{
	int iTank = GetNativeCell(1);
	return MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && g_esClonePlayer[iTank].g_bCloned;
}
#endif

public void OnAllPluginsLoaded()
{
	GameData gdMutantTanks = new GameData(MT_GAMEDATA);
	if (gdMutantTanks == null)
	{
		LogError("%s Unable to load the \"%s\" gamedata file.", MT_TAG, MT_GAMEDATA);

		return;
	}
#if defined MT_MENU_ACID
	vAcidAllPluginsLoaded(gdMutantTanks);
#endif
#if defined MT_MENU_BURY
	vBuryAllPluginsLoaded(gdMutantTanks);
#endif
#if defined MT_MENU_DROP
	vDropAllPluginsLoaded(gdMutantTanks);
#endif
#if defined MT_MENU_FLING
	vFlingAllPluginsLoaded(gdMutantTanks);
#endif
#if defined MT_MENU_IDLE
	vIdleAllPluginsLoaded(gdMutantTanks);
#endif
	delete gdMutantTanks;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_ability", cmdAbilityInfo, "View information about each ability (A-L).");

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
#if defined MT_MENU_ITEM
	vItemEntityCreated(entity, classname);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeEntityCreated(entity, classname);
#endif
}

Action cmdAbilityInfo(int client, int args)
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
#if defined MT_MENU_ABSORB
	vAbsorbDisplayMenu(menu);
#endif
#if defined MT_MENU_ACID
	vAcidDisplayMenu(menu);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessDisplayMenu(menu);
#endif
#if defined MT_MENU_AMMO
	vAmmoDisplayMenu(menu);
#endif
#if defined MT_MENU_BLIND
	vBlindDisplayMenu(menu);
#endif
#if defined MT_MENU_BOMB
	vBombDisplayMenu(menu);
#endif
#if defined MT_MENU_BURY
	vBuryDisplayMenu(menu);
#endif
#if defined MT_MENU_CAR
	vCarDisplayMenu(menu);
#endif
#if defined MT_MENU_CHOKE
	vChokeDisplayMenu(menu);
#endif
#if defined MT_MENU_CLONE
	vCloneDisplayMenu(menu);
#endif
#if defined MT_MENU_CLOUD
	vCloudDisplayMenu(menu);
#endif
#if defined MT_MENU_DROP
	vDropDisplayMenu(menu);
#endif
#if defined MT_MENU_DRUG
	vDrugDisplayMenu(menu);
#endif
#if defined MT_MENU_DRUNK
	vDrunkDisplayMenu(menu);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricDisplayMenu(menu);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceDisplayMenu(menu);
#endif
#if defined MT_MENU_FAST
	vFastDisplayMenu(menu);
#endif
#if defined MT_MENU_FIRE
	vFireDisplayMenu(menu);
#endif
#if defined MT_MENU_FLING
	vFlingDisplayMenu(menu);
#endif
#if defined MT_MENU_FLY
	vFlyDisplayMenu(menu);
#endif
#if defined MT_MENU_FRAGILE
	vFragileDisplayMenu(menu);
#endif
#if defined MT_MENU_GHOST
	vGhostDisplayMenu(menu);
#endif
#if defined MT_MENU_GOD
	vGodDisplayMenu(menu);
#endif
#if defined MT_MENU_GRAVITY
	vGravityDisplayMenu(menu);
#endif
#if defined MT_MENU_GUNNER
	vGunnerDisplayMenu(menu);
#endif
#if defined MT_MENU_HEAL
	vHealDisplayMenu(menu);
#endif
#if defined MT_MENU_HIT
	vHitDisplayMenu(menu);
#endif
#if defined MT_MENU_HURT
	vHurtDisplayMenu(menu);
#endif
#if defined MT_MENU_HYPNO
	vHypnoDisplayMenu(menu);
#endif
#if defined MT_MENU_ICE
	vIceDisplayMenu(menu);
#endif
#if defined MT_MENU_IDLE
	vIdleDisplayMenu(menu);
#endif
#if defined MT_MENU_INVERT
	vInvertDisplayMenu(menu);
#endif
#if defined MT_MENU_ITEM
	vItemDisplayMenu(menu);
#endif
#if defined MT_MENU_JUMP
	vJumpDisplayMenu(menu);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeDisplayMenu(menu);
#endif
#if defined MT_MENU_LAG
	vLagDisplayMenu(menu);
#endif
#if defined MT_MENU_LASER
	vLaserDisplayMenu(menu);
#endif
#if defined MT_MENU_LEECH
	vLeechDisplayMenu(menu);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningDisplayMenu(menu);
#endif
}

public void MT_OnMenuItemSelected(int client, const char[] info)
{
#if defined MT_MENU_ABSORB
	vAbsorbMenuItemSelected(client, info);
#endif
#if defined MT_MENU_ACID
	vAcidMenuItemSelected(client, info);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessMenuItemSelected(client, info);
#endif
#if defined MT_MENU_AMMO
	vAmmoMenuItemSelected(client, info);
#endif
#if defined MT_MENU_BLIND
	vBlindMenuItemSelected(client, info);
#endif
#if defined MT_MENU_BOMB
	vBombMenuItemSelected(client, info);
#endif
#if defined MT_MENU_BURY
	vBuryMenuItemSelected(client, info);
#endif
#if defined MT_MENU_CAR
	vCarMenuItemSelected(client, info);
#endif
#if defined MT_MENU_CHOKE
	vChokeMenuItemSelected(client, info);
#endif
#if defined MT_MENU_CLONE
	vCloneMenuItemSelected(client, info);
#endif
#if defined MT_MENU_CLOUD
	vCloudMenuItemSelected(client, info);
#endif
#if defined MT_MENU_DROP
	vDropMenuItemSelected(client, info);
#endif
#if defined MT_MENU_DRUG
	vDrugMenuItemSelected(client, info);
#endif
#if defined MT_MENU_DRUNK
	vDrunkMenuItemSelected(client, info);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricMenuItemSelected(client, info);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceMenuItemSelected(client, info);
#endif
#if defined MT_MENU_FAST
	vFastMenuItemSelected(client, info);
#endif
#if defined MT_MENU_FIRE
	vFireMenuItemSelected(client, info);
#endif
#if defined MT_MENU_FLING
	vFlingMenuItemSelected(client, info);
#endif
#if defined MT_MENU_FLY
	vFlyMenuItemSelected(client, info);
#endif
#if defined MT_MENU_FRAGILE
	vFragileMenuItemSelected(client, info);
#endif
#if defined MT_MENU_GHOST
	vGhostMenuItemSelected(client, info);
#endif
#if defined MT_MENU_GOD
	vGodMenuItemSelected(client, info);
#endif
#if defined MT_MENU_GRAVITY
	vGravityMenuItemSelected(client, info);
#endif
#if defined MT_MENU_GUNNER
	vGunnerMenuItemSelected(client, info);
#endif
#if defined MT_MENU_HEAL
	vHealMenuItemSelected(client, info);
#endif
#if defined MT_MENU_HIT
	vHitMenuItemSelected(client, info);
#endif
#if defined MT_MENU_HURT
	vHurtMenuItemSelected(client, info);
#endif
#if defined MT_MENU_HYPNO
	vHypnoMenuItemSelected(client, info);
#endif
#if defined MT_MENU_ICE
	vIceMenuItemSelected(client, info);
#endif
#if defined MT_MENU_IDLE
	vIdleMenuItemSelected(client, info);
#endif
#if defined MT_MENU_INVERT
	vInvertMenuItemSelected(client, info);
#endif
#if defined MT_MENU_ITEM
	vItemMenuItemSelected(client, info);
#endif
#if defined MT_MENU_JUMP
	vJumpMenuItemSelected(client, info);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeMenuItemSelected(client, info);
#endif
#if defined MT_MENU_LAG
	vLagMenuItemSelected(client, info);
#endif
#if defined MT_MENU_LASER
	vLaserMenuItemSelected(client, info);
#endif
#if defined MT_MENU_LEECH
	vLeechMenuItemSelected(client, info);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningMenuItemSelected(client, info);
#endif
}

public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
{
#if defined MT_MENU_ABSORB
	vAbsorbMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_ACID
	vAcidMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_AMMO
	vAmmoMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_BLIND
	vBlindMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_BOMB
	vBombMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_BURY
	vBuryMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_CAR
	vCarMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_CHOKE
	vChokeMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_CLONE
	vCloneMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_CLOUD
	vCloudMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_DROP
	vDropMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_DRUG
	vDrugMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_DRUNK
	vDrunkMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_FAST
	vFastMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_FIRE
	vFireMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_FLING
	vFlingMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_FLY
	vFlyMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_FRAGILE
	vFragileMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_GHOST
	vGhostMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_GOD
	vGodMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_GRAVITY
	vGravityMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_GUNNER
	vGunnerMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_HEAL
	vHealMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_HIT
	vHitMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_HURT
	vHurtMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_HYPNO
	vHypnoMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_ICE
	vIceMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_IDLE
	vIdleMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_INVERT
	vInvertMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_ITEM
	vItemMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_JUMP
	vJumpMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_LAG
	vLagMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_LASER
	vLaserMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_LEECH
	vLeechMenuItemDisplayed(client, info, buffer, size);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningMenuItemDisplayed(client, info, buffer, size);
#endif
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!MT_IsCorePluginEnabled())
	{
		return Plugin_Continue;
	}

	Action aReturn = Plugin_Continue;
#if defined MT_MENU_ABSORB
	vAbsorbPlayerRunCmd(client);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessPlayerRunCmd(client);
#endif
#if defined MT_MENU_BURY
	Action aResult = aBuryPlayerRunCmd(client, buttons);
	if (aResult != Plugin_Continue)
	{
		aReturn = aResult;
	}
#endif
#if defined MT_MENU_CHOKE
	Action aResult2 = aChokePlayerRunCmd(client, buttons);
	if (aResult2 != Plugin_Continue)
	{
		aReturn = aResult2;
	}
#endif
#if defined MT_MENU_ENFORCE
	Action aResult3 = aEnforcePlayerRunCmd(client, weapon);
	if (aResult3 != Plugin_Continue)
	{
		aReturn = aResult3;
	}
#endif
#if defined MT_MENU_FAST
	vFastPlayerRunCmd(client);
#endif
#if defined MT_MENU_FLY
	vFlyPlayerRunCmd(client);
#endif
#if defined MT_MENU_FRAGILE
	vFragilePlayerRunCmd(client);
#endif
#if defined MT_MENU_GHOST
	vGhostPlayerRunCmd(client);
#endif
#if defined MT_MENU_GOD
	vGodPlayerRunCmd(client);
#endif
#if defined MT_MENU_GRAVITY
	vGravityPlayerRunCmd(client);
#endif
#if defined MT_MENU_INVERT
	Action aResult4 = aInvertPlayerRunCmd(client, buttons, vel);
	if (aResult4 != Plugin_Continue)
	{
		aReturn = aResult4;
	}
#endif
	return aReturn;
}

public void MT_OnPluginCheck(ArrayList list)
{
#if defined MT_MENU_ABSORB
	vAbsorbPluginCheck(list);
#endif
#if defined MT_MENU_ACID
	vAcidPluginCheck(list);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessPluginCheck(list);
#endif
#if defined MT_MENU_AMMO
	vAmmoPluginCheck(list);
#endif
#if defined MT_MENU_BLIND
	vBlindPluginCheck(list);
#endif
#if defined MT_MENU_BOMB
	vBombPluginCheck(list);
#endif
#if defined MT_MENU_BURY
	vBuryPluginCheck(list);
#endif
#if defined MT_MENU_CAR
	vCarPluginCheck(list);
#endif
#if defined MT_MENU_CHOKE
	vChokePluginCheck(list);
#endif
#if defined MT_MENU_CLONE
	vClonePluginCheck(list);
#endif
#if defined MT_MENU_CLOUD
	vCloudPluginCheck(list);
#endif
#if defined MT_MENU_DROP
	vDropPluginCheck(list);
#endif
#if defined MT_MENU_DRUG
	vDrugPluginCheck(list);
#endif
#if defined MT_MENU_DRUNK
	vDrunkPluginCheck(list);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricPluginCheck(list);
#endif
#if defined MT_MENU_ENFORCE
	vEnforcePluginCheck(list);
#endif
#if defined MT_MENU_FAST
	vFastPluginCheck(list);
#endif
#if defined MT_MENU_FIRE
	vFirePluginCheck(list);
#endif
#if defined MT_MENU_FLING
	vFlingPluginCheck(list);
#endif
#if defined MT_MENU_FLY
	vFlyPluginCheck(list);
#endif
#if defined MT_MENU_FRAGILE
	vFragilePluginCheck(list);
#endif
#if defined MT_MENU_GHOST
	vGhostPluginCheck(list);
#endif
#if defined MT_MENU_GOD
	vGodPluginCheck(list);
#endif
#if defined MT_MENU_GRAVITY
	vGravityPluginCheck(list);
#endif
#if defined MT_MENU_GUNNER
	vGunnerPluginCheck(list);
#endif
#if defined MT_MENU_HEAL
	vHealPluginCheck(list);
#endif
#if defined MT_MENU_HIT
	vHitPluginCheck(list);
#endif
#if defined MT_MENU_HURT
	vHurtPluginCheck(list);
#endif
#if defined MT_MENU_HYPNO
	vHypnoPluginCheck(list);
#endif
#if defined MT_MENU_ICE
	vIcePluginCheck(list);
#endif
#if defined MT_MENU_IDLE
	vIdlePluginCheck(list);
#endif
#if defined MT_MENU_INVERT
	vInvertPluginCheck(list);
#endif
#if defined MT_MENU_ITEM
	vItemPluginCheck(list);
#endif
#if defined MT_MENU_JUMP
	vJumpPluginCheck(list);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazePluginCheck(list);
#endif
#if defined MT_MENU_LAG
	vLagPluginCheck(list);
#endif
#if defined MT_MENU_LASER
	vLaserPluginCheck(list);
#endif
#if defined MT_MENU_LEECH
	vLeechPluginCheck(list);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningPluginCheck(list);
#endif
}

public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
{
#if defined MT_MENU_ABSORB
	vAbsorbAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_ACID
	vAcidAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_AMMO
	vAmmoAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_BLIND
	vBlindAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_BOMB
	vBombAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_BURY
	vBuryAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_CAR
	vCarAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_CHOKE
	vChokeAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_CLONE
	vCloneAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_CLOUD
	vCloudAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_DROP
	vDropAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_DRUG
	vDrugAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_DRUNK
	vDrunkAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_FAST
	vFastAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_FIRE
	vFireAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_FLING
	vFlingAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_FLY
	vFlyAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_FRAGILE
	vFragileAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_GHOST
	vGhostAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_GOD
	vGodAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_GRAVITY
	vGravityAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_GUNNER
	vGunnerAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_HEAL
	vHealAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_HIT
	vHitAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_HURT
	vHurtAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_HYPNO
	vHypnoAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_ICE
	vIceAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_IDLE
	vIdleAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_INVERT
	vInvertAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_ITEM
	vItemAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_JUMP
	vJumpAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_LAG
	vLagAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_LASER
	vLaserAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_LEECH
	vLeechAbilityCheck(list, list2, list3, list4);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningAbilityCheck(list, list2, list3, list4);
#endif
}

public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
{
#if defined MT_MENU_ABSORB
	vAbsorbCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_ACID
	vAcidCombineAbilities(tank, type, random, combo, survivor, weapon, classname);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_AMMO
	vAmmoCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_BLIND
	vBlindCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_BOMB
	vBombCombineAbilities(tank, type, random, combo, survivor, weapon, classname);
#endif
#if defined MT_MENU_BURY
	vBuryCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_CAR
	vCarCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_CHOKE
	vChokeCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_CLONE
	vCloneCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_CLOUD
	vCloudCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_DROP
	vDropCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_DRUG
	vDrugCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_DRUNK
	vDrunkCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_FAST
	vFastCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_FIRE
	vFireCombineAbilities(tank, type, random, combo, survivor, weapon, classname);
#endif
#if defined MT_MENU_FLING
	vFlingCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_FLY
	vFlyCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_FRAGILE
	vFragileCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_GHOST
	vGhostCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_GOD
	vGodCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_GRAVITY
	vGravityCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_GUNNER
	vGunnerCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_HEAL
	vHealCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_HURT
	vHurtCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_HYPNO
	vHypnoCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_ICE
	vIceCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_IDLE
	vIdleCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_INVERT
	vInvertCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_ITEM
	vItemCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_JUMP
	vJumpCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_LAG
	vLagCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_LASER
	vLaserCombineAbilities(tank, type, random, combo);
#endif
#if defined MT_MENU_LEECH
	vLeechCombineAbilities(tank, type, random, combo, survivor, classname);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningCombineAbilities(tank, type, random, combo);
#endif
}

public void MT_OnConfigsLoad(int mode)
{
#if defined MT_MENU_ABSORB
	vAbsorbConfigsLoad(mode);
#endif
#if defined MT_MENU_ACID
	vAcidConfigsLoad(mode);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessConfigsLoad(mode);
#endif
#if defined MT_MENU_AMMO
	vAmmoConfigsLoad(mode);
#endif
#if defined MT_MENU_BLIND
	vBlindConfigsLoad(mode);
#endif
#if defined MT_MENU_BOMB
	vBombConfigsLoad(mode);
#endif
#if defined MT_MENU_BURY
	vBuryConfigsLoad(mode);
#endif
#if defined MT_MENU_CAR
	vCarConfigsLoad(mode);
#endif
#if defined MT_MENU_CHOKE
	vChokeConfigsLoad(mode);
#endif
#if defined MT_MENU_CLONE
	vCloneConfigsLoad(mode);
#endif
#if defined MT_MENU_CLOUD
	vCloudConfigsLoad(mode);
#endif
#if defined MT_MENU_DROP
	vDropConfigsLoad(mode);
#endif
#if defined MT_MENU_DRUG
	vDrugConfigsLoad(mode);
#endif
#if defined MT_MENU_DRUNK
	vDrunkConfigsLoad(mode);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricConfigsLoad(mode);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceConfigsLoad(mode);
#endif
#if defined MT_MENU_FAST
	vFastConfigsLoad(mode);
#endif
#if defined MT_MENU_FIRE
	vFireConfigsLoad(mode);
#endif
#if defined MT_MENU_FLING
	vFlingConfigsLoad(mode);
#endif
#if defined MT_MENU_FLY
	vFlyConfigsLoad(mode);
#endif
#if defined MT_MENU_FRAGILE
	vFragileConfigsLoad(mode);
#endif
#if defined MT_MENU_GHOST
	vGhostConfigsLoad(mode);
#endif
#if defined MT_MENU_GOD
	vGodConfigsLoad(mode);
#endif
#if defined MT_MENU_GRAVITY
	vGravityConfigsLoad(mode);
#endif
#if defined MT_MENU_GUNNER
	vGunnerConfigsLoad(mode);
#endif
#if defined MT_MENU_HEAL
	vHealConfigsLoad(mode);
#endif
#if defined MT_MENU_HIT
	vHitConfigsLoad(mode);
#endif
#if defined MT_MENU_HURT
	vHurtConfigsLoad(mode);
#endif
#if defined MT_MENU_HYPNO
	vHypnoConfigsLoad(mode);
#endif
#if defined MT_MENU_ICE
	vIceConfigsLoad(mode);
#endif
#if defined MT_MENU_IDLE
	vIdleConfigsLoad(mode);
#endif
#if defined MT_MENU_INVERT
	vInvertConfigsLoad(mode);
#endif
#if defined MT_MENU_ITEM
	vItemConfigsLoad(mode);
#endif
#if defined MT_MENU_JUMP
	vJumpConfigsLoad(mode);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeConfigsLoad(mode);
#endif
#if defined MT_MENU_LAG
	vLagConfigsLoad(mode);
#endif
#if defined MT_MENU_LASER
	vLaserConfigsLoad(mode);
#endif
#if defined MT_MENU_LEECH
	vLeechConfigsLoad(mode);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningConfigsLoad(mode);
#endif
}

public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
{
#if defined MT_MENU_ABSORB
	vAbsorbConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_ACID
	vAcidConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_AMMO
	vAmmoConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_BLIND
	vBlindConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_BOMB
	vBombConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_BURY
	vBuryConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_CAR
	vCarConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_CHOKE
	vChokeConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_CLONE
	vCloneConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_CLOUD
	vCloudConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_DROP
	vDropConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_DRUG
	vDrugConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_DRUNK
	vDrunkConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_FAST
	vFastConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_FIRE
	vFireConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_FLING
	vFlingConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_FLY
	vFlyConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_FRAGILE
	vFragileConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_GHOST
	vGhostConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_GOD
	vGodConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_GRAVITY
	vGravityConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_GUNNER
	vGunnerConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_HEAL
	vHealConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_HIT
	vHitConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_HURT
	vHurtConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_HYPNO
	vHypnoConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_ICE
	vIceConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_IDLE
	vIdleConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_INVERT
	vInvertConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_ITEM
	vItemConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_JUMP
	vJumpConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_LAG
	vLagConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_LASER
	vLaserConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_LEECH
	vLeechConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningConfigsLoaded(subsection, key, value, type, admin, mode);
#endif
}

public void MT_OnSettingsCached(int tank, bool apply, int type)
{
#if defined MT_MENU_ABSORB
	vAbsorbSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_ACID
	vAcidSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_AMMO
	vAmmoSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_BLIND
	vBlindSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_BOMB
	vBombSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_BURY
	vBurySettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_CAR
	vCarSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_CHOKE
	vChokeSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_CLONE
	vCloneSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_CLOUD
	vCloudSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_DROP
	vDropSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_DRUG
	vDrugSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_DRUNK
	vDrunkSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_FAST
	vFastSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_FIRE
	vFireSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_FLING
	vFlingSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_FLY
	vFlySettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_FRAGILE
	vFragileSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_GHOST
	vGhostSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_GOD
	vGodSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_GRAVITY
	vGravitySettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_GUNNER
	vGunnerSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_HEAL
	vHealSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_HIT
	vHitSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_HURT
	vHurtSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_HYPNO
	vHypnoSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_ICE
	vIceSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_IDLE
	vIdleSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_INVERT
	vInvertSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_ITEM
	vItemSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_JUMP
	vJumpSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_LAG
	vLagSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_LASER
	vLaserSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_LEECH
	vLeechSettingsCached(tank, apply, type);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningSettingsCached(tank, apply, type);
#endif
}

public void MT_OnCopyStats(int oldTank, int newTank)
{
#if defined MT_MENU_ABSORB
	vAbsorbCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_ACID
	vAcidCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_AMMO
	vAmmoCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_BLIND
	vBlindCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_BOMB
	vBombCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_BURY
	vBuryCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_CAR
	vCarCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_CHOKE
	vChokeCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_CLONE
	vCloneCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_CLOUD
	vCloudCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_DROP
	vDropCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_DRUG
	vDrugCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_DRUNK
	vDrunkCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_FAST
	vFastCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_FIRE
	vFireCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_FLING
	vFlingCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_FLY
	vFlyCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_FRAGILE
	vFragileCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_GHOST
	vGhostCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_GOD
	vGodCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_GRAVITY
	vGravityCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_GUNNER
	vGunnerCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_HEAL
	vHealCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_HURT
	vHurtCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_HYPNO
	vHypnoCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_ICE
	vIceCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_IDLE
	vIdleCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_INVERT
	vInvertCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_ITEM
	vItemCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_JUMP
	vJumpCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_LAG
	vLagCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_LASER
	vLaserCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_LEECH
	vLeechCopyStats(oldTank, newTank);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningCopyStats(oldTank, newTank);
#endif
}

public void MT_OnHookEvent(bool hooked)
{
#if defined MT_MENU_FLY
	vFlyHookEvent(hooked);
#endif
}

public void MT_OnEventFired(Event event, const char[] name, bool dontBroadcast)
{
#if defined MT_MENU_ABSORB
	vAbsorbEventFired(event, name);
#endif
#if defined MT_MENU_ACID
	vAcidEventFired(event, name);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessEventFired(event, name);
#endif
#if defined MT_MENU_AMMO
	vAmmoEventFired(event, name);
#endif
#if defined MT_MENU_BLIND
	vBlindEventFired(event, name);
#endif
#if defined MT_MENU_BOMB
	vBombEventFired(event, name);
#endif
#if defined MT_MENU_BURY
	vBuryEventFired(event, name);
#endif
#if defined MT_MENU_CAR
	vCarEventFired(event, name);
#endif
#if defined MT_MENU_CHOKE
	vChokeEventFired(event, name);
#endif
#if defined MT_MENU_CLONE
	vCloneEventFired(event, name);
#endif
#if defined MT_MENU_CLOUD
	vCloudEventFired(event, name);
#endif
#if defined MT_MENU_DROP
	vDropEventFired(event, name);
#endif
#if defined MT_MENU_DRUG
	vDrugEventFired(event, name);
#endif
#if defined MT_MENU_DRUNK
	vDrunkEventFired(event, name);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricEventFired(event, name);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceEventFired(event, name);
#endif
#if defined MT_MENU_FAST
	vFastEventFired(event, name);
#endif
#if defined MT_MENU_FIRE
	vFireEventFired(event, name);
#endif
#if defined MT_MENU_FLING
	vFlingEventFired(event, name);
#endif
#if defined MT_MENU_FLY
	vFlyEventFired(event, name);
#endif
#if defined MT_MENU_FRAGILE
	vFragileEventFired(event, name);
#endif
#if defined MT_MENU_GHOST
	vGhostEventFired(event, name);
#endif
#if defined MT_MENU_GOD
	vGodEventFired(event, name);
#endif
#if defined MT_MENU_GRAVITY
	vGravityEventFired(event, name);
#endif
#if defined MT_MENU_GUNNER
	vGunnerEventFired(event, name);
#endif
#if defined MT_MENU_HEAL
	vHealEventFired(event, name);
#endif
#if defined MT_MENU_HURT
	vHurtEventFired(event, name);
#endif
#if defined MT_MENU_HYPNO
	vHypnoEventFired(event, name);
#endif
#if defined MT_MENU_ICE
	vIceEventFired(event, name);
#endif
#if defined MT_MENU_IDLE
	vIdleEventFired(event, name);
#endif
#if defined MT_MENU_INVERT
	vInvertEventFired(event, name);
#endif
#if defined MT_MENU_ITEM
	vItemEventFired(event, name);
#endif
#if defined MT_MENU_JUMP
	vJumpEventFired(event, name);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeEventFired(event, name);
#endif
#if defined MT_MENU_LAG
	vLagEventFired(event, name);
#endif
#if defined MT_MENU_LASER
	vLaserEventFired(event, name);
#endif
#if defined MT_MENU_LEECH
	vLeechEventFired(event, name);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningEventFired(event, name);
#endif
}

public void MT_OnAbilityActivated(int tank)
{
	vAbilityPlayer(3, tank);
}

public void MT_OnButtonPressed(int tank, int button)
{
#if defined MT_MENU_ABSORB
	vAbsorbButtonPressed(tank, button);
#endif
#if defined MT_MENU_ACID
	vAcidButtonPressed(tank, button);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessButtonPressed(tank, button);
#endif
#if defined MT_MENU_AMMO
	vAmmoButtonPressed(tank, button);
#endif
#if defined MT_MENU_BLIND
	vBlindButtonPressed(tank, button);
#endif
#if defined MT_MENU_BOMB
	vBombButtonPressed(tank, button);
#endif
#if defined MT_MENU_BURY
	vBuryButtonPressed(tank, button);
#endif
#if defined MT_MENU_CAR
	vCarButtonPressed(tank, button);
#endif
#if defined MT_MENU_CHOKE
	vChokeButtonPressed(tank, button);
#endif
#if defined MT_MENU_CLONE
	vCloneButtonPressed(tank, button);
#endif
#if defined MT_MENU_CLOUD
	vCloudButtonPressed(tank, button);
#endif
#if defined MT_MENU_DROP
	vDropButtonPressed(tank, button);
#endif
#if defined MT_MENU_DRUG
	vDrugButtonPressed(tank, button);
#endif
#if defined MT_MENU_DRUNK
	vDrunkButtonPressed(tank, button);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricButtonPressed(tank, button);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceButtonPressed(tank, button);
#endif
#if defined MT_MENU_FAST
	vFastButtonPressed(tank, button);
#endif
#if defined MT_MENU_FIRE
	vFireButtonPressed(tank, button);
#endif
#if defined MT_MENU_FLING
	vFlingButtonPressed(tank, button);
#endif
#if defined MT_MENU_FLY
	vFlyButtonPressed(tank, button);
#endif
#if defined MT_MENU_FRAGILE
	vFragileButtonPressed(tank, button);
#endif
#if defined MT_MENU_GHOST
	vGhostButtonPressed(tank, button);
#endif
#if defined MT_MENU_GOD
	vGodButtonPressed(tank, button);
#endif
#if defined MT_MENU_GRAVITY
	vGravityButtonPressed(tank, button);
#endif
#if defined MT_MENU_GUNNER
	vGunnerButtonPressed(tank, button);
#endif
#if defined MT_MENU_HEAL
	vHealButtonPressed(tank, button);
#endif
#if defined MT_MENU_HURT
	vHurtButtonPressed(tank, button);
#endif
#if defined MT_MENU_HYPNO
	vHypnoButtonPressed(tank, button);
#endif
#if defined MT_MENU_ICE
	vIceButtonPressed(tank, button);
#endif
#if defined MT_MENU_IDLE
	vIdleButtonPressed(tank, button);
#endif
#if defined MT_MENU_INVERT
	vInvertButtonPressed(tank, button);
#endif
#if defined MT_MENU_ITEM
	vItemButtonPressed(tank, button);
#endif
#if defined MT_MENU_JUMP
	vJumpButtonPressed(tank, button);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeButtonPressed(tank, button);
#endif
#if defined MT_MENU_LAG
	vLagButtonPressed(tank, button);
#endif
#if defined MT_MENU_LASER
	vLaserButtonPressed(tank, button);
#endif
#if defined MT_MENU_LEECH
	vLeechButtonPressed(tank, button);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningButtonPressed(tank, button);
#endif
}

public void MT_OnButtonReleased(int tank, int button)
{
#if defined MT_MENU_ABSORB
	vAbsorbButtonReleased(tank, button);
#endif
#if defined MT_MENU_CAR
	vCarButtonReleased(tank, button);
#endif
#if defined MT_MENU_CLOUD
	vCloudButtonReleased(tank, button);
#endif
#if defined MT_MENU_FAST
	vFastButtonReleased(tank, button);
#endif
#if defined MT_MENU_FLY
	vFlyButtonReleased(tank, button);
#endif
#if defined MT_MENU_FRAGILE
	vFragileButtonReleased(tank, button);
#endif
#if defined MT_MENU_GHOST
	vGhostButtonReleased(tank, button);
#endif
#if defined MT_MENU_GOD
	vGodButtonReleased(tank, button);
#endif
#if defined MT_MENU_GRAVITY
	vGravityButtonReleased(tank, button);
#endif
#if defined MT_MENU_GUNNER
	vGunnerButtonReleased(tank, button);
#endif
#if defined MT_MENU_HEAL
	vHealButtonReleased(tank, button);
#endif
#if defined MT_MENU_JUMP
	vJumpButtonReleased(tank, button);
#endif
#if defined MT_MENU_LASER
	vLaserButtonReleased(tank, button);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningButtonReleased(tank, button);
#endif
}

public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
{
#if defined MT_MENU_ABSORB
	vAbsorbChangeType(tank, oldType);
#endif
#if defined MT_MENU_ACID
	vAcidChangeType(tank, oldType);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessChangeType(tank, oldType);
#endif
#if defined MT_MENU_AMMO
	vAmmoChangeType(tank, oldType);
#endif
#if defined MT_MENU_BLIND
	vBlindChangeType(tank, oldType);
#endif
#if defined MT_MENU_BOMB
	vBombChangeType(tank, oldType);
#endif
#if defined MT_MENU_BURY
	vBuryChangeType(tank, oldType);
#endif
#if defined MT_MENU_CAR
	vCarChangeType(tank, oldType);
#endif
#if defined MT_MENU_CHOKE
	vChokeChangeType(tank, oldType);
#endif
#if defined MT_MENU_CLONE
	vCloneChangeType(tank, oldType, revert);
#endif
#if defined MT_MENU_CLOUD
	vCloudChangeType(tank, oldType);
#endif
#if defined MT_MENU_DROP
	vDropChangeType(tank, oldType);
#endif
#if defined MT_MENU_DRUG
	vDrugChangeType(tank, oldType);
#endif
#if defined MT_MENU_DRUNK
	vDrunkChangeType(tank, oldType);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricChangeType(tank, oldType);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceChangeType(tank, oldType);
#endif
#if defined MT_MENU_FAST
	vFastChangeType(tank, oldType);
#endif
#if defined MT_MENU_FIRE
	vFireChangeType(tank, oldType);
#endif
#if defined MT_MENU_FLING
	vFlingChangeType(tank, oldType);
#endif
#if defined MT_MENU_FLY
	vFlyChangeType(tank, oldType);
#endif
#if defined MT_MENU_FRAGILE
	vFragileChangeType(tank, oldType);
#endif
#if defined MT_MENU_GHOST
	vGhostChangeType(tank, oldType);
#endif
#if defined MT_MENU_GOD
	vGodChangeType(tank, oldType);
#endif
#if defined MT_MENU_GRAVITY
	vGravityChangeType(tank, oldType);
#endif
#if defined MT_MENU_GUNNER
	vGunnerChangeType(tank, oldType);
#endif
#if defined MT_MENU_HEAL
	vHealChangeType(tank, oldType);
#endif
#if defined MT_MENU_HURT
	vHurtChangeType(tank, oldType);
#endif
#if defined MT_MENU_HYPNO
	vHypnoChangeType(tank, oldType);
#endif
#if defined MT_MENU_ICE
	vIceChangeType(tank, oldType);
#endif
#if defined MT_MENU_IDLE
	vIdleChangeType(tank, oldType);
#endif
#if defined MT_MENU_INVERT
	vInvertChangeType(tank, oldType);
#endif
#if defined MT_MENU_ITEM
	vItemChangeType(tank, oldType);
#endif
#if defined MT_MENU_JUMP
	vJumpChangeType(tank, oldType);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeChangeType(tank, oldType);
#endif
#if defined MT_MENU_LAG
	vLagChangeType(tank, oldType);
#endif
#if defined MT_MENU_LASER
	vLaserChangeType(tank, oldType);
#endif
#if defined MT_MENU_LEECH
	vLeechChangeType(tank, oldType);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningChangeType(tank, oldType);
#endif
}

public void MT_OnPostTankSpawn(int tank)
{
	vAbilityPlayer(4, tank);
}

public Action MT_OnFatalFalling(int survivor)
{
#if defined MT_MENU_BURY
	vBuryFatalFalling(survivor);
#endif
#if defined MT_MENU_CHOKE
	vChokeFatalFalling(survivor);
#endif
	return Plugin_Continue;
}

public void MT_OnPlayerEventKilled(int victim, int attacker)
{
#if defined MT_MENU_ITEM
	vItemPlayerEventKilled(victim, attacker);
#endif
}

public Action MT_OnPlayerHitByVomitJar(int player, int thrower)
{
	Action aReturn = Plugin_Continue;
#if defined MT_MENU_GOD
	Action aResult = aGodPlayerHitByVomitJar(player, thrower);
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
#if defined MT_MENU_GOD
	Action aResult = aGodPlayerShovedBySurvivor(player, survivor);
	if (aResult != Plugin_Continue)
	{
		aReturn = aResult;
	}
#endif
	return aReturn;
}

public Action MT_OnRewardSurvivor(int survivor, int tank, int &type, int priority, float &duration, bool apply)
{
#if defined MT_MENU_BURY
	vBuryRewardSurvivor(survivor, type, apply);
#endif
#if defined MT_MENU_GRAVITY
	vGravityRewardSurvivor(survivor, type, apply);
#endif
	return Plugin_Continue;
}

public void MT_OnRockThrow(int tank, int rock)
{
#if defined MT_MENU_FLY
	vFlyRockThrow(tank);
#endif
#if defined MT_MENU_GHOST
	vGhostRockThrow(tank, rock);
#endif
}

public void MT_OnRockBreak(int tank, int rock)
{
#if defined MT_MENU_ACID
	vAcidRockBreak(tank, rock);
#endif
#if defined MT_MENU_BOMB
	vBombRockBreak(tank, rock);
#endif
#if defined MT_MENU_FIRE
	vFireRockBreak(tank, rock);
#endif
}

void vAbilityMenu(int client, const char[] name)
{
#if defined MT_MENU_ABSORB
	vAbsorbMenu(client, name, 0);
#endif
#if defined MT_MENU_ACID
	vAcidMenu(client, name, 0);
#endif
#if defined MT_MENU_AIMLESS
	vAimlessMenu(client, name, 0);
#endif
#if defined MT_MENU_AMMO
	vAmmoMenu(client, name, 0);
#endif
#if defined MT_MENU_BLIND
	vBlindMenu(client, name, 0);
#endif
#if defined MT_MENU_BOMB
	vBombMenu(client, name, 0);
#endif
#if defined MT_MENU_BURY
	vBuryMenu(client, name, 0);
#endif
#if defined MT_MENU_CAR
	vCarMenu(client, name, 0);
#endif
#if defined MT_MENU_CHOKE
	vChokeMenu(client, name, 0);
#endif
#if defined MT_MENU_CLONE
	vCloneMenu(client, name, 0);
#endif
#if defined MT_MENU_CLOUD
	vCloudMenu(client, name, 0);
#endif
#if defined MT_MENU_DROP
	vDropMenu(client, name, 0);
#endif
#if defined MT_MENU_DRUG
	vDrugMenu(client, name, 0);
#endif
#if defined MT_MENU_DRUNK
	vDrunkMenu(client, name, 0);
#endif
#if defined MT_MENU_ELECTRIC
	vElectricMenu(client, name, 0);
#endif
#if defined MT_MENU_ENFORCE
	vEnforceMenu(client, name, 0);
#endif
#if defined MT_MENU_FAST
	vFastMenu(client, name, 0);
#endif
#if defined MT_MENU_FIRE
	vFireMenu(client, name, 0);
#endif
#if defined MT_MENU_FLING
	vFlingMenu(client, name, 0);
#endif
#if defined MT_MENU_FLY
	vFlyMenu(client, name, 0);
#endif
#if defined MT_MENU_FRAGILE
	vFragileMenu(client, name, 0);
#endif
#if defined MT_MENU_GHOST
	vGhostMenu(client, name, 0);
#endif
#if defined MT_MENU_GOD
	vGodMenu(client, name, 0);
#endif
#if defined MT_MENU_GRAVITY
	vGravityMenu(client, name, 0);
#endif
#if defined MT_MENU_GUNNER
	vGunnerMenu(client, name, 0);
#endif
#if defined MT_MENU_HEAL
	vHealMenu(client, name, 0);
#endif
#if defined MT_MENU_HIT
	vHitMenu(client, name, 0);
#endif
#if defined MT_MENU_HURT
	vHurtMenu(client, name, 0);
#endif
#if defined MT_MENU_HYPNO
	vHypnoMenu(client, name, 0);
#endif
#if defined MT_MENU_ICE
	vIceMenu(client, name, 0);
#endif
#if defined MT_MENU_IDLE
	vIdleMenu(client, name, 0);
#endif
#if defined MT_MENU_INVERT
	vInvertMenu(client, name, 0);
#endif
#if defined MT_MENU_ITEM
	vItemMenu(client, name, 0);
#endif
#if defined MT_MENU_JUMP
	vJumpMenu(client, name, 0);
#endif
#if defined MT_MENU_KAMIKAZE
	vKamikazeMenu(client, name, 0);
#endif
#if defined MT_MENU_LAG
	vLagMenu(client, name, 0);
#endif
#if defined MT_MENU_LASER
	vLaserMenu(client, name, 0);
#endif
#if defined MT_MENU_LEECH
	vLeechMenu(client, name, 0);
#endif
#if defined MT_MENU_LIGHTNING
	vLightningMenu(client, name, 0);
#endif
	bool bLog = false;
	if (bLog)
	{
		MT_LogMessage(-1, "%s Ability Menu (%i, %s) - This should never fire.", MT_TAG, client, name);
	}
}

void vAbilityPlayer(int type, int client)
{
#if defined MT_MENU_ABSORB
	switch (type)
	{
		case 0: vAbsorbClientPutInServer(client);
		case 2: vAbsorbClientDisconnect_Post(client);
		case 3: vAbsorbAbilityActivated(client);
	}
#endif
#if defined MT_MENU_ACID
	switch (type)
	{
		case 0: vAcidClientPutInServer(client);
		case 2: vAcidClientDisconnect_Post(client);
		case 3: vAcidAbilityActivated(client);
		case 4: vAcidPostTankSpawn(client);
	}
#endif
#if defined MT_MENU_AIMLESS
	switch (type)
	{
		case 0: vAimlessClientPutInServer(client);
		case 2: vAimlessClientDisconnect_Post(client);
		case 3: vAimlessAbilityActivated(client);
	}
#endif
#if defined MT_MENU_AMMO
	switch (type)
	{
		case 0: vAmmoClientPutInServer(client);
		case 2: vAmmoClientDisconnect_Post(client);
		case 3: vAmmoAbilityActivated(client);
	}
#endif
#if defined MT_MENU_BLIND
	switch (type)
	{
		case 0: vBlindClientPutInServer(client);
		case 2: vBlindClientDisconnect_Post(client);
		case 3: vBlindAbilityActivated(client);
	}
#endif
#if defined MT_MENU_BOMB
	switch (type)
	{
		case 0: vBombClientPutInServer(client);
		case 2: vBombClientDisconnect_Post(client);
		case 3: vBombAbilityActivated(client);
		case 4: vBombPostTankSpawn(client);
	}
#endif
#if defined MT_MENU_BURY
	switch (type)
	{
		case 0: vBuryClientPutInServer(client);
		case 2: vBuryClientDisconnect_Post(client);
		case 3: vBuryAbilityActivated(client);
	}
#endif
#if defined MT_MENU_CAR
	switch (type)
	{
		case 0: vCarClientPutInServer(client);
		case 2: vCarClientDisconnect_Post(client);
		case 3: vCarAbilityActivated(client);
	}
#endif
#if defined MT_MENU_CHOKE
	switch (type)
	{
		case 0: vChokeClientPutInServer(client);
		case 2: vChokeClientDisconnect_Post(client);
		case 3: vChokeAbilityActivated(client);
	}
#endif
#if defined MT_MENU_CLONE
	switch (type)
	{
		case 0: vCloneClientPutInServer(client);
		case 1: vCloneClientDisconnect(client);
		case 2: vCloneClientDisconnect_Post(client);
		case 3: vCloneAbilityActivated(client);
	}
#endif
#if defined MT_MENU_CLOUD
	switch (type)
	{
		case 0: vCloudClientPutInServer(client);
		case 2: vCloudClientDisconnect_Post(client);
		case 3: vCloudAbilityActivated(client);
	}
#endif
#if defined MT_MENU_DROP
	switch (type)
	{
		case 0: vDropClientPutInServer(client);
		case 2: vDropClientDisconnect_Post(client);
		case 3: vDropAbilityActivated(client);
	}
#endif
#if defined MT_MENU_DRUG
	switch (type)
	{
		case 0: vDrugClientPutInServer(client);
		case 2: vDrugClientDisconnect_Post(client);
		case 3: vDrugAbilityActivated(client);
	}
#endif
#if defined MT_MENU_DRUNK
	switch (type)
	{
		case 0: vDrunkClientPutInServer(client);
		case 2: vDrunkClientDisconnect_Post(client);
		case 3: vDrunkAbilityActivated(client);
	}
#endif
#if defined MT_MENU_ELECTRIC
	switch (type)
	{
		case 0: vElectricClientPutInServer(client);
		case 2: vElectricClientDisconnect_Post(client);
		case 3: vElectricAbilityActivated(client);
		case 4: vElectricPostTankSpawn(client);
	}
#endif
#if defined MT_MENU_ENFORCE
	switch (type)
	{
		case 0: vEnforceClientPutInServer(client);
		case 2: vEnforceClientDisconnect_Post(client);
		case 3: vEnforceAbilityActivated(client);
	}
#endif
#if defined MT_MENU_FAST
	switch (type)
	{
		case 0: vFastClientPutInServer(client);
		case 2: vFastClientDisconnect_Post(client);
		case 3: vFastAbilityActivated(client);
	}
#endif
#if defined MT_MENU_FIRE
	switch (type)
	{
		case 0: vFireClientPutInServer(client);
		case 2: vFireClientDisconnect_Post(client);
		case 3: vFireAbilityActivated(client);
		case 4: vFirePostTankSpawn(client);
	}
#endif
#if defined MT_MENU_FLING
	switch (type)
	{
		case 0: vFlingClientPutInServer(client);
		case 2: vFlingClientDisconnect_Post(client);
		case 3: vFlingAbilityActivated(client);
		case 4: vFlingPostTankSpawn(client);
	}
#endif
#if defined MT_MENU_FLY
	switch (type)
	{
		case 0: vFlyClientPutInServer(client);
		case 2: vFlyClientDisconnect_Post(client);
		case 3: vFlyAbilityActivated(client);
	}
#endif
#if defined MT_MENU_FRAGILE
	switch (type)
	{
		case 0: vFragileClientPutInServer(client);
		case 2: vFragileClientDisconnect_Post(client);
		case 3: vFragileAbilityActivated(client);
	}
#endif
#if defined MT_MENU_GHOST
	switch (type)
	{
		case 0: vGhostClientPutInServer(client);
		case 2: vGhostClientDisconnect_Post(client);
		case 3: vGhostAbilityActivated(client);
		case 4: vGhostPostTankSpawn(client);
	}
#endif
#if defined MT_MENU_GOD
	switch (type)
	{
		case 0: vGodClientPutInServer(client);
		case 2: vGodClientDisconnect_Post(client);
		case 3: vGodAbilityActivated(client);
	}
#endif
#if defined MT_MENU_GRAVITY
	switch (type)
	{
		case 0: vGravityClientPutInServer(client);
		case 2: vGravityClientDisconnect_Post(client);
		case 3: vGravityAbilityActivated(client);
	}
#endif
#if defined MT_MENU_GUNNER
	switch (type)
	{
		case 0: vGunnerClientPutInServer(client);
		case 2: vGunnerClientDisconnect_Post(client);
		case 3: vGunnerAbilityActivated(client);
	}
#endif
#if defined MT_MENU_HEAL
	switch (type)
	{
		case 0: vHealClientPutInServer(client);
		case 2: vHealClientDisconnect_Post(client);
		case 3: vHealAbilityActivated(client);
	}
#endif
#if defined MT_MENU_HIT
	if (type == 0)
	{
		vHitClientPutInServer(client);
	}
#endif
#if defined MT_MENU_HURT
	switch (type)
	{
		case 0: vHurtClientPutInServer(client);
		case 2: vHurtClientDisconnect_Post(client);
		case 3: vHurtAbilityActivated(client);
	}
#endif
#if defined MT_MENU_HYPNO
	switch (type)
	{
		case 0: vHypnoClientPutInServer(client);
		case 2: vHypnoClientDisconnect_Post(client);
		case 3: vHypnoAbilityActivated(client);
	}
#endif
#if defined MT_MENU_ICE
	switch (type)
	{
		case 0: vIceClientPutInServer(client);
		case 2: vIceClientDisconnect_Post(client);
		case 3: vIceAbilityActivated(client);
	}
#endif
#if defined MT_MENU_IDLE
	switch (type)
	{
		case 0: vIdleClientPutInServer(client);
		case 2: vIdleClientDisconnect_Post(client);
		case 3: vIdleAbilityActivated(client);
	}
#endif
#if defined MT_MENU_INVERT
	switch (type)
	{
		case 0: vInvertClientPutInServer(client);
		case 2: vInvertClientDisconnect_Post(client);
		case 3: vInvertAbilityActivated(client);
	}
#endif
#if defined MT_MENU_ITEM
	switch (type)
	{
		case 0: vItemClientPutInServer(client);
		case 2: vItemClientDisconnect_Post(client);
		case 3: vItemAbilityActivated(client);
	}
#endif
#if defined MT_MENU_JUMP
	switch (type)
	{
		case 0: vJumpClientPutInServer(client);
		case 2: vJumpClientDisconnect_Post(client);
		case 3: vJumpAbilityActivated(client);
	}
#endif
#if defined MT_MENU_KAMIKAZE
	switch (type)
	{
		case 0: vKamikazeClientPutInServer(client);
		case 2: vKamikazeClientDisconnect_Post(client);
		case 3: vKamikazeAbilityActivated(client);
	}
#endif
#if defined MT_MENU_LAG
	switch (type)
	{
		case 0: vLagClientPutInServer(client);
		case 2: vLagClientDisconnect_Post(client);
		case 3: vLagAbilityActivated(client);
	}
#endif
#if defined MT_MENU_LASER
	switch (type)
	{
		case 0: vLaserClientPutInServer(client);
		case 2: vLaserClientDisconnect_Post(client);
		case 3: vLaserAbilityActivated(client);
	}
#endif
#if defined MT_MENU_LEECH
	switch (type)
	{
		case 0: vLeechClientPutInServer(client);
		case 2: vLeechClientDisconnect_Post(client);
		case 3: vLeechAbilityActivated(client);
	}
#endif
#if defined MT_MENU_LIGHTNING
	switch (type)
	{
		case 0: vLightningClientPutInServer(client);
		case 2: vLightningClientDisconnect_Post(client);
		case 3: vLightningAbilityActivated(client);
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
#if defined MT_MENU_ABSORB
	switch (type)
	{
		case 1: vAbsorbMapStart();
		case 2: vAbsorbMapEnd();
	}
#endif
#if defined MT_MENU_ACID
	switch (type)
	{
		case 1: vAcidMapStart();
		case 2: vAcidMapEnd();
	}
#endif
#if defined MT_MENU_AIMLESS
	switch (type)
	{
		case 1: vAimlessMapStart();
		case 2: vAimlessMapEnd();
	}
#endif
#if defined MT_MENU_AMMO
	switch (type)
	{
		case 1: vAmmoMapStart();
		case 2: vAmmoMapEnd();
	}
#endif
#if defined MT_MENU_BLIND
	switch (type)
	{
		case 0: vBlindPluginStart();
		case 1: vBlindMapStart();
		case 2: vBlindMapEnd();
		case 3: vBlindPluginEnd();
	}
#endif
#if defined MT_MENU_BOMB
	switch (type)
	{
		case 1: vBombMapStart();
		case 2: vBombMapEnd();
	}
#endif
#if defined MT_MENU_BURY
	switch (type)
	{
		case 1: vBuryMapStart();
		case 2: vBuryMapEnd();
		case 3: vBuryPluginEnd();
	}
#endif
#if defined MT_MENU_CAR
	switch (type)
	{
		case 1: vCarMapStart();
		case 2: vCarMapEnd();
	}
#endif
#if defined MT_MENU_CHOKE
	switch (type)
	{
		case 1: vChokeMapStart();
		case 2: vChokeMapEnd();
		case 3: vChokePluginEnd();
	}
#endif
#if defined MT_MENU_CLONE
	switch (type)
	{
		case 1: vCloneMapStart();
		case 2: vCloneMapEnd();
		case 3: vClonePluginEnd();
	}
#endif
#if defined MT_MENU_CLOUD
	switch (type)
	{
		case 1: vCloudMapStart();
		case 2: vCloudMapEnd();
	}
#endif
#if defined MT_MENU_DROP
	switch (type)
	{
		case 0: vDropPluginStart();
		case 1: vDropMapStart();
		case 2: vDropMapEnd();
	}
#endif
#if defined MT_MENU_DRUG
	switch (type)
	{
		case 0: vDrugPluginStart();
		case 1: vDrugMapStart();
		case 2: vDrugMapEnd();
		case 3: vDrugPluginEnd();
	}
#endif
#if defined MT_MENU_DRUNK
	switch (type)
	{
		case 1: vDrunkMapStart();
		case 2: vDrunkMapEnd();
		case 3: vDrunkPluginEnd();
	}
#endif
#if defined MT_MENU_ELECTRIC
	switch (type)
	{
		case 1: vElectricMapStart();
		case 2: vElectricMapEnd();
	}
#endif
#if defined MT_MENU_ENFORCE
	switch (type)
	{
		case 1: vEnforceMapStart();
		case 2: vEnforceMapEnd();
	}
#endif
#if defined MT_MENU_FAST
	switch (type)
	{
		case 1: vFastMapStart();
		case 2: vFastMapEnd();
		case 3: vFastPluginEnd();
	}
#endif
#if defined MT_MENU_FIRE
	switch (type)
	{
		case 1: vFireMapStart();
		case 2: vFireMapEnd();
	}
#endif
#if defined MT_MENU_FLING
	switch (type)
	{
		case 1: vFlingMapStart();
		case 2: vFlingMapEnd();
	}
#endif
#if defined MT_MENU_FLY
	switch (type)
	{
		case 1: vFlyMapStart();
		case 2: vFlyMapEnd();
	}
#endif
#if defined MT_MENU_FRAGILE
	switch (type)
	{
		case 1: vFragileMapStart();
		case 2: vFragileMapEnd();
		case 3: vFragilePluginEnd();
	}
#endif
#if defined MT_MENU_GHOST
	switch (type)
	{
		case 1: vGhostMapStart();
		case 2: vGhostMapEnd();
	}
#endif
#if defined MT_MENU_GOD
	switch (type)
	{
		case 1: vGodMapStart();
		case 2: vGodMapEnd();
	}
#endif
#if defined MT_MENU_GRAVITY
	switch (type)
	{
		case 1: vGravityMapStart();
		case 2: vGravityMapEnd();
		case 3: vGravityPluginEnd();
	}
#endif
#if defined MT_MENU_GUNNER
	switch (type)
	{
		case 1: vGunnerMapStart();
		case 2: vGunnerMapEnd();
		case 3: vGunnerPluginEnd();
	}
#endif
#if defined MT_MENU_HEAL
	switch (type)
	{
		case 0: vHealPluginStart();
		case 1: vHealMapStart();
		case 2: vHealMapEnd();
		case 3: vHealPluginEnd();
	}
#endif
#if defined MT_MENU_HURT
	switch (type)
	{
		case 1: vHurtMapStart();
		case 2: vHurtMapEnd();
	}
#endif
#if defined MT_MENU_HYPNO
	switch (type)
	{
		case 1: vHypnoMapStart();
		case 2: vHypnoMapEnd();
	}
#endif
#if defined MT_MENU_ICE
	switch (type)
	{
		case 1: vIceMapStart();
		case 2: vIceMapEnd();
		case 3: vIcePluginEnd();
	}
#endif
#if defined MT_MENU_IDLE
	switch (type)
	{
		case 1: vIdleMapStart();
		case 2: vIdleMapEnd();
	}
#endif
#if defined MT_MENU_INVERT
	switch (type)
	{
		case 1: vInvertMapStart();
		case 2: vInvertMapEnd();
	}
#endif
#if defined MT_MENU_ITEM
	switch (type)
	{
		case 1: vItemMapStart();
		case 2: vItemMapEnd();
	}
#endif
#if defined MT_MENU_JUMP
	switch (type)
	{
		case 1: vJumpMapStart();
		case 2: vJumpMapEnd();
	}
#endif
#if defined MT_MENU_KAMIKAZE
	switch (type)
	{
		case 1: vKamikazeMapStart();
		case 2: vKamikazeMapEnd();
	}
#endif
#if defined MT_MENU_LAG
	switch (type)
	{
		case 1: vLagMapStart();
		case 2: vLagMapEnd();
	}
#endif
#if defined MT_MENU_LASER
	switch (type)
	{
		case 1: vLaserMapStart();
		case 2: vLaserMapEnd();
	}
#endif
#if defined MT_MENU_LEECH
	switch (type)
	{
		case 1: vLeechMapStart();
		case 2: vLeechMapEnd();
	}
#endif
#if defined MT_MENU_LIGHTNING
	switch (type)
	{
		case 1: vLightningMapStart();
		case 2: vLightningMapEnd();
	}
#endif
	bool bLog = false;
	if (bLog)
	{
		MT_LogMessage(-1, "%s Ability Setup (%i) - This should never fire.", MT_TAG, type);
	}
}