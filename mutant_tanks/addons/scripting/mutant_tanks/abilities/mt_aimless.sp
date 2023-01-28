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

#define MT_AIMLESS_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_AIMLESS_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Aimless Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank prevents survivors from aiming.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Aimless Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_AIMLESS_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_AIMLESS_SECTION "aimlessability"
#define MT_AIMLESS_SECTION2 "aimless ability"
#define MT_AIMLESS_SECTION3 "aimless_ability"
#define MT_AIMLESS_SECTION4 "aimless"

#define MT_MENU_AIMLESS "Aimless Ability"

enum struct esAimlessPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flAimlessChance;
	float g_flAimlessDuration;
	float g_flAimlessRange;
	float g_flAimlessRangeChance;
	float g_flAngle[3];
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAimlessAbility;
	int g_iAimlessCooldown;
	int g_iAimlessEffect;
	int g_iAimlessHit;
	int g_iAimlessHitMode;
	int g_iAimlessMessage;
	int g_iAimlessRangeCooldown;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esAimlessPlayer g_esAimlessPlayer[MAXPLAYERS + 1];

enum struct esAimlessAbility
{
	float g_flAimlessChance;
	float g_flAimlessDuration;
	float g_flAimlessRange;
	float g_flAimlessRangeChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAimlessAbility;
	int g_iAimlessCooldown;
	int g_iAimlessEffect;
	int g_iAimlessHit;
	int g_iAimlessHitMode;
	int g_iAimlessMessage;
	int g_iAimlessRangeCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esAimlessAbility g_esAimlessAbility[MT_MAXTYPES + 1];

enum struct esAimlessCache
{
	float g_flAimlessChance;
	float g_flAimlessDuration;
	float g_flAimlessRange;
	float g_flAimlessRangeChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAimlessAbility;
	int g_iAimlessCooldown;
	int g_iAimlessEffect;
	int g_iAimlessHit;
	int g_iAimlessHitMode;
	int g_iAimlessMessage;
	int g_iAimlessRangeCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
}

esAimlessCache g_esAimlessCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_aimless", cmdAimlessInfo, "View information about the Aimless ability.");

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
void vAimlessMapStart()
#else
public void OnMapStart()
#endif
{
	vAimlessReset();
}

#if defined MT_ABILITIES_MAIN
void vAimlessClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnAimlessTakeDamage);
	vAimlessReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vAimlessClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vAimlessReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vAimlessMapEnd()
#else
public void OnMapEnd()
#endif
{
	vAimlessReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdAimlessInfo(int client, int args)
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
		case false: vAimlessMenu(client, MT_AIMLESS_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vAimlessMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_AIMLESS_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iAimlessMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Aimless Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iAimlessMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esAimlessCache[param1].g_iAimlessAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esAimlessCache[param1].g_iHumanAmmo - g_esAimlessPlayer[param1].g_iAmmoCount), g_esAimlessCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esAimlessCache[param1].g_iHumanAbility == 1) ? g_esAimlessCache[param1].g_iHumanCooldown : g_esAimlessCache[param1].g_iAimlessCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AimlessDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esAimlessCache[param1].g_flAimlessDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esAimlessCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esAimlessCache[param1].g_iHumanAbility == 1) ? g_esAimlessCache[param1].g_iHumanRangeCooldown : g_esAimlessCache[param1].g_iAimlessRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vAimlessMenu(param1, MT_AIMLESS_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pAimless = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "AimlessMenu", param1);
			pAimless.SetTitle(sMenuTitle);
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
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Duration", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
					case 7: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "RangeCooldown", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vAimlessDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_AIMLESS, MT_MENU_AIMLESS);
}

#if defined MT_ABILITIES_MAIN
void vAimlessMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_AIMLESS, false))
	{
		vAimlessMenu(client, MT_AIMLESS_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vAimlessMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_AIMLESS, false))
	{
		FormatEx(buffer, size, "%T", "AimlessMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vAimlessPlayerRunCmd(int client)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (g_esAimlessPlayer[client].g_bAffected && !MT_DoesSurvivorHaveRewardType(client, MT_REWARD_GODMODE))
	{
		TeleportEntity(client, .angles = g_esAimlessPlayer[client].g_flAngle);
	}
#if !defined MT_ABILITIES_MAIN
	return Plugin_Continue;
#endif
}

Action OnAimlessTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esAimlessCache[attacker].g_iAimlessHitMode == 0 || g_esAimlessCache[attacker].g_iAimlessHitMode == 1) && bIsSurvivor(victim) && g_esAimlessCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esAimlessAbility[g_esAimlessPlayer[attacker].g_iTankType].g_iAccessFlags, g_esAimlessPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esAimlessPlayer[attacker].g_iTankType, g_esAimlessAbility[g_esAimlessPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esAimlessPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vAimlessHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esAimlessCache[attacker].g_flAimlessChance, g_esAimlessCache[attacker].g_iAimlessHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esAimlessCache[victim].g_iAimlessHitMode == 0 || g_esAimlessCache[victim].g_iAimlessHitMode == 2) && bIsSurvivor(attacker) && g_esAimlessCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esAimlessAbility[g_esAimlessPlayer[victim].g_iTankType].g_iAccessFlags, g_esAimlessPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esAimlessPlayer[victim].g_iTankType, g_esAimlessAbility[g_esAimlessPlayer[victim].g_iTankType].g_iImmunityFlags, g_esAimlessPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vAimlessHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esAimlessCache[victim].g_flAimlessChance, g_esAimlessCache[victim].g_iAimlessHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vAimlessPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_AIMLESS);
}

#if defined MT_ABILITIES_MAIN
void vAimlessAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_AIMLESS_SECTION);
	list2.PushString(MT_AIMLESS_SECTION2);
	list3.PushString(MT_AIMLESS_SECTION3);
	list4.PushString(MT_AIMLESS_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vAimlessCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAimlessCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_AIMLESS_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_AIMLESS_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_AIMLESS_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_AIMLESS_SECTION4);
	if (g_esAimlessCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_AIMLESS_SECTION, false) || StrEqual(sSubset[iPos], MT_AIMLESS_SECTION2, false) || StrEqual(sSubset[iPos], MT_AIMLESS_SECTION3, false) || StrEqual(sSubset[iPos], MT_AIMLESS_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esAimlessCache[tank].g_iAimlessAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vAimlessAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerAimlessCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esAimlessCache[tank].g_iAimlessHitMode == 0 || g_esAimlessCache[tank].g_iAimlessHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vAimlessHit(survivor, tank, random, flChance, g_esAimlessCache[tank].g_iAimlessHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esAimlessCache[tank].g_iAimlessHitMode == 0 || g_esAimlessCache[tank].g_iAimlessHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vAimlessHit(survivor, tank, random, flChance, g_esAimlessCache[tank].g_iAimlessHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerAimlessCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vAimlessConfigsLoad(int mode)
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
				g_esAimlessAbility[iIndex].g_iAccessFlags = 0;
				g_esAimlessAbility[iIndex].g_iImmunityFlags = 0;
				g_esAimlessAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esAimlessAbility[iIndex].g_iComboAbility = 0;
				g_esAimlessAbility[iIndex].g_iHumanAbility = 0;
				g_esAimlessAbility[iIndex].g_iHumanAmmo = 5;
				g_esAimlessAbility[iIndex].g_iHumanCooldown = 0;
				g_esAimlessAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esAimlessAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esAimlessAbility[iIndex].g_iRequiresHumans = 1;
				g_esAimlessAbility[iIndex].g_iAimlessAbility = 0;
				g_esAimlessAbility[iIndex].g_iAimlessEffect = 0;
				g_esAimlessAbility[iIndex].g_iAimlessMessage = 0;
				g_esAimlessAbility[iIndex].g_flAimlessChance = 33.3;
				g_esAimlessAbility[iIndex].g_iAimlessCooldown = 0;
				g_esAimlessAbility[iIndex].g_flAimlessDuration = 5.0;
				g_esAimlessAbility[iIndex].g_iAimlessHit = 0;
				g_esAimlessAbility[iIndex].g_iAimlessHitMode = 0;
				g_esAimlessAbility[iIndex].g_flAimlessRange = 150.0;
				g_esAimlessAbility[iIndex].g_flAimlessRangeChance = 15.0;
				g_esAimlessAbility[iIndex].g_iAimlessRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esAimlessPlayer[iPlayer].g_iAccessFlags = 0;
					g_esAimlessPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esAimlessPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esAimlessPlayer[iPlayer].g_iComboAbility = 0;
					g_esAimlessPlayer[iPlayer].g_iHumanAbility = 0;
					g_esAimlessPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esAimlessPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esAimlessPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esAimlessPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esAimlessPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esAimlessPlayer[iPlayer].g_iAimlessAbility = 0;
					g_esAimlessPlayer[iPlayer].g_iAimlessEffect = 0;
					g_esAimlessPlayer[iPlayer].g_iAimlessMessage = 0;
					g_esAimlessPlayer[iPlayer].g_flAimlessChance = 0.0;
					g_esAimlessPlayer[iPlayer].g_iAimlessCooldown = 0;
					g_esAimlessPlayer[iPlayer].g_flAimlessDuration = 0.0;
					g_esAimlessPlayer[iPlayer].g_iAimlessHit = 0;
					g_esAimlessPlayer[iPlayer].g_iAimlessHitMode = 0;
					g_esAimlessPlayer[iPlayer].g_flAimlessRange = 0.0;
					g_esAimlessPlayer[iPlayer].g_flAimlessRangeChance = 0.0;
					g_esAimlessPlayer[iPlayer].g_iAimlessRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vAimlessConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esAimlessPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esAimlessPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esAimlessPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esAimlessPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esAimlessPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esAimlessPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esAimlessPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esAimlessPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esAimlessPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esAimlessPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esAimlessPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esAimlessPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esAimlessPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esAimlessPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esAimlessPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esAimlessPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esAimlessPlayer[admin].g_iAimlessAbility = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esAimlessPlayer[admin].g_iAimlessAbility, value, 0, 1);
		g_esAimlessPlayer[admin].g_iAimlessEffect = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esAimlessPlayer[admin].g_iAimlessEffect, value, 0, 7);
		g_esAimlessPlayer[admin].g_iAimlessMessage = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esAimlessPlayer[admin].g_iAimlessMessage, value, 0, 3);
		g_esAimlessPlayer[admin].g_flAimlessChance = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessChance", "Aimless Chance", "Aimless_Chance", "chance", g_esAimlessPlayer[admin].g_flAimlessChance, value, 0.0, 100.0);
		g_esAimlessPlayer[admin].g_iAimlessCooldown = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessCooldown", "Aimless Cooldown", "Aimless_Cooldown", "cooldown", g_esAimlessPlayer[admin].g_iAimlessCooldown, value, 0, 99999);
		g_esAimlessPlayer[admin].g_flAimlessDuration = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessDuration", "Aimless Duration", "Aimless_Duration", "duration", g_esAimlessPlayer[admin].g_flAimlessDuration, value, 0.1, 99999.0);
		g_esAimlessPlayer[admin].g_iAimlessHit = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessHit", "Aimless Hit", "Aimless_Hit", "hit", g_esAimlessPlayer[admin].g_iAimlessHit, value, 0, 1);
		g_esAimlessPlayer[admin].g_iAimlessHitMode = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessHitMode", "Aimless Hit Mode", "Aimless_Hit_Mode", "hitmode", g_esAimlessPlayer[admin].g_iAimlessHitMode, value, 0, 2);
		g_esAimlessPlayer[admin].g_flAimlessRange = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessRange", "Aimless Range", "Aimless_Range", "range", g_esAimlessPlayer[admin].g_flAimlessRange, value, 1.0, 99999.0);
		g_esAimlessPlayer[admin].g_flAimlessRangeChance = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessRangeChance", "Aimless Range Chance", "Aimless_Range_Chance", "rangechance", g_esAimlessPlayer[admin].g_flAimlessRangeChance, value, 0.0, 100.0);
		g_esAimlessPlayer[admin].g_iAimlessRangeCooldown = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessRangeCooldown", "Aimless Range Cooldown", "Aimless_Range_Cooldown", "rangecooldown", g_esAimlessPlayer[admin].g_iAimlessRangeCooldown, value, 0, 99999);
		g_esAimlessPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esAimlessPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esAimlessAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esAimlessAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esAimlessAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esAimlessAbility[type].g_iComboAbility, value, 0, 1);
		g_esAimlessAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esAimlessAbility[type].g_iHumanAbility, value, 0, 2);
		g_esAimlessAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esAimlessAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esAimlessAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esAimlessAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esAimlessAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esAimlessAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esAimlessAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esAimlessAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esAimlessAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esAimlessAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esAimlessAbility[type].g_iAimlessAbility = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esAimlessAbility[type].g_iAimlessAbility, value, 0, 1);
		g_esAimlessAbility[type].g_iAimlessEffect = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esAimlessAbility[type].g_iAimlessEffect, value, 0, 7);
		g_esAimlessAbility[type].g_iAimlessMessage = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esAimlessAbility[type].g_iAimlessMessage, value, 0, 3);
		g_esAimlessAbility[type].g_flAimlessChance = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessChance", "Aimless Chance", "Aimless_Chance", "chance", g_esAimlessAbility[type].g_flAimlessChance, value, 0.0, 100.0);
		g_esAimlessAbility[type].g_iAimlessCooldown = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessCooldown", "Aimless Cooldown", "Aimless_Cooldown", "cooldown", g_esAimlessAbility[type].g_iAimlessCooldown, value, 0, 99999);
		g_esAimlessAbility[type].g_flAimlessDuration = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessDuration", "Aimless Duration", "Aimless_Duration", "duration", g_esAimlessAbility[type].g_flAimlessDuration, value, 0.1, 99999.0);
		g_esAimlessAbility[type].g_iAimlessHit = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessHit", "Aimless Hit", "Aimless_Hit", "hit", g_esAimlessAbility[type].g_iAimlessHit, value, 0, 1);
		g_esAimlessAbility[type].g_iAimlessHitMode = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessHitMode", "Aimless Hit Mode", "Aimless_Hit_Mode", "hitmode", g_esAimlessAbility[type].g_iAimlessHitMode, value, 0, 2);
		g_esAimlessAbility[type].g_flAimlessRange = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessRange", "Aimless Range", "Aimless_Range", "range", g_esAimlessAbility[type].g_flAimlessRange, value, 1.0, 99999.0);
		g_esAimlessAbility[type].g_flAimlessRangeChance = flGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessRangeChance", "Aimless Range Chance", "Aimless_Range_Chance", "rangechance", g_esAimlessAbility[type].g_flAimlessRangeChance, value, 0.0, 100.0);
		g_esAimlessAbility[type].g_iAimlessRangeCooldown = iGetKeyValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AimlessRangeCooldown", "Aimless Range Cooldown", "Aimless_Range_Cooldown", "rangecooldown", g_esAimlessAbility[type].g_iAimlessRangeCooldown, value, 0, 99999);
		g_esAimlessAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esAimlessAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_AIMLESS_SECTION, MT_AIMLESS_SECTION2, MT_AIMLESS_SECTION3, MT_AIMLESS_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vAimlessSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esAimlessCache[tank].g_flAimlessChance = flGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_flAimlessChance, g_esAimlessAbility[type].g_flAimlessChance);
	g_esAimlessCache[tank].g_flAimlessDuration = flGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_flAimlessDuration, g_esAimlessAbility[type].g_flAimlessDuration);
	g_esAimlessCache[tank].g_flAimlessRange = flGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_flAimlessRange, g_esAimlessAbility[type].g_flAimlessRange);
	g_esAimlessCache[tank].g_flAimlessRangeChance = flGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_flAimlessRangeChance, g_esAimlessAbility[type].g_flAimlessRangeChance);
	g_esAimlessCache[tank].g_iAimlessAbility = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iAimlessAbility, g_esAimlessAbility[type].g_iAimlessAbility);
	g_esAimlessCache[tank].g_iAimlessCooldown = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iAimlessCooldown, g_esAimlessAbility[type].g_iAimlessCooldown);
	g_esAimlessCache[tank].g_iAimlessEffect = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iAimlessEffect, g_esAimlessAbility[type].g_iAimlessEffect);
	g_esAimlessCache[tank].g_iAimlessHit = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iAimlessHit, g_esAimlessAbility[type].g_iAimlessHit);
	g_esAimlessCache[tank].g_iAimlessHitMode = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iAimlessHitMode, g_esAimlessAbility[type].g_iAimlessHitMode);
	g_esAimlessCache[tank].g_iAimlessMessage = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iAimlessMessage, g_esAimlessAbility[type].g_iAimlessMessage);
	g_esAimlessCache[tank].g_iAimlessRangeCooldown = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iAimlessRangeCooldown, g_esAimlessAbility[type].g_iAimlessRangeCooldown);
	g_esAimlessCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_flCloseAreasOnly, g_esAimlessAbility[type].g_flCloseAreasOnly);
	g_esAimlessCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iComboAbility, g_esAimlessAbility[type].g_iComboAbility);
	g_esAimlessCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iHumanAbility, g_esAimlessAbility[type].g_iHumanAbility);
	g_esAimlessCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iHumanAmmo, g_esAimlessAbility[type].g_iHumanAmmo);
	g_esAimlessCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iHumanCooldown, g_esAimlessAbility[type].g_iHumanCooldown);
	g_esAimlessCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iHumanRangeCooldown, g_esAimlessAbility[type].g_iHumanRangeCooldown);
	g_esAimlessCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_flOpenAreasOnly, g_esAimlessAbility[type].g_flOpenAreasOnly);
	g_esAimlessCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esAimlessPlayer[tank].g_iRequiresHumans, g_esAimlessAbility[type].g_iRequiresHumans);
	g_esAimlessPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vAimlessCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vAimlessCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveAimless(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vAimlessEventFired(Event event, const char[] name)
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
			vAimlessCopyStats2(iBot, iTank);
			vRemoveAimless(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vAimlessCopyStats2(iTank, iBot);
			vRemoveAimless(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveAimless(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vAimlessReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vAimlessAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAimlessAbility[g_esAimlessPlayer[tank].g_iTankType].g_iAccessFlags, g_esAimlessPlayer[tank].g_iAccessFlags)) || g_esAimlessCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esAimlessCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esAimlessCache[tank].g_iAimlessAbility == 1 && g_esAimlessCache[tank].g_iComboAbility == 0)
	{
		vAimlessAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vAimlessButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esAimlessCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAimlessCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAimlessPlayer[tank].g_iTankType) || (g_esAimlessCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAimlessCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAimlessAbility[g_esAimlessPlayer[tank].g_iTankType].g_iAccessFlags, g_esAimlessPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esAimlessCache[tank].g_iAimlessAbility == 1 && g_esAimlessCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esAimlessPlayer[tank].g_iRangeCooldown == -1 || g_esAimlessPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vAimlessAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "AimlessHuman3", (g_esAimlessPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vAimlessChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveAimless(tank);
}

void vAimlessAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esAimlessCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAimlessCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAimlessPlayer[tank].g_iTankType) || (g_esAimlessCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAimlessCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAimlessAbility[g_esAimlessPlayer[tank].g_iTankType].g_iAccessFlags, g_esAimlessPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esAimlessPlayer[tank].g_iAmmoCount < g_esAimlessCache[tank].g_iHumanAmmo && g_esAimlessCache[tank].g_iHumanAmmo > 0))
	{
		g_esAimlessPlayer[tank].g_bFailed = false;
		g_esAimlessPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esAimlessCache[tank].g_flAimlessRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esAimlessCache[tank].g_flAimlessRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esAimlessPlayer[tank].g_iTankType, g_esAimlessAbility[g_esAimlessPlayer[tank].g_iTankType].g_iImmunityFlags, g_esAimlessPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vAimlessHit(iSurvivor, tank, random, flChance, g_esAimlessCache[tank].g_iAimlessAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAimlessCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "AimlessHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAimlessCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "AimlessAmmo");
	}
}

void vAimlessHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esAimlessCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAimlessCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAimlessPlayer[tank].g_iTankType) || (g_esAimlessCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAimlessCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAimlessAbility[g_esAimlessPlayer[tank].g_iTankType].g_iAccessFlags, g_esAimlessPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esAimlessPlayer[tank].g_iTankType, g_esAimlessAbility[g_esAimlessPlayer[tank].g_iTankType].g_iImmunityFlags, g_esAimlessPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esAimlessPlayer[tank].g_iRangeCooldown != -1 && g_esAimlessPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esAimlessPlayer[tank].g_iCooldown != -1 && g_esAimlessPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esAimlessPlayer[tank].g_iAmmoCount < g_esAimlessCache[tank].g_iHumanAmmo && g_esAimlessCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esAimlessPlayer[survivor].g_bAffected)
			{
				g_esAimlessPlayer[survivor].g_bAffected = true;
				g_esAimlessPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esAimlessPlayer[tank].g_iRangeCooldown == -1 || g_esAimlessPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAimlessCache[tank].g_iHumanAbility == 1)
					{
						g_esAimlessPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "AimlessHuman", g_esAimlessPlayer[tank].g_iAmmoCount, g_esAimlessCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esAimlessCache[tank].g_iAimlessRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAimlessCache[tank].g_iHumanAbility == 1 && g_esAimlessPlayer[tank].g_iAmmoCount < g_esAimlessCache[tank].g_iHumanAmmo && g_esAimlessCache[tank].g_iHumanAmmo > 0) ? g_esAimlessCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esAimlessPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esAimlessPlayer[tank].g_iRangeCooldown != -1 && g_esAimlessPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "AimlessHuman5", (g_esAimlessPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esAimlessPlayer[tank].g_iCooldown == -1 || g_esAimlessPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esAimlessCache[tank].g_iAimlessCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAimlessCache[tank].g_iHumanAbility == 1) ? g_esAimlessCache[tank].g_iHumanCooldown : iCooldown;
					g_esAimlessPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esAimlessPlayer[tank].g_iCooldown != -1 && g_esAimlessPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "AimlessHuman5", (g_esAimlessPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esAimlessCache[tank].g_flAimlessDuration;
				DataPack dpStopAimless;
				CreateDataTimer(flDuration, tTimerStopAimless, dpStopAimless, TIMER_FLAG_NO_MAPCHANGE);
				dpStopAimless.WriteCell(GetClientUserId(survivor));
				dpStopAimless.WriteCell(GetClientUserId(tank));
				dpStopAimless.WriteCell(messages);

				GetClientEyeAngles(survivor, g_esAimlessPlayer[survivor].g_flAngle);
				vScreenEffect(survivor, tank, g_esAimlessCache[tank].g_iAimlessEffect, flags);

				if (g_esAimlessCache[tank].g_iAimlessMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Aimless", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Aimless", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esAimlessPlayer[tank].g_iRangeCooldown == -1 || g_esAimlessPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAimlessCache[tank].g_iHumanAbility == 1 && !g_esAimlessPlayer[tank].g_bFailed)
				{
					g_esAimlessPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "AimlessHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAimlessCache[tank].g_iHumanAbility == 1 && !g_esAimlessPlayer[tank].g_bNoAmmo)
		{
			g_esAimlessPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "AimlessAmmo");
		}
	}
}

void vAimlessCopyStats2(int oldTank, int newTank)
{
	g_esAimlessPlayer[newTank].g_iAmmoCount = g_esAimlessPlayer[oldTank].g_iAmmoCount;
	g_esAimlessPlayer[newTank].g_iCooldown = g_esAimlessPlayer[oldTank].g_iCooldown;
	g_esAimlessPlayer[newTank].g_iRangeCooldown = g_esAimlessPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveAimless(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esAimlessPlayer[iSurvivor].g_bAffected && g_esAimlessPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esAimlessPlayer[iSurvivor].g_bAffected = false;
			g_esAimlessPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vAimlessReset2(tank);
}

void vAimlessReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vAimlessReset2(iPlayer);

			g_esAimlessPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vAimlessReset2(int tank)
{
	g_esAimlessPlayer[tank].g_bAffected = false;
	g_esAimlessPlayer[tank].g_bFailed = false;
	g_esAimlessPlayer[tank].g_bNoAmmo = false;
	g_esAimlessPlayer[tank].g_iAmmoCount = 0;
	g_esAimlessPlayer[tank].g_iCooldown = -1;
	g_esAimlessPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerAimlessCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esAimlessAbility[g_esAimlessPlayer[iTank].g_iTankType].g_iAccessFlags, g_esAimlessPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esAimlessPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esAimlessCache[iTank].g_iAimlessAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vAimlessAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerAimlessCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esAimlessPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esAimlessAbility[g_esAimlessPlayer[iTank].g_iTankType].g_iAccessFlags, g_esAimlessPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esAimlessPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esAimlessCache[iTank].g_iAimlessHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esAimlessCache[iTank].g_iAimlessHitMode == 0 || g_esAimlessCache[iTank].g_iAimlessHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vAimlessHit(iSurvivor, iTank, flRandom, flChance, g_esAimlessCache[iTank].g_iAimlessHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esAimlessCache[iTank].g_iAimlessHitMode == 0 || g_esAimlessCache[iTank].g_iAimlessHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vAimlessHit(iSurvivor, iTank, flRandom, flChance, g_esAimlessCache[iTank].g_iAimlessHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopAimless(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || !g_esAimlessPlayer[iSurvivor].g_bAffected)
	{
		g_esAimlessPlayer[iSurvivor].g_bAffected = false;
		g_esAimlessPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank))
	{
		g_esAimlessPlayer[iSurvivor].g_bAffected = false;
		g_esAimlessPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	g_esAimlessPlayer[iSurvivor].g_bAffected = false;
	g_esAimlessPlayer[iSurvivor].g_iOwner = 0;

	int iMessage = pack.ReadCell();
	if (g_esAimlessCache[iTank].g_iAimlessMessage & iMessage)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Aimless2", iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Aimless2", LANG_SERVER, iSurvivor);
	}

	return Plugin_Continue;
}