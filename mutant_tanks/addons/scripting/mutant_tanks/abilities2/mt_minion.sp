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

#define MT_MINION_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_MINION_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Minion Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank spawns minions.",
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
			strcopy(error, err_max, "\"[MT] Minion Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_MINION_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_MINION_SECTION "minionability"
#define MT_MINION_SECTION2 "minion ability"
#define MT_MINION_SECTION3 "minion_ability"
#define MT_MINION_SECTION4 "minion"

#define MT_MENU_MINION "Minion Ability"

enum struct esMinionPlayer
{
	bool g_bMinion;

	float g_flCloseAreasOnly;
	float g_flMinionChance;
	float g_flMinionLifetime;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iCount;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iMinionAbility;
	int g_iMinionAmount;
	int g_iMinionCooldown;
	int g_iMinionMessage;
	int g_iMinionRemove;
	int g_iMinionReplace;
	int g_iMinionTypes;
	int g_iOwner;
	int g_iRequiresHumans;
	int g_iTankType;
}

esMinionPlayer g_esMinionPlayer[MAXPLAYERS + 1];

enum struct esMinionAbility
{
	float g_flCloseAreasOnly;
	float g_flMinionChance;
	float g_flMinionLifetime;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iMinionAbility;
	int g_iMinionAmount;
	int g_iMinionCooldown;
	int g_iMinionMessage;
	int g_iMinionRemove;
	int g_iMinionReplace;
	int g_iMinionTypes;
	int g_iRequiresHumans;
}

esMinionAbility g_esMinionAbility[MT_MAXTYPES + 1];

enum struct esMinionCache
{
	float g_flCloseAreasOnly;
	float g_flMinionChance;
	float g_flMinionLifetime;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iMinionAbility;
	int g_iMinionAmount;
	int g_iMinionCooldown;
	int g_iMinionMessage;
	int g_iMinionRemove;
	int g_iMinionReplace;
	int g_iMinionTypes;
	int g_iRequiresHumans;
}

esMinionCache g_esMinionCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_minion", cmdMinionInfo, "View information about the Minion ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vMinionMapStart()
#else
public void OnMapStart()
#endif
{
	vMinionReset();
}

#if defined MT_ABILITIES_MAIN2
void vMinionClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveMinion(client);
}

#if defined MT_ABILITIES_MAIN2
void vMinionClientDisconnect(int client)
#else
public void OnClientDisconnect(int client)
#endif
{
	if (bIsSpecialInfected(client) && !bIsValidClient(client, MT_CHECK_FAKECLIENT) && g_esMinionPlayer[client].g_bMinion)
	{
		g_esMinionPlayer[g_esMinionPlayer[client].g_iOwner].g_iCount--;
		g_esMinionPlayer[client].g_iOwner = 0;

		vRemoveMinion(client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveMinion(client);
}

#if defined MT_ABILITIES_MAIN2
void vMinionMapEnd()
#else
public void OnMapEnd()
#endif
{
	vMinionReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdMinionInfo(int client, int args)
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
		case false: vMinionMenu(client, MT_MINION_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vMinionMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_MINION_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iMinionMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Minion Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iMinionMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esMinionCache[param1].g_iMinionAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esMinionCache[param1].g_iHumanAmmo - g_esMinionPlayer[param1].g_iAmmoCount), g_esMinionCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons3");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esMinionCache[param1].g_iHumanAbility == 1) ? g_esMinionCache[param1].g_iHumanCooldown : g_esMinionCache[param1].g_iMinionCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "MinionDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esMinionCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vMinionMenu(param1, MT_MINION_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pMinion = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "MinionMenu", param1);
			pMinion.SetTitle(sMenuTitle);
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
void vMinionDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_MINION, MT_MENU_MINION);
}

#if defined MT_ABILITIES_MAIN2
void vMinionMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_MINION, false))
	{
		vMinionMenu(client, MT_MINION_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_MINION, false))
	{
		FormatEx(buffer, size, "%T", "MinionMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_MINION);
}

#if defined MT_ABILITIES_MAIN2
void vMinionAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_MINION_SECTION);
	list2.PushString(MT_MINION_SECTION2);
	list3.PushString(MT_MINION_SECTION3);
	list4.PushString(MT_MINION_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vMinionCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMinionCache[tank].g_iHumanAbility != 2)
	{
		g_esMinionAbility[g_esMinionPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esMinionAbility[g_esMinionPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_MINION_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_MINION_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_MINION_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_MINION_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esMinionCache[tank].g_iMinionAbility == 1 && g_esMinionCache[tank].g_iComboAbility == 1)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_MINION_SECTION, false) || StrEqual(sSubset[iPos], MT_MINION_SECTION2, false) || StrEqual(sSubset[iPos], MT_MINION_SECTION3, false) || StrEqual(sSubset[iPos], MT_MINION_SECTION4, false))
				{
					g_esMinionAbility[g_esMinionPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vMinion(tank);
							default: CreateTimer(flDelay, tTimerMinionCombo, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionConfigsLoad(int mode)
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
				g_esMinionAbility[iIndex].g_iAccessFlags = 0;
				g_esMinionAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esMinionAbility[iIndex].g_iComboAbility = 0;
				g_esMinionAbility[iIndex].g_iComboPosition = -1;
				g_esMinionAbility[iIndex].g_iHumanAbility = 0;
				g_esMinionAbility[iIndex].g_iHumanAmmo = 5;
				g_esMinionAbility[iIndex].g_iHumanCooldown = 0;
				g_esMinionAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esMinionAbility[iIndex].g_iRequiresHumans = 0;
				g_esMinionAbility[iIndex].g_iMinionAbility = 0;
				g_esMinionAbility[iIndex].g_iMinionMessage = 0;
				g_esMinionAbility[iIndex].g_iMinionAmount = 5;
				g_esMinionAbility[iIndex].g_flMinionChance = 33.3;
				g_esMinionAbility[iIndex].g_iMinionCooldown = 0;
				g_esMinionAbility[iIndex].g_flMinionLifetime = 0.0;
				g_esMinionAbility[iIndex].g_iMinionRemove = 1;
				g_esMinionAbility[iIndex].g_iMinionReplace = 1;
				g_esMinionAbility[iIndex].g_iMinionTypes = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esMinionPlayer[iPlayer].g_iAccessFlags = 0;
					g_esMinionPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esMinionPlayer[iPlayer].g_iComboAbility = 0;
					g_esMinionPlayer[iPlayer].g_iHumanAbility = 0;
					g_esMinionPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esMinionPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esMinionPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esMinionPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esMinionPlayer[iPlayer].g_iMinionAbility = 0;
					g_esMinionPlayer[iPlayer].g_iMinionMessage = 0;
					g_esMinionPlayer[iPlayer].g_iMinionAmount = 0;
					g_esMinionPlayer[iPlayer].g_flMinionChance = 0.0;
					g_esMinionPlayer[iPlayer].g_iMinionCooldown = 0;
					g_esMinionPlayer[iPlayer].g_flMinionLifetime = 0.0;
					g_esMinionPlayer[iPlayer].g_iMinionRemove = 0;
					g_esMinionPlayer[iPlayer].g_iMinionReplace = 0;
					g_esMinionPlayer[iPlayer].g_iMinionTypes = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esMinionPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esMinionPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esMinionPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esMinionPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esMinionPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esMinionPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esMinionPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esMinionPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esMinionPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esMinionPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esMinionPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esMinionPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esMinionPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esMinionPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esMinionPlayer[admin].g_iMinionAbility = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esMinionPlayer[admin].g_iMinionAbility, value, 0, 1);
		g_esMinionPlayer[admin].g_iMinionMessage = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esMinionPlayer[admin].g_iMinionMessage, value, 0, 1);
		g_esMinionPlayer[admin].g_iMinionAmount = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionAmount", "Minion Amount", "Minion_Amount", "amount", g_esMinionPlayer[admin].g_iMinionAmount, value, 1, 15);
		g_esMinionPlayer[admin].g_flMinionChance = flGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionChance", "Minion Chance", "Minion_Chance", "chance", g_esMinionPlayer[admin].g_flMinionChance, value, 0.0, 100.0);
		g_esMinionPlayer[admin].g_iMinionCooldown = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionCooldown", "Minion Cooldown", "Minion_Cooldown", "cooldown", g_esMinionPlayer[admin].g_iMinionCooldown, value, 0, 99999);
		g_esMinionPlayer[admin].g_flMinionLifetime = flGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionLifetime", "Minion Lifetime", "Minion_Lifetime", "lifetime", g_esMinionPlayer[admin].g_flMinionLifetime, value, 0.0, 99999.0);
		g_esMinionPlayer[admin].g_iMinionRemove = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionRemove", "Minion Remove", "Minion_Remove", "remove", g_esMinionPlayer[admin].g_iMinionRemove, value, 0, 1);
		g_esMinionPlayer[admin].g_iMinionReplace = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionReplace", "Minion Replace", "Minion_Replace", "replace", g_esMinionPlayer[admin].g_iMinionReplace, value, 0, 1);
		g_esMinionPlayer[admin].g_iMinionTypes = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionTypes", "Minion Types", "Minion_Types", "types", g_esMinionPlayer[admin].g_iMinionTypes, value, 0, 63);
		g_esMinionPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esMinionAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esMinionAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esMinionAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esMinionAbility[type].g_iComboAbility, value, 0, 1);
		g_esMinionAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esMinionAbility[type].g_iHumanAbility, value, 0, 2);
		g_esMinionAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esMinionAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esMinionAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esMinionAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esMinionAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esMinionAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esMinionAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esMinionAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esMinionAbility[type].g_iMinionAbility = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esMinionAbility[type].g_iMinionAbility, value, 0, 1);
		g_esMinionAbility[type].g_iMinionMessage = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esMinionAbility[type].g_iMinionMessage, value, 0, 1);
		g_esMinionAbility[type].g_iMinionAmount = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionAmount", "Minion Amount", "Minion_Amount", "amount", g_esMinionAbility[type].g_iMinionAmount, value, 1, 15);
		g_esMinionAbility[type].g_flMinionChance = flGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionChance", "Minion Chance", "Minion_Chance", "chance", g_esMinionAbility[type].g_flMinionChance, value, 0.0, 100.0);
		g_esMinionAbility[type].g_iMinionCooldown = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionCooldown", "Minion Cooldown", "Minion_Cooldown", "cooldown", g_esMinionAbility[type].g_iMinionCooldown, value, 0, 99999);
		g_esMinionAbility[type].g_flMinionLifetime = flGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionLifetime", "Minion Lifetime", "Minion_Lifetime", "lifetime", g_esMinionAbility[type].g_flMinionLifetime, value, 0.0, 99999.0);
		g_esMinionAbility[type].g_iMinionRemove = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionRemove", "Minion Remove", "Minion_Remove", "remove", g_esMinionAbility[type].g_iMinionRemove, value, 0, 1);
		g_esMinionAbility[type].g_iMinionReplace = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionReplace", "Minion Replace", "Minion_Replace", "replace", g_esMinionAbility[type].g_iMinionReplace, value, 0, 1);
		g_esMinionAbility[type].g_iMinionTypes = iGetKeyValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "MinionTypes", "Minion Types", "Minion_Types", "types", g_esMinionAbility[type].g_iMinionTypes, value, 0, 63);
		g_esMinionAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_MINION_SECTION, MT_MINION_SECTION2, MT_MINION_SECTION3, MT_MINION_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esMinionCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_flCloseAreasOnly, g_esMinionAbility[type].g_flCloseAreasOnly);
	g_esMinionCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iComboAbility, g_esMinionAbility[type].g_iComboAbility);
	g_esMinionCache[tank].g_flMinionChance = flGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_flMinionChance, g_esMinionAbility[type].g_flMinionChance);
	g_esMinionCache[tank].g_flMinionLifetime = flGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_flMinionLifetime, g_esMinionAbility[type].g_flMinionLifetime);
	g_esMinionCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iHumanAbility, g_esMinionAbility[type].g_iHumanAbility);
	g_esMinionCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iHumanAmmo, g_esMinionAbility[type].g_iHumanAmmo);
	g_esMinionCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iHumanCooldown, g_esMinionAbility[type].g_iHumanCooldown);
	g_esMinionCache[tank].g_iMinionAbility = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iMinionAbility, g_esMinionAbility[type].g_iMinionAbility);
	g_esMinionCache[tank].g_iMinionAmount = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iMinionAmount, g_esMinionAbility[type].g_iMinionAmount);
	g_esMinionCache[tank].g_iMinionCooldown = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iMinionCooldown, g_esMinionAbility[type].g_iMinionCooldown);
	g_esMinionCache[tank].g_iMinionMessage = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iMinionMessage, g_esMinionAbility[type].g_iMinionMessage);
	g_esMinionCache[tank].g_iMinionRemove = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iMinionRemove, g_esMinionAbility[type].g_iMinionRemove);
	g_esMinionCache[tank].g_iMinionReplace = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iMinionReplace, g_esMinionAbility[type].g_iMinionReplace);
	g_esMinionCache[tank].g_iMinionTypes = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iMinionTypes, g_esMinionAbility[type].g_iMinionTypes);
	g_esMinionCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_flOpenAreasOnly, g_esMinionAbility[type].g_flOpenAreasOnly);
	g_esMinionCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esMinionPlayer[tank].g_iRequiresHumans, g_esMinionAbility[type].g_iRequiresHumans);
	g_esMinionPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vMinionCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vMinionCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveMinion(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vMinionPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iMinion = 1; iMinion <= MaxClients; iMinion++)
	{
		if ((bIsTank(iMinion, MT_CHECK_INGAME|MT_CHECK_ALIVE) || bIsSpecialInfected(iMinion, MT_CHECK_INGAME|MT_CHECK_ALIVE)) && g_esMinionPlayer[iMinion].g_bMinion)
		{
			ForcePlayerSuicide(iMinion);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionEventFired(Event event, const char[] name)
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
			vMinionCopyStats2(iBot, iTank);
			vRemoveMinion(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vMinionCopyStats2(iTank, iBot);
			vRemoveMinion(iTank);
		}
	}
	else if (StrEqual(name, "player_death"))
	{
		int iInfectedId = event.GetInt("userid"), iInfected = GetClientOfUserId(iInfectedId);
		if (MT_IsTankSupported(iInfected, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveMinions(iInfected);
			vRemoveMinion(iInfected);
		}
		else if (bIsSpecialInfected(iInfected) && g_esMinionPlayer[iInfected].g_bMinion)
		{
			for (int iOwner = 1; iOwner <= MaxClients; iOwner++)
			{
				if (MT_IsTankSupported(iOwner, MT_CHECK_INGAME|MT_CHECK_ALIVE) && MT_IsCustomTankSupported(iOwner) && g_esMinionPlayer[iInfected].g_iOwner == iOwner)
				{
					g_esMinionPlayer[iInfected].g_bMinion = false;
					g_esMinionPlayer[iInfected].g_iOwner = 0;

					if (g_esMinionCache[iOwner].g_iMinionAbility == 1)
					{
						switch (g_esMinionPlayer[iOwner].g_iCount)
						{
							case 0, 1: g_esMinionPlayer[iOwner].g_iCount = (g_esMinionCache[iOwner].g_iMinionReplace == 1) ? 0 : g_esMinionPlayer[iOwner].g_iCount;
							default:
							{
								if (g_esMinionCache[iOwner].g_iMinionReplace == 1)
								{
									g_esMinionPlayer[iOwner].g_iCount--;
								}

								MT_PrintToChat(iOwner, "%s %t", MT_TAG3, "MinionHuman4");
							}
						}
					}

					break;
				}
			}
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vMinionReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMinionAbility[g_esMinionPlayer[tank].g_iTankType].g_iAccessFlags, g_esMinionPlayer[tank].g_iAccessFlags)) || g_esMinionCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esMinionCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esMinionCache[tank].g_iMinionAbility == 1 && g_esMinionCache[tank].g_iComboAbility == 0)
	{
		vMinionAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esMinionCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esMinionCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMinionPlayer[tank].g_iTankType) || (g_esMinionCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMinionCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMinionAbility[g_esMinionPlayer[tank].g_iTankType].g_iAccessFlags, g_esMinionPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SPECIAL_KEY) && g_esMinionCache[tank].g_iMinionAbility == 1 && g_esMinionCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esMinionPlayer[tank].g_iCooldown == -1 || g_esMinionPlayer[tank].g_iCooldown < iTime)
			{
				case true: vMinionAbility(tank);
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "MinionHuman3", (g_esMinionPlayer[tank].g_iCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMinionChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveMinions(tank);
	vRemoveMinion(tank);
}

void vMinion(int tank)
{
	int iTime = GetTime();
	if (g_esMinionPlayer[tank].g_iCooldown != -1 && g_esMinionPlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	if (g_esMinionPlayer[tank].g_iCount < g_esMinionCache[tank].g_iMinionAmount)
	{
		float flHitPos[3], flPos[3], flAngles[3], flVector[3];
		GetClientEyePosition(tank, flPos);
		GetClientEyeAngles(tank, flAngles);
		flAngles[0] = -25.0;

		GetAngleVectors(flAngles, flAngles, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(flAngles, flAngles);
		ScaleVector(flAngles, -1.0);
		vCopyVector(flAngles, flVector);
		GetVectorAngles(flAngles, flAngles);

		Handle hTrace = TR_TraceRayFilterEx(flPos, flAngles, MASK_SOLID, RayType_Infinite, bTraceRayDontHitSelf, tank);
		if (hTrace != null)
		{
			if (TR_DidHit(hTrace))
			{
				TR_GetEndPosition(flHitPos, hTrace);
				NormalizeVector(flVector, flVector);
				ScaleVector(flVector, -40.0);
				AddVectors(flHitPos, flVector, flHitPos);
				if (40.0 < GetVectorDistance(flHitPos, flPos) < 200.0)
				{
					bool[] bExists = new bool[MaxClients + 1];
					for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
					{
						bExists[iPlayer] = false;
						if (bIsSpecialInfected(iPlayer, MT_CHECK_INGAME))
						{
							bExists[iPlayer] = true;
						}
					}

					int iTypeCount = 0, iTypes[6], iFlag = 0;
					for (int iBit = 0; iBit < (sizeof iTypes); iBit++)
					{
						iFlag = (1 << iBit);
						if (!(g_esMinionCache[tank].g_iMinionTypes & iFlag))
						{
							continue;
						}

						iTypes[iTypeCount] = iFlag;
						iTypeCount++;
					}

					switch (iTypes[MT_GetRandomInt(0, (iTypeCount - 1))])
					{
						case 1: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", "smoker");
						case 2: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", "boomer");
						case 4: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", "hunter");
						case 8: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", g_bSecondGame ? "spitter" : "boomer");
						case 16: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", g_bSecondGame ? "jockey" : "hunter");
						case 32: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", g_bSecondGame ? "charger" : "smoker");
						default:
						{
							switch (MT_GetRandomInt(1, (sizeof iTypes)))
							{
								case 1: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", "smoker");
								case 2: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", "boomer");
								case 3: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", "hunter");
								case 4: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", g_bSecondGame ? "spitter" : "boomer");
								case 5: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", g_bSecondGame ? "jockey" : "hunter");
								case 6: vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", g_bSecondGame ? "charger" : "smoker");
							}
						}
					}

					int iSpecial = 0;
					for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
					{
						if (bIsSpecialInfected(iPlayer, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !bExists[iPlayer])
						{
							iSpecial = iPlayer;

							break;
						}
					}

					if (bIsSpecialInfected(iSpecial))
					{
						TeleportEntity(iSpecial, flHitPos);

						g_esMinionPlayer[iSpecial].g_bMinion = true;
						g_esMinionPlayer[iSpecial].g_iOwner = tank;
						g_esMinionPlayer[tank].g_iCount++;

						if (g_esMinionCache[tank].g_flMinionLifetime > 0.0)
						{
							CreateTimer(g_esMinionCache[tank].g_flMinionLifetime, tTimerKillMinion, GetClientUserId(iSpecial), TIMER_FLAG_NO_MAPCHANGE);
						}

						if (g_esMinionPlayer[tank].g_iCooldown == -1 || g_esMinionPlayer[tank].g_iCooldown < iTime)
						{
							if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMinionCache[tank].g_iHumanAbility == 1)
							{
								g_esMinionPlayer[tank].g_iAmmoCount++;

								MT_PrintToChat(tank, "%s %t", MT_TAG3, "MinionHuman", g_esMinionPlayer[tank].g_iAmmoCount, g_esMinionCache[tank].g_iHumanAmmo);
							}

							int iPos = g_esMinionAbility[g_esMinionPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esMinionCache[tank].g_iMinionCooldown;
							iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMinionCache[tank].g_iHumanAbility == 1 && g_esMinionPlayer[tank].g_iAmmoCount < g_esMinionCache[tank].g_iHumanAmmo && g_esMinionCache[tank].g_iHumanAmmo > 0) ? g_esMinionCache[tank].g_iHumanCooldown : iCooldown;
							g_esMinionPlayer[tank].g_iCooldown = (iTime + iCooldown);
							if (g_esMinionPlayer[tank].g_iCooldown != -1 && g_esMinionPlayer[tank].g_iCooldown > iTime)
							{
								MT_PrintToChat(tank, "%s %t", MT_TAG3, "MinionHuman5", (g_esMinionPlayer[tank].g_iCooldown - iTime));
							}
						}

						if (g_esMinionCache[tank].g_iMinionMessage == 1)
						{
							char sTankName[33];
							MT_GetTankName(tank, sTankName);
							MT_PrintToChatAll("%s %t", MT_TAG2, "Minion", sTankName);
							MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Minion", LANG_SERVER, sTankName);
						}
					}
				}
			}

			delete hTrace;
		}
	}
}

void vMinionAbility(int tank)
{
	if ((g_esMinionPlayer[tank].g_iCooldown != -1 && g_esMinionPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esMinionCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esMinionCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMinionPlayer[tank].g_iTankType) || (g_esMinionCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMinionCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMinionAbility[g_esMinionPlayer[tank].g_iTankType].g_iAccessFlags, g_esMinionPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (g_esMinionPlayer[tank].g_iCount < g_esMinionCache[tank].g_iMinionAmount && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esMinionPlayer[tank].g_iAmmoCount < g_esMinionCache[tank].g_iHumanAmmo && g_esMinionCache[tank].g_iHumanAmmo > 0)))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esMinionCache[tank].g_flMinionChance)
		{
			vMinion(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMinionCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "MinionHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMinionCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "MinionAmmo");
	}
}

void vMinionCopyStats2(int oldTank, int newTank)
{
	g_esMinionPlayer[newTank].g_iAmmoCount = g_esMinionPlayer[oldTank].g_iAmmoCount;
	g_esMinionPlayer[newTank].g_iCooldown = g_esMinionPlayer[oldTank].g_iCooldown;
	g_esMinionPlayer[newTank].g_iCount = g_esMinionPlayer[oldTank].g_iCount;
}

void vRemoveMinion(int tank)
{
	g_esMinionPlayer[tank].g_iAmmoCount = 0;
	g_esMinionPlayer[tank].g_iCooldown = -1;
	g_esMinionPlayer[tank].g_iCount = 0;
}

void vRemoveMinions(int tank)
{
	if (g_esMinionCache[tank].g_iMinionRemove == 1)
	{
		for (int iMinion = 1; iMinion <= MaxClients; iMinion++)
		{
			if (g_esMinionPlayer[iMinion].g_iOwner == tank)
			{
				g_esMinionPlayer[iMinion].g_iOwner = 0;

				if (g_esMinionPlayer[iMinion].g_bMinion && bIsValidClient(iMinion, MT_CHECK_INGAME|MT_CHECK_ALIVE))
				{
					ForcePlayerSuicide(iMinion);
				}
			}
		}
	}
}

void vMinionReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveMinion(iPlayer);

			g_esMinionPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

Action tTimerMinionCombo(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esMinionAbility[g_esMinionPlayer[iTank].g_iTankType].g_iAccessFlags, g_esMinionPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esMinionPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esMinionCache[iTank].g_iMinionAbility == 0)
	{
		return Plugin_Stop;
	}

	vMinion(iTank);

	return Plugin_Continue;
}

Action tTimerKillMinion(Handle timer, int userid)
{
	int iSpecial = GetClientOfUserId(userid);
	if (!bIsSpecialInfected(iSpecial) || !g_esMinionPlayer[iSpecial].g_bMinion)
	{
		return Plugin_Stop;
	}

	ForcePlayerSuicide(iSpecial);

	return Plugin_Continue;
}