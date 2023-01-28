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

#define MT_UNDEAD_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_UNDEAD_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Undead Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank cannot die.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Undead Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_UNDEAD_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_UNDEAD_SECTION "undeadability"
#define MT_UNDEAD_SECTION2 "undead ability"
#define MT_UNDEAD_SECTION3 "undead_ability"
#define MT_UNDEAD_SECTION4 "undead"

#define MT_MENU_UNDEAD "Undead Ability"

enum struct esUndeadPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flUndeadChance;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iCount;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
	int g_iUndeadAbility;
	int g_iUndeadAmount;
	int g_iUndeadCooldown;
	int g_iUndeadMessage;
}

esUndeadPlayer g_esUndeadPlayer[MAXPLAYERS + 1];

enum struct esUndeadAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flUndeadChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iRequiresHumans;
	int g_iUndeadAbility;
	int g_iUndeadAmount;
	int g_iUndeadCooldown;
	int g_iUndeadMessage;
}

esUndeadAbility g_esUndeadAbility[MT_MAXTYPES + 1];

enum struct esUndeadCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flUndeadChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iRequiresHumans;
	int g_iUndeadAbility;
	int g_iUndeadAmount;
	int g_iUndeadCooldown;
	int g_iUndeadMessage;
}

esUndeadCache g_esUndeadCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_undead", cmdUndeadInfo, "View information about the Undead ability.");

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

#if defined MT_ABILITIES_MAIN2
void vUndeadMapStart()
#else
public void OnMapStart()
#endif
{
	vUndeadReset();
}

#if defined MT_ABILITIES_MAIN2
void vUndeadClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnUndeadTakeDamage);
	vRemoveUndead(client);
}

#if defined MT_ABILITIES_MAIN2
void vUndeadClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveUndead(client);
}

#if defined MT_ABILITIES_MAIN2
void vUndeadMapEnd()
#else
public void OnMapEnd()
#endif
{
	vUndeadReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdUndeadInfo(int client, int args)
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
		case false: vUndeadMenu(client, MT_UNDEAD_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vUndeadMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_UNDEAD_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iUndeadMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Undead Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iUndeadMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esUndeadCache[param1].g_iUndeadAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esUndeadCache[param1].g_iHumanAmmo - g_esUndeadPlayer[param1].g_iAmmoCount), g_esUndeadCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esUndeadCache[param1].g_iHumanAbility == 1) ? g_esUndeadCache[param1].g_iHumanCooldown : g_esUndeadCache[param1].g_iUndeadCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "UndeadDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esUndeadCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vUndeadMenu(param1, MT_UNDEAD_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pUndead = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "UndeadMenu", param1);
			pUndead.SetTitle(sMenuTitle);
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
void vUndeadDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_UNDEAD, MT_MENU_UNDEAD);
}

#if defined MT_ABILITIES_MAIN2
void vUndeadMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_UNDEAD, false))
	{
		vUndeadMenu(client, MT_UNDEAD_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vUndeadMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_UNDEAD, false))
	{
		FormatEx(buffer, size, "%T", "UndeadMenu2", client);
	}
}

Action OnUndeadTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && !bIsPlayerIncapacitated(victim) && g_esUndeadPlayer[victim].g_bActivated)
		{
			if (bIsAreaNarrow(victim, g_esUndeadCache[victim].g_flOpenAreasOnly) || bIsAreaWide(victim, g_esUndeadCache[victim].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esUndeadPlayer[victim].g_iTankType) || (g_esUndeadCache[victim].g_iRequiresHumans > 0 && iGetHumanCount() < g_esUndeadCache[victim].g_iRequiresHumans) || (!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esUndeadAbility[g_esUndeadPlayer[victim].g_iTankType].g_iAccessFlags, g_esUndeadPlayer[victim].g_iAccessFlags)))
			{
				return Plugin_Continue;
			}

			if ((GetEntProp(victim, Prop_Data, "m_iHealth") - RoundToNearest(damage)) <= 0)
			{
				g_esUndeadPlayer[victim].g_bActivated = false;

				int iMaxHealth = MT_TankMaxHealth(victim, 1),
					iNewHealth = MT_TankMaxHealth(victim, 2);
				MT_TankMaxHealth(victim, 3, (iMaxHealth + iNewHealth));
				SetEntProp(victim, Prop_Data, "m_iHealth", iNewHealth);

				int iTime = GetTime();
				if (g_esUndeadPlayer[victim].g_iCooldown == -1 || g_esUndeadPlayer[victim].g_iCooldown < iTime)
				{
					int iPos = g_esUndeadAbility[g_esUndeadPlayer[victim].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(victim, 2, iPos)) : g_esUndeadCache[victim].g_iUndeadCooldown;
					iCooldown = (bIsTank(victim, MT_CHECK_FAKECLIENT) && g_esUndeadCache[victim].g_iHumanAbility == 1 && g_esUndeadPlayer[victim].g_iAmmoCount < g_esUndeadCache[victim].g_iHumanAmmo && g_esUndeadCache[victim].g_iHumanAmmo > 0) ? g_esUndeadCache[victim].g_iHumanCooldown : iCooldown;
					g_esUndeadPlayer[victim].g_iCooldown = (iTime + iCooldown);
					if (g_esUndeadPlayer[victim].g_iCooldown != -1 && g_esUndeadPlayer[victim].g_iCooldown > iTime)
					{
						MT_PrintToChat(victim, "%s %t", MT_TAG3, "UndeadHuman5", (g_esUndeadPlayer[victim].g_iCooldown - iTime));
					}
				}

				if (g_esUndeadCache[victim].g_iUndeadMessage == 1)
				{
					char sTankName[33];
					MT_GetTankName(victim, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Undead2", sTankName);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Undead2", LANG_SERVER, sTankName);
				}

				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vUndeadPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_UNDEAD);
}

#if defined MT_ABILITIES_MAIN2
void vUndeadAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_UNDEAD_SECTION);
	list2.PushString(MT_UNDEAD_SECTION2);
	list3.PushString(MT_UNDEAD_SECTION3);
	list4.PushString(MT_UNDEAD_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vUndeadCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esUndeadCache[tank].g_iHumanAbility != 2)
	{
		g_esUndeadAbility[g_esUndeadPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esUndeadAbility[g_esUndeadPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_UNDEAD_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_UNDEAD_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_UNDEAD_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_UNDEAD_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esUndeadCache[tank].g_iUndeadAbility == 1 && g_esUndeadCache[tank].g_iComboAbility == 1 && !g_esUndeadPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_UNDEAD_SECTION, false) || StrEqual(sSubset[iPos], MT_UNDEAD_SECTION2, false) || StrEqual(sSubset[iPos], MT_UNDEAD_SECTION3, false) || StrEqual(sSubset[iPos], MT_UNDEAD_SECTION4, false))
				{
					g_esUndeadAbility[g_esUndeadPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vUndead(tank);
							default: CreateTimer(flDelay, tTimerUndeadCombo, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vUndeadConfigsLoad(int mode)
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
				g_esUndeadAbility[iIndex].g_iAccessFlags = 0;
				g_esUndeadAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esUndeadAbility[iIndex].g_iComboAbility = 0;
				g_esUndeadAbility[iIndex].g_iComboPosition = -1;
				g_esUndeadAbility[iIndex].g_iHumanAbility = 0;
				g_esUndeadAbility[iIndex].g_iHumanAmmo = 5;
				g_esUndeadAbility[iIndex].g_iHumanCooldown = 0;
				g_esUndeadAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esUndeadAbility[iIndex].g_iRequiresHumans = 0;
				g_esUndeadAbility[iIndex].g_iUndeadAbility = 0;
				g_esUndeadAbility[iIndex].g_iUndeadMessage = 0;
				g_esUndeadAbility[iIndex].g_iUndeadAmount = 1;
				g_esUndeadAbility[iIndex].g_flUndeadChance = 33.3;
				g_esUndeadAbility[iIndex].g_iUndeadCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esUndeadPlayer[iPlayer].g_iAccessFlags = 0;
					g_esUndeadPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esUndeadPlayer[iPlayer].g_iComboAbility = 0;
					g_esUndeadPlayer[iPlayer].g_iHumanAbility = 0;
					g_esUndeadPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esUndeadPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esUndeadPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esUndeadPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esUndeadPlayer[iPlayer].g_iUndeadAbility = 0;
					g_esUndeadPlayer[iPlayer].g_iUndeadMessage = 0;
					g_esUndeadPlayer[iPlayer].g_iUndeadAmount = 0;
					g_esUndeadPlayer[iPlayer].g_flUndeadChance = 0.0;
					g_esUndeadPlayer[iPlayer].g_iUndeadCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vUndeadConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esUndeadPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esUndeadPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esUndeadPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esUndeadPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esUndeadPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esUndeadPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esUndeadPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esUndeadPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esUndeadPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esUndeadPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esUndeadPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esUndeadPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esUndeadPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esUndeadPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esUndeadPlayer[admin].g_iUndeadAbility = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esUndeadPlayer[admin].g_iUndeadAbility, value, 0, 1);
		g_esUndeadPlayer[admin].g_iUndeadMessage = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esUndeadPlayer[admin].g_iUndeadMessage, value, 0, 1);
		g_esUndeadPlayer[admin].g_iUndeadAmount = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "UndeadAmount", "Undead Amount", "Undead_Amount", "amount", g_esUndeadPlayer[admin].g_iUndeadAmount, value, 1, 99999);
		g_esUndeadPlayer[admin].g_flUndeadChance = flGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "UndeadChance", "Undead Chance", "Undead_Chance", "chance", g_esUndeadPlayer[admin].g_flUndeadChance, value, 0.0, 100.0);
		g_esUndeadPlayer[admin].g_iUndeadCooldown = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "UndeadCooldown", "Undead Cooldown", "Undead_Cooldown", "cooldown", g_esUndeadPlayer[admin].g_iUndeadCooldown, value, 0, 99999);
		g_esUndeadPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esUndeadAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esUndeadAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esUndeadAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esUndeadAbility[type].g_iComboAbility, value, 0, 1);
		g_esUndeadAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esUndeadAbility[type].g_iHumanAbility, value, 0, 2);
		g_esUndeadAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esUndeadAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esUndeadAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esUndeadAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esUndeadAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esUndeadAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esUndeadAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esUndeadAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esUndeadAbility[type].g_iUndeadAbility = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esUndeadAbility[type].g_iUndeadAbility, value, 0, 1);
		g_esUndeadAbility[type].g_iUndeadMessage = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esUndeadAbility[type].g_iUndeadMessage, value, 0, 1);
		g_esUndeadAbility[type].g_iUndeadAmount = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "UndeadAmount", "Undead Amount", "Undead_Amount", "amount", g_esUndeadAbility[type].g_iUndeadAmount, value, 1, 99999);
		g_esUndeadAbility[type].g_flUndeadChance = flGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "UndeadChance", "Undead Chance", "Undead_Chance", "chance", g_esUndeadAbility[type].g_flUndeadChance, value, 0.0, 100.0);
		g_esUndeadAbility[type].g_iUndeadCooldown = iGetKeyValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "UndeadCooldown", "Undead Cooldown", "Undead_Cooldown", "cooldown", g_esUndeadAbility[type].g_iUndeadCooldown, value, 0, 99999);
		g_esUndeadAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_UNDEAD_SECTION, MT_UNDEAD_SECTION2, MT_UNDEAD_SECTION3, MT_UNDEAD_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vUndeadSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esUndeadCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_flCloseAreasOnly, g_esUndeadAbility[type].g_flCloseAreasOnly);
	g_esUndeadCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_iComboAbility, g_esUndeadAbility[type].g_iComboAbility);
	g_esUndeadCache[tank].g_flUndeadChance = flGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_flUndeadChance, g_esUndeadAbility[type].g_flUndeadChance);
	g_esUndeadCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_iHumanAbility, g_esUndeadAbility[type].g_iHumanAbility);
	g_esUndeadCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_iHumanAmmo, g_esUndeadAbility[type].g_iHumanAmmo);
	g_esUndeadCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_iHumanCooldown, g_esUndeadAbility[type].g_iHumanCooldown);
	g_esUndeadCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_flOpenAreasOnly, g_esUndeadAbility[type].g_flOpenAreasOnly);
	g_esUndeadCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_iRequiresHumans, g_esUndeadAbility[type].g_iRequiresHumans);
	g_esUndeadCache[tank].g_iUndeadAbility = iGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_iUndeadAbility, g_esUndeadAbility[type].g_iUndeadAbility);
	g_esUndeadCache[tank].g_iUndeadAmount = iGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_iUndeadAmount, g_esUndeadAbility[type].g_iUndeadAmount);
	g_esUndeadCache[tank].g_iUndeadCooldown = iGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_iUndeadCooldown, g_esUndeadAbility[type].g_iUndeadCooldown);
	g_esUndeadCache[tank].g_iUndeadMessage = iGetSettingValue(apply, bHuman, g_esUndeadPlayer[tank].g_iUndeadMessage, g_esUndeadAbility[type].g_iUndeadMessage);
	g_esUndeadPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vUndeadCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vUndeadCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveUndead(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vUndeadEventFired(Event event, const char[] name)
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
			vUndeadCopyStats2(iBot, iTank);
			vRemoveUndead(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vUndeadCopyStats2(iTank, iBot);
			vRemoveUndead(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveUndead(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vUndeadReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vUndeadAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esUndeadAbility[g_esUndeadPlayer[tank].g_iTankType].g_iAccessFlags, g_esUndeadPlayer[tank].g_iAccessFlags)) || g_esUndeadCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esUndeadCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esUndeadCache[tank].g_iUndeadAbility == 1 && g_esUndeadCache[tank].g_iComboAbility == 0 && !g_esUndeadPlayer[tank].g_bActivated)
	{
		vUndeadAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vUndeadButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esUndeadCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esUndeadCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esUndeadPlayer[tank].g_iTankType) || (g_esUndeadCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esUndeadCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esUndeadAbility[g_esUndeadPlayer[tank].g_iTankType].g_iAccessFlags, g_esUndeadPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SPECIAL_KEY) && g_esUndeadCache[tank].g_iUndeadAbility == 1 && g_esUndeadCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esUndeadPlayer[tank].g_iCooldown != -1 && g_esUndeadPlayer[tank].g_iCooldown > iTime;
			if (!g_esUndeadPlayer[tank].g_bActivated && !bRecharging)
			{
				vUndeadAbility(tank);
			}
			else if (g_esUndeadPlayer[tank].g_bActivated)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "UndeadHuman3");
			}
			else if (bRecharging)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "UndeadHuman4", (g_esUndeadPlayer[tank].g_iCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vUndeadChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveUndead(tank);
}

void vUndead(int tank)
{
	if (g_esUndeadPlayer[tank].g_iCooldown != -1 && g_esUndeadPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	if (g_esUndeadPlayer[tank].g_iCount < g_esUndeadCache[tank].g_iUndeadAmount)
	{
		g_esUndeadPlayer[tank].g_bActivated = true;
		g_esUndeadPlayer[tank].g_iCount++;

		if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esUndeadCache[tank].g_iHumanAbility == 1)
		{
			g_esUndeadPlayer[tank].g_iAmmoCount++;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "UndeadHuman", g_esUndeadPlayer[tank].g_iAmmoCount, g_esUndeadCache[tank].g_iHumanAmmo);
		}

		if (g_esUndeadCache[tank].g_iUndeadMessage == 1)
		{
			char sTankName[33];
			MT_GetTankName(tank, sTankName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Undead", sTankName);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Undead", LANG_SERVER, sTankName);
		}
	}
}

void vUndeadAbility(int tank)
{
	if ((g_esUndeadPlayer[tank].g_iCooldown != -1 && g_esUndeadPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esUndeadCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esUndeadCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esUndeadPlayer[tank].g_iTankType) || (g_esUndeadCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esUndeadCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esUndeadAbility[g_esUndeadPlayer[tank].g_iTankType].g_iAccessFlags, g_esUndeadPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (g_esUndeadPlayer[tank].g_iCount < g_esUndeadCache[tank].g_iUndeadAmount && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esUndeadPlayer[tank].g_iAmmoCount < g_esUndeadCache[tank].g_iHumanAmmo && g_esUndeadCache[tank].g_iHumanAmmo > 0)))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esUndeadCache[tank].g_flUndeadChance)
		{
			vUndead(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esUndeadCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "UndeadHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esUndeadCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "UndeadAmmo");
	}
}

void vUndeadCopyStats2(int oldTank, int newTank)
{
	g_esUndeadPlayer[newTank].g_bActivated = g_esUndeadPlayer[oldTank].g_bActivated;
	g_esUndeadPlayer[newTank].g_iAmmoCount = g_esUndeadPlayer[oldTank].g_iAmmoCount;
	g_esUndeadPlayer[newTank].g_iCooldown = g_esUndeadPlayer[oldTank].g_iCooldown;
	g_esUndeadPlayer[newTank].g_iCount = g_esUndeadPlayer[oldTank].g_iCount;
}

void vRemoveUndead(int tank)
{
	g_esUndeadPlayer[tank].g_bActivated = false;
	g_esUndeadPlayer[tank].g_iAmmoCount = 0;
	g_esUndeadPlayer[tank].g_iCooldown = -1;
	g_esUndeadPlayer[tank].g_iCount = 0;
}

void vUndeadReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveUndead(iPlayer);
		}
	}
}

Action tTimerUndeadCombo(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esUndeadAbility[g_esUndeadPlayer[iTank].g_iTankType].g_iAccessFlags, g_esUndeadPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esUndeadPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esUndeadCache[iTank].g_iUndeadAbility == 0 || g_esUndeadPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	vUndead(iTank);

	return Plugin_Continue;
}