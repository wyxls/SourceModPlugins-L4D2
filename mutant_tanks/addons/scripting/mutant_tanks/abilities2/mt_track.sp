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

#define MT_TRACK_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_TRACK_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Track Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank throws heat-seeking rocks that will track down the nearest survivors.",
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
			strcopy(error, err_max, "\"[MT] Track Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_TRACK_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_TRACK_SECTION "trackability"
#define MT_TRACK_SECTION2 "track ability"
#define MT_TRACK_SECTION3 "track_ability"
#define MT_TRACK_SECTION4 "track"

#define MT_MENU_TRACK "Track Ability"

enum struct esTrackPlayer
{
	bool g_bActivated;
	bool g_bRainbowColor;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flTrackChance;
	float g_flTrackSpeed;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iRock;
	int g_iTankType;
	int g_iTrackAbility;
	int g_iTrackCooldown;
	int g_iTrackGlow;
	int g_iTrackMessage;
	int g_iTrackMode;
}

esTrackPlayer g_esTrackPlayer[MAXPLAYERS + 1];

enum struct esTrackAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flTrackChance;
	float g_flTrackSpeed;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iTrackAbility;
	int g_iTrackCooldown;
	int g_iTrackGlow;
	int g_iTrackMessage;
	int g_iTrackMode;
}

esTrackAbility g_esTrackAbility[MT_MAXTYPES + 1];

enum struct esTrackCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flTrackChance;
	float g_flTrackSpeed;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iRequiresHumans;
	int g_iTrackAbility;
	int g_iTrackCooldown;
	int g_iTrackGlow;
	int g_iTrackMessage;
	int g_iTrackMode;
}

esTrackCache g_esTrackCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_track", cmdTrackInfo, "View information about the Track ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vTrackMapStart()
#else
public void OnMapStart()
#endif
{
	vTrackReset();
}

#if defined MT_ABILITIES_MAIN2
void vTrackClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveTrack(client);
}

#if defined MT_ABILITIES_MAIN2
void vTrackClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveTrack(client);
}

#if defined MT_ABILITIES_MAIN2
void vTrackMapEnd()
#else
public void OnMapEnd()
#endif
{
	vTrackReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdTrackInfo(int client, int args)
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
		case false: vTrackMenu(client, MT_TRACK_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vTrackMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_TRACK_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iTrackMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Track Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iTrackMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esTrackCache[param1].g_iTrackAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esTrackCache[param1].g_iHumanAmmo - g_esTrackPlayer[param1].g_iAmmoCount), g_esTrackCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons4");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esTrackCache[param1].g_iHumanAbility == 1) ? g_esTrackCache[param1].g_iHumanCooldown : g_esTrackCache[param1].g_iTrackCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "TrackDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esTrackCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vTrackMenu(param1, MT_TRACK_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pTrack = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "TrackMenu", param1);
			pTrack.SetTitle(sMenuTitle);
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
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN2
void vTrackDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_TRACK, MT_MENU_TRACK);
}

#if defined MT_ABILITIES_MAIN2
void vTrackMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_TRACK, false))
	{
		vTrackMenu(client, MT_TRACK_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vTrackMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_TRACK, false))
	{
		FormatEx(buffer, size, "%T", "TrackMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vTrackPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_TRACK);
}

#if defined MT_ABILITIES_MAIN2
void vTrackAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_TRACK_SECTION);
	list2.PushString(MT_TRACK_SECTION2);
	list3.PushString(MT_TRACK_SECTION3);
	list4.PushString(MT_TRACK_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vTrackCombineAbilities(int tank, int type, const float random, const char[] combo, int weapon)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esTrackCache[tank].g_iHumanAbility != 2)
	{
		g_esTrackAbility[g_esTrackPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esTrackAbility[g_esTrackPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_TRACK_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_TRACK_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_TRACK_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_TRACK_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_ROCKTHROW && g_esTrackCache[tank].g_iTrackAbility == 1 && g_esTrackCache[tank].g_iComboAbility == 1 && bIsValidEntity(weapon))
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_TRACK_SECTION, false) || StrEqual(sSubset[iPos], MT_TRACK_SECTION2, false) || StrEqual(sSubset[iPos], MT_TRACK_SECTION3, false) || StrEqual(sSubset[iPos], MT_TRACK_SECTION4, false))
				{
					g_esTrackAbility[g_esTrackPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						vTrack(tank, weapon);
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vTrackConfigsLoad(int mode)
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
				g_esTrackAbility[iIndex].g_iAccessFlags = 0;
				g_esTrackAbility[iIndex].g_iImmunityFlags = 0;
				g_esTrackAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esTrackAbility[iIndex].g_iComboAbility = 0;
				g_esTrackAbility[iIndex].g_iComboPosition = -1;
				g_esTrackAbility[iIndex].g_iHumanAbility = 0;
				g_esTrackAbility[iIndex].g_iHumanAmmo = 5;
				g_esTrackAbility[iIndex].g_iHumanCooldown = 0;
				g_esTrackAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esTrackAbility[iIndex].g_iRequiresHumans = 1;
				g_esTrackAbility[iIndex].g_iTrackAbility = 0;
				g_esTrackAbility[iIndex].g_iTrackMessage = 0;
				g_esTrackAbility[iIndex].g_flTrackChance = 33.3;
				g_esTrackAbility[iIndex].g_iTrackCooldown = 0;
				g_esTrackAbility[iIndex].g_iTrackGlow = 1;
				g_esTrackAbility[iIndex].g_iTrackMode = 1;
				g_esTrackAbility[iIndex].g_flTrackSpeed = 500.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esTrackPlayer[iPlayer].g_iAccessFlags = 0;
					g_esTrackPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esTrackPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esTrackPlayer[iPlayer].g_iComboAbility = 0;
					g_esTrackPlayer[iPlayer].g_iHumanAbility = 0;
					g_esTrackPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esTrackPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esTrackPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esTrackPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esTrackPlayer[iPlayer].g_iTrackAbility = 0;
					g_esTrackPlayer[iPlayer].g_iTrackMessage = 0;
					g_esTrackPlayer[iPlayer].g_flTrackChance = 0.0;
					g_esTrackPlayer[iPlayer].g_iTrackCooldown = 0;
					g_esTrackPlayer[iPlayer].g_iTrackGlow = 0;
					g_esTrackPlayer[iPlayer].g_iTrackMode = 0;
					g_esTrackPlayer[iPlayer].g_flTrackSpeed = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vTrackConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esTrackPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esTrackPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esTrackPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esTrackPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esTrackPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esTrackPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esTrackPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esTrackPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esTrackPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esTrackPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esTrackPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esTrackPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esTrackPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esTrackPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esTrackPlayer[admin].g_iTrackAbility = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esTrackPlayer[admin].g_iTrackAbility, value, 0, 1);
		g_esTrackPlayer[admin].g_iTrackMessage = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esTrackPlayer[admin].g_iTrackMessage, value, 0, 1);
		g_esTrackPlayer[admin].g_flTrackChance = flGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackChance", "Track Chance", "Track_Chance", "chance", g_esTrackPlayer[admin].g_flTrackChance, value, 0.0, 100.0);
		g_esTrackPlayer[admin].g_iTrackCooldown = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackCooldown", "Track Cooldown", "Track_Cooldown", "cooldown", g_esTrackPlayer[admin].g_iTrackCooldown, value, 0, 99999);
		g_esTrackPlayer[admin].g_iTrackGlow = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackGlow", "Track Glow", "Track_Glow", "glow", g_esTrackPlayer[admin].g_iTrackGlow, value, 0, 1);
		g_esTrackPlayer[admin].g_iTrackMode = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackMode", "Track Mode", "Track_Mode", "mode", g_esTrackPlayer[admin].g_iTrackMode, value, 0, 1);
		g_esTrackPlayer[admin].g_flTrackSpeed = flGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackSpeed", "Track Speed", "Track_Speed", "speed", g_esTrackPlayer[admin].g_flTrackSpeed, value, 0.1, 99999.0);
		g_esTrackPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esTrackPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esTrackAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esTrackAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esTrackAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esTrackAbility[type].g_iComboAbility, value, 0, 1);
		g_esTrackAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esTrackAbility[type].g_iHumanAbility, value, 0, 2);
		g_esTrackAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esTrackAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esTrackAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esTrackAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esTrackAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esTrackAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esTrackAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esTrackAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esTrackAbility[type].g_iTrackAbility = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esTrackAbility[type].g_iTrackAbility, value, 0, 1);
		g_esTrackAbility[type].g_iTrackMessage = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esTrackAbility[type].g_iTrackMessage, value, 0, 1);
		g_esTrackAbility[type].g_flTrackChance = flGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackChance", "Track Chance", "Track_Chance", "chance", g_esTrackAbility[type].g_flTrackChance, value, 0.0, 100.0);
		g_esTrackAbility[type].g_iTrackCooldown = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackCooldown", "Track Cooldown", "Track_Cooldown", "cooldown", g_esTrackAbility[type].g_iTrackCooldown, value, 0, 99999);
		g_esTrackAbility[type].g_iTrackGlow = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackGlow", "Track Glow", "Track_Glow", "glow", g_esTrackAbility[type].g_iTrackGlow, value, 0, 1);
		g_esTrackAbility[type].g_iTrackMode = iGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackMode", "Track Mode", "Track_Mode", "mode", g_esTrackAbility[type].g_iTrackMode, value, 0, 1);
		g_esTrackAbility[type].g_flTrackSpeed = flGetKeyValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "TrackSpeed", "Track Speed", "Track_Speed", "speed", g_esTrackAbility[type].g_flTrackSpeed, value, 0.1, 99999.0);
		g_esTrackAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esTrackAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_TRACK_SECTION, MT_TRACK_SECTION2, MT_TRACK_SECTION3, MT_TRACK_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vTrackSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esTrackCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_flCloseAreasOnly, g_esTrackAbility[type].g_flCloseAreasOnly);
	g_esTrackCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iComboAbility, g_esTrackAbility[type].g_iComboAbility);
	g_esTrackCache[tank].g_flTrackChance = flGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_flTrackChance, g_esTrackAbility[type].g_flTrackChance);
	g_esTrackCache[tank].g_flTrackSpeed = flGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_flTrackSpeed, g_esTrackAbility[type].g_flTrackSpeed);
	g_esTrackCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iHumanAbility, g_esTrackAbility[type].g_iHumanAbility);
	g_esTrackCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iHumanAmmo, g_esTrackAbility[type].g_iHumanAmmo);
	g_esTrackCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iHumanCooldown, g_esTrackAbility[type].g_iHumanCooldown);
	g_esTrackCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_flOpenAreasOnly, g_esTrackAbility[type].g_flOpenAreasOnly);
	g_esTrackCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iRequiresHumans, g_esTrackAbility[type].g_iRequiresHumans);
	g_esTrackCache[tank].g_iTrackAbility = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iTrackAbility, g_esTrackAbility[type].g_iTrackAbility);
	g_esTrackCache[tank].g_iTrackCooldown = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iTrackCooldown, g_esTrackAbility[type].g_iTrackCooldown);
	g_esTrackCache[tank].g_iTrackGlow = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iTrackGlow, g_esTrackAbility[type].g_iTrackGlow);
	g_esTrackCache[tank].g_iTrackMessage = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iTrackMessage, g_esTrackAbility[type].g_iTrackMessage);
	g_esTrackCache[tank].g_iTrackMode = iGetSettingValue(apply, bHuman, g_esTrackPlayer[tank].g_iTrackMode, g_esTrackAbility[type].g_iTrackMode);
	g_esTrackPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vTrackCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vTrackCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveTrack(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vTrackEventFired(Event event, const char[] name)
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
			vTrackCopyStats2(iBot, iTank);
			vRemoveTrack(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vTrackCopyStats2(iTank, iBot);
			vRemoveTrack(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveTrack(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vTrackReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vTrackButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esTrackCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esTrackCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esTrackPlayer[tank].g_iTankType) || (g_esTrackCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esTrackCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esTrackAbility[g_esTrackPlayer[tank].g_iTankType].g_iAccessFlags, g_esTrackPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SPECIAL_KEY) && g_esTrackCache[tank].g_iTrackAbility == 1 && g_esTrackCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esTrackPlayer[tank].g_iCooldown != -1 && g_esTrackPlayer[tank].g_iCooldown > iTime;
			if (!g_esTrackPlayer[tank].g_bActivated && !bRecharging)
			{
				switch (g_esTrackPlayer[tank].g_iAmmoCount < g_esTrackCache[tank].g_iHumanAmmo && g_esTrackCache[tank].g_iHumanAmmo > 0)
				{
					case true:
					{
						g_esTrackPlayer[tank].g_bActivated = true;
						g_esTrackPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "TrackHuman", g_esTrackPlayer[tank].g_iAmmoCount, g_esTrackCache[tank].g_iHumanAmmo);
					}
					case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "TrackAmmo");
				}
			}
			else if (g_esTrackPlayer[tank].g_bActivated)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "TrackHuman2");
			}
			else if (bRecharging)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "TrackHuman3", (g_esTrackPlayer[tank].g_iCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vTrackChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveTrack(tank);
}

#if defined MT_ABILITIES_MAIN2
void vTrackRockBreak(int rock)
#else
public void MT_OnRockBreak(int tank, int rock)
#endif
{
	vSetTrackGlow(rock, 0, 0, 0, 0, 0);
}

#if defined MT_ABILITIES_MAIN2
void vTrackRockThrow(int tank, int rock)
#else
public void MT_OnRockThrow(int tank, int rock)
#endif
{
	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esTrackCache[tank].g_iTrackAbility == 1 && g_esTrackCache[tank].g_iComboAbility == 0 && MT_GetRandomFloat(0.1, 100.0) <= g_esTrackCache[tank].g_flTrackChance)
	{
		if (bIsAreaNarrow(tank, g_esTrackCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esTrackCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esTrackPlayer[tank].g_iTankType) || (g_esTrackCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esTrackCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esTrackAbility[g_esTrackPlayer[tank].g_iTankType].g_iAccessFlags, g_esTrackPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		vTrack(tank, rock);
	}
}

void vSetTrackGlow(int rock, int color, int flashing, int min, int max, int type)
{
	if (!g_bSecondGame)
	{
		return;
	}

	SetEntProp(rock, Prop_Send, "m_glowColorOverride", color);
	SetEntProp(rock, Prop_Send, "m_bFlashing", flashing);
	SetEntProp(rock, Prop_Send, "m_nGlowRangeMin", min);
	SetEntProp(rock, Prop_Send, "m_nGlowRange", max);
	SetEntProp(rock, Prop_Send, "m_iGlowType", type);
}

void vTrack(int tank, int rock)
{
	if (g_esTrackPlayer[tank].g_iCooldown != -1 && g_esTrackPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	if ((!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esTrackCache[tank].g_iHumanAbility != 1) && !g_esTrackPlayer[tank].g_bActivated)
	{
		g_esTrackPlayer[tank].g_bActivated = true;
	}

	DataPack dpTrack;
	CreateDataTimer(0.5, tTimerTrack, dpTrack, TIMER_FLAG_NO_MAPCHANGE);
	dpTrack.WriteCell(EntIndexToEntRef(rock));
	dpTrack.WriteCell(GetClientUserId(tank));
	dpTrack.WriteCell(g_esTrackPlayer[tank].g_iTankType);

	if (g_esTrackCache[tank].g_iTrackMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Track", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Track", LANG_SERVER, sTankName);
	}
}

void vTrackThink(int rock)
{
	int iTank = GetEntPropEnt(rock, Prop_Data, "m_hThrower");
	if (bIsValidClient(iTank))
	{
		if (bIsAreaNarrow(iTank, g_esTrackCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esTrackCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esTrackPlayer[iTank].g_iTankType) || (g_esTrackCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esTrackCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esTrackAbility[g_esTrackPlayer[iTank].g_iTankType].g_iAccessFlags, g_esTrackPlayer[iTank].g_iAccessFlags)))
		{
			return;
		}

		switch (g_esTrackCache[iTank].g_iTrackMode)
		{
			case 0:
			{
				float flPos[3], flVelocity[3];
				GetEntPropVector(rock, Prop_Data, "m_vecOrigin", flPos);
				GetEntPropVector(rock, Prop_Data, "m_vecVelocity", flVelocity);

				float flVector = GetVectorLength(flVelocity);
				if (flVector < 100.0)
				{
					return;
				}

				NormalizeVector(flVelocity, flVelocity);

				int iTarget = iGetRockTarget(flPos, flVelocity, iTank);
				if (bIsSurvivor(iTarget))
				{
					float flPos2[3], flVelocity2[3];
					GetClientEyePosition(iTarget, flPos2);
					GetEntPropVector(iTarget, Prop_Data, "m_vecVelocity", flVelocity2);
					if (!bIsVisiblePosition(flPos, flPos2, rock, 4) || GetVectorDistance(flPos, flPos2) > 500.0)
					{
						return;
					}

					SetEntityGravity(rock, 0.01);

					float flDirection[3], flVelocity3[3];
					SubtractVectors(flPos2, flPos, flDirection);
					NormalizeVector(flDirection, flDirection);

					ScaleVector(flDirection, 0.5);
					AddVectors(flVelocity, flDirection, flVelocity3);

					NormalizeVector(flVelocity3, flVelocity3);
					ScaleVector(flVelocity3, flVector);

					TeleportEntity(rock, .velocity = flVelocity3);
				}
			}
			case 1:
			{
				float flPos[3], flVelocity[3];
				GetEntPropVector(rock, Prop_Data, "m_vecOrigin", flPos);
				GetEntPropVector(rock, Prop_Data, "m_vecVelocity", flVelocity);

				if (GetVectorLength(flVelocity) < 50.0)
				{
					return;
				}

				NormalizeVector(flVelocity, flVelocity);

				int iTarget = iGetRockTarget(flPos, flVelocity, iTank);
				float flVelocity2[3], flVector[3], flAngles[3], flDistance = 1000.0;
				bool bVisible = false;
				flVector[0] = flVector[1] = flVector[2] = 0.0;

				if (bIsSurvivor(iTarget))
				{
					float flPos2[3];
					GetClientEyePosition(iTarget, flPos2);
					flDistance = GetVectorDistance(flPos, flPos2);
					bVisible = bIsVisiblePosition(flPos, flPos2, rock, 1);

					GetEntPropVector(iTarget, Prop_Data, "m_vecVelocity", flVelocity2);
					AddVectors(flPos2, flVelocity2, flPos2);
					MakeVectorFromPoints(flPos, flPos2, flVector);
				}

				GetVectorAngles(flVelocity, flAngles);

				float flLeft[3], flRight[3], flUp[3], flDown[3], flFront[3], flVector1[3], flVector2[3], flVector3[3], flVector4[3],
					flVector5[3], flVector6[3], flVector7[3], flVector8[3], flVector9, flFactor1 = 0.2, flFactor2 = 0.5, flBase = 1500.0;
				flFront[0] = flFront[1] = flFront[2] = 0.0;

				if (bVisible)
				{
					flBase = 80.0;

					float flFront2 = flGetDistance(flPos, flAngles, 0.0, 0.0, flFront, rock, 3),
						flDown2 = flGetDistance(flPos, flAngles, 90.0, 0.0, flDown, rock, 3),
						flUp2 = flGetDistance(flPos, flAngles, -90.0, 0.0, flUp, rock, 3),
						flLeft2 = flGetDistance(flPos, flAngles, 0.0, 90.0, flLeft, rock, 3),
						flRight2 = flGetDistance(flPos, flAngles, 0.0, -90.0, flRight, rock, 3),
						flDistance2 = flGetDistance(flPos, flAngles, 30.0, 0.0, flVector1, rock, 3),
						flDistance3 = flGetDistance(flPos, flAngles, 30.0, 45.0, flVector2, rock, 3),
						flDistance4 = flGetDistance(flPos, flAngles, 0.0, 45.0, flVector3, rock, 3),
						flDistance5 = flGetDistance(flPos, flAngles, -30.0, 45.0, flVector4, rock, 3),
						flDistance6 = flGetDistance(flPos, flAngles, -30.0, 0.0, flVector5, rock, 3),
						flDistance7 = flGetDistance(flPos, flAngles, -30.0, -45.0, flVector6, rock, 3),
						flDistance8 = flGetDistance(flPos, flAngles, 0.0, -45.0, flVector7, rock, 3),
						flDistance9 = flGetDistance(flPos, flAngles, 30.0, -45.0, flVector8, rock, 3);

					NormalizeVector(flFront, flFront);
					NormalizeVector(flUp, flUp);
					NormalizeVector(flDown, flDown);
					NormalizeVector(flLeft, flLeft);
					NormalizeVector(flRight, flRight);
					NormalizeVector(flVector, flVector);
					NormalizeVector(flVector1, flVector1);
					NormalizeVector(flVector2, flVector2);
					NormalizeVector(flVector3, flVector3);
					NormalizeVector(flVector4, flVector4);
					NormalizeVector(flVector5, flVector5);
					NormalizeVector(flVector6, flVector6);
					NormalizeVector(flVector7, flVector7);
					NormalizeVector(flVector8, flVector8);

					if (flFront2 > flBase)
					{
						flFront2 = flBase;
					}

					if (flUp2 > flBase)
					{
						flUp2 = flBase;
					}

					if (flDown2 > flBase)
					{
						flDown2 = flBase;
					}

					if (flLeft2 > flBase)
					{
						flLeft2 = flBase;
					}

					if (flRight2 > flBase)
					{
						flRight2 = flBase;
					}

					if (flDistance2 > flBase)
					{
						flDistance2 = flBase;
					}

					if (flDistance3 > flBase)
					{
						flDistance3 = flBase;
					}

					if (flDistance4 > flBase)
					{
						flDistance4 = flBase;
					}

					if (flDistance5 > flBase)
					{
						flDistance5 = flBase;
					}

					if (flDistance6 > flBase)
					{
						flDistance6 = flBase;
					}

					if (flDistance7 > flBase)
					{
						flDistance7 = flBase;
					}

					if (flDistance8 > flBase)
					{
						flDistance8 = flBase;
					}

					if (flDistance9 > flBase)
					{
						flDistance9 = flBase;
					}

					flVector9 =- ((1.0 * flFactor1 * (flBase - flFront2)) / flBase);
					ScaleVector(flFront, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flUp2)) / flBase);
					ScaleVector(flUp, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flDown2)) / flBase);
					ScaleVector(flDown, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flLeft2)) / flBase);
					ScaleVector(flLeft, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flRight2)) / flBase);
					ScaleVector(flRight, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance2)) / flDistance2);
					ScaleVector(flVector1, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance3)) / flDistance3);
					ScaleVector(flVector2, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance4)) / flDistance4);
					ScaleVector(flVector3, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance5)) / flDistance5);
					ScaleVector(flVector4, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance6)) / flDistance6);
					ScaleVector(flVector5, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance7)) / flDistance7);
					ScaleVector(flVector6, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance8)) / flDistance8);
					ScaleVector(flVector7, flVector9);

					flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance9)) / flDistance9);
					ScaleVector(flVector8, flVector9);

					if (flDistance >= 500.0)
					{
						flDistance = 500.0;
					}

					flVector9 = ((1.0 * flFactor2 * (1000.0 - flDistance)) / 500.0);
					ScaleVector(flVector, flVector9);

					AddVectors(flFront, flUp, flFront);
					AddVectors(flFront, flDown, flFront);
					AddVectors(flFront, flLeft, flFront);
					AddVectors(flFront, flRight, flFront);
					AddVectors(flFront, flVector1, flFront);
					AddVectors(flFront, flVector2, flFront);
					AddVectors(flFront, flVector3, flFront);
					AddVectors(flFront, flVector4, flFront);
					AddVectors(flFront, flVector5, flFront);
					AddVectors(flFront, flVector6, flFront);
					AddVectors(flFront, flVector7, flFront);
					AddVectors(flFront, flVector8, flFront);
					AddVectors(flFront, flVector, flFront);

					NormalizeVector(flFront, flFront);
				}

				float flVelocity3[3], flAngles2 = flGetAngle(flFront, flVelocity);
				ScaleVector(flFront, flAngles2);
				AddVectors(flVelocity, flFront, flVelocity3);
				NormalizeVector(flVelocity3, flVelocity3);

				ScaleVector(flVelocity3, g_esTrackCache[iTank].g_flTrackSpeed);

				SetEntityGravity(rock, 0.01);
				TeleportEntity(rock, .velocity = flVelocity3);

				if (g_esTrackCache[iTank].g_iTrackGlow == 1)
				{
					int iGlowColor[4];
					MT_GetTankColors(iTank, 2, iGlowColor[0], iGlowColor[1], iGlowColor[2], iGlowColor[3]);

					switch (iGlowColor[0] == -2 && iGlowColor[1] == -2 && iGlowColor[2] == -2)
					{
						case true:
						{
							g_esTrackPlayer[iTank].g_iRock = EntIndexToEntRef(rock);

							if (!g_esTrackPlayer[iTank].g_bRainbowColor)
							{
								g_esTrackPlayer[iTank].g_bRainbowColor = SDKHookEx(iTank, SDKHook_PreThinkPost, OnTrackPreThinkPost);
							}
						}
						case false: vSetTrackGlow(rock, iGetRGBColor(iGlowColor[0], iGlowColor[1], iGlowColor[2]), !!MT_IsGlowFlashing(iTank), MT_GetGlowRange(iTank, false), MT_GetGlowRange(iTank, true), ((MT_GetGlowType(iTank) == 1) ? 3 : 2));
					}
				}
			}
		}
	}
}

void OnTrackPreThinkPost(int tank)
{
	if (!g_bSecondGame || !MT_IsTankSupported(tank) || !MT_IsCustomTankSupported(tank) || !g_esTrackPlayer[tank].g_bRainbowColor)
	{
		g_esTrackPlayer[tank].g_bRainbowColor = false;

		SDKUnhook(tank, SDKHook_PreThinkPost, OnTrackPreThinkPost);

		return;
	}

	int iRock = EntRefToEntIndex(g_esTrackPlayer[tank].g_iRock);
	if (iRock == INVALID_ENT_REFERENCE || !bIsValidEntity(iRock))
	{
		g_esTrackPlayer[tank].g_bRainbowColor = false;
		g_esTrackPlayer[tank].g_iRock = INVALID_ENT_REFERENCE;

		SDKUnhook(tank, SDKHook_PreThinkPost, OnTrackPreThinkPost);

		return;
	}

	bool bHook = false;
	int iColor[3];
	iColor[0] = RoundToNearest((Cosine((GetGameTime() * 1.0) + tank) * 127.5) + 127.5);
	iColor[1] = RoundToNearest((Cosine((GetGameTime() * 1.0) + tank + 2) * 127.5) + 127.5);
	iColor[2] = RoundToNearest((Cosine((GetGameTime() * 1.0) + tank + 4) * 127.5) + 127.5);

	int iTempColor[4];
	MT_GetTankColors(tank, 2, iTempColor[0], iTempColor[1], iTempColor[2], iTempColor[3]);
	if (iTempColor[0] == -2 && iTempColor[1] == -2 && iTempColor[2] == -2 && g_esTrackCache[tank].g_iTrackGlow == 1)
	{
		bHook = true;

		vSetTrackGlow(iRock, iGetRGBColor(iColor[0], iColor[1], iColor[2]), !!MT_IsGlowFlashing(tank), MT_GetGlowRange(tank, false), MT_GetGlowRange(tank, true), ((MT_GetGlowType(tank) == 1) ? 3 : 2));
	}

	if (!bHook)
	{
		g_esTrackPlayer[tank].g_bRainbowColor = false;

		SDKUnhook(tank, SDKHook_PreThinkPost, OnTrackPreThinkPost);
	}
}

void OnTrackThink(int rock)
{
	switch (bIsValidEntity(rock))
	{
		case true: vTrackThink(rock);
		case false: SDKUnhook(rock, SDKHook_Think, OnTrackThink);
	}
}

void vTrackCopyStats2(int oldTank, int newTank)
{
	g_esTrackPlayer[newTank].g_iAmmoCount = g_esTrackPlayer[oldTank].g_iAmmoCount;
	g_esTrackPlayer[newTank].g_iCooldown = g_esTrackPlayer[oldTank].g_iCooldown;
}

void vRemoveTrack(int tank)
{
	g_esTrackPlayer[tank].g_bActivated = false;
	g_esTrackPlayer[tank].g_bRainbowColor = false;
	g_esTrackPlayer[tank].g_iAmmoCount = 0;
	g_esTrackPlayer[tank].g_iCooldown = -1;
	g_esTrackPlayer[tank].g_iRock = INVALID_ENT_REFERENCE;
}

void vTrackReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveTrack(iPlayer);
		}
	}
}

int iGetRockTarget(float pos[3], float angles[3], int tank)
{
	float flMin = 4.0, flPos[3], flAngle;
	int iTarget = 0;
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			if (MT_IsAdminImmune(iSurvivor, tank) || bIsAdminImmune(iSurvivor, g_esTrackPlayer[tank].g_iTankType, g_esTrackAbility[g_esTrackPlayer[tank].g_iTankType].g_iImmunityFlags, g_esTrackPlayer[iSurvivor].g_iImmunityFlags))
			{
				continue;
			}

			GetClientEyePosition(iSurvivor, flPos);
			MakeVectorFromPoints(pos, flPos, flPos);
			flAngle = flGetAngle(angles, flPos);
			if (flAngle <= flMin)
			{
				flMin = flAngle;
				iTarget = iSurvivor;
			}
		}
	}

	return iTarget;
}

Action tTimerTrack(Handle timer, DataPack pack)
{
	pack.Reset();

	int iRock = EntRefToEntIndex(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || iRock == INVALID_ENT_REFERENCE || !bIsValidEntity(iRock))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esTrackCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esTrackCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esTrackPlayer[iTank].g_iTankType) || (g_esTrackCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esTrackCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esTrackAbility[g_esTrackPlayer[iTank].g_iTankType].g_iAccessFlags, g_esTrackPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esTrackPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esTrackPlayer[iTank].g_iTankType || g_esTrackCache[iTank].g_iTrackAbility == 0 || !g_esTrackPlayer[iTank].g_bActivated)
	{
		g_esTrackPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	SDKUnhook(iRock, SDKHook_Think, OnTrackThink);
	SDKHook(iRock, SDKHook_Think, OnTrackThink);

	int iTime = GetTime();
	if (g_esTrackPlayer[iTank].g_iCooldown == -1 || g_esTrackPlayer[iTank].g_iCooldown < iTime)
	{
		g_esTrackPlayer[iTank].g_bActivated = false;

		int iPos = g_esTrackAbility[g_esTrackPlayer[iTank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 2, iPos)) : g_esTrackCache[iTank].g_iTrackCooldown;
		iCooldown = (bIsTank(iTank, MT_CHECK_FAKECLIENT) && g_esTrackCache[iTank].g_iHumanAbility == 1 && g_esTrackPlayer[iTank].g_iAmmoCount < g_esTrackCache[iTank].g_iHumanAmmo && g_esTrackCache[iTank].g_iHumanAmmo > 0) ? g_esTrackCache[iTank].g_iHumanCooldown : iCooldown;
		g_esTrackPlayer[iTank].g_iCooldown = (iTime + iCooldown);
		if (g_esTrackPlayer[iTank].g_iCooldown != -1 && g_esTrackPlayer[iTank].g_iCooldown > iTime)
		{
			MT_PrintToChat(iTank, "%s %t", MT_TAG3, "TrackHuman4", (g_esTrackPlayer[iTank].g_iCooldown - iTime));
		}
	}

	return Plugin_Continue;
}