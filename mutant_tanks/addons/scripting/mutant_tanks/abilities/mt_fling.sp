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

#define MT_FLING_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_FLING_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Fling Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank flings survivors high into the air.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad, g_bSecondGame;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bSecondGame = false;
		case Engine_Left4Dead2: g_bSecondGame = true;
		default:
		{
			strcopy(error, err_max, "\"[MT] Fling Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_FLING_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define PARTICLE_BLOOD "boomer_explode_D"

#define MT_FLING_SECTION "flingability"
#define MT_FLING_SECTION2 "fling ability"
#define MT_FLING_SECTION3 "fling_ability"
#define MT_FLING_SECTION4 "fling"

#define MT_MENU_FLING "Fling Ability"

enum struct esFlingPlayer
{
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flFlingChance;
	float g_flFlingDeathChance;
	float g_flFlingDeathRange;
	float g_flFlingForce;
	float g_flFlingRange;
	float g_flFlingRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iFlingAbility;
	int g_iFlingCooldown;
	int g_iFlingDeath;
	int g_iFlingEffect;
	int g_iFlingHit;
	int g_iFlingHitMode;
	int g_iFlingMessage;
	int g_iFlingRangeCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esFlingPlayer g_esFlingPlayer[MAXPLAYERS + 1];

enum struct esFlingAbility
{
	float g_flCloseAreasOnly;
	float g_flFlingChance;
	float g_flFlingDeathChance;
	float g_flFlingDeathRange;
	float g_flFlingForce;
	float g_flFlingRange;
	float g_flFlingRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iFlingAbility;
	int g_iFlingCooldown;
	int g_iFlingDeath;
	int g_iFlingEffect;
	int g_iFlingHit;
	int g_iFlingHitMode;
	int g_iFlingMessage;
	int g_iFlingRangeCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esFlingAbility g_esFlingAbility[MT_MAXTYPES + 1];

enum struct esFlingCache
{
	float g_flCloseAreasOnly;
	float g_flFlingChance;
	float g_flFlingDeathChance;
	float g_flFlingDeathRange;
	float g_flFlingForce;
	float g_flFlingRange;
	float g_flFlingRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iFlingAbility;
	int g_iFlingCooldown;
	int g_iFlingDeath;
	int g_iFlingEffect;
	int g_iFlingHit;
	int g_iFlingHitMode;
	int g_iFlingMessage;
	int g_iFlingRangeCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
}

esFlingCache g_esFlingCache[MAXPLAYERS + 1];

Handle g_hSDKFling;

#if defined MT_ABILITIES_MAIN
void vFlingAllPluginsLoaded(GameData gdMutantTanks)
#else
public void OnAllPluginsLoaded()
#endif
{
	if (g_bSecondGame)
	{
#if !defined MT_ABILITIES_MAIN
		GameData gdMutantTanks = new GameData(MT_GAMEDATA);
		if (gdMutantTanks == null)
		{
			SetFailState("Unable to load the \"%s\" gamedata file.", MT_GAMEDATA);
		}
#endif
		StartPrepSDKCall(SDKCall_Player);
		if (!PrepSDKCall_SetFromConf(gdMutantTanks, SDKConf_Signature, "CTerrorPlayer::Fling"))
		{
#if defined MT_ABILITIES_MAIN
			delete gdMutantTanks;

			LogError("%s Failed to find signature: CTerrorPlayer::Fling", MT_TAG);
#else
			SetFailState("Failed to find signature: CTerrorPlayer::Fling");
#endif
		}

		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);

		g_hSDKFling = EndPrepSDKCall();
		if (g_hSDKFling == null)
		{
#if defined MT_ABILITIES_MAIN
			LogError("%s Your \"CTerrorPlayer::Fling\" signature is outdated.", MT_TAG);
#else
			SetFailState("Your \"CTerrorPlayer::Fling\" signature is outdated.");
#endif
		}
#if !defined MT_ABILITIES_MAIN
		delete gdMutantTanks;
#endif
	}
}

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_fling", cmdFlingInfo, "View information about the Fling ability.");

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
#endif

#if defined MT_ABILITIES_MAIN
void vFlingMapStart()
#else
public void OnMapStart()
#endif
{
	iPrecacheParticle(PARTICLE_BLOOD);

	vFlingReset();
}

#if defined MT_ABILITIES_MAIN
void vFlingClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnFlingTakeDamage);
	vRemoveFling(client);
}

#if defined MT_ABILITIES_MAIN
void vFlingClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveFling(client);
}

#if defined MT_ABILITIES_MAIN
void vFlingMapEnd()
#else
public void OnMapEnd()
#endif
{
	vFlingReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdFlingInfo(int client, int args)
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

	switch (IsVoteInProgress())
	{
		case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
		case false: vFlingMenu(client, MT_FLING_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vFlingMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_FLING_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iFlingMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Fling Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iFlingMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFlingCache[param1].g_iFlingAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esFlingCache[param1].g_iHumanAmmo - g_esFlingPlayer[param1].g_iAmmoCount), g_esFlingCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esFlingCache[param1].g_iHumanAbility == 1) ? g_esFlingCache[param1].g_iHumanCooldown : g_esFlingCache[param1].g_iFlingCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "FlingDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFlingCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esFlingCache[param1].g_iHumanAbility == 1) ? g_esFlingCache[param1].g_iHumanRangeCooldown : g_esFlingCache[param1].g_iFlingRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vFlingMenu(param1, MT_FLING_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pFling = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "FlingMenu", param1);
			pFling.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			if (param2 >= 0)
			{
				char sMenuOption[PLATFORM_MAX_PATH];

				switch (param2)
				{
					case 0: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Status", param1);
					case 1: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Ammunition", param1);
					case 2: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Buttons", param1);
					case 3: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Cooldown", param1);
					case 4: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "RangeCooldown", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vFlingDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_FLING, MT_MENU_FLING);
}

#if defined MT_ABILITIES_MAIN
void vFlingMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_FLING, false))
	{
		vFlingMenu(client, MT_FLING_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vFlingMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_FLING, false))
	{
		FormatEx(buffer, size, "%T", "FlingMenu2", client);
	}
}

Action OnFlingTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_bSecondGame && MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esFlingCache[attacker].g_iFlingHitMode == 0 || g_esFlingCache[attacker].g_iFlingHitMode == 1) && bIsSurvivor(victim) && g_esFlingCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esFlingAbility[g_esFlingPlayer[attacker].g_iTankType].g_iAccessFlags, g_esFlingPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esFlingPlayer[attacker].g_iTankType, g_esFlingAbility[g_esFlingPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esFlingPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vFlingHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esFlingCache[attacker].g_flFlingChance, g_esFlingCache[attacker].g_iFlingHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esFlingCache[victim].g_iFlingHitMode == 0 || g_esFlingCache[victim].g_iFlingHitMode == 2) && bIsSurvivor(attacker) && g_esFlingCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esFlingAbility[g_esFlingPlayer[victim].g_iTankType].g_iAccessFlags, g_esFlingPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esFlingPlayer[victim].g_iTankType, g_esFlingAbility[g_esFlingPlayer[victim].g_iTankType].g_iImmunityFlags, g_esFlingPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vFlingHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esFlingCache[victim].g_flFlingChance, g_esFlingCache[victim].g_iFlingHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vFlingPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_FLING);
}

#if defined MT_ABILITIES_MAIN
void vFlingAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_FLING_SECTION);
	list2.PushString(MT_FLING_SECTION2);
	list3.PushString(MT_FLING_SECTION3);
	list4.PushString(MT_FLING_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vFlingCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (!g_bSecondGame || (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlingCache[tank].g_iHumanAbility != 2))
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_FLING_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_FLING_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_FLING_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_FLING_SECTION4);
	if (g_esFlingCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_FLING_SECTION, false) || StrEqual(sSubset[iPos], MT_FLING_SECTION2, false) || StrEqual(sSubset[iPos], MT_FLING_SECTION3, false) || StrEqual(sSubset[iPos], MT_FLING_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esFlingCache[tank].g_iFlingAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vFlingAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerFlingCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
									dpCombo.WriteCell(GetClientUserId(tank));
									dpCombo.WriteFloat(random);
									dpCombo.WriteCell(iPos);
								}
							}
						}
					}
					case MT_COMBO_MELEEHIT:
					{
						flChance = MT_GetCombinationSetting(tank, 1, iPos);

						switch (flDelay)
						{
							case 0.0:
							{
								if ((g_esFlingCache[tank].g_iFlingHitMode == 0 || g_esFlingCache[tank].g_iFlingHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vFlingHit(survivor, tank, random, flChance, g_esFlingCache[tank].g_iFlingHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esFlingCache[tank].g_iFlingHitMode == 0 || g_esFlingCache[tank].g_iFlingHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vFlingHit(survivor, tank, random, flChance, g_esFlingCache[tank].g_iFlingHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerFlingCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(survivor));
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteFloat(random);
								dpCombo.WriteFloat(flChance);
								dpCombo.WriteCell(iPos);
								dpCombo.WriteString(classname);
							}
						}
					}
					case MT_COMBO_POSTSPAWN: vFlingRange(tank, 0, random, iPos);
					case MT_COMBO_UPONDEATH: vFlingRange(tank, 0, random, iPos);
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFlingConfigsLoad(int mode)
#else
public void MT_OnConfigsLoad(int mode)
#endif
{
	switch (mode)
	{
		case 1:
		{
			int iMaxType = MT_GetMaxType();
			for (int iIndex = MT_GetMinType(); iIndex <= iMaxType; iIndex++)
			{
				g_esFlingAbility[iIndex].g_iAccessFlags = 0;
				g_esFlingAbility[iIndex].g_iImmunityFlags = 0;
				g_esFlingAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esFlingAbility[iIndex].g_iComboAbility = 0;
				g_esFlingAbility[iIndex].g_iHumanAbility = 0;
				g_esFlingAbility[iIndex].g_iHumanAmmo = 5;
				g_esFlingAbility[iIndex].g_iHumanCooldown = 0;
				g_esFlingAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esFlingAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esFlingAbility[iIndex].g_iRequiresHumans = 0;
				g_esFlingAbility[iIndex].g_iFlingAbility = 0;
				g_esFlingAbility[iIndex].g_iFlingEffect = 0;
				g_esFlingAbility[iIndex].g_iFlingMessage = 0;
				g_esFlingAbility[iIndex].g_flFlingChance = 33.3;
				g_esFlingAbility[iIndex].g_iFlingCooldown = 0;
				g_esFlingAbility[iIndex].g_iFlingDeath = 0;
				g_esFlingAbility[iIndex].g_flFlingDeathChance = 33.3;
				g_esFlingAbility[iIndex].g_flFlingDeathRange = 200.0;
				g_esFlingAbility[iIndex].g_flFlingForce = 300.0;
				g_esFlingAbility[iIndex].g_iFlingHit = 0;
				g_esFlingAbility[iIndex].g_iFlingHitMode = 0;
				g_esFlingAbility[iIndex].g_flFlingRange = 150.0;
				g_esFlingAbility[iIndex].g_flFlingRangeChance = 15.0;
				g_esFlingAbility[iIndex].g_iFlingRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esFlingPlayer[iPlayer].g_iAccessFlags = 0;
					g_esFlingPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esFlingPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esFlingPlayer[iPlayer].g_iComboAbility = 0;
					g_esFlingPlayer[iPlayer].g_iHumanAbility = 0;
					g_esFlingPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esFlingPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esFlingPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esFlingPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esFlingPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esFlingPlayer[iPlayer].g_iFlingAbility = 0;
					g_esFlingPlayer[iPlayer].g_iFlingEffect = 0;
					g_esFlingPlayer[iPlayer].g_iFlingMessage = 0;
					g_esFlingPlayer[iPlayer].g_flFlingChance = 0.0;
					g_esFlingPlayer[iPlayer].g_iFlingCooldown = 0;
					g_esFlingPlayer[iPlayer].g_iFlingDeath = 0;
					g_esFlingPlayer[iPlayer].g_flFlingDeathChance = 0.0;
					g_esFlingPlayer[iPlayer].g_flFlingDeathRange = 0.0;
					g_esFlingPlayer[iPlayer].g_flFlingForce = 0.0;
					g_esFlingPlayer[iPlayer].g_iFlingHit = 0;
					g_esFlingPlayer[iPlayer].g_iFlingHitMode = 0;
					g_esFlingPlayer[iPlayer].g_flFlingRange = 0.0;
					g_esFlingPlayer[iPlayer].g_flFlingRangeChance = 0.0;
					g_esFlingPlayer[iPlayer].g_iFlingRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFlingConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esFlingPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esFlingPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esFlingPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esFlingPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esFlingPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esFlingPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esFlingPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esFlingPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esFlingPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esFlingPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esFlingPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esFlingPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esFlingPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esFlingPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esFlingPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esFlingPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esFlingPlayer[admin].g_iFlingAbility = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esFlingPlayer[admin].g_iFlingAbility, value, 0, 1);
		g_esFlingPlayer[admin].g_iFlingEffect = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esFlingPlayer[admin].g_iFlingEffect, value, 0, 7);
		g_esFlingPlayer[admin].g_iFlingMessage = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esFlingPlayer[admin].g_iFlingMessage, value, 0, 3);
		g_esFlingPlayer[admin].g_flFlingChance = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingChance", "Fling Chance", "Fling_Chance", "chance", g_esFlingPlayer[admin].g_flFlingChance, value, 0.0, 100.0);
		g_esFlingPlayer[admin].g_iFlingCooldown = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingCooldown", "Fling Cooldown", "Fling_Cooldown", "cooldown", g_esFlingPlayer[admin].g_iFlingCooldown, value, 0, 99999);
		g_esFlingPlayer[admin].g_iFlingDeath = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingDeath", "Fling Death", "Fling_Death", "death", g_esFlingPlayer[admin].g_iFlingDeath, value, 0, 1);
		g_esFlingPlayer[admin].g_flFlingDeathChance = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingDeathChance", "Fling Death Chance", "Fling_Death_Chance", "deathchance", g_esFlingPlayer[admin].g_flFlingDeathChance, value, 0.0, 100.0);
		g_esFlingPlayer[admin].g_flFlingDeathRange = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingDeathRange", "Fling Death Range", "Fling_Death_Range", "deathrange", g_esFlingPlayer[admin].g_flFlingDeathRange, value, 1.0, 99999.0);
		g_esFlingPlayer[admin].g_flFlingForce = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingForce", "Fling Force", "Fling_Force", "force", g_esFlingPlayer[admin].g_flFlingForce, value, 1.0, 99999.0);
		g_esFlingPlayer[admin].g_iFlingHit = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingHit", "Fling Hit", "Fling_Hit", "hit", g_esFlingPlayer[admin].g_iFlingHit, value, 0, 1);
		g_esFlingPlayer[admin].g_iFlingHitMode = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingHitMode", "Fling Hit Mode", "Fling_Hit_Mode", "hitmode", g_esFlingPlayer[admin].g_iFlingHitMode, value, 0, 2);
		g_esFlingPlayer[admin].g_flFlingRange = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingRange", "Fling Range", "Fling_Range", "range", g_esFlingPlayer[admin].g_flFlingRange, value, 1.0, 99999.0);
		g_esFlingPlayer[admin].g_flFlingRangeChance = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingRangeChance", "Fling Range Chance", "Fling_Range_Chance", "rangechance", g_esFlingPlayer[admin].g_flFlingRangeChance, value, 0.0, 100.0);
		g_esFlingPlayer[admin].g_iFlingRangeCooldown = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingRangeCooldown", "Fling Range Cooldown", "Fling_Range_Cooldown", "rangecooldown", g_esFlingPlayer[admin].g_iFlingRangeCooldown, value, 0, 99999);
		g_esFlingPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esFlingPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esFlingAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esFlingAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esFlingAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esFlingAbility[type].g_iComboAbility, value, 0, 1);
		g_esFlingAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esFlingAbility[type].g_iHumanAbility, value, 0, 2);
		g_esFlingAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esFlingAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esFlingAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esFlingAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esFlingAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esFlingAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esFlingAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esFlingAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esFlingAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esFlingAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esFlingAbility[type].g_iFlingAbility = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esFlingAbility[type].g_iFlingAbility, value, 0, 1);
		g_esFlingAbility[type].g_iFlingEffect = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esFlingAbility[type].g_iFlingEffect, value, 0, 7);
		g_esFlingAbility[type].g_iFlingMessage = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esFlingAbility[type].g_iFlingMessage, value, 0, 3);
		g_esFlingAbility[type].g_flFlingChance = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingChance", "Fling Chance", "Fling_Chance", "chance", g_esFlingAbility[type].g_flFlingChance, value, 0.0, 100.0);
		g_esFlingAbility[type].g_iFlingCooldown = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingCooldown", "Fling Cooldown", "Fling_Cooldown", "cooldown", g_esFlingAbility[type].g_iFlingCooldown, value, 0, 99999);
		g_esFlingAbility[type].g_iFlingDeath = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingDeath", "Fling Death", "Fling_Death", "death", g_esFlingAbility[type].g_iFlingDeath, value, 0, 1);
		g_esFlingAbility[type].g_flFlingDeathChance = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingDeathChance", "Fling Death Chance", "Fling_Death_Chance", "deathchance", g_esFlingAbility[type].g_flFlingDeathChance, value, 0.0, 100.0);
		g_esFlingAbility[type].g_flFlingDeathRange = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingDeathRange", "Fling Death Range", "Fling_Death_Range", "deathrange", g_esFlingAbility[type].g_flFlingDeathRange, value, 1.0, 99999.0);
		g_esFlingAbility[type].g_flFlingForce = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingForce", "Fling Force", "Fling_Force", "force", g_esFlingAbility[type].g_flFlingForce, value, 1.0, 99999.0);
		g_esFlingAbility[type].g_iFlingHit = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingHit", "Fling Hit", "Fling_Hit", "hit", g_esFlingAbility[type].g_iFlingHit, value, 0, 1);
		g_esFlingAbility[type].g_iFlingHitMode = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingHitMode", "Fling Hit Mode", "Fling_Hit_Mode", "hitmode", g_esFlingAbility[type].g_iFlingHitMode, value, 0, 2);
		g_esFlingAbility[type].g_flFlingRange = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingRange", "Fling Range", "Fling_Range", "range", g_esFlingAbility[type].g_flFlingRange, value, 1.0, 99999.0);
		g_esFlingAbility[type].g_flFlingRangeChance = flGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingRangeChance", "Fling Range Chance", "Fling_Range_Chance", "rangechance", g_esFlingAbility[type].g_flFlingRangeChance, value, 0.0, 100.0);
		g_esFlingAbility[type].g_iFlingRangeCooldown = iGetKeyValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "FlingRangeCooldown", "Fling Range Cooldown", "Fling_Range_Cooldown", "rangecooldown", g_esFlingAbility[type].g_iFlingRangeCooldown, value, 0, 99999);
		g_esFlingAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esFlingAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_FLING_SECTION, MT_FLING_SECTION2, MT_FLING_SECTION3, MT_FLING_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vFlingSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esFlingCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_flCloseAreasOnly, g_esFlingAbility[type].g_flCloseAreasOnly);
	g_esFlingCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iComboAbility, g_esFlingAbility[type].g_iComboAbility);
	g_esFlingCache[tank].g_flFlingChance = flGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_flFlingChance, g_esFlingAbility[type].g_flFlingChance);
	g_esFlingCache[tank].g_flFlingDeathChance = flGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_flFlingDeathChance, g_esFlingAbility[type].g_flFlingDeathChance);
	g_esFlingCache[tank].g_flFlingDeathRange = flGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_flFlingDeathRange, g_esFlingAbility[type].g_flFlingDeathRange);
	g_esFlingCache[tank].g_flFlingForce = flGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_flFlingForce, g_esFlingAbility[type].g_flFlingForce);
	g_esFlingCache[tank].g_flFlingRange = flGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_flFlingRange, g_esFlingAbility[type].g_flFlingRange);
	g_esFlingCache[tank].g_flFlingRangeChance = flGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_flFlingRangeChance, g_esFlingAbility[type].g_flFlingRangeChance);
	g_esFlingCache[tank].g_iFlingAbility = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iFlingAbility, g_esFlingAbility[type].g_iFlingAbility);
	g_esFlingCache[tank].g_iFlingCooldown = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iFlingCooldown, g_esFlingAbility[type].g_iFlingCooldown);
	g_esFlingCache[tank].g_iFlingDeath = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iFlingDeath, g_esFlingAbility[type].g_iFlingDeath);
	g_esFlingCache[tank].g_iFlingEffect = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iFlingEffect, g_esFlingAbility[type].g_iFlingEffect);
	g_esFlingCache[tank].g_iFlingHit = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iFlingHit, g_esFlingAbility[type].g_iFlingHit);
	g_esFlingCache[tank].g_iFlingHitMode = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iFlingHitMode, g_esFlingAbility[type].g_iFlingHitMode);
	g_esFlingCache[tank].g_iFlingMessage = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iFlingMessage, g_esFlingAbility[type].g_iFlingMessage);
	g_esFlingCache[tank].g_iFlingRangeCooldown = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iFlingRangeCooldown, g_esFlingAbility[type].g_iFlingRangeCooldown);
	g_esFlingCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iHumanAbility, g_esFlingAbility[type].g_iHumanAbility);
	g_esFlingCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iHumanAmmo, g_esFlingAbility[type].g_iHumanAmmo);
	g_esFlingCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iHumanCooldown, g_esFlingAbility[type].g_iHumanCooldown);
	g_esFlingCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iHumanRangeCooldown, g_esFlingAbility[type].g_iHumanRangeCooldown);
	g_esFlingCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_flOpenAreasOnly, g_esFlingAbility[type].g_flOpenAreasOnly);
	g_esFlingCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esFlingPlayer[tank].g_iRequiresHumans, g_esFlingAbility[type].g_iRequiresHumans);
	g_esFlingPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vFlingCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vFlingCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveFling(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vFlingEventFired(Event event, const char[] name)
#else
public void MT_OnEventFired(Event event, const char[] name, bool dontBroadcast)
#endif
{
	if (StrEqual(name, "bot_player_replace"))
	{
		int iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId),
			iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId);
		if (bIsValidClient(iBot) && bIsTank(iTank))
		{
			vFlingCopyStats2(iBot, iTank);
			vRemoveFling(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vFlingCopyStats2(iTank, iBot);
			vRemoveFling(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (g_bSecondGame && MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vFlingRange(iTank, 1, MT_GetRandomFloat(0.1, 100.0));
			vRemoveFling(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vFlingReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vFlingAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (!g_bSecondGame || (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlingAbility[g_esFlingPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlingPlayer[tank].g_iAccessFlags)) || g_esFlingCache[tank].g_iHumanAbility == 0)))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esFlingCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esFlingCache[tank].g_iFlingAbility == 1 && g_esFlingCache[tank].g_iComboAbility == 0)
	{
		vFlingAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vFlingButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (!g_bSecondGame || bIsAreaNarrow(tank, g_esFlingCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFlingCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFlingPlayer[tank].g_iTankType) || (g_esFlingCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFlingCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlingAbility[g_esFlingPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlingPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esFlingCache[tank].g_iFlingAbility == 1 && g_esFlingCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esFlingPlayer[tank].g_iRangeCooldown == -1 || g_esFlingPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vFlingAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman3", (g_esFlingPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFlingChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveFling(tank);
}

#if defined MT_ABILITIES_MAIN
void vFlingPostTankSpawn(int tank)
#else
public void MT_OnPostTankSpawn(int tank)
#endif
{
	vFlingRange(tank, 1, MT_GetRandomFloat(0.1, 100.0));
}

void vFling(int survivor, int tank)
{
	float flSurvivorPos[3], flTankPos[3], flDistance[3], flRatio[3], flVelocity[3];
	GetClientAbsOrigin(survivor, flSurvivorPos);
	GetClientAbsOrigin(tank, flTankPos);

	flDistance[0] = (flTankPos[0] - flSurvivorPos[0]);
	flDistance[1] = (flTankPos[1] - flSurvivorPos[1]);
	flDistance[2] = (flTankPos[2] - flSurvivorPos[2]);

	flRatio[0] = (flDistance[0] / (SquareRoot((flDistance[1] * flDistance[1]) + (flDistance[0] * flDistance[0]))));
	flRatio[1] = (flDistance[1] / (SquareRoot((flDistance[1] * flDistance[1]) + (flDistance[0] * flDistance[0]))));

	flVelocity[0] = ((flRatio[0] * -1) * g_esFlingCache[tank].g_flFlingForce);
	flVelocity[1] = ((flRatio[1] * -1) * g_esFlingCache[tank].g_flFlingForce);
	flVelocity[2] = g_esFlingCache[tank].g_flFlingForce;

	SDKCall(g_hSDKFling, survivor, flVelocity, 76, tank, 3.0);
}

void vFlingAbility(int tank, float random, int pos = -1)
{
	if (!g_bSecondGame || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlingAbility[g_esFlingPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlingPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esFlingPlayer[tank].g_iAmmoCount < g_esFlingCache[tank].g_iHumanAmmo && g_esFlingCache[tank].g_iHumanAmmo > 0))
	{
		g_esFlingPlayer[tank].g_bFailed = false;
		g_esFlingPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esFlingCache[tank].g_flFlingRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esFlingCache[tank].g_flFlingRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !bIsSurvivorDisabled(iSurvivor) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esFlingPlayer[tank].g_iTankType, g_esFlingAbility[g_esFlingPlayer[tank].g_iTankType].g_iImmunityFlags, g_esFlingPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vFlingHit(iSurvivor, tank, random, flChance, g_esFlingCache[tank].g_iFlingAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlingCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlingCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingAmmo");
	}
}

void vFlingHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (!g_bSecondGame || bIsAreaNarrow(tank, g_esFlingCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFlingCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFlingPlayer[tank].g_iTankType) || (g_esFlingCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFlingCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlingAbility[g_esFlingPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlingPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esFlingPlayer[tank].g_iTankType, g_esFlingAbility[g_esFlingPlayer[tank].g_iTankType].g_iImmunityFlags, g_esFlingPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esFlingPlayer[tank].g_iRangeCooldown != -1 && g_esFlingPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esFlingPlayer[tank].g_iCooldown != -1 && g_esFlingPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !bIsSurvivorDisabled(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esFlingPlayer[tank].g_iAmmoCount < g_esFlingCache[tank].g_iHumanAmmo && g_esFlingCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance)
			{
				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esFlingPlayer[tank].g_iRangeCooldown == -1 || g_esFlingPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlingCache[tank].g_iHumanAbility == 1)
					{
						g_esFlingPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman", g_esFlingPlayer[tank].g_iAmmoCount, g_esFlingCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esFlingCache[tank].g_iFlingRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlingCache[tank].g_iHumanAbility == 1 && g_esFlingPlayer[tank].g_iAmmoCount < g_esFlingCache[tank].g_iHumanAmmo && g_esFlingCache[tank].g_iHumanAmmo > 0) ? g_esFlingCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esFlingPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esFlingPlayer[tank].g_iRangeCooldown != -1 && g_esFlingPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman5", (g_esFlingPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esFlingPlayer[tank].g_iCooldown == -1 || g_esFlingPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esFlingCache[tank].g_iFlingCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlingCache[tank].g_iHumanAbility == 1) ? g_esFlingCache[tank].g_iHumanCooldown : iCooldown;
					g_esFlingPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esFlingPlayer[tank].g_iCooldown != -1 && g_esFlingPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman5", (g_esFlingPlayer[tank].g_iCooldown - iTime));
					}
				}

				vFling(survivor, tank);
				vScreenEffect(survivor, tank, g_esFlingCache[tank].g_iFlingEffect, flags);

				char sTankName[33];
				MT_GetTankName(tank, sTankName);
				if (g_esFlingCache[tank].g_iFlingMessage & messages)
				{
					MT_PrintToChatAll("%s %t", MT_TAG2, "Fling", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Fling", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esFlingPlayer[tank].g_iRangeCooldown == -1 || g_esFlingPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlingCache[tank].g_iHumanAbility == 1 && !g_esFlingPlayer[tank].g_bFailed)
				{
					g_esFlingPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlingCache[tank].g_iHumanAbility == 1 && !g_esFlingPlayer[tank].g_bNoAmmo)
		{
			g_esFlingPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlingAmmo");
		}
	}
}

void vFlingRange(int tank, int value, float random, int pos = -1)
{
	float flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 13, pos) : g_esFlingCache[tank].g_flFlingDeathChance;
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(tank) && g_esFlingCache[tank].g_iFlingDeath == 1 && random <= flChance)
	{
		if (!g_bSecondGame || g_esFlingCache[tank].g_iComboAbility == value || bIsAreaNarrow(tank, g_esFlingCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFlingCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFlingPlayer[tank].g_iTankType) || (g_esFlingCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFlingCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlingAbility[g_esFlingPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlingPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		float flTankPos[3];
		GetClientAbsOrigin(tank, flTankPos);

		float flSurvivorPos[3], flDistance, flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 12, pos) : g_esFlingCache[tank].g_flFlingDeathRange;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !bIsSurvivorDisabled(iSurvivor) && !MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esFlingPlayer[tank].g_iTankType, g_esFlingAbility[g_esFlingPlayer[tank].g_iTankType].g_iImmunityFlags, g_esFlingPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				flDistance = GetVectorDistance(flTankPos, flSurvivorPos);
				if (flDistance <= flRange)
				{
					vFling(iSurvivor, tank);
				}
			}
		}
	}
}

void vFlingCopyStats2(int oldTank, int newTank)
{
	g_esFlingPlayer[newTank].g_iAmmoCount = g_esFlingPlayer[oldTank].g_iAmmoCount;
	g_esFlingPlayer[newTank].g_iCooldown = g_esFlingPlayer[oldTank].g_iCooldown;
	g_esFlingPlayer[newTank].g_iRangeCooldown = g_esFlingPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveFling(int tank)
{
	g_esFlingPlayer[tank].g_bFailed = false;
	g_esFlingPlayer[tank].g_bNoAmmo = false;
	g_esFlingPlayer[tank].g_iAmmoCount = 0;
	g_esFlingPlayer[tank].g_iCooldown = -1;
	g_esFlingPlayer[tank].g_iRangeCooldown = -1;
}

void vFlingReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveFling(iPlayer);
		}
	}
}

Action tTimerFlingCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!g_bSecondGame || !MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esFlingAbility[g_esFlingPlayer[iTank].g_iTankType].g_iAccessFlags, g_esFlingPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esFlingPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esFlingCache[iTank].g_iFlingAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vFlingAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerFlingCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!g_bSecondGame || !bIsSurvivor(iSurvivor))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esFlingAbility[g_esFlingPlayer[iTank].g_iTankType].g_iAccessFlags, g_esFlingPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esFlingPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esFlingCache[iTank].g_iFlingHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esFlingCache[iTank].g_iFlingHitMode == 0 || g_esFlingCache[iTank].g_iFlingHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vFlingHit(iSurvivor, iTank, flRandom, flChance, g_esFlingCache[iTank].g_iFlingHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esFlingCache[iTank].g_iFlingHitMode == 0 || g_esFlingCache[iTank].g_iFlingHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vFlingHit(iSurvivor, iTank, flRandom, flChance, g_esFlingCache[iTank].g_iFlingHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}