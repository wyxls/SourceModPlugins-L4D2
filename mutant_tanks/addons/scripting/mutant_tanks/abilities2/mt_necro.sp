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

#define MT_NECRO_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_NECRO_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Necro Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank resurrects nearby special infected that die.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bSecondGame;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bSecondGame = false;
		case Engine_Left4Dead2: g_bSecondGame = true;
		default:
		{
			strcopy(error, err_max, "\"[MT] Necro Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_NECRO_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_NECRO_SECTION "necroability"
#define MT_NECRO_SECTION2 "necro ability"
#define MT_NECRO_SECTION3 "necro_ability"
#define MT_NECRO_SECTION4 "necro"

#define MT_MENU_NECRO "Necro Ability"

enum struct esNecroPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flNecroChance;
	float g_flNecroRange;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iDuration;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iNecroAbility;
	int g_iNecroCooldown;
	int g_iNecroDuration;
	int g_iNecroMessage;
	int g_iRequiresHumans;
	int g_iTankType;
}

esNecroPlayer g_esNecroPlayer[MAXPLAYERS + 1];

enum struct esNecroAbility
{
	float g_flCloseAreasOnly;
	float g_flNecroChance;
	float g_flNecroRange;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iNecroAbility;
	int g_iNecroCooldown;
	int g_iNecroDuration;
	int g_iNecroMessage;
	int g_iRequiresHumans;
}

esNecroAbility g_esNecroAbility[MT_MAXTYPES + 1];

enum struct esNecroCache
{
	float g_flCloseAreasOnly;
	float g_flNecroChance;
	float g_flNecroRange;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iNecroAbility;
	int g_iNecroCooldown;
	int g_iNecroDuration;
	int g_iNecroMessage;
	int g_iRequiresHumans;
}

esNecroCache g_esNecroCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_necro", cmdNecroInfo, "View information about the Necro ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vNecroMapStart()
#else
public void OnMapStart()
#endif
{
	vNecroReset();
}

#if defined MT_ABILITIES_MAIN2
void vNecroClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveNecro(client);
}

#if defined MT_ABILITIES_MAIN2
void vNecroClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveNecro(client);
}

#if defined MT_ABILITIES_MAIN2
void vNecroMapEnd()
#else
public void OnMapEnd()
#endif
{
	vNecroReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdNecroInfo(int client, int args)
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
		case false: vNecroMenu(client, MT_NECRO_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vNecroMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_NECRO_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iNecroMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Necro Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Button Mode", "Button Mode");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iNecroMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esNecroCache[param1].g_iNecroAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esNecroCache[param1].g_iHumanAmmo - g_esNecroPlayer[param1].g_iAmmoCount), g_esNecroCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons3");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esNecroCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esNecroCache[param1].g_iHumanAbility == 1) ? g_esNecroCache[param1].g_iHumanCooldown : g_esNecroCache[param1].g_iNecroCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "NecroDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esNecroCache[param1].g_iHumanAbility == 1) ? g_esNecroCache[param1].g_iHumanDuration : g_esNecroCache[param1].g_iNecroDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esNecroCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vNecroMenu(param1, MT_NECRO_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pNecro = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "NecroMenu", param1);
			pNecro.SetTitle(sMenuTitle);
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
					case 3: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "ButtonMode", param1);
					case 4: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Cooldown", param1);
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Duration", param1);
					case 7: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN2
void vNecroDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_NECRO, MT_MENU_NECRO);
}

#if defined MT_ABILITIES_MAIN2
void vNecroMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_NECRO, false))
	{
		vNecroMenu(client, MT_NECRO_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_NECRO, false))
	{
		FormatEx(buffer, size, "%T", "NecroMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroPlayerRunCmd(int client)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsTankSupported(client) || !g_esNecroPlayer[client].g_bActivated || (bIsTank(client, MT_CHECK_FAKECLIENT) && g_esNecroCache[client].g_iHumanMode == 1) || g_esNecroPlayer[client].g_iDuration == -1)
	{
#if defined MT_ABILITIES_MAIN2
		return;
#else
		return Plugin_Continue;
#endif
	}

	int iTime = GetTime();
	if (g_esNecroPlayer[client].g_iDuration < iTime)
	{
		if (g_esNecroPlayer[client].g_iCooldown == -1 || g_esNecroPlayer[client].g_iCooldown < iTime)
		{
			vNecroReset2(client);
		}

		g_esNecroPlayer[client].g_bActivated = false;
		g_esNecroPlayer[client].g_iDuration = -1;
	}
#if !defined MT_ABILITIES_MAIN2
	return Plugin_Continue;
#endif
}

#if defined MT_ABILITIES_MAIN2
void vNecroPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_NECRO);
}

#if defined MT_ABILITIES_MAIN2
void vNecroAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_NECRO_SECTION);
	list2.PushString(MT_NECRO_SECTION2);
	list3.PushString(MT_NECRO_SECTION3);
	list4.PushString(MT_NECRO_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vNecroCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNecroCache[tank].g_iHumanAbility != 2)
	{
		g_esNecroAbility[g_esNecroPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esNecroAbility[g_esNecroPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_NECRO_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_NECRO_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_NECRO_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_NECRO_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esNecroCache[tank].g_iNecroAbility == 1 && g_esNecroCache[tank].g_iComboAbility == 1 && !g_esNecroPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_NECRO_SECTION, false) || StrEqual(sSubset[iPos], MT_NECRO_SECTION2, false) || StrEqual(sSubset[iPos], MT_NECRO_SECTION3, false) || StrEqual(sSubset[iPos], MT_NECRO_SECTION4, false))
				{
					g_esNecroAbility[g_esNecroPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: g_esNecroPlayer[tank].g_bActivated = true;
							default: CreateTimer(flDelay, tTimerNecroCombo, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroConfigsLoad(int mode)
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
				g_esNecroAbility[iIndex].g_iAccessFlags = 0;
				g_esNecroAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esNecroAbility[iIndex].g_iComboAbility = 0;
				g_esNecroAbility[iIndex].g_iComboPosition = -1;
				g_esNecroAbility[iIndex].g_iHumanAbility = 0;
				g_esNecroAbility[iIndex].g_iHumanAmmo = 5;
				g_esNecroAbility[iIndex].g_iHumanCooldown = 0;
				g_esNecroAbility[iIndex].g_iHumanDuration = 5;
				g_esNecroAbility[iIndex].g_iHumanMode = 1;
				g_esNecroAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esNecroAbility[iIndex].g_iRequiresHumans = 0;
				g_esNecroAbility[iIndex].g_iNecroAbility = 0;
				g_esNecroAbility[iIndex].g_iNecroMessage = 0;
				g_esNecroAbility[iIndex].g_flNecroChance = 33.3;
				g_esNecroAbility[iIndex].g_iNecroCooldown = 0;
				g_esNecroAbility[iIndex].g_iNecroDuration = 0;
				g_esNecroAbility[iIndex].g_flNecroRange = 500.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esNecroPlayer[iPlayer].g_iAccessFlags = 0;
					g_esNecroPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esNecroPlayer[iPlayer].g_iComboAbility = 0;
					g_esNecroPlayer[iPlayer].g_iHumanAbility = 0;
					g_esNecroPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esNecroPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esNecroPlayer[iPlayer].g_iHumanDuration = 0;
					g_esNecroPlayer[iPlayer].g_iHumanMode = 0;
					g_esNecroPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esNecroPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esNecroPlayer[iPlayer].g_iNecroAbility = 0;
					g_esNecroPlayer[iPlayer].g_iNecroMessage = 0;
					g_esNecroPlayer[iPlayer].g_flNecroChance = 0.0;
					g_esNecroPlayer[iPlayer].g_iNecroCooldown = 0;
					g_esNecroPlayer[iPlayer].g_iNecroDuration = 0;
					g_esNecroPlayer[iPlayer].g_flNecroRange = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esNecroPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esNecroPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esNecroPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esNecroPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esNecroPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esNecroPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esNecroPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esNecroPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esNecroPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esNecroPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esNecroPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esNecroPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esNecroPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esNecroPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esNecroPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esNecroPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esNecroPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esNecroPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esNecroPlayer[admin].g_iNecroAbility = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esNecroPlayer[admin].g_iNecroAbility, value, 0, 1);
		g_esNecroPlayer[admin].g_iNecroMessage = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esNecroPlayer[admin].g_iNecroMessage, value, 0, 1);
		g_esNecroPlayer[admin].g_flNecroChance = flGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "NecroChance", "Necro Chance", "Necro_Chance", "chance", g_esNecroPlayer[admin].g_flNecroChance, value, 0.0, 100.0);
		g_esNecroPlayer[admin].g_iNecroCooldown = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "NecroCooldown", "Necro Cooldown", "Necro_Cooldown", "cooldown", g_esNecroPlayer[admin].g_iNecroCooldown, value, 0, 99999);
		g_esNecroPlayer[admin].g_iNecroDuration = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "NecroDuration", "Necro Duration", "Necro_Duration", "duration", g_esNecroPlayer[admin].g_iNecroDuration, value, 0, 99999);
		g_esNecroPlayer[admin].g_flNecroRange = flGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "NecroRange", "Necro Range", "Necro_Range", "range", g_esNecroPlayer[admin].g_flNecroRange, value, 1.0, 99999.0);
		g_esNecroPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esNecroAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esNecroAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esNecroAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esNecroAbility[type].g_iComboAbility, value, 0, 1);
		g_esNecroAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esNecroAbility[type].g_iHumanAbility, value, 0, 2);
		g_esNecroAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esNecroAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esNecroAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esNecroAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esNecroAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esNecroAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esNecroAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esNecroAbility[type].g_iHumanMode, value, 0, 1);
		g_esNecroAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esNecroAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esNecroAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esNecroAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esNecroAbility[type].g_iNecroAbility = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esNecroAbility[type].g_iNecroAbility, value, 0, 1);
		g_esNecroAbility[type].g_iNecroMessage = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esNecroAbility[type].g_iNecroMessage, value, 0, 1);
		g_esNecroAbility[type].g_flNecroChance = flGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "NecroChance", "Necro Chance", "Necro_Chance", "chance", g_esNecroAbility[type].g_flNecroChance, value, 0.0, 100.0);
		g_esNecroAbility[type].g_iNecroCooldown = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "NecroCooldown", "Necro Cooldown", "Necro_Cooldown", "cooldown", g_esNecroAbility[type].g_iNecroCooldown, value, 0, 99999);
		g_esNecroAbility[type].g_iNecroDuration = iGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "NecroDuration", "Necro Duration", "Necro_Duration", "duration", g_esNecroAbility[type].g_iNecroDuration, value, 0, 99999);
		g_esNecroAbility[type].g_flNecroRange = flGetKeyValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "NecroRange", "Necro Range", "Necro_Range", "range", g_esNecroAbility[type].g_flNecroRange, value, 1.0, 99999.0);
		g_esNecroAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_NECRO_SECTION, MT_NECRO_SECTION2, MT_NECRO_SECTION3, MT_NECRO_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esNecroCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_flCloseAreasOnly, g_esNecroAbility[type].g_flCloseAreasOnly);
	g_esNecroCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iComboAbility, g_esNecroAbility[type].g_iComboAbility);
	g_esNecroCache[tank].g_flNecroChance = flGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_flNecroChance, g_esNecroAbility[type].g_flNecroChance);
	g_esNecroCache[tank].g_flNecroRange = flGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_flNecroRange, g_esNecroAbility[type].g_flNecroRange);
	g_esNecroCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iHumanAbility, g_esNecroAbility[type].g_iHumanAbility);
	g_esNecroCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iHumanAmmo, g_esNecroAbility[type].g_iHumanAmmo);
	g_esNecroCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iHumanCooldown, g_esNecroAbility[type].g_iHumanCooldown);
	g_esNecroCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iHumanDuration, g_esNecroAbility[type].g_iHumanDuration);
	g_esNecroCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iHumanMode, g_esNecroAbility[type].g_iHumanMode);
	g_esNecroCache[tank].g_iNecroAbility = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iNecroAbility, g_esNecroAbility[type].g_iNecroAbility);
	g_esNecroCache[tank].g_iNecroCooldown = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iNecroCooldown, g_esNecroAbility[type].g_iNecroCooldown);
	g_esNecroCache[tank].g_iNecroDuration = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iNecroDuration, g_esNecroAbility[type].g_iNecroDuration);
	g_esNecroCache[tank].g_iNecroMessage = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iNecroMessage, g_esNecroAbility[type].g_iNecroMessage);
	g_esNecroCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_flOpenAreasOnly, g_esNecroAbility[type].g_flOpenAreasOnly);
	g_esNecroCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esNecroPlayer[tank].g_iRequiresHumans, g_esNecroAbility[type].g_iRequiresHumans);
	g_esNecroPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vNecroCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vNecroCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveNecro(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vNecroEventFired(Event event, const char[] name)
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
			vNecroCopyStats2(iBot, iTank);
			vRemoveNecro(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vNecroCopyStats2(iTank, iBot);
			vRemoveNecro(iTank);
		}
	}
	else if (StrEqual(name, "player_death"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveNecro(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vNecroReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroPlayerEventKilled(int victim)
#else
public void MT_OnPlayerEventKilled(int victim, int attacker)
#endif
{
	if (bIsSpecialInfected(victim, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		bool bRandom = false;
		float flInfectedPos[3], flTankPos[3], flRange = 0.0;
		int iPos = -1, iClass = 0, iTime = GetTime();
		GetClientAbsOrigin(victim, flInfectedPos);
		for (int iTank = 1; iTank <= MaxClients; iTank++)
		{
			if (MT_IsTankSupported(iTank) && MT_IsCustomTankSupported(iTank) && g_esNecroPlayer[iTank].g_bActivated)
			{
				if ((g_esNecroPlayer[iTank].g_iCooldown != -1 && g_esNecroPlayer[iTank].g_iCooldown > iTime) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esNecroAbility[g_esNecroPlayer[iTank].g_iTankType].g_iAccessFlags, g_esNecroPlayer[iTank].g_iAccessFlags)))
				{
					continue;
				}

				iPos = g_esNecroAbility[g_esNecroPlayer[iTank].g_iTankType].g_iComboPosition;
				bRandom = (iPos != -1) ? true : MT_GetRandomFloat(0.1, 100.0) <= g_esNecroCache[iTank].g_flNecroChance;
				if (g_esNecroCache[iTank].g_iNecroAbility == 1 && bRandom)
				{
					flRange = (iPos != -1) ? MT_GetCombinationSetting(iTank, 9, iPos) : g_esNecroCache[iTank].g_flNecroRange;
					GetClientAbsOrigin(iTank, flTankPos);
					if (GetVectorDistance(flInfectedPos, flTankPos) <= flRange)
					{
						iClass = GetEntProp(victim, Prop_Send, "m_zombieClass");

						switch (iClass)
						{
							case 1: vNecro(iTank, flInfectedPos, "smoker");
							case 2: vNecro(iTank, flInfectedPos, "boomer");
							case 3: vNecro(iTank, flInfectedPos, "hunter");
							case 4, 5, 6:
							{
								if (g_bSecondGame)
								{
									switch (iClass)
									{
										case 4: vNecro(iTank, flInfectedPos, "spitter");
										case 5: vNecro(iTank, flInfectedPos, "jockey");
										case 6: vNecro(iTank, flInfectedPos, "charger");
									}
								}
							}
						}
					}
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esNecroAbility[g_esNecroPlayer[tank].g_iTankType].g_iAccessFlags, g_esNecroPlayer[tank].g_iAccessFlags)) || g_esNecroCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esNecroCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esNecroCache[tank].g_iNecroAbility == 1 && g_esNecroCache[tank].g_iComboAbility == 0 && !g_esNecroPlayer[tank].g_bActivated)
	{
		vNecroAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esNecroCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esNecroCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esNecroPlayer[tank].g_iTankType) || (g_esNecroCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esNecroCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esNecroAbility[g_esNecroPlayer[tank].g_iTankType].g_iAccessFlags, g_esNecroPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esNecroCache[tank].g_iNecroAbility == 1 && g_esNecroCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esNecroPlayer[tank].g_iCooldown != -1 && g_esNecroPlayer[tank].g_iCooldown > iTime;

			switch (g_esNecroCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esNecroPlayer[tank].g_bActivated && !bRecharging)
					{
						vNecroAbility(tank);
					}
					else if (g_esNecroPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroHuman4", (g_esNecroPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esNecroPlayer[tank].g_iAmmoCount < g_esNecroCache[tank].g_iHumanAmmo && g_esNecroCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esNecroPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esNecroPlayer[tank].g_bActivated = true;
							g_esNecroPlayer[tank].g_iAmmoCount++;

							MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroHuman", g_esNecroPlayer[tank].g_iAmmoCount, g_esNecroCache[tank].g_iHumanAmmo);
						}
						else if (g_esNecroPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroHuman4", (g_esNecroPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esNecroCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esNecroCache[tank].g_iHumanMode == 1 && g_esNecroPlayer[tank].g_bActivated && (g_esNecroPlayer[tank].g_iCooldown == -1 || g_esNecroPlayer[tank].g_iCooldown < GetTime()))
		{
			g_esNecroPlayer[tank].g_bActivated = false;

			vNecroReset2(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vNecroChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveNecro(tank);
}

void vNecro(int tank, float pos[3], const char[] type)
{
	if (bIsAreaNarrow(tank, g_esNecroCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esNecroCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esNecroPlayer[tank].g_iTankType) || (g_esNecroCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esNecroCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esNecroAbility[g_esNecroPlayer[tank].g_iTankType].g_iAccessFlags, g_esNecroPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	bool[] bExists = new bool[MaxClients + 1];
	for (int iSpecial = 1; iSpecial <= MaxClients; iSpecial++)
	{
		bExists[iSpecial] = false;
		if (bIsSpecialInfected(iSpecial, MT_CHECK_INGAME))
		{
			bExists[iSpecial] = true;
		}
	}

	vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", type);

	int iInfected = 0;
	for (int iSpecial = 1; iSpecial <= MaxClients; iSpecial++)
	{
		if (bIsSpecialInfected(iSpecial, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !bExists[iSpecial])
		{
			iInfected = iSpecial;

			break;
		}
	}

	if (bIsSpecialInfected(iInfected))
	{
		TeleportEntity(iInfected, pos);

		if (g_esNecroCache[tank].g_iNecroMessage == 1)
		{
			char sTankName[33];
			MT_GetTankName(tank, sTankName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Necro", sTankName);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Necro", LANG_SERVER, sTankName);
		}
	}
}

void vNecroAbility(int tank)
{
	int iTime = GetTime();
	if ((g_esMinionPlayer[tank].g_iCooldown != -1 && g_esMinionPlayer[tank].g_iCooldown > iTime) || bIsAreaNarrow(tank, g_esNecroCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esNecroCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esNecroPlayer[tank].g_iTankType) || (g_esNecroCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esNecroCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esNecroAbility[g_esNecroPlayer[tank].g_iTankType].g_iAccessFlags, g_esNecroPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esNecroPlayer[tank].g_iAmmoCount < g_esNecroCache[tank].g_iHumanAmmo && g_esNecroCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esNecroCache[tank].g_flNecroChance)
		{
			g_esNecroPlayer[tank].g_bActivated = true;

			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNecroCache[tank].g_iHumanAbility == 1)
			{
				int iPos = g_esNecroAbility[g_esNecroPlayer[tank].g_iTankType].g_iComboPosition, iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 5, iPos)) : g_esNecroCache[tank].g_iNecroDuration;
				iDuration = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNecroCache[tank].g_iHumanAbility == 1) ? g_esNecroCache[tank].g_iHumanDuration : iDuration;
				g_esNecroPlayer[tank].g_iAmmoCount++;
				g_esNecroPlayer[tank].g_iDuration = (iTime + iDuration);

				MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroHuman", g_esNecroPlayer[tank].g_iAmmoCount, g_esNecroCache[tank].g_iHumanAmmo);
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNecroCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNecroCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroAmmo");
	}
}

void vNecroCopyStats2(int oldTank, int newTank)
{
	g_esNecroPlayer[newTank].g_iAmmoCount = g_esNecroPlayer[oldTank].g_iAmmoCount;
	g_esNecroPlayer[newTank].g_iCooldown = g_esNecroPlayer[oldTank].g_iCooldown;
}

void vRemoveNecro(int tank)
{
	g_esNecroPlayer[tank].g_bActivated = false;
	g_esNecroPlayer[tank].g_iAmmoCount = 0;
	g_esNecroPlayer[tank].g_iCooldown = -1;
	g_esNecroPlayer[tank].g_iDuration = -1;
}

void vNecroReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveNecro(iPlayer);
		}
	}
}

void vNecroReset2(int tank)
{
	int iTime = GetTime(), iPos = g_esNecroAbility[g_esNecroPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esNecroCache[tank].g_iNecroCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNecroCache[tank].g_iHumanAbility == 1 && g_esNecroCache[tank].g_iHumanMode == 0 && g_esNecroPlayer[tank].g_iAmmoCount < g_esNecroCache[tank].g_iHumanAmmo && g_esNecroCache[tank].g_iHumanAmmo > 0) ? g_esNecroCache[tank].g_iHumanCooldown : iCooldown;
	g_esNecroPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esNecroPlayer[tank].g_iCooldown != -1 && g_esNecroPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "NecroHuman5", (g_esNecroPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerNecroCombo(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esNecroAbility[g_esNecroPlayer[iTank].g_iTankType].g_iAccessFlags, g_esNecroPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esNecroPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esNecroCache[iTank].g_iNecroAbility == 0 || g_esNecroPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	g_esNecroPlayer[iTank].g_bActivated = true;

	return Plugin_Continue;
}