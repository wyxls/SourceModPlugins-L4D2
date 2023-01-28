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

#define MT_WITCH_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_WITCH_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Witch Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank converts nearby common infected into Witch minions.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Witch Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_WITCH_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_WITCH_SECTION "witchability"
#define MT_WITCH_SECTION2 "witch ability"
#define MT_WITCH_SECTION3 "witch_ability"
#define MT_WITCH_SECTION4 "witch"

#define MT_MENU_WITCH "Witch Ability"

enum struct esWitchPlayer
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flWitchChance;
	float g_flWitchDamage;
	float g_flWitchLifetime;
	float g_flWitchRange;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iTankType;
	int g_iWitchAbility;
	int g_iWitchAmount;
	int g_iWitchCooldown;
	int g_iWitchMessage;
	int g_iWitchRemove;
}

esWitchPlayer g_esWitchPlayer[MAXPLAYERS + 1];

enum struct esWitchAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flWitchChance;
	float g_flWitchDamage;
	float g_flWitchLifetime;
	float g_flWitchRange;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iWitchAbility;
	int g_iWitchAmount;
	int g_iWitchCooldown;
	int g_iWitchMessage;
	int g_iWitchRemove;
}

esWitchAbility g_esWitchAbility[MT_MAXTYPES + 1];

enum struct esWitchCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flWitchChance;
	float g_flWitchDamage;
	float g_flWitchLifetime;
	float g_flWitchRange;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iRequiresHumans;
	int g_iWitchAbility;
	int g_iWitchAmount;
	int g_iWitchCooldown;
	int g_iWitchMessage;
	int g_iWitchRemove;
}

esWitchCache g_esWitchCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_witch", cmdWitchInfo, "View information about the Witch ability.");

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
void vWitchMapStart()
#else
public void OnMapStart()
#endif
{
	vWitchReset();
}

#if defined MT_ABILITIES_MAIN2
void vWitchClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnWitchTakeDamage);
	vRemoveWitch(client);
}

#if defined MT_ABILITIES_MAIN2
void vWitchClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveWitch(client);
}

#if defined MT_ABILITIES_MAIN2
void vWitchMapEnd()
#else
public void OnMapEnd()
#endif
{
	vWitchReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdWitchInfo(int client, int args)
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
		case false: vWitchMenu(client, MT_WITCH_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vWitchMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_WITCH_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iWitchMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Witch Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iWitchMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esWitchCache[param1].g_iWitchAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esWitchCache[param1].g_iHumanAmmo - g_esWitchPlayer[param1].g_iAmmoCount), g_esWitchCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons3");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esWitchCache[param1].g_iHumanAbility == 1) ? g_esWitchCache[param1].g_iHumanCooldown : g_esWitchCache[param1].g_iWitchCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "WitchDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esWitchCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vWitchMenu(param1, MT_WITCH_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pWitch = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "WitchMenu", param1);
			pWitch.SetTitle(sMenuTitle);
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
void vWitchDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_WITCH, MT_MENU_WITCH);
}

#if defined MT_ABILITIES_MAIN2
void vWitchMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_WITCH, false))
	{
		vWitchMenu(client, MT_WITCH_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vWitchMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_WITCH, false))
	{
		FormatEx(buffer, size, "%T", "WitchMenu2", client);
	}
}

Action OnWitchTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsWitch(attacker) && bIsSurvivor(victim) && !bIsSurvivorDisabled(victim) && damage > 0.0)
	{
		int iTank = GetEntPropEnt(attacker, Prop_Data, "m_hOwnerEntity");
		if (MT_IsTankSupported(iTank) && MT_IsCustomTankSupported(iTank) && g_esWitchCache[iTank].g_iWitchAbility == 1)
		{
			if ((!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esWitchAbility[g_esWitchPlayer[iTank].g_iTankType].g_iAccessFlags, g_esWitchPlayer[iTank].g_iAccessFlags)) || MT_IsAdminImmune(victim, iTank) || bIsAdminImmune(victim, g_esWitchPlayer[iTank].g_iTankType, g_esWitchAbility[g_esWitchPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esWitchPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Handled;
			}

			int iPos = g_esWitchAbility[g_esWitchPlayer[iTank].g_iTankType].g_iComboPosition;
			float flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : g_esWitchCache[iTank].g_flWitchDamage;
			damage = MT_GetScaledDamage(flDamage);

			return (damage > 0.0) ? Plugin_Changed : Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vWitchPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_WITCH);
}

#if defined MT_ABILITIES_MAIN2
void vWitchAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_WITCH_SECTION);
	list2.PushString(MT_WITCH_SECTION2);
	list3.PushString(MT_WITCH_SECTION3);
	list4.PushString(MT_WITCH_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vWitchCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWitchCache[tank].g_iHumanAbility != 2)
	{
		g_esWitchAbility[g_esWitchPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esWitchAbility[g_esWitchPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_WITCH_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_WITCH_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_WITCH_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_WITCH_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esWitchCache[tank].g_iWitchAbility == 1 && g_esWitchCache[tank].g_iComboAbility == 1)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_WITCH_SECTION, false) || StrEqual(sSubset[iPos], MT_WITCH_SECTION2, false) || StrEqual(sSubset[iPos], MT_WITCH_SECTION3, false) || StrEqual(sSubset[iPos], MT_WITCH_SECTION4, false))
				{
					g_esWitchAbility[g_esWitchPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vWitch(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerWitchCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vWitchConfigsLoad(int mode)
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
				g_esWitchAbility[iIndex].g_iAccessFlags = 0;
				g_esWitchAbility[iIndex].g_iImmunityFlags = 0;
				g_esWitchAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esWitchAbility[iIndex].g_iComboAbility = 0;
				g_esWitchAbility[iIndex].g_iComboPosition = -1;
				g_esWitchAbility[iIndex].g_iHumanAbility = 0;
				g_esWitchAbility[iIndex].g_iHumanAmmo = 5;
				g_esWitchAbility[iIndex].g_iHumanCooldown = 0;
				g_esWitchAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esWitchAbility[iIndex].g_iRequiresHumans = 1;
				g_esWitchAbility[iIndex].g_iWitchAbility = 0;
				g_esWitchAbility[iIndex].g_iWitchMessage = 0;
				g_esWitchAbility[iIndex].g_iWitchAmount = 3;
				g_esWitchAbility[iIndex].g_flWitchChance = 33.3;
				g_esWitchAbility[iIndex].g_iWitchCooldown = 0;
				g_esWitchAbility[iIndex].g_flWitchDamage = 5.0;
				g_esWitchAbility[iIndex].g_flWitchLifetime = 0.0;
				g_esWitchAbility[iIndex].g_flWitchRange = 500.0;
				g_esWitchAbility[iIndex].g_iWitchRemove = 1;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esWitchPlayer[iPlayer].g_iAccessFlags = 0;
					g_esWitchPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esWitchPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esWitchPlayer[iPlayer].g_iComboAbility = 0;
					g_esWitchPlayer[iPlayer].g_iHumanAbility = 0;
					g_esWitchPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esWitchPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esWitchPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esWitchPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esWitchPlayer[iPlayer].g_iWitchAbility = 0;
					g_esWitchPlayer[iPlayer].g_iWitchMessage = 0;
					g_esWitchPlayer[iPlayer].g_iWitchAmount = 0;
					g_esWitchPlayer[iPlayer].g_flWitchChance = 0.0;
					g_esWitchPlayer[iPlayer].g_iWitchCooldown = 0;
					g_esWitchPlayer[iPlayer].g_flWitchDamage = 0.0;
					g_esWitchPlayer[iPlayer].g_flWitchLifetime = 0.0;
					g_esWitchPlayer[iPlayer].g_flWitchRange = 0.0;
					g_esWitchPlayer[iPlayer].g_iWitchRemove = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vWitchConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esWitchPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esWitchPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esWitchPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esWitchPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esWitchPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esWitchPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esWitchPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esWitchPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esWitchPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esWitchPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esWitchPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esWitchPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esWitchPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esWitchPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esWitchPlayer[admin].g_iWitchAbility = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esWitchPlayer[admin].g_iWitchAbility, value, 0, 1);
		g_esWitchPlayer[admin].g_iWitchMessage = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esWitchPlayer[admin].g_iWitchMessage, value, 0, 1);
		g_esWitchPlayer[admin].g_iWitchAmount = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchAmount", "Witch Amount", "Witch_Amount", "amount", g_esWitchPlayer[admin].g_iWitchAmount, value, 1, 25);
		g_esWitchPlayer[admin].g_flWitchChance = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchChance", "Witch Chance", "Witch_Chance", "chance", g_esWitchPlayer[admin].g_flWitchChance, value, 0.0, 100.0);
		g_esWitchPlayer[admin].g_iWitchCooldown = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchCooldown", "Witch Cooldown", "Witch_Cooldown", "cooldown", g_esWitchPlayer[admin].g_iWitchCooldown, value, 0, 99999);
		g_esWitchPlayer[admin].g_flWitchDamage = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchDamage", "Witch Damage", "Witch_Damage", "damage", g_esWitchPlayer[admin].g_flWitchDamage, value, 0.0, 99999.0);
		g_esWitchPlayer[admin].g_flWitchLifetime = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchLifetime", "Witch Lifetime", "Witch_Lifetime", "lifetime", g_esWitchPlayer[admin].g_flWitchLifetime, value, 0.0, 99999.0);
		g_esWitchPlayer[admin].g_flWitchRange = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchRange", "Witch Range", "Witch_Range", "range", g_esWitchPlayer[admin].g_flWitchRange, value, 1.0, 99999.0);
		g_esWitchPlayer[admin].g_iWitchRemove = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchRemove", "Witch Remove", "Witch_Remove", "remove", g_esWitchPlayer[admin].g_iWitchRemove, value, 0, 1);
		g_esWitchPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esWitchPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esWitchAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esWitchAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esWitchAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esWitchAbility[type].g_iComboAbility, value, 0, 1);
		g_esWitchAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esWitchAbility[type].g_iHumanAbility, value, 0, 2);
		g_esWitchAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esWitchAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esWitchAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esWitchAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esWitchAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esWitchAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esWitchAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esWitchAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esWitchAbility[type].g_iWitchAbility = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esWitchAbility[type].g_iWitchAbility, value, 0, 1);
		g_esWitchAbility[type].g_iWitchMessage = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esWitchAbility[type].g_iWitchMessage, value, 0, 1);
		g_esWitchAbility[type].g_iWitchAmount = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchAmount", "Witch Amount", "Witch_Amount", "amount", g_esWitchAbility[type].g_iWitchAmount, value, 1, 25);
		g_esWitchAbility[type].g_flWitchChance = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchChance", "Witch Chance", "Witch_Chance", "chance", g_esWitchAbility[type].g_flWitchChance, value, 0.0, 100.0);
		g_esWitchAbility[type].g_iWitchCooldown = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchCooldown", "Witch Cooldown", "Witch_Cooldown", "cooldown", g_esWitchAbility[type].g_iWitchCooldown, value, 0, 99999);
		g_esWitchAbility[type].g_flWitchDamage = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchDamage", "Witch Damage", "Witch_Damage", "damage", g_esWitchAbility[type].g_flWitchDamage, value, 0.0, 99999.0);
		g_esWitchAbility[type].g_flWitchLifetime = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchLifetime", "Witch Lifetime", "Witch_Lifetime", "lifetime", g_esWitchAbility[type].g_flWitchLifetime, value, 0.0, 99999.0);
		g_esWitchAbility[type].g_flWitchRange = flGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchRange", "Witch Range", "Witch_Range", "range", g_esWitchAbility[type].g_flWitchRange, value, 1.0, 99999.0);
		g_esWitchAbility[type].g_iWitchRemove = iGetKeyValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "WitchRemove", "Witch Remove", "Witch_Remove", "remove", g_esWitchAbility[type].g_iWitchRemove, value, 0, 1);
		g_esWitchAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esWitchAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_WITCH_SECTION, MT_WITCH_SECTION2, MT_WITCH_SECTION3, MT_WITCH_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vWitchSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esWitchCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_flCloseAreasOnly, g_esWitchAbility[type].g_flCloseAreasOnly);
	g_esWitchCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iComboAbility, g_esWitchAbility[type].g_iComboAbility);
	g_esWitchCache[tank].g_flWitchChance = flGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_flWitchChance, g_esWitchAbility[type].g_flWitchChance);
	g_esWitchCache[tank].g_flWitchDamage = flGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_flWitchDamage, g_esWitchAbility[type].g_flWitchDamage);
	g_esWitchCache[tank].g_flWitchLifetime = flGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_flWitchLifetime, g_esWitchAbility[type].g_flWitchLifetime);
	g_esWitchCache[tank].g_flWitchRange = flGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_flWitchRange, g_esWitchAbility[type].g_flWitchRange);
	g_esWitchCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iHumanAbility, g_esWitchAbility[type].g_iHumanAbility);
	g_esWitchCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iHumanAmmo, g_esWitchAbility[type].g_iHumanAmmo);
	g_esWitchCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iHumanCooldown, g_esWitchAbility[type].g_iHumanCooldown);
	g_esWitchCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_flOpenAreasOnly, g_esWitchAbility[type].g_flOpenAreasOnly);
	g_esWitchCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iRequiresHumans, g_esWitchAbility[type].g_iRequiresHumans);
	g_esWitchCache[tank].g_iWitchAbility = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iWitchAbility, g_esWitchAbility[type].g_iWitchAbility);
	g_esWitchCache[tank].g_iWitchAmount = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iWitchAmount, g_esWitchAbility[type].g_iWitchAmount);
	g_esWitchCache[tank].g_iWitchCooldown = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iWitchCooldown, g_esWitchAbility[type].g_iWitchCooldown);
	g_esWitchCache[tank].g_iWitchMessage = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iWitchMessage, g_esWitchAbility[type].g_iWitchMessage);
	g_esWitchCache[tank].g_iWitchRemove = iGetSettingValue(apply, bHuman, g_esWitchPlayer[tank].g_iWitchRemove, g_esWitchAbility[type].g_iWitchRemove);
	g_esWitchPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vWitchCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vWitchCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveWitch(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vWitchEventFired(Event event, const char[] name)
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
			vWitchCopyStats2(iBot, iTank);
			vRemoveWitch(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vWitchCopyStats2(iTank, iBot);
			vRemoveWitch(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			if (g_esWitchCache[iTank].g_iWitchRemove == 0)
			{
				vWitchRange(iTank);
			}

			vRemoveWitches(iTank);
			vRemoveWitch(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vWitchReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vWitchAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esWitchAbility[g_esWitchPlayer[tank].g_iTankType].g_iAccessFlags, g_esWitchPlayer[tank].g_iAccessFlags)) || g_esWitchCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esWitchCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esWitchCache[tank].g_iWitchAbility == 1 && g_esWitchCache[tank].g_iComboAbility == 0)
	{
		vWitchAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vWitchButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esWitchCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esWitchCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esWitchPlayer[tank].g_iTankType) || (g_esWitchCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esWitchCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esWitchAbility[g_esWitchPlayer[tank].g_iTankType].g_iAccessFlags, g_esWitchPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SPECIAL_KEY) && g_esWitchCache[tank].g_iWitchAbility == 1 && g_esWitchCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esWitchPlayer[tank].g_iCooldown != -1 && g_esWitchPlayer[tank].g_iCooldown > iTime)
			{
				case true: MT_PrintToChat(tank, "%s %t", MT_TAG3, "WitchHuman3", (g_esWitchPlayer[tank].g_iCooldown - iTime));
				case false: vWitchAbility(tank);
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vWitchChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveWitch(tank);
}

#if defined MT_ABILITIES_MAIN2
void vWitchPostTankSpawn(int tank)
#else
public void MT_OnPostTankSpawn(int tank)
#endif
{
	vWitchRange(tank);
}

void vWitch(int tank, int pos = -1)
{
	int iTime = GetTime();
	if (g_esWitchPlayer[tank].g_iCooldown != -1 && g_esWitchPlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	bool bConverted = false;
	float flTankPos[3], flInfectedPos[3], flInfectedAngles[3],
		flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esWitchCache[tank].g_flWitchRange;
	int iInfected = -1;
	while ((iInfected = FindEntityByClassname(iInfected, "infected")) != INVALID_ENT_REFERENCE)
	{
		if (iGetWitchCount() < g_esWitchCache[tank].g_iWitchAmount)
		{
			GetClientAbsOrigin(tank, flTankPos);
			GetEntPropVector(iInfected, Prop_Data, "m_vecOrigin", flInfectedPos);
			GetEntPropVector(iInfected, Prop_Data, "m_angRotation", flInfectedAngles);
			if (GetVectorDistance(flInfectedPos, flTankPos) <= flRange)
			{
				bConverted = true;

				RemoveEntity(iInfected);
				vWitch2(tank, flInfectedPos, flInfectedAngles);
			}
		}
	}

	if (bConverted)
	{
		int iCooldown = -1;
		if (g_esWitchPlayer[tank].g_iCooldown == -1 || g_esWitchPlayer[tank].g_iCooldown < iTime)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWitchCache[tank].g_iHumanAbility == 1)
			{
				g_esWitchPlayer[tank].g_iAmmoCount++;

				MT_PrintToChat(tank, "%s %t", MT_TAG3, "WitchHuman", g_esWitchPlayer[tank].g_iAmmoCount, g_esWitchCache[tank].g_iHumanAmmo);
			}

			iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esWitchCache[tank].g_iWitchCooldown;
			iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWitchCache[tank].g_iHumanAbility == 1 && g_esWitchPlayer[tank].g_iAmmoCount < g_esWitchCache[tank].g_iHumanAmmo && g_esWitchCache[tank].g_iHumanAmmo > 0) ? g_esWitchCache[tank].g_iHumanCooldown : iCooldown;
			g_esWitchPlayer[tank].g_iCooldown = (iTime + iCooldown);
			if (g_esWitchPlayer[tank].g_iCooldown != -1 && g_esWitchPlayer[tank].g_iCooldown > iTime)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "WitchHuman4", (g_esWitchPlayer[tank].g_iCooldown - iTime));
			}
		}

		if (g_esWitchCache[tank].g_iWitchMessage == 1)
		{
			char sTankName[33];
			MT_GetTankName(tank, sTankName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Witch", sTankName);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Witch", LANG_SERVER, sTankName);
		}
	}
}

void vWitch2(int tank, float pos[3], float angles[3])
{
	if (bIsAreaNarrow(tank, g_esWitchCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esWitchCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esWitchPlayer[tank].g_iTankType) || (g_esWitchCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esWitchCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esWitchAbility[g_esWitchPlayer[tank].g_iTankType].g_iAccessFlags, g_esWitchPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	int iWitch = CreateEntityByName("witch");
	if (bIsValidEntity(iWitch))
	{
		SetEntPropEnt(iWitch, Prop_Data, "m_hOwnerEntity", tank);
		TeleportEntity(iWitch, pos, angles);
		DispatchSpawn(iWitch);
		ActivateEntity(iWitch);

		if (g_esWitchCache[tank].g_flWitchLifetime > 0.0)
		{
			CreateTimer(g_esWitchCache[tank].g_flWitchLifetime, tTimerWitchKillWitch, EntIndexToEntRef(iWitch), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

void vWitchAbility(int tank)
{
	if ((g_esWitchPlayer[tank].g_iCooldown != -1 && g_esWitchPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esWitchCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esWitchCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esWitchPlayer[tank].g_iTankType) || (g_esWitchCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esWitchCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esWitchAbility[g_esWitchPlayer[tank].g_iTankType].g_iAccessFlags, g_esWitchPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esWitchPlayer[tank].g_iAmmoCount < g_esWitchCache[tank].g_iHumanAmmo && g_esWitchCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esWitchCache[tank].g_flWitchChance)
		{
			vWitch(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWitchCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "WitchHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWitchCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "WitchAmmo");
	}
}

void vWitchRange(int tank)
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(tank) && g_esWitchCache[tank].g_iWitchAbility == 1)
	{
		if (bIsAreaNarrow(tank, g_esWitchCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esWitchCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esWitchPlayer[tank].g_iTankType) || (g_esWitchCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esWitchCache[tank].g_iRequiresHumans) || (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esWitchAbility[g_esWitchPlayer[tank].g_iTankType].g_iAccessFlags, g_esWitchPlayer[tank].g_iAccessFlags)) || g_esWitchCache[tank].g_iHumanAbility == 0)))
		{
			return;
		}

		float flTankPos[3], flTankAngles[3];
		GetClientAbsOrigin(tank, flTankPos);
		GetClientAbsAngles(tank, flTankAngles);
		vWitch2(tank, flTankPos, flTankAngles);
	}
}

void vWitchCopyStats2(int oldTank, int newTank)
{
	g_esWitchPlayer[newTank].g_iAmmoCount = g_esWitchPlayer[oldTank].g_iAmmoCount;
	g_esWitchPlayer[newTank].g_iCooldown = g_esWitchPlayer[oldTank].g_iCooldown;
}

void vRemoveWitch(int tank)
{
	g_esWitchPlayer[tank].g_iAmmoCount = 0;
	g_esWitchPlayer[tank].g_iCooldown = -1;
}

void vRemoveWitches(int tank)
{
	if (g_esWitchCache[tank].g_iWitchRemove)
	{
		int iWitch = -1;
		while ((iWitch = FindEntityByClassname(iWitch, "witch")) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropEnt(iWitch, Prop_Data, "m_hOwnerEntity") == tank)
			{
				RemoveEntity(iWitch);
			}
		}
	}
}

void vWitchReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveWitch(iPlayer);
		}
	}
}

Action tTimerWitchCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esWitchAbility[g_esWitchPlayer[iTank].g_iTankType].g_iAccessFlags, g_esWitchPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esWitchPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esWitchCache[iTank].g_iWitchAbility == 0)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vWitch(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerWitchKillWitch(Handle timer, int ref)
{
	int iWitch = EntRefToEntIndex(ref);
	if (iWitch == INVALID_ENT_REFERENCE || !bIsValidEntity(iWitch) || !bIsWitch(iWitch))
	{
		return Plugin_Stop;
	}

	RemoveEntity(iWitch);

	return Plugin_Continue;
}