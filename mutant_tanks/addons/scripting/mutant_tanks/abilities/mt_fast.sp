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

#define MT_FAST_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_FAST_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Fast Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank runs really fast like the Flash.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Fast Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_FAST_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_FAST_SECTION "fastability"
#define MT_FAST_SECTION2 "fast ability"
#define MT_FAST_SECTION3 "fast_ability"
#define MT_FAST_SECTION4 "fast"

#define MT_MENU_FAST "Fast Ability"

enum struct esFastPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flFastChance;
	float g_flFastSpeed;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iDuration;
	int g_iFastAbility;
	int g_iFastCooldown;
	int g_iFastDuration;
	int g_iFastMessage;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
	int g_iTankType;
}

esFastPlayer g_esFastPlayer[MAXPLAYERS + 1];

enum struct esFastAbility
{
	float g_flCloseAreasOnly;
	float g_flFastChance;
	float g_flFastSpeed;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iFastAbility;
	int g_iFastCooldown;
	int g_iFastDuration;
	int g_iFastMessage;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
}

esFastAbility g_esFastAbility[MT_MAXTYPES + 1];

enum struct esFastCache
{
	float g_flCloseAreasOnly;
	float g_flFastChance;
	float g_flFastSpeed;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iFastAbility;
	int g_iFastCooldown;
	int g_iFastDuration;
	int g_iFastMessage;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
}

esFastCache g_esFastCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_fast", cmdFastInfo, "View information about the Fast ability.");
}
#endif

#if defined MT_ABILITIES_MAIN
void vFastMapStart()
#else
public void OnMapStart()
#endif
{
	vFastReset();
}

#if defined MT_ABILITIES_MAIN
void vFastClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveFast(client);
}

#if defined MT_ABILITIES_MAIN
void vFastClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveFast(client);
}

#if defined MT_ABILITIES_MAIN
void vFastMapEnd()
#else
public void OnMapEnd()
#endif
{
	vFastReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdFastInfo(int client, int args)
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
		case false: vFastMenu(client, MT_FAST_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vFastMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_FAST_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iFastMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Fast Ability Information");
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

int iFastMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFastCache[param1].g_iFastAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esFastCache[param1].g_iHumanAmmo - g_esFastPlayer[param1].g_iAmmoCount), g_esFastCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFastCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esFastCache[param1].g_iHumanAbility == 1) ? g_esFastCache[param1].g_iHumanCooldown : g_esFastCache[param1].g_iFastCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "FastDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esFastCache[param1].g_iHumanAbility == 1) ? g_esFastCache[param1].g_iHumanDuration : g_esFastCache[param1].g_iFastDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFastCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vFastMenu(param1, MT_FAST_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pFast = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "FastMenu", param1);
			pFast.SetTitle(sMenuTitle);
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

#if defined MT_ABILITIES_MAIN
void vFastDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_FAST, MT_MENU_FAST);
}

#if defined MT_ABILITIES_MAIN
void vFastMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_FAST, false))
	{
		vFastMenu(client, MT_FAST_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vFastMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_FAST, false))
	{
		FormatEx(buffer, size, "%T", "FastMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vFastPlayerRunCmd(int client)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsTankSupported(client) || !g_esFastPlayer[client].g_bActivated || (bIsTank(client, MT_CHECK_FAKECLIENT) && g_esFastCache[client].g_iHumanMode == 1) || g_esFastPlayer[client].g_iDuration == -1)
	{
#if defined MT_ABILITIES_MAIN
		return;
#else
		return Plugin_Continue;
#endif
	}

	int iTime = GetTime();
	if (g_esFastPlayer[client].g_iDuration < iTime)
	{
		if (g_esFastPlayer[client].g_iCooldown == -1 || g_esFastPlayer[client].g_iCooldown < iTime)
		{
			vFastReset3(client);
		}

		vFastReset2(client);
	}
#if !defined MT_ABILITIES_MAIN
	return Plugin_Continue;
#endif
}

#if defined MT_ABILITIES_MAIN
void vFastPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_FAST);
}

#if defined MT_ABILITIES_MAIN
void vFastAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_FAST_SECTION);
	list2.PushString(MT_FAST_SECTION2);
	list3.PushString(MT_FAST_SECTION3);
	list4.PushString(MT_FAST_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vFastCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFastCache[tank].g_iHumanAbility != 2)
	{
		g_esFastAbility[g_esFastPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esFastAbility[g_esFastPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_FAST_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_FAST_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_FAST_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_FAST_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esFastCache[tank].g_iFastAbility == 1 && g_esFastCache[tank].g_iComboAbility == 1 && !g_esFastPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_FAST_SECTION, false) || StrEqual(sSubset[iPos], MT_FAST_SECTION2, false) || StrEqual(sSubset[iPos], MT_FAST_SECTION3, false) || StrEqual(sSubset[iPos], MT_FAST_SECTION4, false))
				{
					g_esFastAbility[g_esFastPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vFast(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerFastCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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

#if defined MT_ABILITIES_MAIN
void vFastConfigsLoad(int mode)
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
				g_esFastAbility[iIndex].g_iAccessFlags = 0;
				g_esFastAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esFastAbility[iIndex].g_iComboAbility = 0;
				g_esFastAbility[iIndex].g_iComboPosition = -1;
				g_esFastAbility[iIndex].g_iHumanAbility = 0;
				g_esFastAbility[iIndex].g_iHumanAmmo = 5;
				g_esFastAbility[iIndex].g_iHumanCooldown = 0;
				g_esFastAbility[iIndex].g_iHumanDuration = 5;
				g_esFastAbility[iIndex].g_iHumanMode = 1;
				g_esFastAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esFastAbility[iIndex].g_iRequiresHumans = 0;
				g_esFastAbility[iIndex].g_iFastAbility = 0;
				g_esFastAbility[iIndex].g_iFastMessage = 0;
				g_esFastAbility[iIndex].g_flFastChance = 33.3;
				g_esFastAbility[iIndex].g_iFastCooldown = 0;
				g_esFastAbility[iIndex].g_iFastDuration = 5;
				g_esFastAbility[iIndex].g_flFastSpeed = 5.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esFastPlayer[iPlayer].g_iAccessFlags = 0;
					g_esFastPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esFastPlayer[iPlayer].g_iComboAbility = 0;
					g_esFastPlayer[iPlayer].g_iHumanAbility = 0;
					g_esFastPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esFastPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esFastPlayer[iPlayer].g_iHumanDuration = 0;
					g_esFastPlayer[iPlayer].g_iHumanMode = 0;
					g_esFastPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esFastPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esFastPlayer[iPlayer].g_iFastAbility = 0;
					g_esFastPlayer[iPlayer].g_iFastMessage = 0;
					g_esFastPlayer[iPlayer].g_flFastChance = 0.0;
					g_esFastPlayer[iPlayer].g_iFastCooldown = 0;
					g_esFastPlayer[iPlayer].g_iFastDuration = 0;
					g_esFastPlayer[iPlayer].g_flFastSpeed = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFastConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esFastPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esFastPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esFastPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esFastPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esFastPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esFastPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esFastPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esFastPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esFastPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esFastPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esFastPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esFastPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esFastPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esFastPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esFastPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esFastPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esFastPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esFastPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esFastPlayer[admin].g_iFastAbility = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esFastPlayer[admin].g_iFastAbility, value, 0, 1);
		g_esFastPlayer[admin].g_iFastMessage = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esFastPlayer[admin].g_iFastMessage, value, 0, 1);
		g_esFastPlayer[admin].g_flFastChance = flGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "FastChance", "Fast Chance", "Fast_Chance", "chance", g_esFastPlayer[admin].g_flFastChance, value, 0.0, 100.0);
		g_esFastPlayer[admin].g_iFastCooldown = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "FastCooldown", "Fast Cooldown", "Fast_Cooldown", "cooldown", g_esFastPlayer[admin].g_iFastCooldown, value, 0, 99999);
		g_esFastPlayer[admin].g_iFastDuration = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "FastDuration", "Fast Duration", "Fast_Duration", "duration", g_esFastPlayer[admin].g_iFastDuration, value, 0, 99999);
		g_esFastPlayer[admin].g_flFastSpeed = flGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "FastSpeed", "Fast Speed", "Fast_Speed", "speed", g_esFastPlayer[admin].g_flFastSpeed, value, 3.0, 10.0);
		g_esFastPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esFastAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esFastAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esFastAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esFastAbility[type].g_iComboAbility, value, 0, 1);
		g_esFastAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esFastAbility[type].g_iHumanAbility, value, 0, 2);
		g_esFastAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esFastAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esFastAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esFastAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esFastAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esFastAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esFastAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esFastAbility[type].g_iHumanMode, value, 0, 1);
		g_esFastAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esFastAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esFastAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esFastAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esFastAbility[type].g_iFastAbility = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esFastAbility[type].g_iFastAbility, value, 0, 1);
		g_esFastAbility[type].g_iFastMessage = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esFastAbility[type].g_iFastMessage, value, 0, 1);
		g_esFastAbility[type].g_flFastChance = flGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "FastChance", "Fast Chance", "Fast_Chance", "chance", g_esFastAbility[type].g_flFastChance, value, 0.0, 100.0);
		g_esFastAbility[type].g_iFastCooldown = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "FastCooldown", "Fast Cooldown", "Fast_Cooldown", "cooldown", g_esFastAbility[type].g_iFastCooldown, value, 0, 99999);
		g_esFastAbility[type].g_iFastDuration = iGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "FastDuration", "Fast Duration", "Fast_Duration", "duration", g_esFastAbility[type].g_iFastDuration, value, 0, 99999);
		g_esFastAbility[type].g_flFastSpeed = flGetKeyValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "FastSpeed", "Fast Speed", "Fast_Speed", "speed", g_esFastAbility[type].g_flFastSpeed, value, 3.0, 10.0);
		g_esFastAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_FAST_SECTION, MT_FAST_SECTION2, MT_FAST_SECTION3, MT_FAST_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vFastSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esFastCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_flCloseAreasOnly, g_esFastAbility[type].g_flCloseAreasOnly);
	g_esFastCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iComboAbility, g_esFastAbility[type].g_iComboAbility);
	g_esFastCache[tank].g_flFastChance = flGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_flFastChance, g_esFastAbility[type].g_flFastChance);
	g_esFastCache[tank].g_flFastSpeed = flGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_flFastSpeed, g_esFastAbility[type].g_flFastSpeed);
	g_esFastCache[tank].g_iFastAbility = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iFastAbility, g_esFastAbility[type].g_iFastAbility);
	g_esFastCache[tank].g_iFastCooldown = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iFastCooldown, g_esFastAbility[type].g_iFastCooldown);
	g_esFastCache[tank].g_iFastDuration = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iFastDuration, g_esFastAbility[type].g_iFastDuration);
	g_esFastCache[tank].g_iFastMessage = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iFastMessage, g_esFastAbility[type].g_iFastMessage);
	g_esFastCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iHumanAbility, g_esFastAbility[type].g_iHumanAbility);
	g_esFastCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iHumanAmmo, g_esFastAbility[type].g_iHumanAmmo);
	g_esFastCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iHumanCooldown, g_esFastAbility[type].g_iHumanCooldown);
	g_esFastCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iHumanDuration, g_esFastAbility[type].g_iHumanDuration);
	g_esFastCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iHumanMode, g_esFastAbility[type].g_iHumanMode);
	g_esFastCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_flOpenAreasOnly, g_esFastAbility[type].g_flOpenAreasOnly);
	g_esFastCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esFastPlayer[tank].g_iRequiresHumans, g_esFastAbility[type].g_iRequiresHumans);
	g_esFastPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vFastCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vFastCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveFast(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vFastPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esFastPlayer[iTank].g_bActivated)
		{
			SetEntPropFloat(iTank, Prop_Send, "m_flLaggedMovementValue", 1.0);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFastEventFired(Event event, const char[] name)
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
			vFastCopyStats2(iBot, iTank);
			vRemoveFast(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vFastCopyStats2(iTank, iBot);
			vRemoveFast(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveFast(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vFastReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vFastAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFastAbility[g_esFastPlayer[tank].g_iTankType].g_iAccessFlags, g_esFastPlayer[tank].g_iAccessFlags)) || g_esFastCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esFastCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esFastCache[tank].g_iFastAbility == 1 && g_esFastCache[tank].g_iComboAbility == 0 && !g_esFastPlayer[tank].g_bActivated)
	{
		vFastAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN
void vFastButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esFastCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFastCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFastPlayer[tank].g_iTankType) || (g_esFastCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFastCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFastAbility[g_esFastPlayer[tank].g_iTankType].g_iAccessFlags, g_esFastPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esFastCache[tank].g_iFastAbility == 1 && g_esFastCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esFastPlayer[tank].g_iCooldown != -1 && g_esFastPlayer[tank].g_iCooldown > iTime;

			switch (g_esFastCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esFastPlayer[tank].g_bActivated && !bRecharging)
					{
						vFastAbility(tank);
					}
					else if (g_esFastPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastHuman4", (g_esFastPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esFastPlayer[tank].g_iAmmoCount < g_esFastCache[tank].g_iHumanAmmo && g_esFastCache[tank].g_iHumanAmmo > 0))
					{
						if (!g_esFastPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esFastPlayer[tank].g_bActivated = true;
							g_esFastPlayer[tank].g_iAmmoCount++;

							SetEntPropFloat(tank, Prop_Send, "m_flLaggedMovementValue", g_esFastCache[tank].g_flFastSpeed);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastHuman", g_esFastPlayer[tank].g_iAmmoCount, g_esFastCache[tank].g_iHumanAmmo);
						}
						else if (g_esFastPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastHuman4", (g_esFastPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFastButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esFastCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esFastCache[tank].g_iHumanMode == 1 && g_esFastPlayer[tank].g_bActivated && (g_esFastPlayer[tank].g_iCooldown == -1 || g_esFastPlayer[tank].g_iCooldown < GetTime()))
		{
			vFastReset2(tank);
			vFastReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFastChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveFast(tank);
}

void vFast(int tank, int pos = -1)
{
	int iTime = GetTime();
	if (g_esFastPlayer[tank].g_iCooldown != -1 && g_esFastPlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	int iDuration = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 5, pos)) : g_esFastCache[tank].g_iFastDuration;
	iDuration = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFastCache[tank].g_iHumanAbility == 1) ? g_esFastCache[tank].g_iHumanDuration : iDuration;
	g_esFastPlayer[tank].g_bActivated = true;
	g_esFastPlayer[tank].g_iDuration = (iTime + iDuration);

	float flSpeed = (pos != -1) ? MT_GetCombinationSetting(tank, 16, pos) : g_esFastCache[tank].g_flFastSpeed;
	SetEntPropFloat(tank, Prop_Send, "m_flLaggedMovementValue", flSpeed);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFastCache[tank].g_iHumanAbility == 1)
	{
		g_esFastPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastHuman", g_esFastPlayer[tank].g_iAmmoCount, g_esFastCache[tank].g_iHumanAmmo);
	}

	if (g_esFastCache[tank].g_iFastMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Fast", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Fast", LANG_SERVER, sTankName);
	}
}

void vFastAbility(int tank)
{
	if ((g_esFastPlayer[tank].g_iCooldown != -1 && g_esFastPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esFastCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFastCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFastPlayer[tank].g_iTankType) || (g_esFastCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFastCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFastAbility[g_esFastPlayer[tank].g_iTankType].g_iAccessFlags, g_esFastPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esFastPlayer[tank].g_iAmmoCount < g_esFastCache[tank].g_iHumanAmmo && g_esFastCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esFastCache[tank].g_flFastChance)
		{
			vFast(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFastCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFastCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastAmmo");
	}
}

void vFastCopyStats2(int oldTank, int newTank)
{
	g_esFastPlayer[newTank].g_iAmmoCount = g_esFastPlayer[oldTank].g_iAmmoCount;
	g_esFastPlayer[newTank].g_iCooldown = g_esFastPlayer[oldTank].g_iCooldown;
}

void vRemoveFast(int tank)
{
	g_esFastPlayer[tank].g_bActivated = false;
	g_esFastPlayer[tank].g_iAmmoCount = 0;
	g_esFastPlayer[tank].g_iCooldown = -1;
	g_esFastPlayer[tank].g_iDuration = -1;
}

void vFastReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveFast(iPlayer);
		}
	}
}

void vFastReset2(int tank)
{
	g_esFastPlayer[tank].g_bActivated = false;
	g_esFastPlayer[tank].g_iDuration = -1;

	SetEntPropFloat(tank, Prop_Send, "m_flLaggedMovementValue", MT_GetRunSpeed(tank));

	if (g_esFastCache[tank].g_iFastMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Fast2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Fast2", LANG_SERVER, sTankName);
	}
}

void vFastReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esFastAbility[g_esFastPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esFastCache[tank].g_iFastCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFastCache[tank].g_iHumanAbility == 1 && g_esFastCache[tank].g_iHumanMode == 0 && g_esFastPlayer[tank].g_iAmmoCount < g_esFastCache[tank].g_iHumanAmmo && g_esFastCache[tank].g_iHumanAmmo > 0) ? g_esFastCache[tank].g_iHumanCooldown : iCooldown;
	g_esFastPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esFastPlayer[tank].g_iCooldown != -1 && g_esFastPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "FastHuman5", (g_esFastPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerFastCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esFastAbility[g_esFastPlayer[iTank].g_iTankType].g_iAccessFlags, g_esFastPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esFastPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esFastCache[iTank].g_iFastAbility == 0 || g_esFastPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vFast(iTank, iPos);

	return Plugin_Continue;
}