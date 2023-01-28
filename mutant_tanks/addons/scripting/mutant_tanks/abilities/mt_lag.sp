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

#define MT_LAG_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_LAG_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Lag Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank makes survivors lag.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Lag Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_LAG_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_LAG_SECTION "lagability"
#define MT_LAG_SECTION2 "lag ability"
#define MT_LAG_SECTION3 "lag_ability"
#define MT_LAG_SECTION4 "lag"

#define MT_MENU_LAG "Lag Ability"

enum struct esLagPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flLagChance;
	float g_flLagRange;
	float g_flLagRangeChance;
	float g_flOpenAreasOnly;
	float g_flPosition[3];

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iLagAbility;
	int g_iLagCooldown;
	int g_iLagDuration;
	int g_iLagEffect;
	int g_iLagHit;
	int g_iLagMessage;
	int g_iLagHitMode;
	int g_iLagRangeCooldown;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esLagPlayer g_esLagPlayer[MAXPLAYERS + 1];

enum struct esLagAbility
{
	float g_flCloseAreasOnly;
	float g_flLagChance;
	float g_flLagRange;
	float g_flLagRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iLagAbility;
	int g_iLagCooldown;
	int g_iLagDuration;
	int g_iLagEffect;
	int g_iLagHit;
	int g_iLagMessage;
	int g_iLagHitMode;
	int g_iLagRangeCooldown;
	int g_iRequiresHumans;
}

esLagAbility g_esLagAbility[MT_MAXTYPES + 1];

enum struct esLagCache
{
	float g_flCloseAreasOnly;
	float g_flLagChance;
	float g_flLagRange;
	float g_flLagRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iLagAbility;
	int g_iLagCooldown;
	int g_iLagDuration;
	int g_iLagEffect;
	int g_iLagHit;
	int g_iLagMessage;
	int g_iLagHitMode;
	int g_iLagRangeCooldown;
	int g_iRequiresHumans;
}

esLagCache g_esLagCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_lag", cmdLagInfo, "View information about the Lag ability.");

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

#if defined MT_ABILITIES_MAIN
void vLagMapStart()
#else
public void OnMapStart()
#endif
{
	vLagReset();
}

#if defined MT_ABILITIES_MAIN
void vLagClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnLagTakeDamage);
	vLagReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vLagClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vLagReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vLagMapEnd()
#else
public void OnMapEnd()
#endif
{
	vLagReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdLagInfo(int client, int args)
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
		case false: vLagMenu(client, MT_LAG_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vLagMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_LAG_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iLagMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Lag Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iLagMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLagCache[param1].g_iLagAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esLagCache[param1].g_iHumanAmmo - g_esLagPlayer[param1].g_iAmmoCount), g_esLagCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esLagCache[param1].g_iHumanAbility == 1) ? g_esLagCache[param1].g_iHumanCooldown : g_esLagCache[param1].g_iLagCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "LagDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esLagCache[param1].g_iLagDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLagCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esLagCache[param1].g_iHumanAbility == 1) ? g_esLagCache[param1].g_iHumanRangeCooldown : g_esLagCache[param1].g_iLagRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vLagMenu(param1, MT_LAG_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pLag = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "LagMenu", param1);
			pLag.SetTitle(sMenuTitle);
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
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Duration", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
					case 7: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "RangeCooldown", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vLagDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_LAG, MT_MENU_LAG);
}

#if defined MT_ABILITIES_MAIN
void vLagMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_LAG, false))
	{
		vLagMenu(client, MT_LAG_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vLagMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_LAG, false))
	{
		FormatEx(buffer, size, "%T", "LagMenu2", client);
	}
}

Action OnLagTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esLagCache[attacker].g_iLagHitMode == 0 || g_esLagCache[attacker].g_iLagHitMode == 1) && bIsSurvivor(victim) && g_esLagCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esLagAbility[g_esLagPlayer[attacker].g_iTankType].g_iAccessFlags, g_esLagPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esLagPlayer[attacker].g_iTankType, g_esLagAbility[g_esLagPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esLagPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vLagHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esLagCache[attacker].g_flLagChance, g_esLagCache[attacker].g_iLagHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esLagCache[victim].g_iLagHitMode == 0 || g_esLagCache[victim].g_iLagHitMode == 2) && bIsSurvivor(attacker) && g_esLagCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esLagAbility[g_esLagPlayer[victim].g_iTankType].g_iAccessFlags, g_esLagPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esLagPlayer[victim].g_iTankType, g_esLagAbility[g_esLagPlayer[victim].g_iTankType].g_iImmunityFlags, g_esLagPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vLagHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esLagCache[victim].g_flLagChance, g_esLagCache[victim].g_iLagHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vLagPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_LAG);
}

#if defined MT_ABILITIES_MAIN
void vLagAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_LAG_SECTION);
	list2.PushString(MT_LAG_SECTION2);
	list3.PushString(MT_LAG_SECTION3);
	list4.PushString(MT_LAG_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vLagCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLagCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_LAG_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_LAG_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_LAG_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_LAG_SECTION4);
	if (g_esLagCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_LAG_SECTION, false) || StrEqual(sSubset[iPos], MT_LAG_SECTION2, false) || StrEqual(sSubset[iPos], MT_LAG_SECTION3, false) || StrEqual(sSubset[iPos], MT_LAG_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esLagCache[tank].g_iLagAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vLagAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerLagCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
									dpCombo.WriteCell(GetClientUserId(tank));
									dpCombo.WriteFloat(random);
									dpCombo.WriteCell(iPos);
								}
							}
						}
					}
					case MT_COMBO_MELEEHIT:
					{
						flChance = MT_GetCombinationSetting(tank, 1, iPos);

						switch (flDelay)
						{
							case 0.0:
							{
								if ((g_esLagCache[tank].g_iLagHitMode == 0 || g_esLagCache[tank].g_iLagHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vLagHit(survivor, tank, random, flChance, g_esLagCache[tank].g_iLagHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esLagCache[tank].g_iLagHitMode == 0 || g_esLagCache[tank].g_iLagHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vLagHit(survivor, tank, random, flChance, g_esLagCache[tank].g_iLagHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerLagCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(survivor));
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteFloat(random);
								dpCombo.WriteFloat(flChance);
								dpCombo.WriteCell(iPos);
								dpCombo.WriteString(classname);
							}
						}
					}
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLagConfigsLoad(int mode)
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
				g_esLagAbility[iIndex].g_iAccessFlags = 0;
				g_esLagAbility[iIndex].g_iImmunityFlags = 0;
				g_esLagAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esLagAbility[iIndex].g_iComboAbility = 0;
				g_esLagAbility[iIndex].g_iHumanAbility = 0;
				g_esLagAbility[iIndex].g_iHumanAmmo = 5;
				g_esLagAbility[iIndex].g_iHumanCooldown = 0;
				g_esLagAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esLagAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esLagAbility[iIndex].g_iRequiresHumans = 1;
				g_esLagAbility[iIndex].g_iLagAbility = 0;
				g_esLagAbility[iIndex].g_iLagEffect = 0;
				g_esLagAbility[iIndex].g_iLagMessage = 0;
				g_esLagAbility[iIndex].g_flLagChance = 33.3;
				g_esLagAbility[iIndex].g_iLagCooldown = 0;
				g_esLagAbility[iIndex].g_iLagDuration = 5;
				g_esLagAbility[iIndex].g_iLagHit = 0;
				g_esLagAbility[iIndex].g_iLagHitMode = 0;
				g_esLagAbility[iIndex].g_flLagRange = 150.0;
				g_esLagAbility[iIndex].g_flLagRangeChance = 15.0;
				g_esLagAbility[iIndex].g_iLagRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esLagPlayer[iPlayer].g_iAccessFlags = 0;
					g_esLagPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esLagPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esLagPlayer[iPlayer].g_iComboAbility = 0;
					g_esLagPlayer[iPlayer].g_iHumanAbility = 0;
					g_esLagPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esLagPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esLagPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esLagPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esLagPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esLagPlayer[iPlayer].g_iLagAbility = 0;
					g_esLagPlayer[iPlayer].g_iLagEffect = 0;
					g_esLagPlayer[iPlayer].g_iLagMessage = 0;
					g_esLagPlayer[iPlayer].g_flLagChance = 0.0;
					g_esLagPlayer[iPlayer].g_iLagCooldown = 0;
					g_esLagPlayer[iPlayer].g_iLagDuration = 0;
					g_esLagPlayer[iPlayer].g_iLagHit = 0;
					g_esLagPlayer[iPlayer].g_iLagHitMode = 0;
					g_esLagPlayer[iPlayer].g_flLagRange = 0.0;
					g_esLagPlayer[iPlayer].g_flLagRangeChance = 0.0;
					g_esLagPlayer[iPlayer].g_iLagRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLagConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esLagPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esLagPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esLagPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esLagPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esLagPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esLagPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esLagPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esLagPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esLagPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esLagPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esLagPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esLagPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esLagPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esLagPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esLagPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esLagPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esLagPlayer[admin].g_iLagAbility = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esLagPlayer[admin].g_iLagAbility, value, 0, 1);
		g_esLagPlayer[admin].g_iLagEffect = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esLagPlayer[admin].g_iLagEffect, value, 0, 7);
		g_esLagPlayer[admin].g_iLagMessage = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esLagPlayer[admin].g_iLagMessage, value, 0, 3);
		g_esLagPlayer[admin].g_flLagChance = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagChance", "Lag Chance", "Lag_Chance", "chance", g_esLagPlayer[admin].g_flLagChance, value, 0.0, 100.0);
		g_esLagPlayer[admin].g_iLagCooldown = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagCooldown", "Lag Cooldown", "Lag_Cooldown", "cooldown", g_esLagPlayer[admin].g_iLagCooldown, value, 0, 99999);
		g_esLagPlayer[admin].g_iLagDuration = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagDuration", "Lag Duration", "Lag_Duration", "duration", g_esLagPlayer[admin].g_iLagDuration, value, 1, 99999);
		g_esLagPlayer[admin].g_iLagHit = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagHit", "Lag Hit", "Lag_Hit", "hit", g_esLagPlayer[admin].g_iLagHit, value, 0, 1);
		g_esLagPlayer[admin].g_iLagHitMode = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagHitMode", "Lag Hit Mode", "Lag_Hit_Mode", "hitmode", g_esLagPlayer[admin].g_iLagHitMode, value, 0, 2);
		g_esLagPlayer[admin].g_flLagRange = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagRange", "Lag Range", "Lag_Range", "range", g_esLagPlayer[admin].g_flLagRange, value, 1.0, 99999.0);
		g_esLagPlayer[admin].g_flLagRangeChance = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagRangeChance", "Lag Range Chance", "Lag_Range_Chance", "rangechance", g_esLagPlayer[admin].g_flLagRangeChance, value, 0.0, 100.0);
		g_esLagPlayer[admin].g_iLagRangeCooldown = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagRangeCooldown", "Lag Range Cooldown", "Lag_Range_Cooldown", "rangecooldown", g_esLagPlayer[admin].g_iLagRangeCooldown, value, 0, 99999);
		g_esLagPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esLagPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esLagAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esLagAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esLagAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esLagAbility[type].g_iComboAbility, value, 0, 1);
		g_esLagAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esLagAbility[type].g_iHumanAbility, value, 0, 2);
		g_esLagAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esLagAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esLagAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esLagAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esLagAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esLagAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esLagAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esLagAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esLagAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esLagAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esLagAbility[type].g_iLagAbility = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esLagAbility[type].g_iLagAbility, value, 0, 1);
		g_esLagAbility[type].g_iLagEffect = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esLagAbility[type].g_iLagEffect, value, 0, 7);
		g_esLagAbility[type].g_iLagMessage = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esLagAbility[type].g_iLagMessage, value, 0, 3);
		g_esLagAbility[type].g_flLagChance = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagChance", "Lag Chance", "Lag_Chance", "chance", g_esLagAbility[type].g_flLagChance, value, 0.0, 100.0);
		g_esLagAbility[type].g_iLagCooldown = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagCooldown", "Lag Cooldown", "Lag_Cooldown", "cooldown", g_esLagAbility[type].g_iLagCooldown, value, 0, 99999);
		g_esLagAbility[type].g_iLagDuration = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagDuration", "Lag Duration", "Lag_Duration", "duration", g_esLagAbility[type].g_iLagDuration, value, 1, 99999);
		g_esLagAbility[type].g_iLagHit = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagHit", "Lag Hit", "Lag_Hit", "hit", g_esLagAbility[type].g_iLagHit, value, 0, 1);
		g_esLagAbility[type].g_iLagHitMode = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagHitMode", "Lag Hit Mode", "Lag_Hit_Mode", "hitmode", g_esLagAbility[type].g_iLagHitMode, value, 0, 2);
		g_esLagAbility[type].g_flLagRange = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagRange", "Lag Range", "Lag_Range", "range", g_esLagAbility[type].g_flLagRange, value, 1.0, 99999.0);
		g_esLagAbility[type].g_flLagRangeChance = flGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagRangeChance", "Lag Range Chance", "Lag_Range_Chance", "rangechance", g_esLagAbility[type].g_flLagRangeChance, value, 0.0, 100.0);
		g_esLagAbility[type].g_iLagRangeCooldown = iGetKeyValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "LagRangeCooldown", "Lag Range Cooldown", "Lag_Range_Cooldown", "rangecooldown", g_esLagAbility[type].g_iLagRangeCooldown, value, 0, 99999);
		g_esLagAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esLagAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_LAG_SECTION, MT_LAG_SECTION2, MT_LAG_SECTION3, MT_LAG_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vLagSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esLagCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_flCloseAreasOnly, g_esLagAbility[type].g_flCloseAreasOnly);
	g_esLagCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iComboAbility, g_esLagAbility[type].g_iComboAbility);
	g_esLagCache[tank].g_flLagChance = flGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_flLagChance, g_esLagAbility[type].g_flLagChance);
	g_esLagCache[tank].g_flLagRange = flGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_flLagRange, g_esLagAbility[type].g_flLagRange);
	g_esLagCache[tank].g_flLagRangeChance = flGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_flLagRangeChance, g_esLagAbility[type].g_flLagRangeChance);
	g_esLagCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iHumanAbility, g_esLagAbility[type].g_iHumanAbility);
	g_esLagCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iHumanAmmo, g_esLagAbility[type].g_iHumanAmmo);
	g_esLagCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iHumanCooldown, g_esLagAbility[type].g_iHumanCooldown);
	g_esLagCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iHumanRangeCooldown, g_esLagAbility[type].g_iHumanRangeCooldown);
	g_esLagCache[tank].g_iLagAbility = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iLagAbility, g_esLagAbility[type].g_iLagAbility);
	g_esLagCache[tank].g_iLagCooldown = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iLagCooldown, g_esLagAbility[type].g_iLagCooldown);
	g_esLagCache[tank].g_iLagDuration = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iLagDuration, g_esLagAbility[type].g_iLagDuration);
	g_esLagCache[tank].g_iLagEffect = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iLagEffect, g_esLagAbility[type].g_iLagEffect);
	g_esLagCache[tank].g_iLagHit = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iLagHit, g_esLagAbility[type].g_iLagHit);
	g_esLagCache[tank].g_iLagMessage = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iLagMessage, g_esLagAbility[type].g_iLagMessage);
	g_esLagCache[tank].g_iLagHitMode = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iLagHitMode, g_esLagAbility[type].g_iLagHitMode);
	g_esLagCache[tank].g_iLagRangeCooldown = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iLagRangeCooldown, g_esLagAbility[type].g_iLagRangeCooldown);
	g_esLagCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_flOpenAreasOnly, g_esLagAbility[type].g_flOpenAreasOnly);
	g_esLagCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esLagPlayer[tank].g_iRequiresHumans, g_esLagAbility[type].g_iRequiresHumans);
	g_esLagPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vLagCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vLagCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveLag(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vLagEventFired(Event event, const char[] name)
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
			vLagCopyStats2(iBot, iTank);
			vRemoveLag(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vLagCopyStats2(iTank, iBot);
			vRemoveLag(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveLag(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vLagReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vLagAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLagAbility[g_esLagPlayer[tank].g_iTankType].g_iAccessFlags, g_esLagPlayer[tank].g_iAccessFlags)) || g_esLagCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esLagCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esLagCache[tank].g_iLagAbility == 1 && g_esLagCache[tank].g_iComboAbility == 0)
	{
		vLagAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vLagButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esLagCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLagCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLagPlayer[tank].g_iTankType) || (g_esLagCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLagCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLagAbility[g_esLagPlayer[tank].g_iTankType].g_iAccessFlags, g_esLagPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esLagCache[tank].g_iLagAbility == 1 && g_esLagCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esLagPlayer[tank].g_iRangeCooldown == -1 || g_esLagPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vLagAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "LagHuman3", (g_esLagPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLagChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveLag(tank);
}

void vLagAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esLagCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLagCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLagPlayer[tank].g_iTankType) || (g_esLagCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLagCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLagAbility[g_esLagPlayer[tank].g_iTankType].g_iAccessFlags, g_esLagPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esLagPlayer[tank].g_iAmmoCount < g_esLagCache[tank].g_iHumanAmmo && g_esLagCache[tank].g_iHumanAmmo > 0))
	{
		g_esLagPlayer[tank].g_bFailed = false;
		g_esLagPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esLagCache[tank].g_flLagRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esLagCache[tank].g_flLagRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esLagPlayer[tank].g_iTankType, g_esLagAbility[g_esLagPlayer[tank].g_iTankType].g_iImmunityFlags, g_esLagPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vLagHit(iSurvivor, tank, random, flChance, g_esLagCache[tank].g_iLagAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLagCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "LagHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLagCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "LagAmmo");
	}
}

void vLagHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esLagCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLagCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLagPlayer[tank].g_iTankType) || (g_esLagCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLagCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLagAbility[g_esLagPlayer[tank].g_iTankType].g_iAccessFlags, g_esLagPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esLagPlayer[tank].g_iTankType, g_esLagAbility[g_esLagPlayer[tank].g_iTankType].g_iImmunityFlags, g_esLagPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esLagPlayer[tank].g_iRangeCooldown != -1 && g_esLagPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esLagPlayer[tank].g_iCooldown != -1 && g_esLagPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esLagPlayer[tank].g_iAmmoCount < g_esLagCache[tank].g_iHumanAmmo && g_esLagCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esLagPlayer[survivor].g_bAffected)
			{
				g_esLagPlayer[survivor].g_bAffected = true;
				g_esLagPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esLagPlayer[tank].g_iRangeCooldown == -1 || g_esLagPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLagCache[tank].g_iHumanAbility == 1)
					{
						g_esLagPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LagHuman", g_esLagPlayer[tank].g_iAmmoCount, g_esLagCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esLagCache[tank].g_iLagRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLagCache[tank].g_iHumanAbility == 1 && g_esLagPlayer[tank].g_iAmmoCount < g_esLagCache[tank].g_iHumanAmmo && g_esLagCache[tank].g_iHumanAmmo > 0) ? g_esLagCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esLagPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esLagPlayer[tank].g_iRangeCooldown != -1 && g_esLagPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LagHuman5", (g_esLagPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esLagPlayer[tank].g_iCooldown == -1 || g_esLagPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esLagCache[tank].g_iLagCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLagCache[tank].g_iHumanAbility == 1) ? g_esLagCache[tank].g_iHumanCooldown : iCooldown;
					g_esLagPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esLagPlayer[tank].g_iCooldown != -1 && g_esLagPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LagHuman5", (g_esLagPlayer[tank].g_iCooldown - iTime));
					}
				}

				GetClientAbsOrigin(survivor, g_esLagPlayer[survivor].g_flPosition);

				int iSurvivorId = GetClientUserId(survivor), iTankId = GetClientUserId(tank);
				DataPack dpLagTeleport;
				CreateDataTimer(1.0, tTimerLagTeleport, dpLagTeleport, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpLagTeleport.WriteCell(iSurvivorId);
				dpLagTeleport.WriteCell(iTankId);
				dpLagTeleport.WriteCell(g_esLagPlayer[tank].g_iTankType);
				dpLagTeleport.WriteCell(messages);
				dpLagTeleport.WriteCell(enabled);
				dpLagTeleport.WriteCell(pos);
				dpLagTeleport.WriteCell(iTime);

				DataPack dpLagPosition;
				CreateDataTimer(0.5, tTimerLagPosition, dpLagPosition, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpLagPosition.WriteCell(iSurvivorId);
				dpLagPosition.WriteCell(iTankId);
				dpLagPosition.WriteCell(g_esLagPlayer[tank].g_iTankType);
				dpLagPosition.WriteCell(enabled);
				dpLagPosition.WriteCell(pos);
				dpLagPosition.WriteCell(iTime);

				vScreenEffect(survivor, tank, g_esLagCache[tank].g_iLagEffect, flags);

				if (g_esLagCache[tank].g_iLagMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Lag", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Lag", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esLagPlayer[tank].g_iRangeCooldown == -1 || g_esLagPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLagCache[tank].g_iHumanAbility == 1 && !g_esLagPlayer[tank].g_bFailed)
				{
					g_esLagPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "LagHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLagCache[tank].g_iHumanAbility == 1 && !g_esLagPlayer[tank].g_bNoAmmo)
		{
			g_esLagPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "LagAmmo");
		}
	}
}

void vLagCopyStats2(int oldTank, int newTank)
{
	g_esLagPlayer[newTank].g_iAmmoCount = g_esLagPlayer[oldTank].g_iAmmoCount;
	g_esLagPlayer[newTank].g_iCooldown = g_esLagPlayer[oldTank].g_iCooldown;
	g_esLagPlayer[newTank].g_iRangeCooldown = g_esLagPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveLag(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esLagPlayer[iSurvivor].g_bAffected && g_esLagPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esLagPlayer[iSurvivor].g_bAffected = false;
			g_esLagPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vLagReset3(tank);
}

void vLagReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vLagReset3(iPlayer);

			g_esLagPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vLagReset2(int survivor, int tank, int messages)
{
	g_esLagPlayer[survivor].g_bAffected = false;
	g_esLagPlayer[survivor].g_iOwner = 0;

	if (g_esLagCache[tank].g_iLagMessage & messages)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Lag2", survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Lag2", LANG_SERVER, survivor);
	}
}

void vLagReset3(int tank)
{
	g_esLagPlayer[tank].g_bAffected = false;
	g_esLagPlayer[tank].g_bFailed = false;
	g_esLagPlayer[tank].g_bNoAmmo = false;
	g_esLagPlayer[tank].g_iAmmoCount = 0;
	g_esLagPlayer[tank].g_iCooldown = -1;
	g_esLagPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerLagCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLagAbility[g_esLagPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLagPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLagPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esLagCache[iTank].g_iLagAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vLagAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerLagCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esLagPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLagAbility[g_esLagPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLagPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLagPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esLagCache[iTank].g_iLagHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esLagCache[iTank].g_iLagHitMode == 0 || g_esLagCache[iTank].g_iLagHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vLagHit(iSurvivor, iTank, flRandom, flChance, g_esLagCache[iTank].g_iLagHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esLagCache[iTank].g_iLagHitMode == 0 || g_esLagCache[iTank].g_iLagHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vLagHit(iSurvivor, iTank, flRandom, flChance, g_esLagCache[iTank].g_iLagHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerLagTeleport(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor))
	{
		g_esLagPlayer[iSurvivor].g_bAffected = false;
		g_esLagPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esLagCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esLagCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLagPlayer[iTank].g_iTankType) || (g_esLagCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLagCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLagAbility[g_esLagPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLagPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLagPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esLagPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esLagPlayer[iTank].g_iTankType, g_esLagAbility[g_esLagPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esLagPlayer[iSurvivor].g_iImmunityFlags) || !g_esLagPlayer[iSurvivor].g_bAffected)
	{
		vLagReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iLagEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esLagCache[iTank].g_iLagDuration,
		iTime = pack.ReadCell();
	if (iLagEnabled == 0 || (iTime + iDuration) < GetTime())
	{
		vLagReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	TeleportEntity(iSurvivor, g_esLagPlayer[iSurvivor].g_flPosition);

	return Plugin_Continue;
}

Action tTimerLagPosition(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor) || !g_esLagPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esLagCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esLagCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLagPlayer[iTank].g_iTankType) || (g_esLagCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLagCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLagAbility[g_esLagPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLagPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLagPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esLagPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esLagPlayer[iTank].g_iTankType, g_esLagAbility[g_esLagPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esLagPlayer[iSurvivor].g_iImmunityFlags))
	{
		return Plugin_Stop;
	}

	int iLagEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esLagCache[iTank].g_iLagDuration,
		iTime = pack.ReadCell();
	if (iLagEnabled == 0 || (iTime + iDuration) < GetTime())
	{
		return Plugin_Stop;
	}

	GetClientAbsOrigin(iSurvivor, g_esLagPlayer[iSurvivor].g_flPosition);

	return Plugin_Continue;
}