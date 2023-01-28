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

#define MT_OMNI_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_OMNI_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Omni Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank has omni-level access to other nearby Mutant Tanks' abilities.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Omni Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_OMNI_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_OMNI_SECTION "omniability"
#define MT_OMNI_SECTION2 "omni ability"
#define MT_OMNI_SECTION3 "omni_ability"
#define MT_OMNI_SECTION4 "omni"

#define MT_MENU_OMNI "Omni Ability"

enum struct esOmniPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flOmniChance;
	float g_flOmniRange;
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
	int g_iOmniAbility;
	int g_iOmniCooldown;
	int g_iOmniDuration;
	int g_iOmniMessage;
	int g_iOmniMode;
	int g_iOmniType;
	int g_iRequiresHumans;
	int g_iTankType;
}

esOmniPlayer g_esOmniPlayer[MAXPLAYERS + 1];

enum struct esOmniAbility
{
	float g_flCloseAreasOnly;
	float g_flOmniChance;
	float g_flOmniRange;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iOmniAbility;
	int g_iOmniCooldown;
	int g_iOmniDuration;
	int g_iOmniMessage;
	int g_iOmniMode;
	int g_iRequiresHumans;
}

esOmniAbility g_esOmniAbility[MT_MAXTYPES + 1];

enum struct esOmniCache
{
	float g_flCloseAreasOnly;
	float g_flOmniChance;
	float g_flOmniRange;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iOmniAbility;
	int g_iOmniCooldown;
	int g_iOmniDuration;
	int g_iOmniMessage;
	int g_iOmniMode;
	int g_iRequiresHumans;
}

esOmniCache g_esOmniCache[MAXPLAYERS + 1];

enum struct esOmni
{
	float g_flOmniChance;
	float g_flOmniRange;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iOmniAbility;
	int g_iOmniCooldown;
	int g_iOmniDuration;
	int g_iOmniMessage;
	int g_iOmniMode;
	int g_iRequiresHumans;
}

esOmni g_esOmni[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_omni", cmdOmniInfo, "View information about the Omni ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vOmniMapStart()
#else
public void OnMapStart()
#endif
{
	vOmniReset();
}

#if defined MT_ABILITIES_MAIN2
void vOmniClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveOmni(client);
}

#if defined MT_ABILITIES_MAIN2
void vOmniClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveOmni(client);
}

#if defined MT_ABILITIES_MAIN2
void vOmniMapEnd()
#else
public void OnMapEnd()
#endif
{
	vOmniReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdOmniInfo(int client, int args)
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
		case false: vOmniMenu(client, MT_OMNI_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vOmniMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_OMNI_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iOmniMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Omni Ability Information");
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

int iOmniMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esOmni[param1].g_iOmniAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esOmni[param1].g_iHumanAmmo - g_esOmniPlayer[param1].g_iAmmoCount), g_esOmni[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esOmni[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esOmni[param1].g_iHumanAbility == 1) ? g_esOmni[param1].g_iHumanCooldown : g_esOmni[param1].g_iOmniCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "OmniDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esOmni[param1].g_iHumanAbility == 1) ? g_esOmni[param1].g_iHumanDuration : g_esOmni[param1].g_iOmniDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esOmni[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vOmniMenu(param1, MT_OMNI_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pOmni = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "OmniMenu", param1);
			pOmni.SetTitle(sMenuTitle);
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
void vOmniDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_OMNI, MT_MENU_OMNI);
}

#if defined MT_ABILITIES_MAIN2
void vOmniMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_OMNI, false))
	{
		vOmniMenu(client, MT_OMNI_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vOmniMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_OMNI, false))
	{
		FormatEx(buffer, size, "%T", "OmniMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vOmniPlayerRunCmd(int client)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsTankSupported(client) || !g_esOmniPlayer[client].g_bActivated || (bIsTank(client, MT_CHECK_FAKECLIENT) && g_esOmni[client].g_iHumanMode == 1) || g_esOmniPlayer[client].g_iDuration == -1)
	{
#if defined MT_ABILITIES_MAIN2
		return;
#else
		return Plugin_Continue;
#endif
	}

	int iTime = GetTime();
	if (g_esOmniPlayer[client].g_iDuration < iTime)
	{
		if (g_esOmniPlayer[client].g_iCooldown == -1 || g_esOmniPlayer[client].g_iCooldown < iTime)
		{
			vOmniReset3(client);
		}

		vOmniReset2(client);
	}
#if !defined MT_ABILITIES_MAIN2
	return Plugin_Continue;
#endif
}

#if defined MT_ABILITIES_MAIN2
void vOmniPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_OMNI);
}

#if defined MT_ABILITIES_MAIN2
void vOmniAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_OMNI_SECTION);
	list2.PushString(MT_OMNI_SECTION2);
	list3.PushString(MT_OMNI_SECTION3);
	list4.PushString(MT_OMNI_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vOmniCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esOmniCache[tank].g_iHumanAbility != 2)
	{
		g_esOmniAbility[g_esOmniPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esOmniAbility[g_esOmniPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_OMNI_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_OMNI_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_OMNI_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_OMNI_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esOmniCache[tank].g_iOmniAbility == 1 && g_esOmniCache[tank].g_iComboAbility == 1 && !g_esOmniPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_OMNI_SECTION, false) || StrEqual(sSubset[iPos], MT_OMNI_SECTION2, false) || StrEqual(sSubset[iPos], MT_OMNI_SECTION3, false) || StrEqual(sSubset[iPos], MT_OMNI_SECTION4, false))
				{
					g_esOmniAbility[g_esOmniPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vOmni(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerOmniCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vOmniConfigsLoad(int mode)
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
				g_esOmniAbility[iIndex].g_iAccessFlags = 0;
				g_esOmniAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esOmniAbility[iIndex].g_iComboAbility = 0;
				g_esOmniAbility[iIndex].g_iComboPosition = -1;
				g_esOmniAbility[iIndex].g_iHumanAbility = 0;
				g_esOmniAbility[iIndex].g_iHumanAmmo = 5;
				g_esOmniAbility[iIndex].g_iHumanCooldown = 0;
				g_esOmniAbility[iIndex].g_iHumanDuration = 5;
				g_esOmniAbility[iIndex].g_iHumanMode = 1;
				g_esOmniAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esOmniAbility[iIndex].g_iRequiresHumans = 1;
				g_esOmniAbility[iIndex].g_iOmniAbility = 0;
				g_esOmniAbility[iIndex].g_iOmniMessage = 0;
				g_esOmniAbility[iIndex].g_flOmniChance = 33.3;
				g_esOmniAbility[iIndex].g_iOmniCooldown = 0;
				g_esOmniAbility[iIndex].g_iOmniDuration = 5;
				g_esOmniAbility[iIndex].g_iOmniMode = 0;
				g_esOmniAbility[iIndex].g_flOmniRange = 500.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esOmniPlayer[iPlayer].g_iAccessFlags = 0;
					g_esOmniPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esOmniPlayer[iPlayer].g_iComboAbility = 0;
					g_esOmniPlayer[iPlayer].g_iHumanAbility = 0;
					g_esOmniPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esOmniPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esOmniPlayer[iPlayer].g_iHumanDuration = 0;
					g_esOmniPlayer[iPlayer].g_iHumanMode = 0;
					g_esOmniPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esOmniPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esOmniPlayer[iPlayer].g_iOmniAbility = 0;
					g_esOmniPlayer[iPlayer].g_iOmniMessage = 0;
					g_esOmniPlayer[iPlayer].g_flOmniChance = 0.0;
					g_esOmniPlayer[iPlayer].g_iOmniCooldown = 0;
					g_esOmniPlayer[iPlayer].g_iOmniDuration = 0;
					g_esOmniPlayer[iPlayer].g_iOmniMode = 0;
					g_esOmniPlayer[iPlayer].g_flOmniRange = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vOmniConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esOmniPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esOmniPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esOmniPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esOmniPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esOmniPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esOmniPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esOmniPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esOmniPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esOmniPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esOmniPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esOmniPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esOmniPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esOmniPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esOmniPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esOmniPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esOmniPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esOmniPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esOmniPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esOmniPlayer[admin].g_iOmniAbility = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esOmniPlayer[admin].g_iOmniAbility, value, 0, 1);
		g_esOmniPlayer[admin].g_iOmniMessage = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esOmniPlayer[admin].g_iOmniMessage, value, 0, 1);
		g_esOmniPlayer[admin].g_flOmniChance = flGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniChance", "Omni Chance", "Omni_Chance", "chance", g_esOmniPlayer[admin].g_flOmniChance, value, 0.0, 100.0);
		g_esOmniPlayer[admin].g_iOmniCooldown = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniCooldown", "Omni Cooldown", "Omni_Cooldown", "cooldown", g_esOmniPlayer[admin].g_iOmniCooldown, value, 0, 99999);
		g_esOmniPlayer[admin].g_iOmniDuration = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniDuration", "Omni Duration", "Omni_Duration", "duration", g_esOmniPlayer[admin].g_iOmniDuration, value, 0, 99999);
		g_esOmniPlayer[admin].g_iOmniMode = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniMode", "Omni Mode", "Omni_Mode", "mode", g_esOmniPlayer[admin].g_iOmniMode, value, 0, 1);
		g_esOmniPlayer[admin].g_flOmniRange = flGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniRange", "Omni Range", "Omni_Range", "range", g_esOmniPlayer[admin].g_flOmniRange, value, 1.0, 99999.0);
		g_esOmniPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esOmniAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esOmniAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esOmniAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esOmniAbility[type].g_iComboAbility, value, 0, 1);
		g_esOmniAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esOmniAbility[type].g_iHumanAbility, value, 0, 2);
		g_esOmniAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esOmniAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esOmniAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esOmniAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esOmniAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esOmniAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esOmniAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esOmniAbility[type].g_iHumanMode, value, 0, 1);
		g_esOmniAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esOmniAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esOmniAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esOmniAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esOmniAbility[type].g_iOmniAbility = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esOmniAbility[type].g_iOmniAbility, value, 0, 1);
		g_esOmniAbility[type].g_iOmniMessage = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esOmniAbility[type].g_iOmniMessage, value, 0, 1);
		g_esOmniAbility[type].g_flOmniChance = flGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniChance", "Omni Chance", "Omni_Chance", "chance", g_esOmniAbility[type].g_flOmniChance, value, 0.0, 100.0);
		g_esOmniAbility[type].g_iOmniCooldown = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniCooldown", "Omni Cooldown", "Omni_Cooldown", "cooldown", g_esOmniAbility[type].g_iOmniCooldown, value, 0, 99999);
		g_esOmniAbility[type].g_iOmniDuration = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniDuration", "Omni Duration", "Omni_Duration", "duration", g_esOmniAbility[type].g_iOmniDuration, value, 0, 99999);
		g_esOmniAbility[type].g_iOmniMode = iGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniMode", "Omni Mode", "Omni_Mode", "mode", g_esOmniAbility[type].g_iOmniMode, value, 0, 1);
		g_esOmniAbility[type].g_flOmniRange = flGetKeyValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "OmniRange", "Omni Range", "Omni_Range", "range", g_esOmniAbility[type].g_flOmniRange, value, 1.0, 99999.0);
		g_esOmniAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_OMNI_SECTION, MT_OMNI_SECTION2, MT_OMNI_SECTION3, MT_OMNI_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vOmniSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esOmniCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_flCloseAreasOnly, g_esOmniAbility[type].g_flCloseAreasOnly);
	g_esOmniCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iComboAbility, g_esOmniAbility[type].g_iComboAbility);
	g_esOmniCache[tank].g_flOmniChance = flGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_flOmniChance, g_esOmniAbility[type].g_flOmniChance);
	g_esOmniCache[tank].g_flOmniRange = flGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_flOmniRange, g_esOmniAbility[type].g_flOmniRange);
	g_esOmniCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iHumanAbility, g_esOmniAbility[type].g_iHumanAbility);
	g_esOmniCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iHumanAmmo, g_esOmniAbility[type].g_iHumanAmmo);
	g_esOmniCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iHumanCooldown, g_esOmniAbility[type].g_iHumanCooldown);
	g_esOmniCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iHumanDuration, g_esOmniAbility[type].g_iHumanDuration);
	g_esOmniCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iHumanMode, g_esOmniAbility[type].g_iHumanMode);
	g_esOmniCache[tank].g_iOmniAbility = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iOmniAbility, g_esOmniAbility[type].g_iOmniAbility);
	g_esOmniCache[tank].g_iOmniCooldown = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iOmniCooldown, g_esOmniAbility[type].g_iOmniCooldown);
	g_esOmniCache[tank].g_iOmniDuration = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iOmniDuration, g_esOmniAbility[type].g_iOmniDuration);
	g_esOmniCache[tank].g_iOmniMessage = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iOmniMessage, g_esOmniAbility[type].g_iOmniMessage);
	g_esOmniCache[tank].g_iOmniMode = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iOmniMode, g_esOmniAbility[type].g_iOmniMode);
	g_esOmniCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_flOpenAreasOnly, g_esOmniAbility[type].g_flOpenAreasOnly);
	g_esOmniCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esOmniPlayer[tank].g_iRequiresHumans, g_esOmniAbility[type].g_iRequiresHumans);
	g_esOmniPlayer[tank].g_iTankType = apply ? type : 0;
}

void vCacheOriginalSettings(int tank)
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	int iType = (g_esOmniPlayer[tank].g_iOmniType > 0) ? g_esOmniPlayer[tank].g_iOmniType : g_esOmniPlayer[tank].g_iTankType;
	g_esOmni[tank].g_flOmniChance = flGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_flOmniChance, g_esOmniAbility[iType].g_flOmniChance);
	g_esOmni[tank].g_flOmniRange = flGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_flOmniRange, g_esOmniAbility[iType].g_flOmniRange);
	g_esOmni[tank].g_iAccessFlags = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iAccessFlags, g_esOmniAbility[iType].g_iAccessFlags);
	g_esOmni[tank].g_iHumanAbility = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iHumanAbility, g_esOmniAbility[iType].g_iHumanAbility);
	g_esOmni[tank].g_iHumanAmmo = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iHumanAmmo, g_esOmniAbility[iType].g_iHumanAmmo);
	g_esOmni[tank].g_iHumanCooldown = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iHumanCooldown, g_esOmniAbility[iType].g_iHumanCooldown);
	g_esOmni[tank].g_iHumanDuration = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iHumanDuration, g_esOmniAbility[iType].g_iHumanDuration);
	g_esOmni[tank].g_iHumanMode = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iHumanMode, g_esOmniAbility[iType].g_iHumanMode);
	g_esOmni[tank].g_iOmniAbility = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iOmniAbility, g_esOmniAbility[iType].g_iOmniAbility);
	g_esOmni[tank].g_iOmniCooldown = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iOmniCooldown, g_esOmniAbility[iType].g_iOmniCooldown);
	g_esOmni[tank].g_iOmniDuration = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iOmniDuration, g_esOmniAbility[iType].g_iOmniDuration);
	g_esOmni[tank].g_iOmniMessage = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iOmniMessage, g_esOmniAbility[iType].g_iOmniMessage);
	g_esOmni[tank].g_iOmniMode = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iOmniMode, g_esOmniAbility[iType].g_iOmniMode);
	g_esOmni[tank].g_iRequiresHumans = iGetSettingValue(true, bHuman, g_esOmniPlayer[tank].g_iRequiresHumans, g_esOmniAbility[iType].g_iRequiresHumans);
}

#if defined MT_ABILITIES_MAIN2
void vOmniCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vOmniCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveOmni(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vOmniEventFired(Event event, const char[] name)
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
			vOmniCopyStats2(iBot, iTank);
			vRemoveOmni(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vOmniCopyStats2(iTank, iBot);
			vRemoveOmni(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveOmni(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vOmniReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vOmniAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esOmni[tank].g_iAccessFlags, g_esOmniPlayer[tank].g_iAccessFlags)) || g_esOmni[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esOmni[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esOmni[tank].g_iOmniAbility == 1 && g_esOmniCache[tank].g_iComboAbility == 0 && !g_esOmniPlayer[tank].g_bActivated)
	{
		vOmniAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vOmniButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esOmniCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esOmniCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esOmniPlayer[tank].g_iTankType) || (g_esOmniCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esOmniCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esOmniAbility[g_esOmniPlayer[tank].g_iTankType].g_iAccessFlags, g_esOmniPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esOmni[tank].g_iOmniAbility == 1 && g_esOmni[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esOmniPlayer[tank].g_iCooldown != -1 && g_esOmniPlayer[tank].g_iCooldown > iTime;

			switch (g_esOmni[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esOmniPlayer[tank].g_bActivated && !bRecharging)
					{
						vOmniAbility(tank);
					}
					else if (g_esOmniPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniHuman4", (g_esOmniPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esOmniPlayer[tank].g_iAmmoCount < g_esOmni[tank].g_iHumanAmmo && g_esOmni[tank].g_iHumanAmmo > 0)
					{
						if (!g_esOmniPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esOmniPlayer[tank].g_bActivated = true;
							g_esOmniPlayer[tank].g_iAmmoCount++;

							vOmni2(tank);

							MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniHuman", g_esOmniPlayer[tank].g_iAmmoCount, g_esOmni[tank].g_iHumanAmmo);
						}
						else if (g_esOmniPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniHuman4", (g_esOmniPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vOmniButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esOmniCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esOmni[tank].g_iHumanMode == 1 && g_esOmniPlayer[tank].g_bActivated && (g_esOmniPlayer[tank].g_iCooldown == -1 || g_esOmniPlayer[tank].g_iCooldown < GetTime()))
		{
			vOmniReset2(tank);
			vOmniReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vOmniPostTankSpawn(int tank)
#else
public void MT_OnPostTankSpawn(int tank)
#endif
{
	vCacheOriginalSettings(tank);
}

void vOmni(int tank, int pos = -1)
{
	int iTime = GetTime();
	if (g_esOmniPlayer[tank].g_iCooldown != -1 && g_esOmniPlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	int iDuration = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 5, pos)) : g_esOmniCache[tank].g_iOmniDuration;
	iDuration = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esOmniCache[tank].g_iHumanAbility == 1) ? g_esOmniCache[tank].g_iHumanDuration : iDuration;
	g_esOmniPlayer[tank].g_bActivated = true;
	g_esOmniPlayer[tank].g_iDuration = (iTime + iDuration);

	vOmni2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esOmni[tank].g_iHumanAbility == 1)
	{
		g_esOmniPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniHuman", g_esOmniPlayer[tank].g_iAmmoCount, g_esOmni[tank].g_iHumanAmmo);
	}

	if (g_esOmni[tank].g_iOmniMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Omni", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Omni", LANG_SERVER, sTankName);
	}
}

void vOmni2(int tank, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esOmniCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esOmniCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esOmniPlayer[tank].g_iTankType) || (g_esOmniCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esOmniCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esOmniAbility[g_esOmniPlayer[tank].g_iTankType].g_iAccessFlags, g_esOmniPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	g_esOmniPlayer[tank].g_iOmniType = g_esOmniPlayer[tank].g_iTankType;
	vCacheOriginalSettings(tank);

	float flTankPos[3], flTankPos2[3];
	GetClientAbsOrigin(tank, flTankPos);
	float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esOmni[tank].g_flOmniRange;
	int iTypeCount = 0, iTypes[MT_MAXTYPES + 1];
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (MT_IsTankSupported(iTank, MT_CHECK_INGAME) && MT_IsCustomTankSupported(iTank) && iTank != tank)
		{
			GetClientAbsOrigin(iTank, flTankPos2);
			if (GetVectorDistance(flTankPos, flTankPos2) <= flRange && g_esOmniCache[iTank].g_iOmniAbility == 0)
			{
				iTypes[iTypeCount + 1] = MT_GetTankType(iTank);
				iTypeCount++;
			}
		}
	}

	if (iTypeCount > 0)
	{
		MT_SetTankType(tank, iTypes[MT_GetRandomInt(1, iTypeCount)], !!g_esOmni[tank].g_iOmniMode);
	}
	else
	{
		int iMaxType = MT_GetMaxType();
		iTypeCount = 0;
		for (int iIndex = MT_GetMinType(); iIndex <= iMaxType; iIndex++)
		{
			if (!MT_IsTypeEnabled(iIndex) || !MT_CanTypeSpawn(iIndex) || MT_DoesTypeRequireHumans(iIndex) || g_esOmniPlayer[tank].g_iOmniType == iIndex)
			{
				continue;
			}

			iTypes[iTypeCount + 1] = iIndex;
			iTypeCount++;
		}

		if (iTypeCount > 0)
		{
			MT_SetTankType(tank, iTypes[MT_GetRandomInt(1, iTypeCount)], !!g_esOmni[tank].g_iOmniMode);
		}
	}
}

void vOmniAbility(int tank)
{
	if ((g_esOmniPlayer[tank].g_iCooldown != -1 && g_esOmniPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esOmniCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esOmniCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esOmniPlayer[tank].g_iTankType) || (g_esOmniCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esOmniCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esOmniAbility[g_esOmniPlayer[tank].g_iTankType].g_iAccessFlags, g_esOmniPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (g_esOmniPlayer[tank].g_iAmmoCount < g_esOmniCache[tank].g_iHumanAmmo && g_esOmniCache[tank].g_iHumanAmmo > 0)
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esOmniCache[tank].g_flOmniChance)
		{
			vOmni(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esOmniCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esOmniCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniAmmo");
	}
}

void vOmniCopyStats2(int oldTank, int newTank)
{
	g_esOmniPlayer[newTank].g_iCooldown = g_esOmniPlayer[oldTank].g_iCooldown;
	g_esOmniPlayer[newTank].g_iAmmoCount = g_esOmniPlayer[oldTank].g_iAmmoCount;
	g_esOmniPlayer[newTank].g_iOmniType = g_esOmniPlayer[oldTank].g_iOmniType;
	g_esOmni[newTank].g_flOmniChance = g_esOmni[oldTank].g_flOmniChance;
	g_esOmni[newTank].g_flOmniRange = g_esOmni[oldTank].g_flOmniRange;
	g_esOmni[newTank].g_iAccessFlags = g_esOmni[oldTank].g_iAccessFlags;
	g_esOmni[newTank].g_iHumanAbility = g_esOmni[oldTank].g_iHumanAbility;
	g_esOmni[newTank].g_iHumanAmmo = g_esOmni[oldTank].g_iHumanAmmo;
	g_esOmni[newTank].g_iHumanCooldown = g_esOmni[oldTank].g_iHumanCooldown;
	g_esOmni[newTank].g_iHumanDuration = g_esOmni[oldTank].g_iHumanDuration;
	g_esOmni[newTank].g_iHumanMode = g_esOmni[oldTank].g_iHumanMode;
	g_esOmni[newTank].g_iOmniAbility = g_esOmni[oldTank].g_iOmniAbility;
	g_esOmni[newTank].g_iOmniDuration = g_esOmni[oldTank].g_iOmniDuration;
	g_esOmni[newTank].g_iOmniMessage = g_esOmni[oldTank].g_iOmniMessage;
	g_esOmni[newTank].g_iOmniMode = g_esOmni[oldTank].g_iOmniMode;
	g_esOmni[newTank].g_iRequiresHumans = g_esOmni[oldTank].g_iRequiresHumans;
}

void vRemoveOmni(int tank)
{
	g_esOmniPlayer[tank].g_bActivated = false;
	g_esOmniPlayer[tank].g_iAmmoCount = 0;
	g_esOmniPlayer[tank].g_iCooldown = -1;
	g_esOmniPlayer[tank].g_iDuration = -1;
	g_esOmniPlayer[tank].g_iOmniType = 0;
}

void vOmniReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveOmni(iPlayer);
		}
	}
}

void vOmniReset2(int tank)
{
	g_esOmniPlayer[tank].g_bActivated = false;
	g_esOmniPlayer[tank].g_iDuration = -1;

	MT_SetTankType(tank, g_esOmniPlayer[tank].g_iOmniType, !!g_esOmni[tank].g_iOmniMode);
	g_esOmniPlayer[tank].g_iOmniType = 0;

	if (g_esOmni[tank].g_iOmniMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Omni2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Omni2", LANG_SERVER, sTankName);
	}
}

void vOmniReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esOmniAbility[g_esOmniPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esOmni[tank].g_iOmniCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esOmni[tank].g_iHumanAbility == 1 && g_esOmniPlayer[tank].g_iAmmoCount < g_esOmni[tank].g_iHumanAmmo && g_esOmni[tank].g_iHumanAmmo > 0) ? g_esOmni[tank].g_iHumanCooldown : iCooldown;
	g_esOmniPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esOmniPlayer[tank].g_iCooldown != -1 && g_esOmniPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "OmniHuman5", (g_esOmniPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerOmniCombo(Handle timer, DataPack pack)
{
	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esOmniAbility[g_esOmniPlayer[iTank].g_iTankType].g_iAccessFlags, g_esOmniPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esOmniPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esOmniCache[iTank].g_iOmniAbility == 0 || g_esOmniPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vOmni(iTank, iPos);

	return Plugin_Continue;
}