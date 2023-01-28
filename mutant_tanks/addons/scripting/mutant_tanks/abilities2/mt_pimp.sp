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

#define MT_PIMP_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_PIMP_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Pimp Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank pimp slaps survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Pimp Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_PIMP_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_PIMP_SECTION "pimpability"
#define MT_PIMP_SECTION2 "pimp ability"
#define MT_PIMP_SECTION3 "pimp_ability"
#define MT_PIMP_SECTION4 "pimp"

#define MT_MENU_PIMP "Pimp Ability"

enum struct esPimpPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flPimpChance;
	float g_flPimpInterval;
	float g_flPimpRange;
	float g_flPimpRangeChance;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iOwner;
	int g_iPimpAbility;
	int g_iPimpCooldown;
	int g_iPimpDamage;
	int g_iPimpDuration;
	int g_iPimpEffect;
	int g_iPimpHit;
	int g_iPimpHitMode;
	int g_iPimpMessage;
	int g_iPimpRangeCooldown;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esPimpPlayer g_esPimpPlayer[MAXPLAYERS + 1];

enum struct esPimpAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flPimpChance;
	float g_flPimpInterval;
	float g_flPimpRange;
	float g_flPimpRangeChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iPimpAbility;
	int g_iPimpCooldown;
	int g_iPimpDamage;
	int g_iPimpDuration;
	int g_iPimpEffect;
	int g_iPimpHit;
	int g_iPimpHitMode;
	int g_iPimpMessage;
	int g_iPimpRangeCooldown;
	int g_iRequiresHumans;
}

esPimpAbility g_esPimpAbility[MT_MAXTYPES + 1];

enum struct esPimpCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flPimpChance;
	float g_flPimpInterval;
	float g_flPimpRange;
	float g_flPimpRangeChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iPimpAbility;
	int g_iPimpCooldown;
	int g_iPimpDamage;
	int g_iPimpDuration;
	int g_iPimpEffect;
	int g_iPimpHit;
	int g_iPimpHitMode;
	int g_iPimpMessage;
	int g_iPimpRangeCooldown;
	int g_iRequiresHumans;
}

esPimpCache g_esPimpCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_pimp", cmdPimpInfo, "View information about the Pimp ability.");

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
void vPimpMapStart()
#else
public void OnMapStart()
#endif
{
	vPimpReset();
}

#if defined MT_ABILITIES_MAIN2
void vPimpClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnPimpTakeDamage);
	vRemovePimp(client);
}

#if defined MT_ABILITIES_MAIN2
void vPimpClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemovePimp(client);
}

#if defined MT_ABILITIES_MAIN2
void vPimpMapEnd()
#else
public void OnMapEnd()
#endif
{
	vPimpReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdPimpInfo(int client, int args)
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
		case false: vPimpMenu(client, MT_PIMP_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vPimpMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_PIMP_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iPimpMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Pimp Ability Information");
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

int iPimpMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esPimpCache[param1].g_iPimpAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esPimpCache[param1].g_iHumanAmmo - g_esPimpPlayer[param1].g_iAmmoCount), g_esPimpCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esPimpCache[param1].g_iHumanAbility == 1) ? g_esPimpCache[param1].g_iHumanCooldown : g_esPimpCache[param1].g_iPimpCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "PimpDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esPimpCache[param1].g_iPimpDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esPimpCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esPimpCache[param1].g_iHumanAbility == 1) ? g_esPimpCache[param1].g_iHumanRangeCooldown : g_esPimpCache[param1].g_iPimpRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vPimpMenu(param1, MT_PIMP_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pPimp = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "PimpMenu", param1);
			pPimp.SetTitle(sMenuTitle);
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

#if defined MT_ABILITIES_MAIN2
void vPimpDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_PIMP, MT_MENU_PIMP);
}

#if defined MT_ABILITIES_MAIN2
void vPimpMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_PIMP, false))
	{
		vPimpMenu(client, MT_PIMP_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPimpMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_PIMP, false))
	{
		FormatEx(buffer, size, "%T", "PimpMenu2", client);
	}
}

Action OnPimpTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esPimpCache[attacker].g_iPimpHitMode == 0 || g_esPimpCache[attacker].g_iPimpHitMode == 1) && bIsSurvivor(victim) && g_esPimpCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esPimpAbility[g_esPimpPlayer[attacker].g_iTankType].g_iAccessFlags, g_esPimpPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esPimpPlayer[attacker].g_iTankType, g_esPimpAbility[g_esPimpPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esPimpPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vPimpHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esPimpCache[attacker].g_flPimpChance, g_esPimpCache[attacker].g_iPimpHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esPimpCache[victim].g_iPimpHitMode == 0 || g_esPimpCache[victim].g_iPimpHitMode == 2) && bIsSurvivor(attacker) && g_esPimpCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esPimpAbility[g_esPimpPlayer[victim].g_iTankType].g_iAccessFlags, g_esPimpPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esPimpPlayer[victim].g_iTankType, g_esPimpAbility[g_esPimpPlayer[victim].g_iTankType].g_iImmunityFlags, g_esPimpPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vPimpHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esPimpCache[victim].g_flPimpChance, g_esPimpCache[victim].g_iPimpHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vPimpPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_PIMP);
}

#if defined MT_ABILITIES_MAIN2
void vPimpAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_PIMP_SECTION);
	list2.PushString(MT_PIMP_SECTION2);
	list3.PushString(MT_PIMP_SECTION3);
	list4.PushString(MT_PIMP_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vPimpCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPimpCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_PIMP_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_PIMP_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_PIMP_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_PIMP_SECTION4);
	if (g_esPimpCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_PIMP_SECTION, false) || StrEqual(sSubset[iPos], MT_PIMP_SECTION2, false) || StrEqual(sSubset[iPos], MT_PIMP_SECTION3, false) || StrEqual(sSubset[iPos], MT_PIMP_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esPimpCache[tank].g_iPimpAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vPimpAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerPimpCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esPimpCache[tank].g_iPimpHitMode == 0 || g_esPimpCache[tank].g_iPimpHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vPimpHit(survivor, tank, random, flChance, g_esPimpCache[tank].g_iPimpHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esPimpCache[tank].g_iPimpHitMode == 0 || g_esPimpCache[tank].g_iPimpHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vPimpHit(survivor, tank, random, flChance, g_esPimpCache[tank].g_iPimpHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerPimpCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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

#if defined MT_ABILITIES_MAIN2
void vPimpConfigsLoad(int mode)
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
				g_esPimpAbility[iIndex].g_iAccessFlags = 0;
				g_esPimpAbility[iIndex].g_iImmunityFlags = 0;
				g_esPimpAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esPimpAbility[iIndex].g_iComboAbility = 0;
				g_esPimpAbility[iIndex].g_iHumanAbility = 0;
				g_esPimpAbility[iIndex].g_iHumanAmmo = 5;
				g_esPimpAbility[iIndex].g_iHumanCooldown = 0;
				g_esPimpAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esPimpAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esPimpAbility[iIndex].g_iRequiresHumans = 0;
				g_esPimpAbility[iIndex].g_iPimpAbility = 0;
				g_esPimpAbility[iIndex].g_iPimpEffect = 0;
				g_esPimpAbility[iIndex].g_iPimpMessage = 0;
				g_esPimpAbility[iIndex].g_flPimpChance = 33.3;
				g_esPimpAbility[iIndex].g_iPimpCooldown = 0;
				g_esPimpAbility[iIndex].g_iPimpDamage = 1;
				g_esPimpAbility[iIndex].g_iPimpDuration = 5;
				g_esPimpAbility[iIndex].g_iPimpHit = 0;
				g_esPimpAbility[iIndex].g_iPimpHitMode = 0;
				g_esPimpAbility[iIndex].g_flPimpInterval = 1.0;
				g_esPimpAbility[iIndex].g_flPimpRange = 150.0;
				g_esPimpAbility[iIndex].g_flPimpRangeChance = 15.0;
				g_esPimpAbility[iIndex].g_iPimpRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esPimpPlayer[iPlayer].g_iAccessFlags = 0;
					g_esPimpPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esPimpPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esPimpPlayer[iPlayer].g_iComboAbility = 0;
					g_esPimpPlayer[iPlayer].g_iHumanAbility = 0;
					g_esPimpPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esPimpPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esPimpPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esPimpPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esPimpPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esPimpPlayer[iPlayer].g_iPimpAbility = 0;
					g_esPimpPlayer[iPlayer].g_iPimpEffect = 0;
					g_esPimpPlayer[iPlayer].g_iPimpMessage = 0;
					g_esPimpPlayer[iPlayer].g_flPimpChance = 0.0;
					g_esPimpPlayer[iPlayer].g_iPimpCooldown = 0;
					g_esPimpPlayer[iPlayer].g_iPimpDamage = 0;
					g_esPimpPlayer[iPlayer].g_iPimpDuration = 0;
					g_esPimpPlayer[iPlayer].g_iPimpHit = 0;
					g_esPimpPlayer[iPlayer].g_iPimpHitMode = 0;
					g_esPimpPlayer[iPlayer].g_flPimpInterval = 0.0;
					g_esPimpPlayer[iPlayer].g_flPimpRange = 0.0;
					g_esPimpPlayer[iPlayer].g_flPimpRangeChance = 0.0;
					g_esPimpPlayer[iPlayer].g_iPimpRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPimpConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esPimpPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esPimpPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esPimpPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esPimpPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esPimpPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esPimpPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esPimpPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esPimpPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esPimpPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esPimpPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esPimpPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esPimpPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esPimpPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esPimpPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esPimpPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esPimpPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esPimpPlayer[admin].g_iPimpAbility = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esPimpPlayer[admin].g_iPimpAbility, value, 0, 1);
		g_esPimpPlayer[admin].g_iPimpEffect = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esPimpPlayer[admin].g_iPimpEffect, value, 0, 7);
		g_esPimpPlayer[admin].g_iPimpMessage = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esPimpPlayer[admin].g_iPimpMessage, value, 0, 3);
		g_esPimpPlayer[admin].g_flPimpChance = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpChance", "Pimp Chance", "Pimp_Chance", "chance", g_esPimpPlayer[admin].g_flPimpChance, value, 0.0, 100.0);
		g_esPimpPlayer[admin].g_iPimpCooldown = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpCooldown", "Pimp Cooldown", "Pimp_Cooldown", "cooldown", g_esPimpPlayer[admin].g_iPimpCooldown, value, 0, 99999);
		g_esPimpPlayer[admin].g_iPimpDamage = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpDamage", "Pimp Damage", "Pimp_Damage", "damage", g_esPimpPlayer[admin].g_iPimpDamage, value, 0, 99999);
		g_esPimpPlayer[admin].g_iPimpDuration = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpDuration", "Pimp Duration", "Pimp_Duration", "duration", g_esPimpPlayer[admin].g_iPimpDuration, value, 1, 99999);
		g_esPimpPlayer[admin].g_iPimpHit = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpHit", "Pimp Hit", "Pimp_Hit", "hit", g_esPimpPlayer[admin].g_iPimpHit, value, 0, 1);
		g_esPimpPlayer[admin].g_iPimpHitMode = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpHitMode", "Pimp Hit Mode", "Pimp_Hit_Mode", "hitmode", g_esPimpPlayer[admin].g_iPimpHitMode, value, 0, 2);
		g_esPimpPlayer[admin].g_flPimpInterval = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpInterval", "Pimp Interval", "Pimp_Interval", "interval", g_esPimpPlayer[admin].g_flPimpInterval, value, 0.1, 99999.0);
		g_esPimpPlayer[admin].g_flPimpRange = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpRange", "Pimp Range", "Pimp_Range", "range", g_esPimpPlayer[admin].g_flPimpRange, value, 1.0, 99999.0);
		g_esPimpPlayer[admin].g_flPimpRangeChance = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpRangeChance", "Pimp Range Chance", "Pimp_Range_Chance", "rangechance", g_esPimpPlayer[admin].g_flPimpRangeChance, value, 0.0, 100.0);
		g_esPimpPlayer[admin].g_iPimpRangeCooldown = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpRangeCooldown", "Pimp Range Cooldown", "Pimp_Range_Cooldown", "rangecooldown", g_esPimpPlayer[admin].g_iPimpRangeCooldown, value, 0, 99999);
		g_esPimpPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esPimpPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esPimpAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esPimpAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esPimpAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esPimpAbility[type].g_iComboAbility, value, 0, 1);
		g_esPimpAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esPimpAbility[type].g_iHumanAbility, value, 0, 2);
		g_esPimpAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esPimpAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esPimpAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esPimpAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esPimpAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esPimpAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esPimpAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esPimpAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esPimpAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esPimpAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esPimpAbility[type].g_iPimpAbility = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esPimpAbility[type].g_iPimpAbility, value, 0, 1);
		g_esPimpAbility[type].g_iPimpEffect = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esPimpAbility[type].g_iPimpEffect, value, 0, 7);
		g_esPimpAbility[type].g_iPimpMessage = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esPimpAbility[type].g_iPimpMessage, value, 0, 3);
		g_esPimpAbility[type].g_flPimpChance = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpChance", "Pimp Chance", "Pimp_Chance", "chance", g_esPimpAbility[type].g_flPimpChance, value, 0.0, 100.0);
		g_esPimpAbility[type].g_iPimpCooldown = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpCooldown", "Pimp Cooldown", "Pimp_Cooldown", "cooldown", g_esPimpAbility[type].g_iPimpCooldown, value, 0, 99999);
		g_esPimpAbility[type].g_iPimpDamage = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpDamage", "Pimp Damage", "Pimp_Damage", "damage", g_esPimpAbility[type].g_iPimpDamage, value, 0, 99999);
		g_esPimpAbility[type].g_iPimpDuration = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpDuration", "Pimp Duration", "Pimp_Duration", "duration", g_esPimpAbility[type].g_iPimpDuration, value, 1, 99999);
		g_esPimpAbility[type].g_iPimpHit = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpHit", "Pimp Hit", "Pimp_Hit", "hit", g_esPimpAbility[type].g_iPimpHit, value, 0, 1);
		g_esPimpAbility[type].g_iPimpHitMode = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpHitMode", "Pimp Hit Mode", "Pimp_Hit_Mode", "hitmode", g_esPimpAbility[type].g_iPimpHitMode, value, 0, 2);
		g_esPimpAbility[type].g_flPimpInterval = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpInterval", "Pimp Interval", "Pimp_Interval", "interval", g_esPimpAbility[type].g_flPimpInterval, value, 0.1, 99999.0);
		g_esPimpAbility[type].g_flPimpRange = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpRange", "Pimp Range", "Pimp_Range", "range", g_esPimpAbility[type].g_flPimpRange, value, 1.0, 99999.0);
		g_esPimpAbility[type].g_flPimpRangeChance = flGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpRangeChance", "Pimp Range Chance", "Pimp_Range_Chance", "rangechance", g_esPimpAbility[type].g_flPimpRangeChance, value, 0.0, 100.0);
		g_esPimpAbility[type].g_iPimpRangeCooldown = iGetKeyValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "PimpRangeCooldown", "Pimp Range Cooldown", "Pimp_Range_Cooldown", "rangecooldown", g_esPimpAbility[type].g_iPimpRangeCooldown, value, 0, 99999);
		g_esPimpAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esPimpAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_PIMP_SECTION, MT_PIMP_SECTION2, MT_PIMP_SECTION3, MT_PIMP_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vPimpSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esPimpCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_flCloseAreasOnly, g_esPimpAbility[type].g_flCloseAreasOnly);
	g_esPimpCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iComboAbility, g_esPimpAbility[type].g_iComboAbility);
	g_esPimpCache[tank].g_flPimpChance = flGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_flPimpChance, g_esPimpAbility[type].g_flPimpChance);
	g_esPimpCache[tank].g_flPimpInterval = flGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_flPimpInterval, g_esPimpAbility[type].g_flPimpInterval);
	g_esPimpCache[tank].g_flPimpRange = flGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_flPimpRange, g_esPimpAbility[type].g_flPimpRange);
	g_esPimpCache[tank].g_flPimpRangeChance = flGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_flPimpRangeChance, g_esPimpAbility[type].g_flPimpRangeChance);
	g_esPimpCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iHumanAbility, g_esPimpAbility[type].g_iHumanAbility);
	g_esPimpCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iHumanAmmo, g_esPimpAbility[type].g_iHumanAmmo);
	g_esPimpCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iHumanCooldown, g_esPimpAbility[type].g_iHumanCooldown);
	g_esPimpCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iHumanRangeCooldown, g_esPimpAbility[type].g_iHumanRangeCooldown);
	g_esPimpCache[tank].g_iPimpAbility = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iPimpAbility, g_esPimpAbility[type].g_iPimpAbility);
	g_esPimpCache[tank].g_iPimpCooldown = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iPimpCooldown, g_esPimpAbility[type].g_iPimpCooldown);
	g_esPimpCache[tank].g_iPimpDamage = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iPimpDamage, g_esPimpAbility[type].g_iPimpDamage);
	g_esPimpCache[tank].g_iPimpDuration = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iPimpDuration, g_esPimpAbility[type].g_iPimpDuration);
	g_esPimpCache[tank].g_iPimpEffect = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iPimpEffect, g_esPimpAbility[type].g_iPimpEffect);
	g_esPimpCache[tank].g_iPimpHit = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iPimpHit, g_esPimpAbility[type].g_iPimpHit);
	g_esPimpCache[tank].g_iPimpHitMode = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iPimpHitMode, g_esPimpAbility[type].g_iPimpHitMode);
	g_esPimpCache[tank].g_iPimpMessage = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iPimpMessage, g_esPimpAbility[type].g_iPimpMessage);
	g_esPimpCache[tank].g_iPimpRangeCooldown = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iPimpRangeCooldown, g_esPimpAbility[type].g_iPimpRangeCooldown);
	g_esPimpCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_flOpenAreasOnly, g_esPimpAbility[type].g_flOpenAreasOnly);
	g_esPimpCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esPimpPlayer[tank].g_iRequiresHumans, g_esPimpAbility[type].g_iRequiresHumans);
	g_esPimpPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vPimpCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vPimpCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemovePimp(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vPimpEventFired(Event event, const char[] name)
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
			vPimpCopyStats2(iBot, iTank);
			vRemovePimp(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vPimpCopyStats2(iTank, iBot);
			vRemovePimp(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemovePimp(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vPimpReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vPimpAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPimpAbility[g_esPimpPlayer[tank].g_iTankType].g_iAccessFlags, g_esPimpPlayer[tank].g_iAccessFlags)) || g_esPimpCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esPimpCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esPimpCache[tank].g_iPimpAbility == 1 && g_esPimpCache[tank].g_iComboAbility == 0)
	{
		vPimpAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vPimpButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esPimpCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esPimpCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPimpPlayer[tank].g_iTankType) || (g_esPimpCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPimpCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPimpAbility[g_esPimpPlayer[tank].g_iTankType].g_iAccessFlags, g_esPimpPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esPimpCache[tank].g_iPimpAbility == 1 && g_esPimpCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esPimpPlayer[tank].g_iRangeCooldown == -1 || g_esPimpPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vPimpAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "PimpHuman3", (g_esPimpPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vPimpChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemovePimp(tank);
}

void vPimpAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esPimpCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esPimpCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPimpPlayer[tank].g_iTankType) || (g_esPimpCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPimpCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPimpAbility[g_esPimpPlayer[tank].g_iTankType].g_iAccessFlags, g_esPimpPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esPimpPlayer[tank].g_iAmmoCount < g_esPimpCache[tank].g_iHumanAmmo && g_esPimpCache[tank].g_iHumanAmmo > 0))
	{
		g_esPimpPlayer[tank].g_bFailed = false;
		g_esPimpPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esPimpCache[tank].g_flPimpRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esPimpCache[tank].g_flPimpRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esPimpPlayer[tank].g_iTankType, g_esPimpAbility[g_esPimpPlayer[tank].g_iTankType].g_iImmunityFlags, g_esPimpPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vPimpHit(iSurvivor, tank, random, flChance, g_esPimpCache[tank].g_iPimpAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPimpCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "PimpHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPimpCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "PimpAmmo");
	}
}

void vPimpHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esPimpCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esPimpCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPimpPlayer[tank].g_iTankType) || (g_esPimpCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPimpCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esPimpAbility[g_esPimpPlayer[tank].g_iTankType].g_iAccessFlags, g_esPimpPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esPimpPlayer[tank].g_iTankType, g_esPimpAbility[g_esPimpPlayer[tank].g_iTankType].g_iImmunityFlags, g_esPimpPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esPimpPlayer[tank].g_iRangeCooldown != -1 && g_esPimpPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esPimpPlayer[tank].g_iCooldown != -1 && g_esPimpPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esPimpPlayer[tank].g_iAmmoCount < g_esPimpCache[tank].g_iHumanAmmo && g_esPimpCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esPimpPlayer[survivor].g_bAffected)
			{
				g_esPimpPlayer[survivor].g_bAffected = true;
				g_esPimpPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esPimpPlayer[tank].g_iRangeCooldown == -1 || g_esPimpPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPimpCache[tank].g_iHumanAbility == 1)
					{
						g_esPimpPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "PimpHuman", g_esPimpPlayer[tank].g_iAmmoCount, g_esPimpCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esPimpCache[tank].g_iPimpRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPimpCache[tank].g_iHumanAbility == 1 && g_esPimpPlayer[tank].g_iAmmoCount < g_esPimpCache[tank].g_iHumanAmmo && g_esPimpCache[tank].g_iHumanAmmo > 0) ? g_esPimpCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esPimpPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esPimpPlayer[tank].g_iRangeCooldown != -1 && g_esPimpPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "PimpHuman5", (g_esPimpPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esPimpPlayer[tank].g_iCooldown == -1 || g_esPimpPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esPimpCache[tank].g_iPimpCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPimpCache[tank].g_iHumanAbility == 1) ? g_esPimpCache[tank].g_iHumanCooldown : iCooldown;
					g_esPimpPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esPimpPlayer[tank].g_iCooldown != -1 && g_esPimpPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "PimpHuman5", (g_esPimpPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esPimpCache[tank].g_flPimpInterval;
				DataPack dpPimp;
				CreateDataTimer(flInterval, tTimerPimp, dpPimp, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpPimp.WriteCell(GetClientUserId(survivor));
				dpPimp.WriteCell(GetClientUserId(tank));
				dpPimp.WriteCell(g_esPimpPlayer[tank].g_iTankType);
				dpPimp.WriteCell(messages);
				dpPimp.WriteCell(enabled);
				dpPimp.WriteCell(pos);
				dpPimp.WriteCell(iTime);

				vScreenEffect(survivor, tank, g_esPimpCache[tank].g_iPimpEffect, flags);

				if (g_esPimpCache[tank].g_iPimpMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Pimp", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Pimp", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esPimpPlayer[tank].g_iRangeCooldown == -1 || g_esPimpPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPimpCache[tank].g_iHumanAbility == 1 && !g_esPimpPlayer[tank].g_bFailed)
				{
					g_esPimpPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "PimpHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esPimpCache[tank].g_iHumanAbility == 1 && !g_esPimpPlayer[tank].g_bNoAmmo)
		{
			g_esPimpPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "PimpAmmo");
		}
	}
}

void vPimpCopyStats2(int oldTank, int newTank)
{
	g_esPimpPlayer[newTank].g_iAmmoCount = g_esPimpPlayer[oldTank].g_iAmmoCount;
	g_esPimpPlayer[newTank].g_iCooldown = g_esPimpPlayer[oldTank].g_iCooldown;
	g_esPimpPlayer[newTank].g_iRangeCooldown = g_esPimpPlayer[oldTank].g_iRangeCooldown;
}

void vRemovePimp(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esPimpPlayer[iSurvivor].g_bAffected && g_esPimpPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esPimpPlayer[iSurvivor].g_bAffected = false;
			g_esPimpPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vPimpReset3(tank);
}

void vPimpReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vPimpReset3(iPlayer);

			g_esPimpPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vPimpReset2(int survivor, int tank, int messages)
{
	g_esPimpPlayer[survivor].g_bAffected = false;
	g_esPimpPlayer[survivor].g_iOwner = 0;

	if (g_esPimpCache[tank].g_iPimpMessage & messages)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Pimp2", survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Pimp2", LANG_SERVER, survivor);
	}
}

void vPimpReset3(int tank)
{
	g_esPimpPlayer[tank].g_bAffected = false;
	g_esPimpPlayer[tank].g_bFailed = false;
	g_esPimpPlayer[tank].g_bNoAmmo = false;
	g_esPimpPlayer[tank].g_iAmmoCount = 0;
	g_esPimpPlayer[tank].g_iCooldown = -1;
	g_esPimpPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerPimpCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esPimpAbility[g_esPimpPlayer[iTank].g_iTankType].g_iAccessFlags, g_esPimpPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esPimpPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esPimpCache[iTank].g_iPimpAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vPimpAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerPimpCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esPimpPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esPimpAbility[g_esPimpPlayer[iTank].g_iTankType].g_iAccessFlags, g_esPimpPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esPimpPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esPimpCache[iTank].g_iPimpHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esPimpCache[iTank].g_iPimpHitMode == 0 || g_esPimpCache[iTank].g_iPimpHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vPimpHit(iSurvivor, iTank, flRandom, flChance, g_esPimpCache[iTank].g_iPimpHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esPimpCache[iTank].g_iPimpHitMode == 0 || g_esPimpCache[iTank].g_iPimpHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vPimpHit(iSurvivor, iTank, flRandom, flChance, g_esPimpCache[iTank].g_iPimpHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerPimp(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor))
	{
		g_esPimpPlayer[iSurvivor].g_bAffected = false;
		g_esPimpPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esPimpCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esPimpCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esPimpPlayer[iTank].g_iTankType) || (g_esPimpCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esPimpCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esPimpAbility[g_esPimpPlayer[iTank].g_iTankType].g_iAccessFlags, g_esPimpPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esPimpPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esPimpPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esPimpPlayer[iTank].g_iTankType, g_esPimpAbility[g_esPimpPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esPimpPlayer[iSurvivor].g_iImmunityFlags) || !g_esPimpPlayer[iSurvivor].g_bAffected || MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE))
	{
		vPimpReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iPimpEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esPimpCache[iTank].g_iPimpDuration,
		iTime = pack.ReadCell();
	if (iPimpEnabled == 0 || (iTime + iDuration) < GetTime() || !g_esPimpPlayer[iSurvivor].g_bAffected)
	{
		vPimpReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	float flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : float(g_esPimpCache[iTank].g_iPimpDamage);
	if (flDamage > 0.0)
	{
		SlapPlayer(iSurvivor, RoundToNearest(MT_GetScaledDamage(flDamage)), true);
	}

	return Plugin_Continue;
}