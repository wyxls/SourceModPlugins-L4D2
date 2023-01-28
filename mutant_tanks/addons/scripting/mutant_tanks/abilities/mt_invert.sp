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

#define MT_INVERT_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_INVERT_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Invert Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank inverts the survivors' movement keys.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Invert Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_INVERT_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_INVERT_SECTION "invertability"
#define MT_INVERT_SECTION2 "invert ability"
#define MT_INVERT_SECTION3 "invert_ability"
#define MT_INVERT_SECTION4 "invert"

#define MT_MENU_INVERT "Invert Ability"

enum struct esInvertPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flInvertChance;
	float g_flInvertDuration;
	float g_flInvertRange;
	float g_flInvertRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iInvertAbility;
	int g_iInvertCooldown;
	int g_iInvertEffect;
	int g_iInvertHit;
	int g_iInvertHitMode;
	int g_iInvertMessage;
	int g_iInvertRangeCooldown;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esInvertPlayer g_esInvertPlayer[MAXPLAYERS + 1];

enum struct esInvertAbility
{
	float g_flCloseAreasOnly;
	float g_flInvertChance;
	float g_flInvertDuration;
	float g_flInvertRange;
	float g_flInvertRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iInvertAbility;
	int g_iInvertCooldown;
	int g_iInvertEffect;
	int g_iInvertHit;
	int g_iInvertHitMode;
	int g_iInvertMessage;
	int g_iInvertRangeCooldown;
	int g_iRequiresHumans;
}

esInvertAbility g_esInvertAbility[MT_MAXTYPES + 1];

enum struct esInvertCache
{
	float g_flCloseAreasOnly;
	float g_flInvertChance;
	float g_flInvertDuration;
	float g_flInvertRange;
	float g_flInvertRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iInvertAbility;
	int g_iInvertCooldown;
	int g_iInvertEffect;
	int g_iInvertHit;
	int g_iInvertHitMode;
	int g_iInvertMessage;
	int g_iInvertRangeCooldown;
	int g_iRequiresHumans;
}

esInvertCache g_esInvertCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_invert", cmdInvertInfo, "View information about the Invert ability.");

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
void vInvertMapStart()
#else
public void OnMapStart()
#endif
{
	vInvertReset();
}

#if defined MT_ABILITIES_MAIN
void vInvertClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnInvertTakeDamage);
	vInvertReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vInvertClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vInvertReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vInvertMapEnd()
#else
public void OnMapEnd()
#endif
{
	vInvertReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdInvertInfo(int client, int args)
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
		case false: vInvertMenu(client, MT_INVERT_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vInvertMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_INVERT_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iInvertMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Invert Ability Information");
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

int iInvertMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esInvertCache[param1].g_iInvertAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esInvertCache[param1].g_iHumanAmmo - g_esInvertPlayer[param1].g_iAmmoCount), g_esInvertCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esInvertCache[param1].g_iHumanAbility == 1) ? g_esInvertCache[param1].g_iHumanCooldown : g_esInvertCache[param1].g_iInvertCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "InvertDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esInvertCache[param1].g_flInvertDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esInvertCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esInvertCache[param1].g_iHumanAbility == 1) ? g_esInvertCache[param1].g_iHumanRangeCooldown : g_esInvertCache[param1].g_iInvertRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vInvertMenu(param1, MT_INVERT_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pInvert = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "InvertMenu", param1);
			pInvert.SetTitle(sMenuTitle);
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
void vInvertDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_INVERT, MT_MENU_INVERT);
}

#if defined MT_ABILITIES_MAIN
void vInvertMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_INVERT, false))
	{
		vInvertMenu(client, MT_INVERT_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vInvertMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_INVERT, false))
	{
		FormatEx(buffer, size, "%T", "InvertMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
Action aInvertPlayerRunCmd(int client, int &buttons, float vel[3])
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsCorePluginEnabled())
	{
		return Plugin_Continue;
	}

	if (bIsSurvivor(client) && g_esInvertPlayer[client].g_bAffected)
	{
		vel[0] = -vel[0];
		if (buttons & IN_FORWARD)
		{
			buttons &= ~IN_FORWARD;
			buttons |= IN_BACK;
		}
		else if (buttons & IN_BACK)
		{
			buttons &= ~IN_BACK;
			buttons |= IN_FORWARD;
		}

		vel[1] = -vel[1];
		if (buttons & IN_MOVELEFT)
		{
			buttons &= ~IN_MOVELEFT;
			buttons |= IN_MOVERIGHT;
		}
		else if (buttons & IN_MOVERIGHT)
		{
			buttons &= ~IN_MOVERIGHT;
			buttons |= IN_MOVELEFT;
		}

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

Action OnInvertTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esInvertCache[attacker].g_iInvertHitMode == 0 || g_esInvertCache[attacker].g_iInvertHitMode == 1) && bIsSurvivor(victim) && g_esInvertCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esInvertAbility[g_esInvertPlayer[attacker].g_iTankType].g_iAccessFlags, g_esInvertPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esInvertPlayer[attacker].g_iTankType, g_esInvertAbility[g_esInvertPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esInvertPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vInvertHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esInvertCache[attacker].g_flInvertChance, g_esInvertCache[attacker].g_iInvertHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esInvertCache[victim].g_iInvertHitMode == 0 || g_esInvertCache[victim].g_iInvertHitMode == 2) && bIsSurvivor(attacker) && g_esInvertCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esInvertAbility[g_esInvertPlayer[victim].g_iTankType].g_iAccessFlags, g_esInvertPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esInvertPlayer[victim].g_iTankType, g_esInvertAbility[g_esInvertPlayer[victim].g_iTankType].g_iImmunityFlags, g_esInvertPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vInvertHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esInvertCache[victim].g_flInvertChance, g_esInvertCache[victim].g_iInvertHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vInvertPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_INVERT);
}

#if defined MT_ABILITIES_MAIN
void vInvertAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_INVERT_SECTION);
	list2.PushString(MT_INVERT_SECTION2);
	list3.PushString(MT_INVERT_SECTION3);
	list4.PushString(MT_INVERT_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vInvertCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esInvertCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_INVERT_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_INVERT_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_INVERT_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_INVERT_SECTION4);
	if (g_esInvertCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_INVERT_SECTION, false) || StrEqual(sSubset[iPos], MT_INVERT_SECTION2, false) || StrEqual(sSubset[iPos], MT_INVERT_SECTION3, false) || StrEqual(sSubset[iPos], MT_INVERT_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esInvertCache[tank].g_iInvertAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vInvertAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerInvertCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esInvertCache[tank].g_iInvertHitMode == 0 || g_esInvertCache[tank].g_iInvertHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vInvertHit(survivor, tank, random, flChance, g_esInvertCache[tank].g_iInvertHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esInvertCache[tank].g_iInvertHitMode == 0 || g_esInvertCache[tank].g_iInvertHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vInvertHit(survivor, tank, random, flChance, g_esInvertCache[tank].g_iInvertHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerInvertCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vInvertConfigsLoad(int mode)
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
				g_esInvertAbility[iIndex].g_iAccessFlags = 0;
				g_esInvertAbility[iIndex].g_iImmunityFlags = 0;
				g_esInvertAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esInvertAbility[iIndex].g_iComboAbility = 0;
				g_esInvertAbility[iIndex].g_iHumanAbility = 0;
				g_esInvertAbility[iIndex].g_iHumanAmmo = 5;
				g_esInvertAbility[iIndex].g_iHumanCooldown = 0;
				g_esInvertAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esInvertAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esInvertAbility[iIndex].g_iRequiresHumans = 0;
				g_esInvertAbility[iIndex].g_iInvertAbility = 0;
				g_esInvertAbility[iIndex].g_iInvertEffect = 0;
				g_esInvertAbility[iIndex].g_iInvertMessage = 0;
				g_esInvertAbility[iIndex].g_flInvertChance = 33.3;
				g_esInvertAbility[iIndex].g_iInvertCooldown = 0;
				g_esInvertAbility[iIndex].g_flInvertDuration = 5.0;
				g_esInvertAbility[iIndex].g_iInvertHit = 0;
				g_esInvertAbility[iIndex].g_iInvertHitMode = 0;
				g_esInvertAbility[iIndex].g_flInvertRange = 150.0;
				g_esInvertAbility[iIndex].g_flInvertRangeChance = 15.0;
				g_esInvertAbility[iIndex].g_iInvertRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esInvertPlayer[iPlayer].g_iAccessFlags = 0;
					g_esInvertPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esInvertPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esInvertPlayer[iPlayer].g_iComboAbility = 0;
					g_esInvertPlayer[iPlayer].g_iHumanAbility = 0;
					g_esInvertPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esInvertPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esInvertPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esInvertPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esInvertPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esInvertPlayer[iPlayer].g_iInvertAbility = 0;
					g_esInvertPlayer[iPlayer].g_iInvertEffect = 0;
					g_esInvertPlayer[iPlayer].g_iInvertMessage = 0;
					g_esInvertPlayer[iPlayer].g_flInvertChance = 0.0;
					g_esInvertPlayer[iPlayer].g_iInvertCooldown = 0;
					g_esInvertPlayer[iPlayer].g_flInvertDuration = 0.0;
					g_esInvertPlayer[iPlayer].g_iInvertHit = 0;
					g_esInvertPlayer[iPlayer].g_iInvertHitMode = 0;
					g_esInvertPlayer[iPlayer].g_flInvertRange = 0.0;
					g_esInvertPlayer[iPlayer].g_flInvertRangeChance = 0.0;
					g_esInvertPlayer[iPlayer].g_iInvertRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vInvertConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esInvertPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esInvertPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esInvertPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esInvertPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esInvertPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esInvertPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esInvertPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esInvertPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esInvertPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esInvertPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esInvertPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esInvertPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esInvertPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esInvertPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esInvertPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esInvertPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esInvertPlayer[admin].g_iInvertAbility = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esInvertPlayer[admin].g_iInvertAbility, value, 0, 1);
		g_esInvertPlayer[admin].g_iInvertEffect = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esInvertPlayer[admin].g_iInvertEffect, value, 0, 7);
		g_esInvertPlayer[admin].g_iInvertMessage = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esInvertPlayer[admin].g_iInvertMessage, value, 0, 3);
		g_esInvertPlayer[admin].g_flInvertChance = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertChance", "Invert Chance", "Invert_Chance", "chance", g_esInvertPlayer[admin].g_flInvertChance, value, 0.0, 100.0);
		g_esInvertPlayer[admin].g_iInvertCooldown = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertCooldown", "Invert Cooldown", "Invert_Cooldown", "cooldown", g_esInvertPlayer[admin].g_iInvertCooldown, value, 0, 99999);
		g_esInvertPlayer[admin].g_flInvertDuration = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertDuration", "Invert Duration", "Invert_Duration", "duration", g_esInvertPlayer[admin].g_flInvertDuration, value, 0.1, 99999.0);
		g_esInvertPlayer[admin].g_iInvertHit = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertHit", "Invert Hit", "Invert_Hit", "hit", g_esInvertPlayer[admin].g_iInvertHit, value, 0, 1);
		g_esInvertPlayer[admin].g_iInvertHitMode = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertHitMode", "Invert Hit Mode", "Invert_Hit_Mode", "hitmde", g_esInvertPlayer[admin].g_iInvertHitMode, value, 0, 2);
		g_esInvertPlayer[admin].g_flInvertRange = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertRange", "Invert Range", "Invert_Range", "range", g_esInvertPlayer[admin].g_flInvertRange, value, 1.0, 99999.0);
		g_esInvertPlayer[admin].g_flInvertRangeChance = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertRangeChance", "Invert Range Chance", "Invert_Range_Chance", "rangechance", g_esInvertPlayer[admin].g_flInvertRangeChance, value, 0.0, 100.0);
		g_esInvertPlayer[admin].g_iInvertRangeCooldown = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertRangeCooldown", "Invert Range Cooldown", "Invert_Range_Cooldown", "rangecooldown", g_esInvertPlayer[admin].g_iInvertRangeCooldown, value, 0, 99999);
		g_esInvertPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esInvertPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esInvertAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esInvertAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esInvertAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esInvertAbility[type].g_iComboAbility, value, 0, 1);
		g_esInvertAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esInvertAbility[type].g_iHumanAbility, value, 0, 2);
		g_esInvertAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esInvertAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esInvertAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esInvertAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esInvertAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esInvertAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esInvertAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esInvertAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esInvertAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esInvertAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esInvertAbility[type].g_iInvertAbility = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esInvertAbility[type].g_iInvertAbility, value, 0, 1);
		g_esInvertAbility[type].g_iInvertEffect = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esInvertAbility[type].g_iInvertEffect, value, 0, 7);
		g_esInvertAbility[type].g_iInvertMessage = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esInvertAbility[type].g_iInvertMessage, value, 0, 3);
		g_esInvertAbility[type].g_flInvertChance = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertChance", "Invert Chance", "Invert_Chance", "chance", g_esInvertAbility[type].g_flInvertChance, value, 0.0, 100.0);
		g_esInvertAbility[type].g_iInvertCooldown = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertCooldown", "Invert Cooldown", "Invert_Cooldown", "cooldown", g_esInvertAbility[type].g_iInvertCooldown, value, 0, 99999);
		g_esInvertAbility[type].g_flInvertDuration = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertDuration", "Invert Duration", "Invert_Duration", "duration", g_esInvertAbility[type].g_flInvertDuration, value, 0.1, 99999.0);
		g_esInvertAbility[type].g_iInvertHit = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertHit", "Invert Hit", "Invert_Hit", "hit", g_esInvertAbility[type].g_iInvertHit, value, 0, 1);
		g_esInvertAbility[type].g_iInvertHitMode = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertHitMode", "Invert Hit Mode", "Invert_Hit_Mode", "hitmde", g_esInvertAbility[type].g_iInvertHitMode, value, 0, 2);
		g_esInvertAbility[type].g_flInvertRange = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertRange", "Invert Range", "Invert_Range", "range", g_esInvertAbility[type].g_flInvertRange, value, 1.0, 99999.0);
		g_esInvertAbility[type].g_flInvertRangeChance = flGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertRangeChance", "Invert Range Chance", "Invert_Range_Chance", "rangechance", g_esInvertAbility[type].g_flInvertRangeChance, value, 0.0, 100.0);
		g_esInvertAbility[type].g_iInvertRangeCooldown = iGetKeyValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "InvertRangeCooldown", "Invert Range Cooldown", "Invert_Range_Cooldown", "rangecooldown", g_esInvertAbility[type].g_iInvertRangeCooldown, value, 0, 99999);
		g_esInvertAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esInvertAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_INVERT_SECTION, MT_INVERT_SECTION2, MT_INVERT_SECTION3, MT_INVERT_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vInvertSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esInvertCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_flCloseAreasOnly, g_esInvertAbility[type].g_flCloseAreasOnly);
	g_esInvertCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iComboAbility, g_esInvertAbility[type].g_iComboAbility);
	g_esInvertCache[tank].g_flInvertChance = flGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_flInvertChance, g_esInvertAbility[type].g_flInvertChance);
	g_esInvertCache[tank].g_flInvertDuration = flGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_flInvertDuration, g_esInvertAbility[type].g_flInvertDuration);
	g_esInvertCache[tank].g_flInvertRange = flGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_flInvertRange, g_esInvertAbility[type].g_flInvertRange);
	g_esInvertCache[tank].g_flInvertRangeChance = flGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_flInvertRangeChance, g_esInvertAbility[type].g_flInvertRangeChance);
	g_esInvertCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iHumanAbility, g_esInvertAbility[type].g_iHumanAbility);
	g_esInvertCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iHumanAmmo, g_esInvertAbility[type].g_iHumanAmmo);
	g_esInvertCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iHumanCooldown, g_esInvertAbility[type].g_iHumanCooldown);
	g_esInvertCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iHumanRangeCooldown, g_esInvertAbility[type].g_iHumanRangeCooldown);
	g_esInvertCache[tank].g_iInvertAbility = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iInvertAbility, g_esInvertAbility[type].g_iInvertAbility);
	g_esInvertCache[tank].g_iInvertCooldown = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iInvertCooldown, g_esInvertAbility[type].g_iInvertCooldown);
	g_esInvertCache[tank].g_iInvertEffect = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iInvertEffect, g_esInvertAbility[type].g_iInvertEffect);
	g_esInvertCache[tank].g_iInvertHit = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iInvertHit, g_esInvertAbility[type].g_iInvertHit);
	g_esInvertCache[tank].g_iInvertHitMode = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iInvertHitMode, g_esInvertAbility[type].g_iInvertHitMode);
	g_esInvertCache[tank].g_iInvertMessage = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iInvertMessage, g_esInvertAbility[type].g_iInvertMessage);
	g_esInvertCache[tank].g_iInvertRangeCooldown = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iInvertRangeCooldown, g_esInvertAbility[type].g_iInvertRangeCooldown);
	g_esInvertCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_flOpenAreasOnly, g_esInvertAbility[type].g_flOpenAreasOnly);
	g_esInvertCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esInvertPlayer[tank].g_iRequiresHumans, g_esInvertAbility[type].g_iRequiresHumans);
	g_esInvertPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vInvertCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vInvertCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveInvert(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vInvertEventFired(Event event, const char[] name)
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
			vInvertCopyStats2(iBot, iTank);
			vRemoveInvert(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vInvertCopyStats2(iTank, iBot);
			vRemoveInvert(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveInvert(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vInvertReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vInvertAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esInvertAbility[g_esInvertPlayer[tank].g_iTankType].g_iAccessFlags, g_esInvertPlayer[tank].g_iAccessFlags)) || g_esInvertCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esInvertCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esInvertCache[tank].g_iInvertAbility == 1 && g_esInvertCache[tank].g_iComboAbility == 0)
	{
		vInvertAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vInvertButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esInvertCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esInvertCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esInvertPlayer[tank].g_iTankType) || (g_esInvertCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esInvertCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esInvertAbility[g_esInvertPlayer[tank].g_iTankType].g_iAccessFlags, g_esInvertPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esInvertCache[tank].g_iInvertAbility == 1 && g_esInvertCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esInvertPlayer[tank].g_iRangeCooldown == -1 || g_esInvertPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vInvertAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "InvertHuman3", (g_esInvertPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vInvertChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveInvert(tank);
}

void vInvertAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esInvertCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esInvertCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esInvertPlayer[tank].g_iTankType) || (g_esInvertCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esInvertCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esInvertAbility[g_esInvertPlayer[tank].g_iTankType].g_iAccessFlags, g_esInvertPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esInvertPlayer[tank].g_iAmmoCount < g_esInvertCache[tank].g_iHumanAmmo && g_esInvertCache[tank].g_iHumanAmmo > 0))
	{
		g_esInvertPlayer[tank].g_bFailed = false;
		g_esInvertPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esInvertCache[tank].g_flInvertRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esInvertCache[tank].g_flInvertRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esInvertPlayer[tank].g_iTankType, g_esInvertAbility[g_esInvertPlayer[tank].g_iTankType].g_iImmunityFlags, g_esInvertPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vInvertHit(iSurvivor, tank, random, flChance, g_esInvertCache[tank].g_iInvertAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esInvertCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "InvertHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esInvertCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "InvertAmmo");
	}
}

void vInvertHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esInvertCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esInvertCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esInvertPlayer[tank].g_iTankType) || (g_esInvertCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esInvertCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esInvertAbility[g_esInvertPlayer[tank].g_iTankType].g_iAccessFlags, g_esInvertPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esInvertPlayer[tank].g_iTankType, g_esInvertAbility[g_esInvertPlayer[tank].g_iTankType].g_iImmunityFlags, g_esInvertPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esInvertPlayer[tank].g_iRangeCooldown != -1 && g_esInvertPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esInvertPlayer[tank].g_iCooldown != -1 && g_esInvertPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esInvertPlayer[tank].g_iAmmoCount < g_esInvertCache[tank].g_iHumanAmmo && g_esInvertCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esInvertPlayer[survivor].g_bAffected)
			{
				g_esInvertPlayer[survivor].g_bAffected = true;
				g_esInvertPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esInvertPlayer[tank].g_iRangeCooldown == -1 || g_esInvertPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esInvertCache[tank].g_iHumanAbility == 1)
					{
						g_esInvertPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "InvertHuman", g_esInvertPlayer[tank].g_iAmmoCount, g_esInvertCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esInvertCache[tank].g_iInvertRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esInvertCache[tank].g_iHumanAbility == 1 && g_esInvertPlayer[tank].g_iAmmoCount < g_esInvertCache[tank].g_iHumanAmmo && g_esInvertCache[tank].g_iHumanAmmo > 0) ? g_esInvertCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esInvertPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esInvertPlayer[tank].g_iRangeCooldown != -1 && g_esInvertPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "InvertHuman5", (g_esInvertPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esInvertPlayer[tank].g_iCooldown == -1 || g_esInvertPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esInvertCache[tank].g_iInvertCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esInvertCache[tank].g_iHumanAbility == 1) ? g_esInvertCache[tank].g_iHumanCooldown : iCooldown;
					g_esInvertPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esInvertPlayer[tank].g_iCooldown != -1 && g_esInvertPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "InvertHuman5", (g_esInvertPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esInvertCache[tank].g_flInvertDuration;
				DataPack dpStopInvert;
				CreateDataTimer(flDuration, tTimerStopInvert, dpStopInvert, TIMER_FLAG_NO_MAPCHANGE);
				dpStopInvert.WriteCell(GetClientUserId(survivor));
				dpStopInvert.WriteCell(GetClientUserId(tank));
				dpStopInvert.WriteCell(messages);

				vScreenEffect(survivor, tank, g_esInvertCache[tank].g_iInvertEffect, flags);

				if (g_esInvertCache[tank].g_iInvertMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Invert", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Invert", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esInvertPlayer[tank].g_iRangeCooldown == -1 || g_esInvertPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esInvertCache[tank].g_iHumanAbility == 1 && !g_esInvertPlayer[tank].g_bFailed)
				{
					g_esInvertPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "InvertHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esInvertCache[tank].g_iHumanAbility == 1 && !g_esInvertPlayer[tank].g_bNoAmmo)
		{
			g_esInvertPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "InvertAmmo");
		}
	}
}

void vInvertCopyStats2(int oldTank, int newTank)
{
	g_esInvertPlayer[newTank].g_iAmmoCount = g_esInvertPlayer[oldTank].g_iAmmoCount;
	g_esInvertPlayer[newTank].g_iCooldown = g_esInvertPlayer[oldTank].g_iCooldown;
	g_esInvertPlayer[newTank].g_iRangeCooldown = g_esInvertPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveInvert(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esInvertPlayer[iSurvivor].g_bAffected && g_esInvertPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esInvertPlayer[iSurvivor].g_bAffected = false;
			g_esInvertPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vInvertReset2(tank);
}

void vInvertReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vInvertReset2(iPlayer);

			g_esInvertPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vInvertReset2(int tank)
{
	g_esInvertPlayer[tank].g_bAffected = false;
	g_esInvertPlayer[tank].g_bFailed = false;
	g_esInvertPlayer[tank].g_bNoAmmo = false;
	g_esInvertPlayer[tank].g_iAmmoCount = 0;
	g_esInvertPlayer[tank].g_iCooldown = -1;
	g_esInvertPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerInvertCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esInvertAbility[g_esInvertPlayer[iTank].g_iTankType].g_iAccessFlags, g_esInvertPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esInvertPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esInvertCache[iTank].g_iInvertAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vInvertAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerInvertCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esInvertPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esInvertAbility[g_esInvertPlayer[iTank].g_iTankType].g_iAccessFlags, g_esInvertPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esInvertPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esInvertCache[iTank].g_iInvertHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esInvertCache[iTank].g_iInvertHitMode == 0 || g_esInvertCache[iTank].g_iInvertHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vInvertHit(iSurvivor, iTank, flRandom, flChance, g_esInvertCache[iTank].g_iInvertHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esInvertCache[iTank].g_iInvertHitMode == 0 || g_esInvertCache[iTank].g_iInvertHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vInvertHit(iSurvivor, iTank, flRandom, flChance, g_esInvertCache[iTank].g_iInvertHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopInvert(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || !g_esInvertPlayer[iSurvivor].g_bAffected)
	{
		g_esInvertPlayer[iSurvivor].g_bAffected = false;
		g_esInvertPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank))
	{
		g_esInvertPlayer[iSurvivor].g_bAffected = false;
		g_esInvertPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	g_esInvertPlayer[iSurvivor].g_bAffected = false;
	g_esInvertPlayer[iSurvivor].g_iOwner = 0;

	int iMessage = pack.ReadCell();
	if (g_esInvertCache[iTank].g_iInvertMessage & iMessage)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Invert2", iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Invert2", LANG_SERVER, iSurvivor);
	}

	return Plugin_Continue;
}