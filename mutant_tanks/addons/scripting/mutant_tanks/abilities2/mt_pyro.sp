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

#define MT_PYRO_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_PYRO_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Pyro Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank ignites itself and gains a speed boost when on fire.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Pyro Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_PYRO_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_PYRO_SECTION "pyroability"
#define MT_PYRO_SECTION2 "pyro ability"
#define MT_PYRO_SECTION3 "pyro_ability"
#define MT_PYRO_SECTION4 "pyro"

#define MT_MENU_PYRO "Pyro Ability"

enum struct esPyroPlayer
{
	bool g_bActivated;
	bool g_bActivated2;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flPyroChance;
	float g_flPyroDamageBoost;
	float g_flPyroSpeedBoost;

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
	int g_iPyroAbility;
	int g_iPyroCooldown;
	int g_iPyroDuration;
	int g_iPyroMessage;
	int g_iPyroMode;
	int g_iPyroReignite;
	int g_iRequiresHumans;
	int g_iTankType;
}

esPyroPlayer g_esPyroPlayer[MAXPLAYERS + 1];

enum struct esPyroAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flPyroChance;
	float g_flPyroDamageBoost;
	float g_flPyroSpeedBoost;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iPyroAbility;
	int g_iPyroCooldown;
	int g_iPyroDuration;
	int g_iPyroMessage;
	int g_iPyroMode;
	int g_iPyroReignite;
	int g_iRequiresHumans;
}

esPyroAbility g_esPyroAbility[MT_MAXTYPES + 1];

enum struct esPyroCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flPyroChance;
	float g_flPyroDamageBoost;
	float g_flPyroSpeedBoost;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iPyroAbility;
	int g_iPyroCooldown;
	int g_iPyroDuration;
	int g_iPyroMessage;
	int g_iPyroMode;
	int g_iPyroReignite;
	int g_iRequiresHumans;
}

esPyroCache g_esPyroCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_pyro", cmdPyroInfo, "View information about the Pyro ability.");

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
void vPyroMapStart()
#else
public void OnMapStart()
#endif
{
	vPyroReset();
}

#if defined MT_ABILITIES_MAIN2
void vPyroClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnPyroTakeDamage);
	vRemovePyro(client);
}

#if defined MT_ABILITIES_MAIN2
void vPyroClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemovePyro(client);
}

#if defined MT_ABILITIES_MAIN2
void vPyroMapEnd()
#else
public void OnMapEnd()
#endif
{
	vPyroReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdPyroInfo(int client, int args)
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
		case false: vPyroMenu(client, MT_PYRO_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vPyroMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_PYRO_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iPyroMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Pyro Ability Information");
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

int iPyroMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esPyroCache[param1].g_iPyroAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esPyroCache[param1].g_iHumanAmmo - g_esPyroPlayer[param1].g_iAmmoCount), g_esPyroCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esPyroCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esPyroCache[param1].g_iHumanAbility == 1) ? g_esPyroCache[param1].g_iHumanCooldown : g_esPyroCache[param1].g_iPyroCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "PyroDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esPyroCache[param1].g_iHumanAbility == 1) ? g_esPyroCache[param1].g_iHumanDuration : g_esPyroCache[param1].g_iPyroDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esPyroCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vPyroMenu(param1, MT_PYRO_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pPyro = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "PyroMenu", param1);
			pPyro.SetTitle(sMenuTitle);
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
void vPyroDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_PYRO, MT_MENU_PYRO);
}

#if defined MT_ABILITIES_MAIN2
void vPyroMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_PYRO, false))
	{
		vPyroMenu(client, MT_PYRO_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPyroMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_PYRO, false))
	{
		FormatEx(buffer, size, "%T", "PyroMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPyroPlayerRunCmd(int client)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsTankSupported(client) || !g_esPyroPlayer[client].g_bActivated || (bIsTank(client, MT_CHECK_FAKECLIENT) && g_esPyroCache[client].g_iHumanMode == 1) || g_esPyroPlayer[client].g_iDuration == -1)
	{
#if defined MT_ABILITIES_MAIN2
		return;
#else
		return Plugin_Continue;
#endif
	}

	if (!bIsPlayerBurning(client))
	{
		switch (g_esPyroCache[client].g_iPyroReignite)
		{
			case 0: vRemovePyro2(client);
			case 1:
			{
				int iPos = g_esPyroAbility[g_esPyroPlayer[client].g_iTankType].g_iComboPosition;
				float flDuration = (iPos != -1) ? MT_GetCombinationSetting(client, 5, iPos) : float(g_esPyroCache[client].g_iPyroDuration);
				flDuration = (bIsTank(client, MT_CHECK_FAKECLIENT) && g_esPyroCache[client].g_iHumanAbility == 1) ? float(g_esPyroCache[client].g_iHumanDuration) : flDuration;
				IgniteEntity(client, flDuration);
			}
		}
	}

	if (g_esPyroPlayer[client].g_iDuration != -1 && g_esPyroPlayer[client].g_iDuration < GetTime())
	{
		vRemovePyro2(client);
	}
#if !defined MT_ABILITIES_MAIN2
	return Plugin_Continue;
#endif
}

Action OnPyroTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim))
		{
			if (!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esPyroAbility[g_esPyroPlayer[victim].g_iTankType].g_iAccessFlags, g_esPyroPlayer[victim].g_iAccessFlags))
			{
				return Plugin_Continue;
			}

			if (g_esPyroCache[victim].g_iPyroAbility == 1 && ((damagetype & DMG_BURN) || (damagetype & DMG_DIRECT) || bIsPlayerBurning(victim)))
			{
				if (!g_esPyroPlayer[victim].g_bActivated)
				{
					int iPos = g_esPyroAbility[g_esPyroPlayer[victim].g_iTankType].g_iComboPosition, iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(victim, 5, iPos)) : g_esPyroCache[victim].g_iPyroDuration;
					iDuration = (bIsTank(victim, MT_CHECK_FAKECLIENT) && g_esPyroCache[victim].g_iHumanAbility == 1) ? g_esPyroCache[victim].g_iHumanDuration : iDuration;
					g_esPyroPlayer[victim].g_bActivated = true;
					g_esPyroPlayer[victim].g_iDuration = (GetTime() + iDuration);
				}

				switch (g_esPyroCache[victim].g_iPyroMode)
				{
					case 0: SetEntPropFloat(victim, Prop_Send, "m_flLaggedMovementValue", (MT_GetRunSpeed(victim) + g_esPyroCache[victim].g_flPyroSpeedBoost));
					case 1: SetEntPropFloat(victim, Prop_Send, "m_flLaggedMovementValue", g_esPyroCache[victim].g_flPyroSpeedBoost);
				}

				if (!g_esPyroPlayer[victim].g_bActivated2 && g_esPyroCache[victim].g_iPyroMessage == 1)
				{
					g_esPyroPlayer[victim].g_bActivated2 = true;

					char sTankName[33];
					MT_GetTankName(victim, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Pyro2", sTankName);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Pyro2", LANG_SERVER, sTankName);
				}
			}
		}
		else if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker))
		{
			if (!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esPyroAbility[g_esPyroPlayer[attacker].g_iTankType].g_iAccessFlags, g_esPyroPlayer[attacker].g_iAccessFlags))
			{
				return Plugin_Continue;
			}

			if (g_esPyroCache[attacker].g_iPyroAbility == 1 && g_esPyroPlayer[attacker].g_bActivated)
			{
				char sClassname[32];
				GetEntityClassname(inflictor, sClassname, sizeof sClassname);
				if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
				{
					switch (g_esPyroCache[attacker].g_iPyroMode)
					{
						case 0:
						{
							damage += g_esPyroCache[attacker].g_flPyroDamageBoost;
							damage = MT_GetScaledDamage(damage);
						}
						case 1: damage = MT_GetScaledDamage(g_esPyroCache[attacker].g_flPyroDamageBoost);
					}

					return Plugin_Changed;
				}
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vPyroPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_PYRO);
}

#if defined MT_ABILITIES_MAIN2
void vPyroAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_PYRO_SECTION);
	list2.PushString(MT_PYRO_SECTION2);
	list3.PushString(MT_PYRO_SECTION3);
	list4.PushString(MT_PYRO_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vPyroCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPyroCache[tank].g_iHumanAbility != 2)
	{
		g_esPyroAbility[g_esPyroPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esPyroAbility[g_esPyroPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_PYRO_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_PYRO_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_PYRO_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_PYRO_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esPyroCache[tank].g_iPyroAbility == 1 && g_esPyroCache[tank].g_iComboAbility == 1 && !g_esPyroPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_PYRO_SECTION, false) || StrEqual(sSubset[iPos], MT_PYRO_SECTION2, false) || StrEqual(sSubset[iPos], MT_PYRO_SECTION3, false) || StrEqual(sSubset[iPos], MT_PYRO_SECTION4, false))
				{
					g_esPyroAbility[g_esPyroPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vPyro(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerPyroCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vPyroConfigsLoad(int mode)
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
				g_esPyroAbility[iIndex].g_iAccessFlags = 0;
				g_esPyroAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esPyroAbility[iIndex].g_iComboAbility = 0;
				g_esPyroAbility[iIndex].g_iComboPosition = -1;
				g_esPyroAbility[iIndex].g_iHumanAbility = 0;
				g_esPyroAbility[iIndex].g_iHumanAmmo = 5;
				g_esPyroAbility[iIndex].g_iHumanCooldown = 0;
				g_esPyroAbility[iIndex].g_iHumanDuration = 5;
				g_esPyroAbility[iIndex].g_iHumanMode = 1;
				g_esPyroAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esPyroAbility[iIndex].g_iRequiresHumans = 0;
				g_esPyroAbility[iIndex].g_iPyroAbility = 0;
				g_esPyroAbility[iIndex].g_iPyroMessage = 0;
				g_esPyroAbility[iIndex].g_flPyroChance = 33.3;
				g_esPyroAbility[iIndex].g_iPyroCooldown = 0;
				g_esPyroAbility[iIndex].g_flPyroDamageBoost = 5.0;
				g_esPyroAbility[iIndex].g_iPyroDuration = 5;
				g_esPyroAbility[iIndex].g_iPyroMode = 0;
				g_esPyroAbility[iIndex].g_iPyroReignite = 1;
				g_esPyroAbility[iIndex].g_flPyroSpeedBoost = 1.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esPyroPlayer[iPlayer].g_iAccessFlags = 0;
					g_esPyroPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esPyroPlayer[iPlayer].g_iComboAbility = 0;
					g_esPyroPlayer[iPlayer].g_iHumanAbility = 0;
					g_esPyroPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esPyroPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esPyroPlayer[iPlayer].g_iHumanDuration = 0;
					g_esPyroPlayer[iPlayer].g_iHumanMode = 0;
					g_esPyroPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esPyroPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esPyroPlayer[iPlayer].g_iPyroAbility = 0;
					g_esPyroPlayer[iPlayer].g_iPyroMessage = 0;
					g_esPyroPlayer[iPlayer].g_flPyroChance = 0.0;
					g_esPyroPlayer[iPlayer].g_iPyroCooldown = 0;
					g_esPyroPlayer[iPlayer].g_flPyroDamageBoost = 0.0;
					g_esPyroPlayer[iPlayer].g_iPyroDuration = 0;
					g_esPyroPlayer[iPlayer].g_iPyroMode = 0;
					g_esPyroPlayer[iPlayer].g_iPyroReignite = 0;
					g_esPyroPlayer[iPlayer].g_flPyroSpeedBoost = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPyroConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esPyroPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esPyroPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esPyroPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esPyroPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esPyroPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esPyroPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esPyroPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esPyroPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esPyroPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esPyroPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esPyroPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esPyroPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esPyroPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esPyroPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esPyroPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esPyroPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esPyroPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esPyroPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esPyroPlayer[admin].g_iPyroAbility = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esPyroPlayer[admin].g_iPyroAbility, value, 0, 1);
		g_esPyroPlayer[admin].g_iPyroMessage = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esPyroPlayer[admin].g_iPyroMessage, value, 0, 1);
		g_esPyroPlayer[admin].g_flPyroChance = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroChance", "Pyro Chance", "Pyro_Chance", "chance", g_esPyroPlayer[admin].g_flPyroChance, value, 0.0, 100.0);
		g_esPyroPlayer[admin].g_iPyroCooldown = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroCooldown", "Pyro Cooldown", "Pyro_Cooldown", "cooldown", g_esPyroPlayer[admin].g_iPyroCooldown, value, 0, 99999);
		g_esPyroPlayer[admin].g_flPyroDamageBoost = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroDamageBoost", "Pyro Damage Boost", "Pyro_Damage_Boost", "dmgboost", g_esPyroPlayer[admin].g_flPyroDamageBoost, value, 0.1, 99999.0);
		g_esPyroPlayer[admin].g_iPyroDuration = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroDuration", "Pyro Duration", "Pyro_Duration", "duration", g_esPyroPlayer[admin].g_iPyroDuration, value, 0, 99999);
		g_esPyroPlayer[admin].g_iPyroMode = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroMode", "Pyro Mode", "Pyro_Mode", "mode", g_esPyroPlayer[admin].g_iPyroMode, value, 0, 1);
		g_esPyroPlayer[admin].g_iPyroReignite = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroReignite", "Pyro Reignite", "Pyro_Reignite", "reignite", g_esPyroPlayer[admin].g_iPyroReignite, value, 0, 1);
		g_esPyroPlayer[admin].g_flPyroSpeedBoost = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroSpeedBoost", "Pyro Speed Boost", "Pyro_Speed_Boost", "speedboost", g_esPyroPlayer[admin].g_flPyroSpeedBoost, value, 0.1, 3.0);
		g_esPyroPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esPyroAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esPyroAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esPyroAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esPyroAbility[type].g_iComboAbility, value, 0, 1);
		g_esPyroAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esPyroAbility[type].g_iHumanAbility, value, 0, 2);
		g_esPyroAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esPyroAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esPyroAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esPyroAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esPyroAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esPyroAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esPyroAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esPyroAbility[type].g_iHumanMode, value, 0, 1);
		g_esPyroAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esPyroAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esPyroAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esPyroAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esPyroAbility[type].g_iPyroAbility = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esPyroAbility[type].g_iPyroAbility, value, 0, 1);
		g_esPyroAbility[type].g_iPyroMessage = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esPyroAbility[type].g_iPyroMessage, value, 0, 1);
		g_esPyroAbility[type].g_flPyroChance = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroChance", "Pyro Chance", "Pyro_Chance", "chance", g_esPyroAbility[type].g_flPyroChance, value, 0.0, 100.0);
		g_esPyroAbility[type].g_iPyroCooldown = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroCooldown", "Pyro Cooldown", "Pyro_Cooldown", "cooldown", g_esPyroAbility[type].g_iPyroCooldown, value, 0, 99999);
		g_esPyroAbility[type].g_flPyroDamageBoost = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroDamageBoost", "Pyro Damage Boost", "Pyro_Damage_Boost", "dmgboost", g_esPyroAbility[type].g_flPyroDamageBoost, value, 0.1, 99999.0);
		g_esPyroAbility[type].g_iPyroDuration = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroDuration", "Pyro Duration", "Pyro_Duration", "duration", g_esPyroAbility[type].g_iPyroDuration, value, 0, 99999);
		g_esPyroAbility[type].g_iPyroMode = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroMode", "Pyro Mode", "Pyro_Mode", "mode", g_esPyroAbility[type].g_iPyroMode, value, 0, 1);
		g_esPyroAbility[type].g_iPyroReignite = iGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroReignite", "Pyro Reignite", "Pyro_Reignite", "reignite", g_esPyroAbility[type].g_iPyroReignite, value, 0, 1);
		g_esPyroAbility[type].g_flPyroSpeedBoost = flGetKeyValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "PyroSpeedBoost", "Pyro Speed Boost", "Pyro_Speed_Boost", "speedboost", g_esPyroAbility[type].g_flPyroSpeedBoost, value, 0.1, 3.0);
		g_esPyroAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_PYRO_SECTION, MT_PYRO_SECTION2, MT_PYRO_SECTION3, MT_PYRO_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPyroSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esPyroCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_flCloseAreasOnly, g_esPyroAbility[type].g_flCloseAreasOnly);
	g_esPyroCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iComboAbility, g_esPyroAbility[type].g_iComboAbility);
	g_esPyroCache[tank].g_flPyroChance = flGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_flPyroChance, g_esPyroAbility[type].g_flPyroChance);
	g_esPyroCache[tank].g_flPyroDamageBoost = flGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_flPyroDamageBoost, g_esPyroAbility[type].g_flPyroDamageBoost);
	g_esPyroCache[tank].g_flPyroSpeedBoost = flGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_flPyroSpeedBoost, g_esPyroAbility[type].g_flPyroSpeedBoost);
	g_esPyroCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iHumanAbility, g_esPyroAbility[type].g_iHumanAbility);
	g_esPyroCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iHumanAmmo, g_esPyroAbility[type].g_iHumanAmmo);
	g_esPyroCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iHumanCooldown, g_esPyroAbility[type].g_iHumanCooldown);
	g_esPyroCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iHumanDuration, g_esPyroAbility[type].g_iHumanDuration);
	g_esPyroCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iHumanMode, g_esPyroAbility[type].g_iHumanMode);
	g_esPyroCache[tank].g_iPyroAbility = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iPyroAbility, g_esPyroAbility[type].g_iPyroAbility);
	g_esPyroCache[tank].g_iPyroCooldown = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iPyroCooldown, g_esPyroAbility[type].g_iPyroCooldown);
	g_esPyroCache[tank].g_iPyroDuration = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iPyroDuration, g_esPyroAbility[type].g_iPyroDuration);
	g_esPyroCache[tank].g_iPyroMessage = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iPyroMessage, g_esPyroAbility[type].g_iPyroMessage);
	g_esPyroCache[tank].g_iPyroMode = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iPyroMode, g_esPyroAbility[type].g_iPyroMode);
	g_esPyroCache[tank].g_iPyroReignite = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iPyroReignite, g_esPyroAbility[type].g_iPyroReignite);
	g_esPyroCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_flOpenAreasOnly, g_esPyroAbility[type].g_flOpenAreasOnly);
	g_esPyroCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esPyroPlayer[tank].g_iRequiresHumans, g_esPyroAbility[type].g_iRequiresHumans);
	g_esPyroPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vPyroCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vPyroCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemovePyro(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vPyroPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esPyroPlayer[iTank].g_bActivated)
		{
			SetEntPropFloat(iTank, Prop_Send, "m_flLaggedMovementValue", 1.0);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPyroEventFired(Event event, const char[] name)
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
			vPyroCopyStats2(iBot, iTank);
			vRemovePyro(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vPyroCopyStats2(iTank, iBot);
			vRemovePyro(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemovePyro(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vPyroReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vPyroAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPyroAbility[g_esPyroPlayer[tank].g_iTankType].g_iAccessFlags, g_esPyroPlayer[tank].g_iAccessFlags)) || g_esPyroCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esPyroCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esPyroCache[tank].g_iPyroAbility == 1 && g_esPyroCache[tank].g_iComboAbility == 0 && !g_esPyroPlayer[tank].g_bActivated)
	{
		vPyroAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPyroButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esPyroCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esPyroCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPyroPlayer[tank].g_iTankType) || (g_esPyroCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPyroCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPyroAbility[g_esPyroPlayer[tank].g_iTankType].g_iAccessFlags, g_esPyroPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esPyroCache[tank].g_iPyroAbility == 1 && g_esPyroCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esPyroPlayer[tank].g_iCooldown != -1 && g_esPyroPlayer[tank].g_iCooldown > iTime;

			switch (g_esPyroCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esPyroPlayer[tank].g_bActivated && !bRecharging)
					{
						vPyroAbility(tank);
					}
					else if (g_esPyroPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "PyroHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "PyroHuman4", (g_esPyroPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esPyroPlayer[tank].g_iAmmoCount < g_esPyroCache[tank].g_iHumanAmmo && g_esPyroCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esPyroPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esPyroPlayer[tank].g_bActivated = true;
							g_esPyroPlayer[tank].g_iAmmoCount++;

							int iPos = g_esPyroAbility[g_esPyroPlayer[tank].g_iTankType].g_iComboPosition;
							float flDuration = (iPos != -1) ? MT_GetCombinationSetting(tank, 5, iPos) : float(g_esPyroCache[tank].g_iPyroDuration);
							flDuration = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPyroCache[tank].g_iHumanAbility == 1) ? float(g_esPyroCache[tank].g_iHumanDuration) : flDuration;
							IgniteEntity(tank, flDuration);
						}
						else if (g_esPyroPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "PyroHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "PyroHuman4", (g_esPyroPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "PyroAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPyroButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esPyroCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esPyroCache[tank].g_iHumanMode == 1 && g_esPyroPlayer[tank].g_bActivated && (g_esPyroPlayer[tank].g_iCooldown == -1 || g_esPyroPlayer[tank].g_iCooldown < GetTime()))
		{
			vPyroReset2(tank);
			vPyroReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPyroChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemovePyro(tank);
}

void vPyro(int tank, int pos = -1)
{
	int iTime = GetTime();
	if (g_esPyroPlayer[tank].g_iCooldown != -1 && g_esPyroPlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	int iDuration = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 5, pos)) : g_esPyroCache[tank].g_iPyroDuration;
	iDuration = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPyroCache[tank].g_iHumanAbility == 1) ? g_esPyroCache[tank].g_iHumanDuration : iDuration;
	g_esPyroPlayer[tank].g_bActivated = true;
	g_esPyroPlayer[tank].g_iDuration = (iTime + iDuration);

	IgniteEntity(tank, float(iDuration));

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPyroCache[tank].g_iHumanAbility == 1)
	{
		g_esPyroPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "PyroHuman", g_esPyroPlayer[tank].g_iAmmoCount, g_esPyroCache[tank].g_iHumanAmmo);
	}

	if (g_esPyroCache[tank].g_iPyroMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Pyro", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Pyro", LANG_SERVER, sTankName);
	}
}

void vPyroAbility(int tank)
{
	if ((g_esPyroPlayer[tank].g_iCooldown != -1 && g_esPyroPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esPyroCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esPyroCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPyroPlayer[tank].g_iTankType) || (g_esPyroCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPyroCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPyroAbility[g_esPyroPlayer[tank].g_iTankType].g_iAccessFlags, g_esPyroPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esPyroPlayer[tank].g_iAmmoCount < g_esPyroCache[tank].g_iHumanAmmo && g_esPyroCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esPyroCache[tank].g_flPyroChance)
		{
			vPyro(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPyroCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "PyroHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPyroCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "PyroAmmo");
	}
}

void vPyroCopyStats2(int oldTank, int newTank)
{
	g_esPyroPlayer[newTank].g_iAmmoCount = g_esPyroPlayer[oldTank].g_iAmmoCount;
	g_esPyroPlayer[newTank].g_iCooldown = g_esPyroPlayer[oldTank].g_iCooldown;
}

void vRemovePyro(int tank)
{
	g_esPyroPlayer[tank].g_bActivated = false;
	g_esPyroPlayer[tank].g_bActivated2 = false;
	g_esPyroPlayer[tank].g_iAmmoCount = 0;
	g_esPyroPlayer[tank].g_iCooldown = -1;
	g_esPyroPlayer[tank].g_iDuration = -1;
}

void vRemovePyro2(int tank)
{
	if (g_esPyroPlayer[tank].g_iCooldown == -1 || g_esPyroPlayer[tank].g_iCooldown < GetTime())
	{
		vPyroReset3(tank);
	}

	vPyroReset2(tank);
}

void vPyroReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemovePyro(iPlayer);
		}
	}
}

void vPyroReset2(int tank)
{
	g_esPyroPlayer[tank].g_bActivated = false;
	g_esPyroPlayer[tank].g_bActivated2 = false;
	g_esPyroPlayer[tank].g_iDuration = -1;

	ExtinguishEntity(tank);
	SetEntPropFloat(tank, Prop_Send, "m_flLaggedMovementValue", MT_GetRunSpeed(tank));

	if (g_esPyroCache[tank].g_iPyroMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Pyro3", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Pyro3", LANG_SERVER, sTankName);
	}
}

void vPyroReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esPyroAbility[g_esPyroPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esPyroCache[tank].g_iPyroCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPyroCache[tank].g_iHumanAbility == 1 && g_esPyroCache[tank].g_iHumanMode == 0 && g_esPyroPlayer[tank].g_iAmmoCount < g_esPyroCache[tank].g_iHumanAmmo && g_esPyroCache[tank].g_iHumanAmmo > 0) ? g_esPyroCache[tank].g_iHumanCooldown : iCooldown;
	g_esPyroPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esPyroPlayer[tank].g_iCooldown != -1 && g_esPyroPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "PyroHuman5", (g_esPyroPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerPyroCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esPyroAbility[g_esPyroPlayer[iTank].g_iTankType].g_iAccessFlags, g_esPyroPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esPyroPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esPyroCache[iTank].g_iPyroAbility == 0 || g_esPyroPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vPyro(iTank, iPos);

	return Plugin_Continue;
}