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

#define MT_SPLASH_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_SPLASH_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Splash Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank constantly deals splash damage to nearby survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Splash Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_SPLASH_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_SPLASH_SECTION "splashability"
#define MT_SPLASH_SECTION2 "splash ability"
#define MT_SPLASH_SECTION3 "splash_ability"
#define MT_SPLASH_SECTION4 "splash"

#define MT_MENU_SPLASH "Splash Ability"

enum struct esSplashPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSplashChance;
	float g_flSplashDamage;
	float g_flSplashInterval;
	float g_flSplashRange;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iSplashAbility;
	int g_iSplashCooldown;
	int g_iSplashDuration;
	int g_iSplashMessage;
	int g_iTankType;
}

esSplashPlayer g_esSplashPlayer[MAXPLAYERS + 1];

enum struct esSplashAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSplashChance;
	float g_flSplashDamage;
	float g_flSplashInterval;
	float g_flSplashRange;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iSplashAbility;
	int g_iSplashCooldown;
	int g_iSplashDuration;
	int g_iSplashMessage;
}

esSplashAbility g_esSplashAbility[MT_MAXTYPES + 1];

enum struct esSplashCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSplashChance;
	float g_flSplashDamage;
	float g_flSplashInterval;
	float g_flSplashRange;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
	int g_iSplashAbility;
	int g_iSplashCooldown;
	int g_iSplashDuration;
	int g_iSplashMessage;
}

esSplashCache g_esSplashCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_splash", cmdSplashInfo, "View information about the Splash ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vSplashMapStart()
#else
public void OnMapStart()
#endif
{
	vSplashReset();
}

#if defined MT_ABILITIES_MAIN2
void vSplashClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveSplash(client);
}

#if defined MT_ABILITIES_MAIN2
void vSplashClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveSplash(client);
}

#if defined MT_ABILITIES_MAIN2
void vSplashMapEnd()
#else
public void OnMapEnd()
#endif
{
	vSplashReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdSplashInfo(int client, int args)
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
		case false: vSplashMenu(client, MT_SPLASH_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vSplashMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_SPLASH_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iSplashMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Splash Ability Information");
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

int iSplashMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSplashCache[param1].g_iSplashAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esSplashCache[param1].g_iHumanAmmo - g_esSplashPlayer[param1].g_iAmmoCount), g_esSplashCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSplashCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esSplashCache[param1].g_iHumanAbility == 1) ? g_esSplashCache[param1].g_iHumanCooldown : g_esSplashCache[param1].g_iSplashCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "SplashDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esSplashCache[param1].g_iHumanAbility == 1) ? g_esSplashCache[param1].g_iHumanDuration : g_esSplashCache[param1].g_iSplashDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSplashCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vSplashMenu(param1, MT_SPLASH_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pSplash = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "SplashMenu", param1);
			pSplash.SetTitle(sMenuTitle);
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
void vSplashDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_SPLASH, MT_MENU_SPLASH);
}

#if defined MT_ABILITIES_MAIN2
void vSplashMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_SPLASH, false))
	{
		vSplashMenu(client, MT_SPLASH_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplashMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_SPLASH, false))
	{
		FormatEx(buffer, size, "%T", "SplashMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplashPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_SPLASH);
}

#if defined MT_ABILITIES_MAIN2
void vSplashAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_SPLASH_SECTION);
	list2.PushString(MT_SPLASH_SECTION2);
	list3.PushString(MT_SPLASH_SECTION3);
	list4.PushString(MT_SPLASH_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vSplashCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplashCache[tank].g_iHumanAbility != 2)
	{
		g_esSplashAbility[g_esSplashPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esSplashAbility[g_esSplashPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_SPLASH_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_SPLASH_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_SPLASH_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_SPLASH_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esSplashCache[tank].g_iSplashAbility == 1 && g_esSplashCache[tank].g_iComboAbility == 1 && !g_esSplashPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_SPLASH_SECTION, false) || StrEqual(sSubset[iPos], MT_SPLASH_SECTION2, false) || StrEqual(sSubset[iPos], MT_SPLASH_SECTION3, false) || StrEqual(sSubset[iPos], MT_SPLASH_SECTION4, false))
				{
					g_esSplashAbility[g_esSplashPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vSplash(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerSplashCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vSplashConfigsLoad(int mode)
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
				g_esSplashAbility[iIndex].g_iAccessFlags = 0;
				g_esSplashAbility[iIndex].g_iImmunityFlags = 0;
				g_esSplashAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esSplashAbility[iIndex].g_iComboAbility = 0;
				g_esSplashAbility[iIndex].g_iComboPosition = -1;
				g_esSplashAbility[iIndex].g_iHumanAbility = 0;
				g_esSplashAbility[iIndex].g_iHumanAmmo = 5;
				g_esSplashAbility[iIndex].g_iHumanCooldown = 0;
				g_esSplashAbility[iIndex].g_iHumanDuration = 5;
				g_esSplashAbility[iIndex].g_iHumanMode = 1;
				g_esSplashAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esSplashAbility[iIndex].g_iRequiresHumans = 0;
				g_esSplashAbility[iIndex].g_iSplashAbility = 0;
				g_esSplashAbility[iIndex].g_iSplashMessage = 0;
				g_esSplashAbility[iIndex].g_flSplashChance = 33.3;
				g_esSplashAbility[iIndex].g_iSplashCooldown = 0;
				g_esSplashAbility[iIndex].g_flSplashDamage = 5.0;
				g_esSplashAbility[iIndex].g_iSplashDuration = 0;
				g_esSplashAbility[iIndex].g_flSplashInterval = 5.0;
				g_esSplashAbility[iIndex].g_flSplashRange = 500.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esSplashPlayer[iPlayer].g_iAccessFlags = 0;
					g_esSplashPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esSplashPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esSplashPlayer[iPlayer].g_iComboAbility = 0;
					g_esSplashPlayer[iPlayer].g_iHumanAbility = 0;
					g_esSplashPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esSplashPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esSplashPlayer[iPlayer].g_iHumanDuration = 0;
					g_esSplashPlayer[iPlayer].g_iHumanMode = 0;
					g_esSplashPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esSplashPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esSplashPlayer[iPlayer].g_iSplashAbility = 0;
					g_esSplashPlayer[iPlayer].g_iSplashMessage = 0;
					g_esSplashPlayer[iPlayer].g_flSplashChance = 0.0;
					g_esSplashPlayer[iPlayer].g_iSplashCooldown = 0;
					g_esSplashPlayer[iPlayer].g_flSplashDamage = 0.0;
					g_esSplashPlayer[iPlayer].g_iSplashDuration = 0;
					g_esSplashPlayer[iPlayer].g_flSplashInterval = 0.0;
					g_esSplashPlayer[iPlayer].g_flSplashRange = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplashConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esSplashPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSplashPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSplashPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSplashPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esSplashPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSplashPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esSplashPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSplashPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esSplashPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSplashPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esSplashPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esSplashPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esSplashPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esSplashPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esSplashPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSplashPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSplashPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSplashPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esSplashPlayer[admin].g_iSplashAbility = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSplashPlayer[admin].g_iSplashAbility, value, 0, 1);
		g_esSplashPlayer[admin].g_iSplashMessage = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSplashPlayer[admin].g_iSplashMessage, value, 0, 1);
		g_esSplashPlayer[admin].g_flSplashChance = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashChance", "Splash Chance", "Splash_Chance", "chance", g_esSplashPlayer[admin].g_flSplashChance, value, 0.0, 100.0);
		g_esSplashPlayer[admin].g_iSplashCooldown = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashCooldown", "Splash Cooldown", "Splash_Cooldown", "cooldown", g_esSplashPlayer[admin].g_iSplashCooldown, value, 0, 99999);
		g_esSplashPlayer[admin].g_flSplashDamage = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashDamage", "Splash Damage", "Splash_Damage", "damage", g_esSplashPlayer[admin].g_flSplashDamage, value, 0.0, 99999.0);
		g_esSplashPlayer[admin].g_iSplashDuration = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashDuration", "Splash Duration", "Splash_Duration", "duration", g_esSplashPlayer[admin].g_iSplashDuration, value, 0, 99999);
		g_esSplashPlayer[admin].g_flSplashInterval = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashInterval", "Splash Interval", "Splash_Interval", "interval", g_esSplashPlayer[admin].g_flSplashInterval, value, 0.1, 99999.0);
		g_esSplashPlayer[admin].g_flSplashRange = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashRange", "Splash Range", "Splash_Range", "range", g_esSplashPlayer[admin].g_flSplashRange, value, 1.0, 99999.0);
		g_esSplashPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSplashPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esSplashAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSplashAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSplashAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSplashAbility[type].g_iComboAbility, value, 0, 1);
		g_esSplashAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSplashAbility[type].g_iHumanAbility, value, 0, 2);
		g_esSplashAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSplashAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esSplashAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSplashAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esSplashAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esSplashAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esSplashAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esSplashAbility[type].g_iHumanMode, value, 0, 1);
		g_esSplashAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSplashAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSplashAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSplashAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esSplashAbility[type].g_iSplashAbility = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSplashAbility[type].g_iSplashAbility, value, 0, 1);
		g_esSplashAbility[type].g_iSplashMessage = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSplashAbility[type].g_iSplashMessage, value, 0, 1);
		g_esSplashAbility[type].g_flSplashChance = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashChance", "Splash Chance", "Splash_Chance", "chance", g_esSplashAbility[type].g_flSplashChance, value, 0.0, 100.0);
		g_esSplashAbility[type].g_iSplashCooldown = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashCooldown", "Splash Cooldown", "Splash_Cooldown", "cooldown", g_esSplashAbility[type].g_iSplashCooldown, value, 0, 99999);
		g_esSplashAbility[type].g_flSplashDamage = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashDamage", "Splash Damage", "Splash_Damage", "damage", g_esSplashAbility[type].g_flSplashDamage, value, 0.0, 99999.0);
		g_esSplashAbility[type].g_iSplashDuration = iGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashDuration", "Splash Duration", "Splash_Duration", "duration", g_esSplashAbility[type].g_iSplashDuration, value, 0, 99999);
		g_esSplashAbility[type].g_flSplashInterval = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashInterval", "Splash Interval", "Splash_Interval", "interval", g_esSplashAbility[type].g_flSplashInterval, value, 0.1, 99999.0);
		g_esSplashAbility[type].g_flSplashRange = flGetKeyValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "SplashRange", "Splash Range", "Splash_Range", "range", g_esSplashAbility[type].g_flSplashRange, value, 1.0, 99999.0);
		g_esSplashAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSplashAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SPLASH_SECTION, MT_SPLASH_SECTION2, MT_SPLASH_SECTION3, MT_SPLASH_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplashSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esSplashCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_flCloseAreasOnly, g_esSplashAbility[type].g_flCloseAreasOnly);
	g_esSplashCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iComboAbility, g_esSplashAbility[type].g_iComboAbility);
	g_esSplashCache[tank].g_flSplashChance = flGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_flSplashChance, g_esSplashAbility[type].g_flSplashChance);
	g_esSplashCache[tank].g_flSplashDamage = flGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_flSplashDamage, g_esSplashAbility[type].g_flSplashDamage);
	g_esSplashCache[tank].g_flSplashInterval = flGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_flSplashInterval, g_esSplashAbility[type].g_flSplashInterval);
	g_esSplashCache[tank].g_flSplashRange = flGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_flSplashRange, g_esSplashAbility[type].g_flSplashRange);
	g_esSplashCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iHumanAbility, g_esSplashAbility[type].g_iHumanAbility);
	g_esSplashCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iHumanAmmo, g_esSplashAbility[type].g_iHumanAmmo);
	g_esSplashCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iHumanCooldown, g_esSplashAbility[type].g_iHumanCooldown);
	g_esSplashCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iHumanDuration, g_esSplashAbility[type].g_iHumanDuration);
	g_esSplashCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iHumanMode, g_esSplashAbility[type].g_iHumanMode);
	g_esSplashCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_flOpenAreasOnly, g_esSplashAbility[type].g_flOpenAreasOnly);
	g_esSplashCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iRequiresHumans, g_esSplashAbility[type].g_iRequiresHumans);
	g_esSplashCache[tank].g_iSplashAbility = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iSplashAbility, g_esSplashAbility[type].g_iSplashAbility);
	g_esSplashCache[tank].g_iSplashCooldown = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iSplashCooldown, g_esSplashAbility[type].g_iSplashCooldown);
	g_esSplashCache[tank].g_iSplashDuration = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iSplashDuration, g_esSplashAbility[type].g_iSplashDuration);
	g_esSplashCache[tank].g_iSplashMessage = iGetSettingValue(apply, bHuman, g_esSplashPlayer[tank].g_iSplashMessage, g_esSplashAbility[type].g_iSplashMessage);
	g_esSplashPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vSplashCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vSplashCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveSplash(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vSplashEventFired(Event event, const char[] name)
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
			vSplashCopyStats2(iBot, iTank);
			vRemoveSplash(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vSplashCopyStats2(iTank, iBot);
			vRemoveSplash(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveSplash(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vSplashReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplashAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSplashAbility[g_esSplashPlayer[tank].g_iTankType].g_iAccessFlags, g_esSplashPlayer[tank].g_iAccessFlags)) || g_esSplashCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esSplashCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esSplashCache[tank].g_iSplashAbility == 1 && g_esSplashCache[tank].g_iComboAbility == 0 && !g_esSplashPlayer[tank].g_bActivated)
	{
		vSplashAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplashButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esSplashCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSplashCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSplashPlayer[tank].g_iTankType) || (g_esSplashCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSplashCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSplashAbility[g_esSplashPlayer[tank].g_iTankType].g_iAccessFlags, g_esSplashPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esSplashCache[tank].g_iSplashAbility == 1 && g_esSplashCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esSplashPlayer[tank].g_iCooldown != -1 && g_esSplashPlayer[tank].g_iCooldown > iTime;

			switch (g_esSplashCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esSplashPlayer[tank].g_bActivated && !bRecharging)
					{
						vSplashAbility(tank);
					}
					else if (g_esSplashPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashHuman4", (g_esSplashPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esSplashPlayer[tank].g_iAmmoCount < g_esSplashCache[tank].g_iHumanAmmo && g_esSplashCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esSplashPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esSplashPlayer[tank].g_bActivated = true;
							g_esSplashPlayer[tank].g_iAmmoCount++;

							vSplash2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashHuman", g_esSplashPlayer[tank].g_iAmmoCount, g_esSplashCache[tank].g_iHumanAmmo);
						}
						else if (g_esSplashPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashHuman4", (g_esSplashPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplashButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esSplashCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esSplashCache[tank].g_iHumanMode == 1 && g_esSplashPlayer[tank].g_bActivated && (g_esSplashPlayer[tank].g_iCooldown == -1 || g_esSplashPlayer[tank].g_iCooldown < GetTime()))
		{
			vSplashReset2(tank);
			vSplashReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplashChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveSplash(tank);
}

void vSplash(int tank, int pos = -1)
{
	if (g_esSplashPlayer[tank].g_iCooldown != -1 && g_esSplashPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esSplashPlayer[tank].g_bActivated = true;

	vSplash2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplashCache[tank].g_iHumanAbility == 1)
	{
		g_esSplashPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashHuman", g_esSplashPlayer[tank].g_iAmmoCount, g_esSplashCache[tank].g_iHumanAmmo);
	}

	if (g_esSplashCache[tank].g_iSplashMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Splash", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Splash", LANG_SERVER, sTankName);
	}
}

void vSplash2(int tank, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esSplashCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSplashCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSplashPlayer[tank].g_iTankType) || (g_esSplashCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSplashCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSplashAbility[g_esSplashPlayer[tank].g_iTankType].g_iAccessFlags, g_esSplashPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esSplashCache[tank].g_flSplashInterval;
	DataPack dpSplash;
	CreateDataTimer(flInterval, tTimerSplash, dpSplash, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpSplash.WriteCell(GetClientUserId(tank));
	dpSplash.WriteCell(g_esSplashPlayer[tank].g_iTankType);
	dpSplash.WriteCell(GetTime());
	dpSplash.WriteCell(pos);
}

void vSplashAbility(int tank)
{
	if ((g_esSplashPlayer[tank].g_iCooldown != -1 && g_esSplashPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esSplashCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSplashCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSplashPlayer[tank].g_iTankType) || (g_esSplashCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSplashCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSplashAbility[g_esSplashPlayer[tank].g_iTankType].g_iAccessFlags, g_esSplashPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esSplashPlayer[tank].g_iAmmoCount < g_esSplashCache[tank].g_iHumanAmmo && g_esSplashCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esSplashCache[tank].g_flSplashChance)
		{
			vSplash(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplashCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplashCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashAmmo");
	}
}

void vSplashCopyStats2(int oldTank, int newTank)
{
	g_esSplashPlayer[newTank].g_iAmmoCount = g_esSplashPlayer[oldTank].g_iAmmoCount;
	g_esSplashPlayer[newTank].g_iCooldown = g_esSplashPlayer[oldTank].g_iCooldown;
}

void vRemoveSplash(int tank)
{
	g_esSplashPlayer[tank].g_bActivated = false;
	g_esSplashPlayer[tank].g_iAmmoCount = 0;
	g_esSplashPlayer[tank].g_iCooldown = -1;
}

void vSplashReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveSplash(iPlayer);
		}
	}
}

void vSplashReset2(int tank)
{
	g_esSplashPlayer[tank].g_bActivated = false;

	if (g_esSplashCache[tank].g_iSplashMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Splash2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Splash2", LANG_SERVER, sTankName);
	}
}

void vSplashReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esSplashAbility[g_esSplashPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esSplashCache[tank].g_iSplashCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplashCache[tank].g_iHumanAbility == 1 && g_esSplashCache[tank].g_iHumanMode == 0 && g_esSplashPlayer[tank].g_iAmmoCount < g_esSplashCache[tank].g_iHumanAmmo && g_esSplashCache[tank].g_iHumanAmmo > 0) ? g_esSplashCache[tank].g_iHumanCooldown : iCooldown;
	g_esSplashPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esSplashPlayer[tank].g_iCooldown != -1 && g_esSplashPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplashHuman5", (g_esSplashPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerSplashCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSplashAbility[g_esSplashPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSplashPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSplashPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSplashCache[iTank].g_iSplashAbility == 0 || g_esSplashPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vSplash(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerSplash(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esSplashCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esSplashCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSplashPlayer[iTank].g_iTankType) || (g_esSplashCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSplashCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSplashAbility[g_esSplashPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSplashPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSplashPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esSplashPlayer[iTank].g_iTankType || g_esSplashCache[iTank].g_iSplashAbility == 0 || !g_esSplashPlayer[iTank].g_bActivated)
	{
		vSplashReset2(iTank);

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esSplashCache[iTank].g_iSplashDuration;
	iDuration = (bHuman && g_esSplashCache[iTank].g_iHumanAbility == 1) ? g_esSplashCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esSplashCache[iTank].g_iHumanAbility == 1 && g_esSplashCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime && (g_esSplashPlayer[iTank].g_iCooldown == -1 || g_esSplashPlayer[iTank].g_iCooldown < iCurrentTime))
	{
		vSplashReset2(iTank);
		vSplashReset3(iTank);

		return Plugin_Stop;
	}

	float flTankPos[3], flSurvivorPos[3];
	GetClientAbsOrigin(iTank, flTankPos);
	float flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : g_esSplashCache[iTank].g_flSplashDamage,
		flRange = (iPos != -1) ? MT_GetCombinationSetting(iTank, 9, iPos) : g_esSplashCache[iTank].g_flSplashRange;
	if (flDamage > 0.0)
	{
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, iTank) && !bIsAdminImmune(iSurvivor, g_esSplashPlayer[iTank].g_iTankType, g_esSplashAbility[g_esSplashPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esSplashPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vDamagePlayer(iSurvivor, iTank, MT_GetScaledDamage(flDamage), "65536");
				}
			}
		}
	}

	return Plugin_Continue;
}