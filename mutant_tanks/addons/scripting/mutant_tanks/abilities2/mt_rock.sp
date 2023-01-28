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

#define MT_ROCK_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_ROCK_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Rock Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank creates rock showers.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Rock Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_ROCK_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_ROCK_SECTION "rockability"
#define MT_ROCK_SECTION2 "rock ability"
#define MT_ROCK_SECTION3 "rock_ability"
#define MT_ROCK_SECTION4 "rock"

#define MT_MENU_ROCK "Rock Ability"

enum struct esRockPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flRockChance;
	float g_flRockInterval;
	float g_flRockRadius[2];

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
	int g_iLauncher;
	int g_iRequiresHumans;
	int g_iRockAbility;
	int g_iRockCooldown;
	int g_iRockDamage;
	int g_iRockDuration;
	int g_iRockMessage;
	int g_iTankType;
}

esRockPlayer g_esRockPlayer[MAXPLAYERS + 1];

enum struct esRockAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flRockChance;
	float g_flRockInterval;
	float g_flRockRadius[2];

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
	int g_iRockAbility;
	int g_iRockCooldown;
	int g_iRockDamage;
	int g_iRockDuration;
	int g_iRockMessage;
}

esRockAbility g_esRockAbility[MT_MAXTYPES + 1];

enum struct esRockCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flRockChance;
	float g_flRockInterval;
	float g_flRockRadius[2];

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
	int g_iRockAbility;
	int g_iRockCooldown;
	int g_iRockDamage;
	int g_iRockDuration;
	int g_iRockMessage;
}

esRockCache g_esRockCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_rock", cmdRockInfo, "View information about the Rock ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vRockMapStart()
#else
public void OnMapStart()
#endif
{
	vRockReset();
}

#if defined MT_ABILITIES_MAIN2
void vRockClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnRockTakeDamage);
	vRemoveRock(client);
}

#if defined MT_ABILITIES_MAIN2
void vRockClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveRock(client);
}

#if defined MT_ABILITIES_MAIN2
void vRockMapEnd()
#else
public void OnMapEnd()
#endif
{
	vRockReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdRockInfo(int client, int args)
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
		case false: vRockMenu(client, MT_ROCK_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vRockMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_ROCK_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iRockMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Rock Ability Information");
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

int iRockMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esRockCache[param1].g_iRockAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esRockCache[param1].g_iHumanAmmo - g_esRockPlayer[param1].g_iAmmoCount), g_esRockCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esRockCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esRockCache[param1].g_iHumanAbility == 1) ? g_esRockCache[param1].g_iHumanCooldown : g_esRockCache[param1].g_iRockCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "RockDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esRockCache[param1].g_iHumanAbility == 1) ? g_esRockCache[param1].g_iHumanDuration : g_esRockCache[param1].g_iRockDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esRockCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vRockMenu(param1, MT_ROCK_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pRock = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "RockMenu", param1);
			pRock.SetTitle(sMenuTitle);
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
void vRockDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_ROCK, MT_MENU_ROCK);
}

#if defined MT_ABILITIES_MAIN2
void vRockMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_ROCK, false))
	{
		vRockMenu(client, MT_ROCK_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vRockMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_ROCK, false))
	{
		FormatEx(buffer, size, "%T", "RockMenu2", client);
	}
}

Action OnRockTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (StrEqual(sClassname, "tank_rock"))
		{
			int iLauncher = GetEntPropEnt(inflictor, Prop_Data, "m_hOwnerEntity"),
				iThrower = GetEntPropEnt(inflictor, Prop_Data, "m_hThrower");
			if (bIsValidEntity(iLauncher) && bIsTank(iThrower, MT_CHECK_INDEX|MT_CHECK_INGAME))
			{
				int iTank = GetEntPropEnt(iLauncher, Prop_Data, "m_hOwnerEntity");
				if (iThrower == iTank && MT_IsTankSupported(iTank) && MT_IsCustomTankSupported(iTank) && g_esRockCache[iTank].g_iRockAbility == 1 && g_esRockPlayer[iTank].g_iLauncher != INVALID_ENT_REFERENCE && iLauncher == EntRefToEntIndex(g_esRockPlayer[iTank].g_iLauncher) && (MT_HasAdminAccess(iTank) || bHasAdminAccess(iTank, g_esRockAbility[g_esRockPlayer[iTank].g_iTankType].g_iAccessFlags, g_esRockPlayer[iTank].g_iAccessFlags)))
				{
					if (bIsInfected(victim) || (bIsSurvivor(victim) && (MT_IsAdminImmune(victim, iTank) || bIsAdminImmune(victim, g_esRockPlayer[iTank].g_iTankType, g_esRockAbility[g_esRockPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esRockPlayer[victim].g_iImmunityFlags))))
					{
						return Plugin_Handled;
					}

					int iPos = g_esRockAbility[g_esRockPlayer[iTank].g_iTankType].g_iComboPosition;
					float flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : float(g_esRockCache[iTank].g_iRockDamage);
					damage = MT_GetScaledDamage(flDamage);

					return Plugin_Changed;
				}
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vRockPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_ROCK);
}

#if defined MT_ABILITIES_MAIN2
void vRockAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_ROCK_SECTION);
	list2.PushString(MT_ROCK_SECTION2);
	list3.PushString(MT_ROCK_SECTION3);
	list4.PushString(MT_ROCK_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vRockCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRockCache[tank].g_iHumanAbility != 2)
	{
		g_esRockAbility[g_esRockPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esRockAbility[g_esRockPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_ROCK_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_ROCK_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_ROCK_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_ROCK_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esRockCache[tank].g_iRockAbility == 1 && g_esRockCache[tank].g_iComboAbility == 1 && !g_esRockPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_ROCK_SECTION, false) || StrEqual(sSubset[iPos], MT_ROCK_SECTION2, false) || StrEqual(sSubset[iPos], MT_ROCK_SECTION3, false) || StrEqual(sSubset[iPos], MT_ROCK_SECTION4, false))
				{
					g_esRockAbility[g_esRockPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vRock(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerRockCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vRockConfigsLoad(int mode)
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
				g_esRockAbility[iIndex].g_iAccessFlags = 0;
				g_esRockAbility[iIndex].g_iImmunityFlags = 0;
				g_esRockAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esRockAbility[iIndex].g_iComboAbility = 0;
				g_esRockAbility[iIndex].g_iComboPosition = -1;
				g_esRockAbility[iIndex].g_iHumanAbility = 0;
				g_esRockAbility[iIndex].g_iHumanAmmo = 5;
				g_esRockAbility[iIndex].g_iHumanCooldown = 0;
				g_esRockAbility[iIndex].g_iHumanDuration = 5;
				g_esRockAbility[iIndex].g_iHumanMode = 1;
				g_esRockAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esRockAbility[iIndex].g_iRequiresHumans = 1;
				g_esRockAbility[iIndex].g_iRockAbility = 0;
				g_esRockAbility[iIndex].g_iRockMessage = 0;
				g_esRockAbility[iIndex].g_flRockChance = 33.3;
				g_esRockAbility[iIndex].g_iRockCooldown = 0;
				g_esRockAbility[iIndex].g_iRockDamage = 5;
				g_esRockAbility[iIndex].g_iRockDuration = 5;
				g_esRockAbility[iIndex].g_flRockInterval = 0.2;
				g_esRockAbility[iIndex].g_flRockRadius[0] = -1.25;
				g_esRockAbility[iIndex].g_flRockRadius[1] = 1.25;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esRockPlayer[iPlayer].g_iAccessFlags = 0;
					g_esRockPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esRockPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esRockPlayer[iPlayer].g_iComboAbility = 0;
					g_esRockPlayer[iPlayer].g_iHumanAbility = 0;
					g_esRockPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esRockPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esRockPlayer[iPlayer].g_iHumanDuration = 0;
					g_esRockPlayer[iPlayer].g_iHumanMode = 0;
					g_esRockPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esRockPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esRockPlayer[iPlayer].g_iRockAbility = 0;
					g_esRockPlayer[iPlayer].g_iRockMessage = 0;
					g_esRockPlayer[iPlayer].g_flRockChance = 0.0;
					g_esRockPlayer[iPlayer].g_iRockCooldown = 0;
					g_esRockPlayer[iPlayer].g_iRockDamage = 0;
					g_esRockPlayer[iPlayer].g_iRockDuration = 0;
					g_esRockPlayer[iPlayer].g_flRockInterval = 0.0;
					g_esRockPlayer[iPlayer].g_flRockRadius[0] = 0.0;
					g_esRockPlayer[iPlayer].g_flRockRadius[1] = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRockConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esRockPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esRockPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esRockPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esRockPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esRockPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esRockPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esRockPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esRockPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esRockPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esRockPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esRockPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esRockPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esRockPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esRockPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esRockPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esRockPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esRockPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esRockPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esRockPlayer[admin].g_iRockAbility = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esRockPlayer[admin].g_iRockAbility, value, 0, 1);
		g_esRockPlayer[admin].g_iRockMessage = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esRockPlayer[admin].g_iRockMessage, value, 0, 1);
		g_esRockPlayer[admin].g_flRockChance = flGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockChance", "Rock Chance", "Rock_Chance", "chance", g_esRockPlayer[admin].g_flRockChance, value, 0.0, 100.0);
		g_esRockPlayer[admin].g_iRockCooldown = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockCooldown", "Rock Cooldown", "Rock_Cooldown", "cooldown", g_esRockPlayer[admin].g_iRockCooldown, value, 0, 99999);
		g_esRockPlayer[admin].g_iRockDamage = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockDamage", "Rock Damage", "Rock_Damage", "damage", g_esRockPlayer[admin].g_iRockDamage, value, 0, 99999);
		g_esRockPlayer[admin].g_iRockDuration = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockDuration", "Rock Duration", "Rock_Duration", "duration", g_esRockPlayer[admin].g_iRockDuration, value, 0, 99999);
		g_esRockPlayer[admin].g_flRockInterval = flGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockInterval", "Rock Interval", "Rock_Interval", "interval", g_esRockPlayer[admin].g_flRockInterval, value, 0.1, 1.0);
		g_esRockPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esRockPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

		if (StrEqual(subsection, MT_ROCK_SECTION, false) || StrEqual(subsection, MT_ROCK_SECTION2, false) || StrEqual(subsection, MT_ROCK_SECTION3, false) || StrEqual(subsection, MT_ROCK_SECTION4, false))
		{
			if (StrEqual(key, "RockRadius", false) || StrEqual(key, "Rock Radius", false) || StrEqual(key, "Rock_Radius", false) || StrEqual(key, "radius", false))
			{
				char sSet[2][6], sValue[12];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);

				g_esRockPlayer[admin].g_flRockRadius[0] = (sSet[0][0] != '\0') ? flClamp(StringToFloat(sSet[0]), -5.0, 0.0) : g_esRockPlayer[admin].g_flRockRadius[0];
				g_esRockPlayer[admin].g_flRockRadius[1] = (sSet[1][0] != '\0') ? flClamp(StringToFloat(sSet[1]), 0.0, 5.0) : g_esRockPlayer[admin].g_flRockRadius[1];
			}
		}
	}

	if (mode < 3 && type > 0)
	{
		g_esRockAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esRockAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esRockAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esRockAbility[type].g_iComboAbility, value, 0, 1);
		g_esRockAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esRockAbility[type].g_iHumanAbility, value, 0, 2);
		g_esRockAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esRockAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esRockAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esRockAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esRockAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esRockAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esRockAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esRockAbility[type].g_iHumanMode, value, 0, 1);
		g_esRockAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esRockAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esRockAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esRockAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esRockAbility[type].g_iRockAbility = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esRockAbility[type].g_iRockAbility, value, 0, 1);
		g_esRockAbility[type].g_iRockMessage = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esRockAbility[type].g_iRockMessage, value, 0, 1);
		g_esRockAbility[type].g_flRockChance = flGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockChance", "Rock Chance", "Rock_Chance", "chance", g_esRockAbility[type].g_flRockChance, value, 0.0, 100.0);
		g_esRockAbility[type].g_iRockCooldown = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockCooldown", "Rock Cooldown", "Rock_Cooldown", "cooldown", g_esRockAbility[type].g_iRockCooldown, value, 0, 99999);
		g_esRockAbility[type].g_iRockDamage = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockDamage", "Rock Damage", "Rock_Damage", "damage", g_esRockAbility[type].g_iRockDamage, value, 0, 99999);
		g_esRockAbility[type].g_iRockDuration = iGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockDuration", "Rock Duration", "Rock_Duration", "duration", g_esRockAbility[type].g_iRockDuration, value, 0, 99999);
		g_esRockAbility[type].g_flRockInterval = flGetKeyValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "RockInterval", "Rock Interval", "Rock_Interval", "interval", g_esRockAbility[type].g_flRockInterval, value, 0.1, 1.0);
		g_esRockAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esRockAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ROCK_SECTION, MT_ROCK_SECTION2, MT_ROCK_SECTION3, MT_ROCK_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

		if (StrEqual(subsection, MT_ROCK_SECTION, false) || StrEqual(subsection, MT_ROCK_SECTION2, false) || StrEqual(subsection, MT_ROCK_SECTION3, false) || StrEqual(subsection, MT_ROCK_SECTION4, false))
		{
			if (StrEqual(key, "RockRadius", false) || StrEqual(key, "Rock Radius", false) || StrEqual(key, "Rock_Radius", false) || StrEqual(key, "radius", false))
			{
				char sSet[2][6], sValue[12];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);

				g_esRockAbility[type].g_flRockRadius[0] = (sSet[0][0] != '\0') ? flClamp(StringToFloat(sSet[0]), -5.0, 0.0) : g_esRockAbility[type].g_flRockRadius[0];
				g_esRockAbility[type].g_flRockRadius[1] = (sSet[1][0] != '\0') ? flClamp(StringToFloat(sSet[1]), 0.0, 5.0) : g_esRockAbility[type].g_flRockRadius[1];
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRockSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esRockCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_flCloseAreasOnly, g_esRockAbility[type].g_flCloseAreasOnly);
	g_esRockCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iComboAbility, g_esRockAbility[type].g_iComboAbility);
	g_esRockCache[tank].g_flRockChance = flGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_flRockChance, g_esRockAbility[type].g_flRockChance);
	g_esRockCache[tank].g_flRockInterval = flGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_flRockInterval, g_esRockAbility[type].g_flRockInterval);
	g_esRockCache[tank].g_flRockRadius[0] = flGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_flRockRadius[0], g_esRockAbility[type].g_flRockRadius[0]);
	g_esRockCache[tank].g_flRockRadius[1] = flGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_flRockRadius[1], g_esRockAbility[type].g_flRockRadius[1]);
	g_esRockCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iHumanAbility, g_esRockAbility[type].g_iHumanAbility);
	g_esRockCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iHumanAmmo, g_esRockAbility[type].g_iHumanAmmo);
	g_esRockCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iHumanCooldown, g_esRockAbility[type].g_iHumanCooldown);
	g_esRockCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iHumanDuration, g_esRockAbility[type].g_iHumanDuration);
	g_esRockCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iHumanMode, g_esRockAbility[type].g_iHumanMode);
	g_esRockCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_flOpenAreasOnly, g_esRockAbility[type].g_flOpenAreasOnly);
	g_esRockCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iRequiresHumans, g_esRockAbility[type].g_iRequiresHumans);
	g_esRockCache[tank].g_iRockAbility = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iRockAbility, g_esRockAbility[type].g_iRockAbility);
	g_esRockCache[tank].g_iRockCooldown = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iRockCooldown, g_esRockAbility[type].g_iRockCooldown);
	g_esRockCache[tank].g_iRockDamage = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iRockDamage, g_esRockAbility[type].g_iRockDamage);
	g_esRockCache[tank].g_iRockDuration = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iRockDuration, g_esRockAbility[type].g_iRockDuration);
	g_esRockCache[tank].g_iRockMessage = iGetSettingValue(apply, bHuman, g_esRockPlayer[tank].g_iRockMessage, g_esRockAbility[type].g_iRockMessage);
	g_esRockPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vRockCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vRockCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveRock(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vRockEventFired(Event event, const char[] name)
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
			vRockCopyStats2(iBot, iTank);
			vRemoveRock(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vRockCopyStats2(iTank, iBot);
			vRemoveRock(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveRock(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vRockReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vRockAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRockAbility[g_esRockPlayer[tank].g_iTankType].g_iAccessFlags, g_esRockPlayer[tank].g_iAccessFlags)) || g_esRockCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esRockCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esRockCache[tank].g_iRockAbility == 1 && g_esRockCache[tank].g_iComboAbility == 0 && !g_esRockPlayer[tank].g_bActivated)
	{
		vRockAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vRockButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esRockCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esRockCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRockPlayer[tank].g_iTankType) || (g_esRockCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRockCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRockAbility[g_esRockPlayer[tank].g_iTankType].g_iAccessFlags, g_esRockPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esRockCache[tank].g_iRockAbility == 1 && g_esRockCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esRockPlayer[tank].g_iCooldown != -1 && g_esRockPlayer[tank].g_iCooldown > iTime;

			switch (g_esRockCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esRockPlayer[tank].g_bActivated && !bRecharging)
					{
						vRockAbility(tank);
					}
					else if (g_esRockPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockHuman4", (g_esRockPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esRockPlayer[tank].g_iAmmoCount < g_esRockCache[tank].g_iHumanAmmo && g_esRockCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esRockPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esRockPlayer[tank].g_bActivated = true;
							g_esRockPlayer[tank].g_iAmmoCount++;

							vRock2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockHuman", g_esRockPlayer[tank].g_iAmmoCount, g_esRockCache[tank].g_iHumanAmmo);
						}
						else if (g_esRockPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockHuman4", (g_esRockPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRockButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esRockCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esRockCache[tank].g_iHumanMode == 1 && g_esRockPlayer[tank].g_bActivated && (g_esRockPlayer[tank].g_iCooldown == -1 || g_esRockPlayer[tank].g_iCooldown < GetTime()))
		{
			vRockReset2(tank);
			vRockReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRockChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveRock(tank);
}

void vRock(int tank, int pos = -1)
{
	if (g_esRockPlayer[tank].g_iCooldown != -1 && g_esRockPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esRockPlayer[tank].g_bActivated = true;

	vRock2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRockCache[tank].g_iHumanAbility == 1)
	{
		g_esRockPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockHuman", g_esRockPlayer[tank].g_iAmmoCount, g_esRockCache[tank].g_iHumanAmmo);
	}

	if (g_esRockCache[tank].g_iRockMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Rock", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Rock", LANG_SERVER, sTankName);
	}
}

void vRock2(int tank, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esRockCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esRockCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRockPlayer[tank].g_iTankType) || (g_esRockCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRockCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRockAbility[g_esRockPlayer[tank].g_iTankType].g_iAccessFlags, g_esRockPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	char sDamage[11];
	float flDamage = (pos != -1) ? MT_GetCombinationSetting(tank, 3, pos) : float(g_esRockCache[tank].g_iRockDamage);
	IntToString(RoundToNearest(MT_GetScaledDamage(flDamage)), sDamage, sizeof sDamage);

	float flPos[3], flAngles[3];
	GetClientEyePosition(tank, flPos);
	GetClientEyeAngles(tank, flAngles);

	int iLauncher = CreateEntityByName("env_rock_launcher");
	if (bIsValidEntity(iLauncher))
	{
		SetEntPropEnt(iLauncher, Prop_Data, "m_hOwnerEntity", tank);
		TeleportEntity(iLauncher, flPos, flAngles);
		DispatchSpawn(iLauncher);
		DispatchKeyValue(iLauncher, "rockdamageoverride", sDamage);
		iLauncher = EntIndexToEntRef(iLauncher);
		g_esRockPlayer[tank].g_iLauncher = iLauncher;
	}

	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esRockCache[tank].g_flRockInterval;
	DataPack dpRock;
	CreateDataTimer(flInterval, tTimerRock, dpRock, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpRock.WriteCell(iLauncher);
	dpRock.WriteCell(GetClientUserId(tank));
	dpRock.WriteCell(g_esRockPlayer[tank].g_iTankType);
	dpRock.WriteCell(GetTime());
	dpRock.WriteCell(pos);
}

void vRockAbility(int tank)
{
	if ((g_esRockPlayer[tank].g_iCooldown != -1 && g_esRockPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esRockCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esRockCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRockPlayer[tank].g_iTankType) || (g_esRockCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRockCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRockAbility[g_esRockPlayer[tank].g_iTankType].g_iAccessFlags, g_esRockPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esRockPlayer[tank].g_iAmmoCount < g_esRockCache[tank].g_iHumanAmmo && g_esRockCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esRockCache[tank].g_flRockChance)
		{
			vRock(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRockCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRockCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockAmmo");
	}
}

void vRockCopyStats2(int oldTank, int newTank)
{
	g_esRockPlayer[newTank].g_iAmmoCount = g_esRockPlayer[oldTank].g_iAmmoCount;
	g_esRockPlayer[newTank].g_iCooldown = g_esRockPlayer[oldTank].g_iCooldown;
}

void vRemoveRockLauncher(int tank)
{
	if (bIsValidEntRef(g_esRockPlayer[tank].g_iLauncher))
	{
		g_esRockPlayer[tank].g_iLauncher = EntRefToEntIndex(g_esRockPlayer[tank].g_iLauncher);
		if (bIsValidEntity(g_esRockPlayer[tank].g_iLauncher))
		{
			RemoveEntity(g_esRockPlayer[tank].g_iLauncher);
		}
	}

	g_esRockPlayer[tank].g_iLauncher = INVALID_ENT_REFERENCE;
}

void vRemoveRock(int tank)
{
	vRemoveRockLauncher(tank);

	g_esRockPlayer[tank].g_bActivated = false;
	g_esRockPlayer[tank].g_iAmmoCount = 0;
	g_esRockPlayer[tank].g_iCooldown = -1;
}

void vRockReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveRock(iPlayer);
		}
	}
}

void vRockReset2(int tank)
{
	vRemoveRockLauncher(tank);

	g_esRockPlayer[tank].g_bActivated = false;

	if (g_esRockCache[tank].g_iRockMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Rock2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Rock2", LANG_SERVER, sTankName);
	}
}

void vRockReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esRockAbility[g_esRockPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esRockCache[tank].g_iRockCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRockCache[tank].g_iHumanAbility == 1 && g_esRockCache[tank].g_iHumanMode == 0 && g_esRockPlayer[tank].g_iAmmoCount < g_esRockCache[tank].g_iHumanAmmo && g_esRockCache[tank].g_iHumanAmmo > 0) ? g_esRockCache[tank].g_iHumanCooldown : iCooldown;
	g_esRockPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esRockPlayer[tank].g_iCooldown != -1 && g_esRockPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "RockHuman5", (g_esRockPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerRockCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esRockAbility[g_esRockPlayer[iTank].g_iTankType].g_iAccessFlags, g_esRockPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esRockPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esRockCache[iTank].g_iRockAbility == 0 || g_esRockPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vRock(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerRock(Handle timer, DataPack pack)
{
	pack.Reset();

	int iLauncher = EntRefToEntIndex(pack.ReadCell()), iTank = GetClientOfUserId(pack.ReadCell());
	if (iLauncher == INVALID_ENT_REFERENCE || !bIsValidEntity(iLauncher))
	{
		g_esRockPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	int iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esRockCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esRockCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRockPlayer[iTank].g_iTankType) || (g_esRockCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRockCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esRockAbility[g_esRockPlayer[iTank].g_iTankType].g_iAccessFlags, g_esRockPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esRockPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esRockPlayer[iTank].g_iTankType || g_esRockCache[iTank].g_iRockAbility == 0 || !g_esRockPlayer[iTank].g_bActivated)
	{
		vRockReset2(iTank);

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esRockCache[iTank].g_iRockDuration;
	iDuration = (bHuman && g_esRockCache[iTank].g_iHumanAbility == 1) ? g_esRockCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esRockCache[iTank].g_iHumanAbility == 1 && g_esRockCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime)
	{
		vRockReset2(iTank);
		vRockReset3(iTank);

		return Plugin_Stop;
	}

	float flPos[3], flAngles[3];
	GetClientEyePosition(iTank, flPos);
	flPos[2] += 20.0;
	flAngles[0] = MT_GetRandomFloat(-1.0, 1.0);
	flAngles[1] = MT_GetRandomFloat(-1.0, 1.0);
	flAngles[2] = 2.0;
	GetVectorAngles(flAngles, flAngles);

	float flMinRadius = (iPos != -1) ? MT_GetCombinationSetting(iTank, 7, iPos) : g_esRockCache[iTank].g_flRockRadius[0],
		flMaxRadius = (iPos != -1) ? MT_GetCombinationSetting(iTank, 8, iPos) : g_esRockCache[iTank].g_flRockRadius[1],
		flHitPos[3];
	iGetRayHitPos(flPos, flAngles, flHitPos, iTank, true, 2);
	float flDistance = GetVectorDistance(flPos, flHitPos);
	if (flDistance > 800.0)
	{
		flDistance = 800.0;
	}

	float flVector[3];
	MakeVectorFromPoints(flPos, flHitPos, flVector);
	NormalizeVector(flVector, flVector);
	ScaleVector(flVector, (flDistance - 40.0));
	AddVectors(flPos, flVector, flHitPos);
	if (flDistance > 300.0)
	{
		float flAngles2[3];
		if (bIsValidEntity(iLauncher))
		{
			flAngles2[0] = MT_GetRandomFloat(flMinRadius, flMaxRadius);
			flAngles2[1] = MT_GetRandomFloat(flMinRadius, flMaxRadius);
			flAngles2[2] = -2.0;
			GetVectorAngles(flAngles2, flAngles2);

			TeleportEntity(iLauncher, flHitPos, flAngles2);
			AcceptEntityInput(iLauncher, "LaunchRock");
		}
	}

	return Plugin_Continue;
}