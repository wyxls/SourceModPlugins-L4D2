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

#define MT_PANIC_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_PANIC_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Panic Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank starts panic events.",
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
			strcopy(error, err_max, "\"[MT] Panic Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_PANIC_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_PANIC_SECTION "panicability"
#define MT_PANIC_SECTION2 "panic ability"
#define MT_PANIC_SECTION3 "panic_ability"
#define MT_PANIC_SECTION4 "panic"

#define MT_MENU_PANIC "Panic Ability"

enum struct esPanicPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flPanicChance;
	float g_flPanicInterval;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iPanicAbility;
	int g_iPanicCooldown;
	int g_iPanicDuration;
	int g_iPanicMessage;
	int g_iRequiresHumans;
	int g_iTankType;
}

esPanicPlayer g_esPanicPlayer[MAXPLAYERS + 1];

enum struct esPanicAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flPanicChance;
	float g_flPanicInterval;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iPanicAbility;
	int g_iPanicCooldown;
	int g_iPanicDuration;
	int g_iPanicMessage;
	int g_iRequiresHumans;
}

esPanicAbility g_esPanicAbility[MT_MAXTYPES + 1];

enum struct esPanicCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flPanicChance;
	float g_flPanicInterval;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iPanicAbility;
	int g_iPanicCooldown;
	int g_iPanicDuration;
	int g_iPanicMessage;
	int g_iRequiresHumans;
}

esPanicCache g_esPanicCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_panic", cmdPanicInfo, "View information about the Panic ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vPanicMapStart()
#else
public void OnMapStart()
#endif
{
	vPanicReset();
}

#if defined MT_ABILITIES_MAIN2
void vPanicClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemovePanic(client);
}

#if defined MT_ABILITIES_MAIN2
void vPanicClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemovePanic(client);
}

#if defined MT_ABILITIES_MAIN2
void vPanicMapEnd()
#else
public void OnMapEnd()
#endif
{
	vPanicReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdPanicInfo(int client, int args)
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
		case false: vPanicMenu(client, MT_PANIC_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vPanicMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_PANIC_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iPanicMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Panic Ability Information");
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

int iPanicMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esPanicCache[param1].g_iPanicAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esPanicCache[param1].g_iHumanAmmo - g_esPanicPlayer[param1].g_iAmmoCount), g_esPanicCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esPanicCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esPanicCache[param1].g_iHumanAbility == 1) ? g_esPanicCache[param1].g_iHumanCooldown : g_esPanicCache[param1].g_iPanicCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "PanicDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esPanicCache[param1].g_iHumanAbility == 1) ? g_esPanicCache[param1].g_iHumanDuration : g_esPanicCache[param1].g_iPanicDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esPanicCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vPanicMenu(param1, MT_PANIC_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pPanic = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "PanicMenu", param1);
			pPanic.SetTitle(sMenuTitle);
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
void vPanicDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_PANIC, MT_MENU_PANIC);
}

#if defined MT_ABILITIES_MAIN2
void vPanicMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_PANIC, false))
	{
		vPanicMenu(client, MT_PANIC_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPanicMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_PANIC, false))
	{
		FormatEx(buffer, size, "%T", "PanicMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPanicPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_PANIC);
}

#if defined MT_ABILITIES_MAIN2
void vPanicAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_PANIC_SECTION);
	list2.PushString(MT_PANIC_SECTION2);
	list3.PushString(MT_PANIC_SECTION3);
	list4.PushString(MT_PANIC_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vPanicCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPanicCache[tank].g_iHumanAbility != 2)
	{
		g_esPanicAbility[g_esPanicPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esPanicAbility[g_esPanicPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_PANIC_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_PANIC_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_PANIC_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_PANIC_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esPanicCache[tank].g_iPanicAbility == 1 && g_esPanicCache[tank].g_iComboAbility == 1 && !g_esPanicPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_PANIC_SECTION, false) || StrEqual(sSubset[iPos], MT_PANIC_SECTION2, false) || StrEqual(sSubset[iPos], MT_PANIC_SECTION3, false) || StrEqual(sSubset[iPos], MT_PANIC_SECTION4, false))
				{
					g_esPanicAbility[g_esPanicPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vPanic(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerPanicCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteCell(iPos);
							}
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPanicConfigsLoad(int mode)
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
				g_esPanicAbility[iIndex].g_iAccessFlags = 0;
				g_esPanicAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esPanicAbility[iIndex].g_iComboAbility = 0;
				g_esPanicAbility[iIndex].g_iComboPosition = -1;
				g_esPanicAbility[iIndex].g_iHumanAbility = 0;
				g_esPanicAbility[iIndex].g_iHumanAmmo = 5;
				g_esPanicAbility[iIndex].g_iHumanCooldown = 0;
				g_esPanicAbility[iIndex].g_iHumanDuration = 5;
				g_esPanicAbility[iIndex].g_iHumanMode = 1;
				g_esPanicAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esPanicAbility[iIndex].g_iRequiresHumans = 0;
				g_esPanicAbility[iIndex].g_iPanicAbility = 0;
				g_esPanicAbility[iIndex].g_iPanicMessage = 0;
				g_esPanicAbility[iIndex].g_flPanicChance = 33.3;
				g_esPanicAbility[iIndex].g_iPanicCooldown = 0;
				g_esPanicAbility[iIndex].g_iPanicDuration = 0;
				g_esPanicAbility[iIndex].g_flPanicInterval = 5.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esPanicPlayer[iPlayer].g_iAccessFlags = 0;
					g_esPanicPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esPanicPlayer[iPlayer].g_iComboAbility = 0;
					g_esPanicPlayer[iPlayer].g_iHumanAbility = 0;
					g_esPanicPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esPanicPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esPanicPlayer[iPlayer].g_iHumanDuration = 0;
					g_esPanicPlayer[iPlayer].g_iHumanMode = 0;
					g_esPanicPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esPanicPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esPanicPlayer[iPlayer].g_iPanicAbility = 0;
					g_esPanicPlayer[iPlayer].g_iPanicMessage = 0;
					g_esPanicPlayer[iPlayer].g_flPanicChance = 0.0;
					g_esPanicPlayer[iPlayer].g_iPanicCooldown = 0;
					g_esPanicPlayer[iPlayer].g_iPanicDuration = 0;
					g_esPanicPlayer[iPlayer].g_flPanicInterval = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPanicConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esPanicPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esPanicPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esPanicPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esPanicPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esPanicPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esPanicPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esPanicPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esPanicPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esPanicPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esPanicPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esPanicPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esPanicPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esPanicPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esPanicPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esPanicPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esPanicPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esPanicPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esPanicPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esPanicPlayer[admin].g_iPanicAbility = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esPanicPlayer[admin].g_iPanicAbility, value, 0, 3);
		g_esPanicPlayer[admin].g_iPanicMessage = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esPanicPlayer[admin].g_iPanicMessage, value, 0, 1);
		g_esPanicPlayer[admin].g_flPanicChance = flGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "PanicChance", "Panic Chance", "Panic_Chance", "chance", g_esPanicPlayer[admin].g_flPanicChance, value, 0.0, 100.0);
		g_esPanicPlayer[admin].g_iPanicCooldown = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "PanicCooldown", "Panic Cooldown", "Panic_Cooldown", "cooldown", g_esPanicPlayer[admin].g_iPanicCooldown, value, 0, 99999);
		g_esPanicPlayer[admin].g_iPanicDuration = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "PanicDuration", "Panic Duration", "Panic_Duration", "duration", g_esPanicPlayer[admin].g_iPanicDuration, value, 0, 99999);
		g_esPanicPlayer[admin].g_flPanicInterval = flGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "PanicInterval", "Panic Interval", "Panic_Interval", "interval", g_esPanicPlayer[admin].g_flPanicInterval, value, 0.1, 99999.0);
		g_esPanicPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esPanicAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esPanicAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esPanicAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esPanicAbility[type].g_iComboAbility, value, 0, 1);
		g_esPanicAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esPanicAbility[type].g_iHumanAbility, value, 0, 2);
		g_esPanicAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esPanicAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esPanicAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esPanicAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esPanicAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esPanicAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esPanicAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esPanicAbility[type].g_iHumanMode, value, 0, 1);
		g_esPanicAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esPanicAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esPanicAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esPanicAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esPanicAbility[type].g_iPanicAbility = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esPanicAbility[type].g_iPanicAbility, value, 0, 3);
		g_esPanicAbility[type].g_iPanicMessage = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esPanicAbility[type].g_iPanicMessage, value, 0, 1);
		g_esPanicAbility[type].g_flPanicChance = flGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "PanicChance", "Panic Chance", "Panic_Chance", "chance", g_esPanicAbility[type].g_flPanicChance, value, 0.0, 100.0);
		g_esPanicAbility[type].g_iPanicCooldown = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "PanicCooldown", "Panic Cooldown", "Panic_Cooldown", "cooldown", g_esPanicAbility[type].g_iPanicCooldown, value, 0, 99999);
		g_esPanicAbility[type].g_iPanicDuration = iGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "PanicDuration", "Panic Duration", "Panic_Duration", "duration", g_esPanicAbility[type].g_iPanicDuration, value, 0, 99999);
		g_esPanicAbility[type].g_flPanicInterval = flGetKeyValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "PanicInterval", "Panic Interval", "Panic_Interval", "interval", g_esPanicAbility[type].g_flPanicInterval, value, 0.1, 99999.0);
		g_esPanicAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_PANIC_SECTION, MT_PANIC_SECTION2, MT_PANIC_SECTION3, MT_PANIC_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPanicSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esPanicCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_flCloseAreasOnly, g_esPanicAbility[type].g_flCloseAreasOnly);
	g_esPanicCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iComboAbility, g_esPanicAbility[type].g_iComboAbility);
	g_esPanicCache[tank].g_flPanicChance = flGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_flPanicChance, g_esPanicAbility[type].g_flPanicChance);
	g_esPanicCache[tank].g_flPanicInterval = flGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_flPanicInterval, g_esPanicAbility[type].g_flPanicInterval);
	g_esPanicCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iHumanAbility, g_esPanicAbility[type].g_iHumanAbility);
	g_esPanicCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iHumanAmmo, g_esPanicAbility[type].g_iHumanAmmo);
	g_esPanicCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iHumanCooldown, g_esPanicAbility[type].g_iHumanCooldown);
	g_esPanicCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iHumanDuration, g_esPanicAbility[type].g_iHumanDuration);
	g_esPanicCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iHumanMode, g_esPanicAbility[type].g_iHumanMode);
	g_esPanicCache[tank].g_iPanicAbility = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iPanicAbility, g_esPanicAbility[type].g_iPanicAbility);
	g_esPanicCache[tank].g_iPanicCooldown = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iPanicCooldown, g_esPanicAbility[type].g_iPanicCooldown);
	g_esPanicCache[tank].g_iPanicDuration = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iPanicDuration, g_esPanicAbility[type].g_iPanicDuration);
	g_esPanicCache[tank].g_iPanicMessage = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iPanicMessage, g_esPanicAbility[type].g_iPanicMessage);
	g_esPanicCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_flOpenAreasOnly, g_esPanicAbility[type].g_flOpenAreasOnly);
	g_esPanicCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esPanicPlayer[tank].g_iRequiresHumans, g_esPanicAbility[type].g_iRequiresHumans);
	g_esPanicPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vPanicCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vPanicCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemovePanic(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vPanicEventFired(Event event, const char[] name)
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
			vPanicCopyStats2(iBot, iTank);
			vRemovePanic(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vPanicCopyStats2(iTank, iBot);
			vRemovePanic(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vPanicRange(iTank, false);
			vRemovePanic(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vPanicReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vPanicAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPanicAbility[g_esPanicPlayer[tank].g_iTankType].g_iAccessFlags, g_esPanicPlayer[tank].g_iAccessFlags)) || g_esPanicCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esPanicCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esPanicCache[tank].g_iPanicAbility == 1 && g_esPanicCache[tank].g_iComboAbility == 0 && !g_esPanicPlayer[tank].g_bActivated)
	{
		vPanicAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPanicButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esPanicCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esPanicCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPanicPlayer[tank].g_iTankType) || (g_esPanicCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPanicCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPanicAbility[g_esPanicPlayer[tank].g_iTankType].g_iAccessFlags, g_esPanicPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esPanicCache[tank].g_iPanicAbility == 1 && g_esPanicCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esPanicPlayer[tank].g_iCooldown != -1 && g_esPanicPlayer[tank].g_iCooldown > iTime;

			switch (g_esPanicCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esPanicPlayer[tank].g_bActivated && !bRecharging)
					{
						vPanicAbility(tank);
					}
					else if (g_esPanicPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicHuman4", (g_esPanicPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esPanicPlayer[tank].g_iAmmoCount < g_esPanicCache[tank].g_iHumanAmmo && g_esPanicCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esPanicPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esPanicPlayer[tank].g_bActivated = true;
							g_esPanicPlayer[tank].g_iAmmoCount++;

							vPanic2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicHuman", g_esPanicPlayer[tank].g_iAmmoCount, g_esPanicCache[tank].g_iHumanAmmo);
						}
						else if (g_esPanicPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicHuman4", (g_esPanicPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPanicButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esPanicCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esPanicCache[tank].g_iHumanMode == 1 && g_esPanicPlayer[tank].g_bActivated && (g_esPanicPlayer[tank].g_iCooldown == -1 || g_esPanicPlayer[tank].g_iCooldown < GetTime()))
		{
			vPanicReset2(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPanicChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemovePanic(tank);
}

#if defined MT_ABILITIES_MAIN2
void vPanicPostTankSpawn(int tank)
#else
public void MT_OnPostTankSpawn(int tank)
#endif
{
	vPanicRange(tank, true);
}

void vPanic(int tank, int pos = -1)
{
	if (g_esPanicPlayer[tank].g_iCooldown != -1 && g_esPanicPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esPanicPlayer[tank].g_bActivated = true;

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPanicCache[tank].g_iHumanAbility == 1)
	{
		g_esPanicPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicHuman", g_esPanicPlayer[tank].g_iAmmoCount, g_esPanicCache[tank].g_iHumanAmmo);
	}

	vPanic2(tank, pos);

	if (g_esPanicCache[tank].g_iPanicMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Panic", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Panic", LANG_SERVER, sTankName);
	}
}

void vPanic2(int tank, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esPanicCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esPanicCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPanicPlayer[tank].g_iTankType) || (g_esPanicCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPanicCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPanicAbility[g_esPanicPlayer[tank].g_iTankType].g_iAccessFlags, g_esPanicPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esPanicCache[tank].g_flPanicInterval;
	DataPack dpPanic;
	CreateDataTimer(flInterval, tTimerPanic, dpPanic, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpPanic.WriteCell(GetClientUserId(tank));
	dpPanic.WriteCell(g_esPanicPlayer[tank].g_iTankType);
	dpPanic.WriteCell(GetTime());
	dpPanic.WriteCell(pos);
}

void vPanic3(int tank)
{
	switch (g_bSecondGame)
	{
		case true:
		{
			int iDirector = CreateEntityByName("info_director");
			if (IsValidEntity(iDirector))
			{
				DispatchSpawn(iDirector);
				AcceptEntityInput(iDirector, "ForcePanicEvent");
				RemoveEntity(iDirector);
			}
		}
		case false: vCheatCommand(tank, "director_force_panic_event");
	}
}

void vPanicAbility(int tank)
{
	if ((g_esPanicPlayer[tank].g_iCooldown != -1 && g_esPanicPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esPanicCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esPanicCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPanicPlayer[tank].g_iTankType) || (g_esPanicCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPanicCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPanicAbility[g_esPanicPlayer[tank].g_iTankType].g_iAccessFlags, g_esPanicPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esPanicPlayer[tank].g_iAmmoCount < g_esPanicCache[tank].g_iHumanAmmo && g_esPanicCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esPanicCache[tank].g_flPanicChance)
		{
			vPanic(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPanicCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPanicCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicAmmo");
	}
}

void vPanicRange(int tank, bool idle)
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(tank) && g_esPanicCache[tank].g_iPanicAbility == 1 && MT_GetRandomFloat(0.1, 100.0) <= g_esPanicCache[tank].g_flPanicChance)
	{
		if ((idle && MT_IsTankIdle(tank)) || bIsAreaNarrow(tank, g_esPanicCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esPanicCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPanicPlayer[tank].g_iTankType) || (g_esPanicCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPanicCache[tank].g_iRequiresHumans) || (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPanicAbility[g_esPanicPlayer[tank].g_iTankType].g_iAccessFlags, g_esPanicPlayer[tank].g_iAccessFlags)) || g_esPanicCache[tank].g_iHumanAbility == 0)))
		{
			return;
		}

		vPanic3(tank);
	}
}

void vPanicCopyStats2(int oldTank, int newTank)
{
	g_esPanicPlayer[newTank].g_iAmmoCount = g_esPanicPlayer[oldTank].g_iAmmoCount;
	g_esPanicPlayer[newTank].g_iCooldown = g_esPanicPlayer[oldTank].g_iCooldown;
}

void vRemovePanic(int tank)
{
	g_esPanicPlayer[tank].g_bActivated = false;
	g_esPanicPlayer[tank].g_iAmmoCount = 0;
	g_esPanicPlayer[tank].g_iCooldown = -1;
}

void vPanicReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemovePanic(iPlayer);
		}
	}
}

void vPanicReset2(int tank)
{
	g_esPanicPlayer[tank].g_bActivated = false;

	int iTime = GetTime(), iPos = g_esPanicAbility[g_esPanicPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esPanicCache[tank].g_iPanicCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPanicCache[tank].g_iHumanAbility == 1 && g_esPanicPlayer[tank].g_iAmmoCount < g_esPanicCache[tank].g_iHumanAmmo && g_esPanicCache[tank].g_iHumanAmmo > 0) ? g_esPanicCache[tank].g_iHumanCooldown : iCooldown;
	g_esPanicPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esPanicPlayer[tank].g_iCooldown != -1 && g_esPanicPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "PanicHuman5", (g_esPanicPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerPanicCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esPanicAbility[g_esPanicPlayer[iTank].g_iTankType].g_iAccessFlags, g_esPanicPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esPanicPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esPanicCache[iTank].g_iPanicAbility == 0 || g_esPanicPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vPanic(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerPanic(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esPanicCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esPanicCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPanicPlayer[iTank].g_iTankType) || (g_esPanicCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPanicCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esPanicAbility[g_esPanicPlayer[iTank].g_iTankType].g_iAccessFlags, g_esPanicPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esPanicPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esPanicPlayer[iTank].g_iTankType || g_esPanicCache[iTank].g_iPanicAbility == 0 || !g_esPanicPlayer[iTank].g_bActivated)
	{
		g_esPanicPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esPanicCache[iTank].g_iPanicDuration;
	iDuration = (bHuman && g_esPanicCache[iTank].g_iHumanAbility == 1) ? g_esPanicCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esPanicCache[iTank].g_iHumanAbility == 1 && g_esPanicCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime && (g_esPanicPlayer[iTank].g_iCooldown == -1 || g_esPanicPlayer[iTank].g_iCooldown < iCurrentTime))
	{
		vPanicReset2(iTank);

		return Plugin_Stop;
	}

	vPanic3(iTank);

	if (g_esPanicCache[iTank].g_iPanicMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(iTank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Panic2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Panic2", LANG_SERVER, sTankName);
	}

	return Plugin_Continue;
}