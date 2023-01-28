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

#define MT_IDLE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_IDLE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Idle Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank forces survivors to go idle.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Idle Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_IDLE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_IDLE_SECTION "idleability"
#define MT_IDLE_SECTION2 "idle ability"
#define MT_IDLE_SECTION3 "idle_ability"
#define MT_IDLE_SECTION4 "idle"

#define MT_MENU_IDLE "Idle Ability"

enum struct esIdlePlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flIdleChance;
	float g_flIdleRange;
	float g_flIdleRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iIdleAbility;
	int g_iIdleCooldown;
	int g_iIdleEffect;
	int g_iIdleHit;
	int g_iIdleHitMode;
	int g_iIdleMessage;
	int g_iIdleRangeCooldown;
	int g_iImmunityFlags;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esIdlePlayer g_esIdlePlayer[MAXPLAYERS + 1];

enum struct esIdleAbility
{
	float g_flCloseAreasOnly;
	float g_flIdleChance;
	float g_flIdleRange;
	float g_flIdleRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iIdleAbility;
	int g_iIdleCooldown;
	int g_iIdleEffect;
	int g_iIdleHit;
	int g_iIdleHitMode;
	int g_iIdleMessage;
	int g_iIdleRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esIdleAbility g_esIdleAbility[MT_MAXTYPES + 1];

enum struct esIdleCache
{
	float g_flCloseAreasOnly;
	float g_flIdleChance;
	float g_flIdleRange;
	float g_flIdleRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iIdleAbility;
	int g_iIdleCooldown;
	int g_iIdleEffect;
	int g_iIdleHit;
	int g_iIdleHitMode;
	int g_iIdleMessage;
	int g_iIdleRangeCooldown;
	int g_iRequiresHumans;
}

esIdleCache g_esIdleCache[MAXPLAYERS + 1];

Handle g_hSDKGoAFK;

#if defined MT_ABILITIES_MAIN
void vIdleAllPluginsLoaded(GameData gdMutantTanks)
#else
public void OnAllPluginsLoaded()
#endif
{
#if !defined MT_ABILITIES_MAIN
	GameData gdMutantTanks = new GameData(MT_GAMEDATA);
	if (gdMutantTanks == null)
	{
		SetFailState("Unable to load the \"%s\" gamedata file.", MT_GAMEDATA);
	}
#endif
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(gdMutantTanks, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard"))
	{
#if defined MT_ABILITIES_MAIN
		delete gdMutantTanks;

		LogError("%s Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard", MT_TAG);
#else
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");
#endif
	}

	g_hSDKGoAFK = EndPrepSDKCall();
	if (g_hSDKGoAFK == null)
	{
#if defined MT_ABILITIES_MAIN
		LogError("%s Your \"CTerrorPlayer::GoAwayFromKeyboard\" signature is outdated.", MT_TAG);
#else
		SetFailState("Your \"CTerrorPlayer::GoAwayFromKeyboard\" signature is outdated.");
#endif
	}
#if !defined MT_ABILITIES_MAIN
	delete gdMutantTanks;
#endif
}

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_idle", cmdIdleInfo, "View information about the Idle ability.");

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
void vIdleMapStart()
#else
public void OnMapStart()
#endif
{
	vIdleReset();
}

#if defined MT_ABILITIES_MAIN
void vIdleClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnIdleTakeDamage);
	vRemoveIdle(client);
}

#if defined MT_ABILITIES_MAIN
void vIdleClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveIdle(client);
}

#if defined MT_ABILITIES_MAIN
void vIdleMapEnd()
#else
public void OnMapEnd()
#endif
{
	vIdleReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdIdleInfo(int client, int args)
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
		case false: vIdleMenu(client, MT_IDLE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vIdleMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_IDLE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iIdleMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Idle Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iIdleMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esIdleCache[param1].g_iIdleAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esIdleCache[param1].g_iHumanAmmo - g_esIdlePlayer[param1].g_iAmmoCount), g_esIdleCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esIdleCache[param1].g_iHumanAbility == 1) ? g_esIdleCache[param1].g_iHumanCooldown : g_esIdleCache[param1].g_iIdleCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "IdleDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esIdleCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esIdleCache[param1].g_iHumanAbility == 1) ? g_esIdleCache[param1].g_iHumanRangeCooldown : g_esIdleCache[param1].g_iIdleRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vIdleMenu(param1, MT_IDLE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pIdle = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "IdleMenu", param1);
			pIdle.SetTitle(sMenuTitle);
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
void vIdleDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_IDLE, MT_MENU_IDLE);
}

#if defined MT_ABILITIES_MAIN
void vIdleMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_IDLE, false))
	{
		vIdleMenu(client, MT_IDLE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vIdleMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_IDLE, false))
	{
		FormatEx(buffer, size, "%T", "IdleMenu2", client);
	}
}

Action OnIdleTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esIdleCache[attacker].g_iIdleHitMode == 0 || g_esIdleCache[attacker].g_iIdleHitMode == 1) && bIsHumanSurvivor(victim) && g_esIdleCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esIdleAbility[g_esIdlePlayer[attacker].g_iTankType].g_iAccessFlags, g_esIdlePlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esIdlePlayer[attacker].g_iTankType, g_esIdleAbility[g_esIdlePlayer[attacker].g_iTankType].g_iImmunityFlags, g_esIdlePlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vIdleHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esIdleCache[attacker].g_flIdleChance, g_esIdleCache[attacker].g_iIdleHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esIdleCache[victim].g_iIdleHitMode == 0 || g_esIdleCache[victim].g_iIdleHitMode == 2) && bIsHumanSurvivor(attacker) && g_esIdleCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esIdleAbility[g_esIdlePlayer[victim].g_iTankType].g_iAccessFlags, g_esIdlePlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esIdlePlayer[victim].g_iTankType, g_esIdleAbility[g_esIdlePlayer[victim].g_iTankType].g_iImmunityFlags, g_esIdlePlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vIdleHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esIdleCache[victim].g_flIdleChance, g_esIdleCache[victim].g_iIdleHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vIdlePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_IDLE);
}

#if defined MT_ABILITIES_MAIN
void vIdleAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_IDLE_SECTION);
	list2.PushString(MT_IDLE_SECTION2);
	list3.PushString(MT_IDLE_SECTION3);
	list4.PushString(MT_IDLE_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vIdleCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIdleCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_IDLE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_IDLE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_IDLE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_IDLE_SECTION4);
	if (g_esIdleCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_IDLE_SECTION, false) || StrEqual(sSubset[iPos], MT_IDLE_SECTION2, false) || StrEqual(sSubset[iPos], MT_IDLE_SECTION3, false) || StrEqual(sSubset[iPos], MT_IDLE_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esIdleCache[tank].g_iIdleAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vIdleAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerIdleCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esIdleCache[tank].g_iIdleHitMode == 0 || g_esIdleCache[tank].g_iIdleHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vIdleHit(survivor, tank, random, flChance, g_esIdleCache[tank].g_iIdleHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esIdleCache[tank].g_iIdleHitMode == 0 || g_esIdleCache[tank].g_iIdleHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vIdleHit(survivor, tank, random, flChance, g_esIdleCache[tank].g_iIdleHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerIdleCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(survivor));
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteFloat(random);
								dpCombo.WriteFloat(flChance);
								dpCombo.WriteCell(iPos);
								dpCombo.WriteString(classname);
							}
						}
					}
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vIdleConfigsLoad(int mode)
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
				g_esIdleAbility[iIndex].g_iAccessFlags = 0;
				g_esIdleAbility[iIndex].g_iImmunityFlags = 0;
				g_esIdleAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esIdleAbility[iIndex].g_iComboAbility = 0;
				g_esIdleAbility[iIndex].g_iHumanAbility = 0;
				g_esIdleAbility[iIndex].g_iHumanAmmo = 5;
				g_esIdleAbility[iIndex].g_iHumanCooldown = 0;
				g_esIdleAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esIdleAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esIdleAbility[iIndex].g_iRequiresHumans = 1;
				g_esIdleAbility[iIndex].g_iIdleAbility = 0;
				g_esIdleAbility[iIndex].g_iIdleEffect = 0;
				g_esIdleAbility[iIndex].g_iIdleMessage = 0;
				g_esIdleAbility[iIndex].g_flIdleChance = 33.3;
				g_esIdleAbility[iIndex].g_iIdleCooldown = 0;
				g_esIdleAbility[iIndex].g_iIdleHit = 0;
				g_esIdleAbility[iIndex].g_iIdleHitMode = 0;
				g_esIdleAbility[iIndex].g_flIdleRange = 150.0;
				g_esIdleAbility[iIndex].g_flIdleRangeChance = 15.0;
				g_esIdleAbility[iIndex].g_iIdleRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esIdlePlayer[iPlayer].g_iAccessFlags = 0;
					g_esIdlePlayer[iPlayer].g_iImmunityFlags = 0;
					g_esIdlePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esIdlePlayer[iPlayer].g_iComboAbility = 0;
					g_esIdlePlayer[iPlayer].g_iHumanAbility = 0;
					g_esIdlePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esIdlePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esIdlePlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esIdlePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esIdlePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esIdlePlayer[iPlayer].g_iIdleAbility = 0;
					g_esIdlePlayer[iPlayer].g_iIdleEffect = 0;
					g_esIdlePlayer[iPlayer].g_iIdleMessage = 0;
					g_esIdlePlayer[iPlayer].g_flIdleChance = 0.0;
					g_esIdlePlayer[iPlayer].g_iIdleCooldown = 0;
					g_esIdlePlayer[iPlayer].g_iIdleHit = 0;
					g_esIdlePlayer[iPlayer].g_iIdleHitMode = 0;
					g_esIdlePlayer[iPlayer].g_flIdleRange = 0.0;
					g_esIdlePlayer[iPlayer].g_flIdleRangeChance = 0.0;
					g_esIdlePlayer[iPlayer].g_iIdleRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vIdleConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esIdlePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esIdlePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esIdlePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esIdlePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esIdlePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esIdlePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esIdlePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esIdlePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esIdlePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esIdlePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esIdlePlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esIdlePlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esIdlePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esIdlePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esIdlePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esIdlePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esIdlePlayer[admin].g_iIdleAbility = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esIdlePlayer[admin].g_iIdleAbility, value, 0, 1);
		g_esIdlePlayer[admin].g_iIdleEffect = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esIdlePlayer[admin].g_iIdleEffect, value, 0, 7);
		g_esIdlePlayer[admin].g_iIdleMessage = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esIdlePlayer[admin].g_iIdleMessage, value, 0, 3);
		g_esIdlePlayer[admin].g_flIdleChance = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleChance", "Idle Chance", "Idle_Chance", "chance", g_esIdlePlayer[admin].g_flIdleChance, value, 0.0, 100.0);
		g_esIdlePlayer[admin].g_iIdleCooldown = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleCooldown", "Idle Cooldown", "Idle_Cooldown", "cooldown", g_esIdlePlayer[admin].g_iIdleCooldown, value, 0, 99999);
		g_esIdlePlayer[admin].g_iIdleHit = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleHit", "Idle Hit", "Idle_Hit", "hit", g_esIdlePlayer[admin].g_iIdleHit, value, 0, 1);
		g_esIdlePlayer[admin].g_iIdleHitMode = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleHitMode", "Idle Hit Mode", "Idle_Hit_Mode", "hitmode", g_esIdlePlayer[admin].g_iIdleHitMode, value, 0, 2);
		g_esIdlePlayer[admin].g_flIdleRange = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleRange", "Idle Range", "Idle_Range", "range", g_esIdlePlayer[admin].g_flIdleRange, value, 1.0, 99999.0);
		g_esIdlePlayer[admin].g_flIdleRangeChance = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleRangeChance", "Idle Range Chance", "Idle_Range_Chance", "rangechance", g_esIdlePlayer[admin].g_flIdleRangeChance, value, 0.0, 100.0);
		g_esIdlePlayer[admin].g_iIdleRangeCooldown = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleRangeCooldown", "Idle Range Cooldown", "Idle_Range_Cooldown", "rangecooldown", g_esIdlePlayer[admin].g_iIdleRangeCooldown, value, 0, 99999);
		g_esIdlePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esIdlePlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esIdleAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esIdleAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esIdleAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esIdleAbility[type].g_iComboAbility, value, 0, 1);
		g_esIdleAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esIdleAbility[type].g_iHumanAbility, value, 0, 2);
		g_esIdleAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esIdleAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esIdleAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esIdleAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esIdleAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esIdleAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esIdleAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esIdleAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esIdleAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esIdleAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esIdleAbility[type].g_iIdleAbility = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esIdleAbility[type].g_iIdleAbility, value, 0, 1);
		g_esIdleAbility[type].g_iIdleEffect = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esIdleAbility[type].g_iIdleEffect, value, 0, 7);
		g_esIdleAbility[type].g_iIdleMessage = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esIdleAbility[type].g_iIdleMessage, value, 0, 3);
		g_esIdleAbility[type].g_flIdleChance = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleChance", "Idle Chance", "Idle_Chance", "chance", g_esIdleAbility[type].g_flIdleChance, value, 0.0, 100.0);
		g_esIdleAbility[type].g_iIdleCooldown = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleCooldown", "Idle Cooldown", "Idle_Cooldown", "cooldown", g_esIdleAbility[type].g_iIdleCooldown, value, 0, 99999);
		g_esIdleAbility[type].g_iIdleHit = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleHit", "Idle Hit", "Idle_Hit", "hit", g_esIdleAbility[type].g_iIdleHit, value, 0, 1);
		g_esIdleAbility[type].g_iIdleHitMode = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleHitMode", "Idle Hit Mode", "Idle_Hit_Mode", "hitmode", g_esIdleAbility[type].g_iIdleHitMode, value, 0, 2);
		g_esIdleAbility[type].g_flIdleRange = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleRange", "Idle Range", "Idle_Range", "range", g_esIdleAbility[type].g_flIdleRange, value, 1.0, 99999.0);
		g_esIdleAbility[type].g_flIdleRangeChance = flGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleRangeChance", "Idle Range Chance", "Idle_Range_Chance", "rangechance", g_esIdleAbility[type].g_flIdleRangeChance, value, 0.0, 100.0);
		g_esIdleAbility[type].g_iIdleRangeCooldown = iGetKeyValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "IdleRangeCooldown", "Idle Range Cooldown", "Idle_Range_Cooldown", "rangecooldown", g_esIdleAbility[type].g_iIdleRangeCooldown, value, 0, 99999);
		g_esIdleAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esIdleAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_IDLE_SECTION, MT_IDLE_SECTION2, MT_IDLE_SECTION3, MT_IDLE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vIdleSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esIdleCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_flCloseAreasOnly, g_esIdleAbility[type].g_flCloseAreasOnly);
	g_esIdleCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iComboAbility, g_esIdleAbility[type].g_iComboAbility);
	g_esIdleCache[tank].g_flIdleChance = flGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_flIdleChance, g_esIdleAbility[type].g_flIdleChance);
	g_esIdleCache[tank].g_flIdleRange = flGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_flIdleRange, g_esIdleAbility[type].g_flIdleRange);
	g_esIdleCache[tank].g_flIdleRangeChance = flGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_flIdleRangeChance, g_esIdleAbility[type].g_flIdleRangeChance);
	g_esIdleCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iHumanAbility, g_esIdleAbility[type].g_iHumanAbility);
	g_esIdleCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iHumanAmmo, g_esIdleAbility[type].g_iHumanAmmo);
	g_esIdleCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iHumanCooldown, g_esIdleAbility[type].g_iHumanCooldown);
	g_esIdleCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iHumanRangeCooldown, g_esIdleAbility[type].g_iHumanRangeCooldown);
	g_esIdleCache[tank].g_iIdleAbility = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iIdleAbility, g_esIdleAbility[type].g_iIdleAbility);
	g_esIdleCache[tank].g_iIdleCooldown = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iIdleCooldown, g_esIdleAbility[type].g_iIdleCooldown);
	g_esIdleCache[tank].g_iIdleEffect = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iIdleEffect, g_esIdleAbility[type].g_iIdleEffect);
	g_esIdleCache[tank].g_iIdleHit = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iIdleHit, g_esIdleAbility[type].g_iIdleHit);
	g_esIdleCache[tank].g_iIdleHitMode = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iIdleHitMode, g_esIdleAbility[type].g_iIdleHitMode);
	g_esIdleCache[tank].g_iIdleMessage = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iIdleMessage, g_esIdleAbility[type].g_iIdleMessage);
	g_esIdleCache[tank].g_iIdleRangeCooldown = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iIdleRangeCooldown, g_esIdleAbility[type].g_iIdleRangeCooldown);
	g_esIdleCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_flOpenAreasOnly, g_esIdleAbility[type].g_flOpenAreasOnly);
	g_esIdleCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esIdlePlayer[tank].g_iRequiresHumans, g_esIdleAbility[type].g_iRequiresHumans);
	g_esIdlePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vIdleCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vIdleCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveIdle(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vIdleEventFired(Event event, const char[] name)
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
			vIdleCopyStats2(iBot, iTank);
			vRemoveIdle(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vIdleCopyStats2(iTank, iBot);
			vRemoveIdle(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(iTank))
		{
			vRemoveIdle(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vIdleReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vIdleAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esIdleAbility[g_esIdlePlayer[tank].g_iTankType].g_iAccessFlags, g_esIdlePlayer[tank].g_iAccessFlags)) || g_esIdleCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esIdleCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esIdleCache[tank].g_iIdleAbility == 1 && g_esIdleCache[tank].g_iComboAbility == 0)
	{
		vIdleAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vIdleButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esIdleCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esIdleCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esIdlePlayer[tank].g_iTankType) || (g_esIdleCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esIdleCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esIdleAbility[g_esIdlePlayer[tank].g_iTankType].g_iAccessFlags, g_esIdlePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esIdleCache[tank].g_iIdleAbility == 1 && g_esIdleCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esIdlePlayer[tank].g_iRangeCooldown == -1 || g_esIdlePlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vIdleAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "IdleHuman3", (g_esIdlePlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vIdleChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveIdle(tank);
}

void vIdleAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esIdleCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esIdleCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esIdlePlayer[tank].g_iTankType) || (g_esIdleCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esIdleCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esIdleAbility[g_esIdlePlayer[tank].g_iTankType].g_iAccessFlags, g_esIdlePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esIdlePlayer[tank].g_iAmmoCount < g_esIdleCache[tank].g_iHumanAmmo && g_esIdleCache[tank].g_iHumanAmmo > 0))
	{
		g_esIdlePlayer[tank].g_bFailed = false;
		g_esIdlePlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esIdleCache[tank].g_flIdleRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esIdleCache[tank].g_flIdleRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsHumanSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esIdlePlayer[tank].g_iTankType, g_esIdleAbility[g_esIdlePlayer[tank].g_iTankType].g_iImmunityFlags, g_esIdlePlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vIdleHit(iSurvivor, tank, random, flChance, g_esIdleCache[tank].g_iIdleAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIdleCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "IdleHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIdleCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "IdleAmmo");
	}
}

void vIdleHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esIdleCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esIdleCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esIdlePlayer[tank].g_iTankType) || (g_esIdleCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esIdleCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esIdleAbility[g_esIdlePlayer[tank].g_iTankType].g_iAccessFlags, g_esIdlePlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esIdlePlayer[tank].g_iTankType, g_esIdleAbility[g_esIdlePlayer[tank].g_iTankType].g_iImmunityFlags, g_esIdlePlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esIdlePlayer[tank].g_iRangeCooldown != -1 && g_esIdlePlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esIdlePlayer[tank].g_iCooldown != -1 && g_esIdlePlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsHumanSurvivor(survivor) && !bIsSurvivorHanging(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esIdlePlayer[tank].g_iAmmoCount < g_esIdleCache[tank].g_iHumanAmmo && g_esIdleCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esIdlePlayer[survivor].g_bAffected)
			{
				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esIdlePlayer[tank].g_iRangeCooldown == -1 || g_esIdlePlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIdleCache[tank].g_iHumanAbility == 1)
					{
						g_esIdlePlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "IdleHuman", g_esIdlePlayer[tank].g_iAmmoCount, g_esIdleCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esIdleCache[tank].g_iIdleRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIdleCache[tank].g_iHumanAbility == 1 && g_esIdlePlayer[tank].g_iAmmoCount < g_esIdleCache[tank].g_iHumanAmmo && g_esIdleCache[tank].g_iHumanAmmo > 0) ? g_esIdleCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esIdlePlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esIdlePlayer[tank].g_iRangeCooldown != -1 && g_esIdlePlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "IdleHuman5", (g_esIdlePlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esIdlePlayer[tank].g_iCooldown == -1 || g_esIdlePlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esIdleCache[tank].g_iIdleCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIdleCache[tank].g_iHumanAbility == 1) ? g_esIdleCache[tank].g_iHumanCooldown : iCooldown;
					g_esIdlePlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esIdlePlayer[tank].g_iCooldown != -1 && g_esIdlePlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "IdleHuman5", (g_esIdlePlayer[tank].g_iCooldown - iTime));
					}
				}

				switch (iGetHumanCount() > 1 || g_hSDKGoAFK == null)
				{
					case true: FakeClientCommand(survivor, "go_away_from_keyboard");
					case false: SDKCall(g_hSDKGoAFK, survivor);
				}

				if (bIsBotIdle(survivor))
				{
					g_esIdlePlayer[survivor].g_bAffected = true;

					vScreenEffect(survivor, tank, g_esIdleCache[tank].g_iIdleEffect, flags);

					if (g_esIdleCache[tank].g_iIdleMessage & messages)
					{
						char sTankName[33];
						MT_GetTankName(tank, sTankName);
						MT_PrintToChatAll("%s %t", MT_TAG2, "Idle", sTankName, survivor);
						MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Idle", LANG_SERVER, sTankName, survivor);
					}
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esIdlePlayer[tank].g_iRangeCooldown == -1 || g_esIdlePlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIdleCache[tank].g_iHumanAbility == 1 && !g_esIdlePlayer[tank].g_bFailed)
				{
					g_esIdlePlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "IdleHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIdleCache[tank].g_iHumanAbility == 1 && !g_esIdlePlayer[tank].g_bNoAmmo)
		{
			g_esIdlePlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "IdleAmmo");
		}
	}
}

void vIdleCopyStats2(int oldTank, int newTank)
{
	g_esIdlePlayer[newTank].g_iAmmoCount = g_esIdlePlayer[oldTank].g_iAmmoCount;
	g_esIdlePlayer[newTank].g_iCooldown = g_esIdlePlayer[oldTank].g_iCooldown;
	g_esIdlePlayer[newTank].g_iRangeCooldown = g_esIdlePlayer[oldTank].g_iRangeCooldown;
}

void vRemoveIdle(int tank)
{
	g_esIdlePlayer[tank].g_bAffected = false;
	g_esIdlePlayer[tank].g_bFailed = false;
	g_esIdlePlayer[tank].g_bNoAmmo = false;
	g_esIdlePlayer[tank].g_iAmmoCount = 0;
	g_esIdlePlayer[tank].g_iCooldown = -1;
	g_esIdlePlayer[tank].g_iRangeCooldown = -1;
}

void vIdleReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveIdle(iPlayer);
		}
	}
}

Action tTimerIdleCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esIdleAbility[g_esIdlePlayer[iTank].g_iTankType].g_iAccessFlags, g_esIdlePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esIdlePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esIdleCache[iTank].g_iIdleAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vIdleAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerIdleCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esIdleAbility[g_esIdlePlayer[iTank].g_iTankType].g_iAccessFlags, g_esIdlePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esIdlePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esIdleCache[iTank].g_iIdleHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esIdleCache[iTank].g_iIdleHitMode == 0 || g_esIdleCache[iTank].g_iIdleHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vIdleHit(iSurvivor, iTank, flRandom, flChance, g_esIdleCache[iTank].g_iIdleHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esIdleCache[iTank].g_iIdleHitMode == 0 || g_esIdleCache[iTank].g_iIdleHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vIdleHit(iSurvivor, iTank, flRandom, flChance, g_esIdleCache[iTank].g_iIdleHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}