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

#define MT_DRUNK_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_DRUNK_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Drunk Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank makes survivors drunk.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Drunk Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_DRUNK_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_DRUNK_SECTION "drunkability"
#define MT_DRUNK_SECTION2 "drunk ability"
#define MT_DRUNK_SECTION3 "drunk_ability"
#define MT_DRUNK_SECTION4 "drunk"

#define MT_MENU_DRUNK "Drunk Ability"

enum struct esDrunkPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flDrunkChance;
	float g_flDrunkRange;
	float g_flDrunkRangeChance;
	float g_flDrunkSpeedInterval;
	float g_flDrunkTurnInterval;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iDrunkAbility;
	int g_iDrunkCooldown;
	int g_iDrunkDuration;
	int g_iDrunkEffect;
	int g_iDrunkHit;
	int g_iDrunkHitMode;
	int g_iDrunkMessage;
	int g_iDrunkRangeCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esDrunkPlayer g_esDrunkPlayer[MAXPLAYERS + 1];

enum struct esDrunkAbility
{
	float g_flCloseAreasOnly;
	float g_flDrunkChance;
	float g_flDrunkRange;
	float g_flDrunkRangeChance;
	float g_flDrunkSpeedInterval;
	float g_flDrunkTurnInterval;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iDrunkAbility;
	int g_iDrunkCooldown;
	int g_iDrunkDuration;
	int g_iDrunkEffect;
	int g_iDrunkHit;
	int g_iDrunkHitMode;
	int g_iDrunkMessage;
	int g_iDrunkRangeCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esDrunkAbility g_esDrunkAbility[MT_MAXTYPES + 1];

enum struct esDrunkCache
{
	float g_flCloseAreasOnly;
	float g_flDrunkChance;
	float g_flDrunkRange;
	float g_flDrunkRangeChance;
	float g_flDrunkSpeedInterval;
	float g_flDrunkTurnInterval;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iDrunkAbility;
	int g_iDrunkCooldown;
	int g_iDrunkDuration;
	int g_iDrunkEffect;
	int g_iDrunkHit;
	int g_iDrunkHitMode;
	int g_iDrunkMessage;
	int g_iDrunkRangeCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
}

esDrunkCache g_esDrunkCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_drunk", cmdDrunkInfo, "View information about the Drunk ability.");

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
void vDrunkMapStart()
#else
public void OnMapStart()
#endif
{
	vDrunkReset();
}

#if defined MT_ABILITIES_MAIN
void vDrunkClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnDrunkTakeDamage);
	vDrunkReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vDrunkClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vDrunkReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vDrunkMapEnd()
#else
public void OnMapEnd()
#endif
{
	vDrunkReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdDrunkInfo(int client, int args)
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
		case false: vDrunkMenu(client, MT_DRUNK_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vDrunkMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_DRUNK_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iDrunkMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Drunk Ability Information");
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

int iDrunkMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esDrunkCache[param1].g_iDrunkAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esDrunkCache[param1].g_iHumanAmmo - g_esDrunkPlayer[param1].g_iAmmoCount), g_esDrunkCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esDrunkCache[param1].g_iHumanAbility == 1) ? g_esDrunkCache[param1].g_iHumanCooldown : g_esDrunkCache[param1].g_iDrunkCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "DrunkDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esDrunkCache[param1].g_iDrunkDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esDrunkCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esDrunkCache[param1].g_iHumanAbility == 1) ? g_esDrunkCache[param1].g_iHumanRangeCooldown : g_esDrunkCache[param1].g_iDrunkRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vDrunkMenu(param1, MT_DRUNK_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pDrunk = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "DrunkMenu", param1);
			pDrunk.SetTitle(sMenuTitle);
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
void vDrunkDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_DRUNK, MT_MENU_DRUNK);
}

#if defined MT_ABILITIES_MAIN
void vDrunkMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_DRUNK, false))
	{
		vDrunkMenu(client, MT_DRUNK_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vDrunkMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_DRUNK, false))
	{
		FormatEx(buffer, size, "%T", "DrunkMenu2", client);
	}
}

Action OnDrunkTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esDrunkCache[attacker].g_iDrunkHitMode == 0 || g_esDrunkCache[attacker].g_iDrunkHitMode == 1) && bIsSurvivor(victim) && g_esDrunkCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esDrunkAbility[g_esDrunkPlayer[attacker].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esDrunkPlayer[attacker].g_iTankType, g_esDrunkAbility[g_esDrunkPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esDrunkPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vDrunkHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esDrunkCache[attacker].g_flDrunkChance, g_esDrunkCache[attacker].g_iDrunkHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esDrunkCache[victim].g_iDrunkHitMode == 0 || g_esDrunkCache[victim].g_iDrunkHitMode == 2) && bIsSurvivor(attacker) && g_esDrunkCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esDrunkAbility[g_esDrunkPlayer[victim].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esDrunkPlayer[victim].g_iTankType, g_esDrunkAbility[g_esDrunkPlayer[victim].g_iTankType].g_iImmunityFlags, g_esDrunkPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vDrunkHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esDrunkCache[victim].g_flDrunkChance, g_esDrunkCache[victim].g_iDrunkHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vDrunkPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_DRUNK);
}

#if defined MT_ABILITIES_MAIN
void vDrunkAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_DRUNK_SECTION);
	list2.PushString(MT_DRUNK_SECTION2);
	list3.PushString(MT_DRUNK_SECTION3);
	list4.PushString(MT_DRUNK_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vDrunkCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrunkCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_DRUNK_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_DRUNK_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_DRUNK_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_DRUNK_SECTION4);
	if (g_esDrunkCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_DRUNK_SECTION, false) || StrEqual(sSubset[iPos], MT_DRUNK_SECTION2, false) || StrEqual(sSubset[iPos], MT_DRUNK_SECTION3, false) || StrEqual(sSubset[iPos], MT_DRUNK_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esDrunkCache[tank].g_iDrunkAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vDrunkAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerDrunkCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esDrunkCache[tank].g_iDrunkHitMode == 0 || g_esDrunkCache[tank].g_iDrunkHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vDrunkHit(survivor, tank, random, flChance, g_esDrunkCache[tank].g_iDrunkHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esDrunkCache[tank].g_iDrunkHitMode == 0 || g_esDrunkCache[tank].g_iDrunkHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vDrunkHit(survivor, tank, random, flChance, g_esDrunkCache[tank].g_iDrunkHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerDrunkCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vDrunkConfigsLoad(int mode)
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
				g_esDrunkAbility[iIndex].g_iAccessFlags = 0;
				g_esDrunkAbility[iIndex].g_iImmunityFlags = 0;
				g_esDrunkAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esDrunkAbility[iIndex].g_iComboAbility = 0;
				g_esDrunkAbility[iIndex].g_iHumanAbility = 0;
				g_esDrunkAbility[iIndex].g_iHumanAmmo = 5;
				g_esDrunkAbility[iIndex].g_iHumanCooldown = 0;
				g_esDrunkAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esDrunkAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esDrunkAbility[iIndex].g_iRequiresHumans = 0;
				g_esDrunkAbility[iIndex].g_iDrunkAbility = 0;
				g_esDrunkAbility[iIndex].g_iDrunkEffect = 0;
				g_esDrunkAbility[iIndex].g_iDrunkMessage = 0;
				g_esDrunkAbility[iIndex].g_flDrunkChance = 33.3;
				g_esDrunkAbility[iIndex].g_iDrunkCooldown = 0;
				g_esDrunkAbility[iIndex].g_iDrunkDuration = 5;
				g_esDrunkAbility[iIndex].g_iDrunkHit = 0;
				g_esDrunkAbility[iIndex].g_iDrunkHitMode = 0;
				g_esDrunkAbility[iIndex].g_flDrunkRange = 150.0;
				g_esDrunkAbility[iIndex].g_flDrunkRangeChance = 15.0;
				g_esDrunkAbility[iIndex].g_iDrunkRangeCooldown = 0;
				g_esDrunkAbility[iIndex].g_flDrunkSpeedInterval = 1.5;
				g_esDrunkAbility[iIndex].g_flDrunkTurnInterval = 0.5;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esDrunkPlayer[iPlayer].g_iAccessFlags = 0;
					g_esDrunkPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esDrunkPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esDrunkPlayer[iPlayer].g_iComboAbility = 0;
					g_esDrunkPlayer[iPlayer].g_iHumanAbility = 0;
					g_esDrunkPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esDrunkPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esDrunkPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esDrunkPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esDrunkPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esDrunkPlayer[iPlayer].g_iDrunkAbility = 0;
					g_esDrunkPlayer[iPlayer].g_iDrunkEffect = 0;
					g_esDrunkPlayer[iPlayer].g_iDrunkMessage = 0;
					g_esDrunkPlayer[iPlayer].g_flDrunkChance = 0.0;
					g_esDrunkPlayer[iPlayer].g_iDrunkCooldown = 0;
					g_esDrunkPlayer[iPlayer].g_iDrunkDuration = 0;
					g_esDrunkPlayer[iPlayer].g_iDrunkHit = 0;
					g_esDrunkPlayer[iPlayer].g_iDrunkHitMode = 0;
					g_esDrunkPlayer[iPlayer].g_flDrunkRange = 0.0;
					g_esDrunkPlayer[iPlayer].g_flDrunkRangeChance = 0.0;
					g_esDrunkPlayer[iPlayer].g_iDrunkRangeCooldown = 0;
					g_esDrunkPlayer[iPlayer].g_flDrunkSpeedInterval = 0.0;
					g_esDrunkPlayer[iPlayer].g_flDrunkTurnInterval = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vDrunkConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esDrunkPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esDrunkPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esDrunkPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esDrunkPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esDrunkPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esDrunkPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esDrunkPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esDrunkPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esDrunkPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esDrunkPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esDrunkPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esDrunkPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esDrunkPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esDrunkPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esDrunkPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esDrunkPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esDrunkPlayer[admin].g_iDrunkAbility = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esDrunkPlayer[admin].g_iDrunkAbility, value, 0, 1);
		g_esDrunkPlayer[admin].g_iDrunkEffect = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esDrunkPlayer[admin].g_iDrunkEffect, value, 0, 7);
		g_esDrunkPlayer[admin].g_iDrunkMessage = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esDrunkPlayer[admin].g_iDrunkMessage, value, 0, 3);
		g_esDrunkPlayer[admin].g_flDrunkChance = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkChance", "Drunk Chance", "Drunk_Chance", "chance", g_esDrunkPlayer[admin].g_flDrunkChance, value, 0.0, 100.0);
		g_esDrunkPlayer[admin].g_iDrunkCooldown = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkCooldown", "Drunk Cooldown", "Drunk_Cooldown", "cooldown", g_esDrunkPlayer[admin].g_iDrunkCooldown, value, 0, 99999);
		g_esDrunkPlayer[admin].g_iDrunkDuration = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkDuration", "Drunk Duration", "Drunk_Duration", "duration", g_esDrunkPlayer[admin].g_iDrunkDuration, value, 1, 99999);
		g_esDrunkPlayer[admin].g_iDrunkHit = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkHit", "Drunk Hit", "Drunk_Hit", "hit", g_esDrunkPlayer[admin].g_iDrunkHit, value, 0, 1);
		g_esDrunkPlayer[admin].g_iDrunkHitMode = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkHitMode", "Drunk Hit Mode", "Drunk_Hit_Mode", "hitmode", g_esDrunkPlayer[admin].g_iDrunkHitMode, value, 0, 2);
		g_esDrunkPlayer[admin].g_flDrunkRange = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkRange", "Drunk Range", "Drunk_Range", "range", g_esDrunkPlayer[admin].g_flDrunkRange, value, 1.0, 99999.0);
		g_esDrunkPlayer[admin].g_flDrunkRangeChance = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkRangeChance", "Drunk Range Chance", "Drunk_Range_Chance", "rangechance", g_esDrunkPlayer[admin].g_flDrunkRangeChance, value, 0.0, 100.0);
		g_esDrunkPlayer[admin].g_iDrunkRangeCooldown = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkRangeCooldown", "Drunk Range Cooldown", "Drunk_Range_Cooldown", "rangecooldown", g_esDrunkPlayer[admin].g_iDrunkRangeCooldown, value, 0, 99999);
		g_esDrunkPlayer[admin].g_flDrunkSpeedInterval = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkSpeedInterval", "Drunk Speed Interval", "Drunk_Speed_Interval", "speedinterval", g_esDrunkPlayer[admin].g_flDrunkSpeedInterval, value, 0.1, 99999.0);
		g_esDrunkPlayer[admin].g_flDrunkTurnInterval = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkTurnInterval", "Drunk Turn Interval", "Drunk_Turn_Interval", "turninterval", g_esDrunkPlayer[admin].g_flDrunkTurnInterval, value, 0.1, 99999.0);
		g_esDrunkPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esDrunkPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esDrunkAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esDrunkAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esDrunkAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esDrunkAbility[type].g_iComboAbility, value, 0, 1);
		g_esDrunkAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esDrunkAbility[type].g_iHumanAbility, value, 0, 2);
		g_esDrunkAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esDrunkAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esDrunkAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esDrunkAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esDrunkAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esDrunkAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esDrunkAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esDrunkAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esDrunkAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esDrunkAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esDrunkAbility[type].g_iDrunkAbility = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esDrunkAbility[type].g_iDrunkAbility, value, 0, 1);
		g_esDrunkAbility[type].g_iDrunkEffect = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esDrunkAbility[type].g_iDrunkEffect, value, 0, 7);
		g_esDrunkAbility[type].g_iDrunkMessage = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esDrunkAbility[type].g_iDrunkMessage, value, 0, 3);
		g_esDrunkAbility[type].g_flDrunkChance = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkChance", "Drunk Chance", "Drunk_Chance", "chance", g_esDrunkAbility[type].g_flDrunkChance, value, 0.0, 100.0);
		g_esDrunkAbility[type].g_iDrunkCooldown = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkCooldown", "Drunk Cooldown", "Drunk_Cooldown", "cooldown", g_esDrunkAbility[type].g_iDrunkCooldown, value, 0, 99999);
		g_esDrunkAbility[type].g_iDrunkDuration = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkDuration", "Drunk Duration", "Drunk_Duration", "duration", g_esDrunkAbility[type].g_iDrunkDuration, value, 1, 99999);
		g_esDrunkAbility[type].g_iDrunkHit = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkHit", "Drunk Hit", "Drunk_Hit", "hit", g_esDrunkAbility[type].g_iDrunkHit, value, 0, 1);
		g_esDrunkAbility[type].g_iDrunkHitMode = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkHitMode", "Drunk Hit Mode", "Drunk_Hit_Mode", "hitmode", g_esDrunkAbility[type].g_iDrunkHitMode, value, 0, 2);
		g_esDrunkAbility[type].g_flDrunkRange = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkRange", "Drunk Range", "Drunk_Range", "range", g_esDrunkAbility[type].g_flDrunkRange, value, 1.0, 99999.0);
		g_esDrunkAbility[type].g_flDrunkRangeChance = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkRangeChance", "Drunk Range Chance", "Drunk_Range_Chance", "rangechance", g_esDrunkAbility[type].g_flDrunkRangeChance, value, 0.0, 100.0);
		g_esDrunkAbility[type].g_iDrunkRangeCooldown = iGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkRangeCooldown", "Drunk Range Cooldown", "Drunk_Range_Cooldown", "rangecooldown", g_esDrunkAbility[type].g_iDrunkRangeCooldown, value, 0, 99999);
		g_esDrunkAbility[type].g_flDrunkSpeedInterval = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkSpeedInterval", "Drunk Speed Interval", "Drunk_Speed_Interval", "speedinterval", g_esDrunkAbility[type].g_flDrunkSpeedInterval, value, 0.1, 99999.0);
		g_esDrunkAbility[type].g_flDrunkTurnInterval = flGetKeyValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "DrunkTurnInterval", "Drunk Turn Interval", "Drunk_Turn_Interval", "turninterval", g_esDrunkAbility[type].g_flDrunkTurnInterval, value, 0.1, 99999.0);
		g_esDrunkAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esDrunkAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_DRUNK_SECTION, MT_DRUNK_SECTION2, MT_DRUNK_SECTION3, MT_DRUNK_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vDrunkSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esDrunkCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_flCloseAreasOnly, g_esDrunkAbility[type].g_flCloseAreasOnly);
	g_esDrunkCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iComboAbility, g_esDrunkAbility[type].g_iComboAbility);
	g_esDrunkCache[tank].g_flDrunkChance = flGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_flDrunkChance, g_esDrunkAbility[type].g_flDrunkChance);
	g_esDrunkCache[tank].g_flDrunkRange = flGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_flDrunkRange, g_esDrunkAbility[type].g_flDrunkRange);
	g_esDrunkCache[tank].g_flDrunkRangeChance = flGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_flDrunkRangeChance, g_esDrunkAbility[type].g_flDrunkRangeChance);
	g_esDrunkCache[tank].g_flDrunkSpeedInterval = flGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_flDrunkSpeedInterval, g_esDrunkAbility[type].g_flDrunkSpeedInterval);
	g_esDrunkCache[tank].g_flDrunkTurnInterval = flGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_flDrunkTurnInterval, g_esDrunkAbility[type].g_flDrunkTurnInterval);
	g_esDrunkCache[tank].g_iDrunkAbility = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iDrunkAbility, g_esDrunkAbility[type].g_iDrunkAbility);
	g_esDrunkCache[tank].g_iDrunkCooldown = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iDrunkCooldown, g_esDrunkAbility[type].g_iDrunkCooldown);
	g_esDrunkCache[tank].g_iDrunkDuration = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iDrunkDuration, g_esDrunkAbility[type].g_iDrunkDuration);
	g_esDrunkCache[tank].g_iDrunkEffect = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iDrunkEffect, g_esDrunkAbility[type].g_iDrunkEffect);
	g_esDrunkCache[tank].g_iDrunkHit = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iDrunkHit, g_esDrunkAbility[type].g_iDrunkHit);
	g_esDrunkCache[tank].g_iDrunkHitMode = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iDrunkHitMode, g_esDrunkAbility[type].g_iDrunkHitMode);
	g_esDrunkCache[tank].g_iDrunkMessage = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iDrunkMessage, g_esDrunkAbility[type].g_iDrunkMessage);
	g_esDrunkCache[tank].g_iDrunkRangeCooldown = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iDrunkRangeCooldown, g_esDrunkAbility[type].g_iDrunkRangeCooldown);
	g_esDrunkCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iHumanAbility, g_esDrunkAbility[type].g_iHumanAbility);
	g_esDrunkCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iHumanAmmo, g_esDrunkAbility[type].g_iHumanAmmo);
	g_esDrunkCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iHumanCooldown, g_esDrunkAbility[type].g_iHumanCooldown);
	g_esDrunkCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iHumanRangeCooldown, g_esDrunkAbility[type].g_iHumanRangeCooldown);
	g_esDrunkCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_flOpenAreasOnly, g_esDrunkAbility[type].g_flOpenAreasOnly);
	g_esDrunkCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esDrunkPlayer[tank].g_iRequiresHumans, g_esDrunkAbility[type].g_iRequiresHumans);
	g_esDrunkPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vDrunkCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vDrunkCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveDrunk(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vDrunkPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esDrunkPlayer[iSurvivor].g_bAffected)
		{
			SetEntPropFloat(iSurvivor, Prop_Send, "m_flLaggedMovementValue", 1.0);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vDrunkEventFired(Event event, const char[] name)
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
			vDrunkCopyStats2(iBot, iTank);
			vRemoveDrunk(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vDrunkCopyStats2(iTank, iBot);
			vRemoveDrunk(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveDrunk(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vDrunkReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vDrunkAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDrunkAbility[g_esDrunkPlayer[tank].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[tank].g_iAccessFlags)) || g_esDrunkCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esDrunkCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esDrunkCache[tank].g_iDrunkAbility == 1 && g_esDrunkCache[tank].g_iComboAbility == 0)
	{
		vDrunkAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vDrunkButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esDrunkCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esDrunkCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDrunkPlayer[tank].g_iTankType) || (g_esDrunkCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDrunkCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDrunkAbility[g_esDrunkPlayer[tank].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esDrunkCache[tank].g_iDrunkAbility == 1 && g_esDrunkCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esDrunkPlayer[tank].g_iRangeCooldown == -1 || g_esDrunkPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vDrunkAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrunkHuman3", (g_esDrunkPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vDrunkChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveDrunk(tank);
}

void vDrunkAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esDrunkCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esDrunkCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDrunkPlayer[tank].g_iTankType) || (g_esDrunkCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDrunkCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDrunkAbility[g_esDrunkPlayer[tank].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esDrunkPlayer[tank].g_iAmmoCount < g_esDrunkCache[tank].g_iHumanAmmo && g_esDrunkCache[tank].g_iHumanAmmo > 0))
	{
		g_esDrunkPlayer[tank].g_bFailed = false;
		g_esDrunkPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esDrunkCache[tank].g_flDrunkRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esDrunkCache[tank].g_flDrunkRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esDrunkPlayer[tank].g_iTankType, g_esDrunkAbility[g_esDrunkPlayer[tank].g_iTankType].g_iImmunityFlags, g_esDrunkPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vDrunkHit(iSurvivor, tank, random, flChance, g_esDrunkCache[tank].g_iDrunkAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrunkCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrunkHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrunkCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrunkAmmo");
	}
}

void vDrunkHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esDrunkCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esDrunkCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDrunkPlayer[tank].g_iTankType) || (g_esDrunkCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDrunkCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDrunkAbility[g_esDrunkPlayer[tank].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esDrunkPlayer[tank].g_iTankType, g_esDrunkAbility[g_esDrunkPlayer[tank].g_iTankType].g_iImmunityFlags, g_esDrunkPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esDrunkPlayer[tank].g_iRangeCooldown != -1 && g_esDrunkPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esDrunkPlayer[tank].g_iCooldown != -1 && g_esDrunkPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esDrunkPlayer[tank].g_iAmmoCount < g_esDrunkCache[tank].g_iHumanAmmo && g_esDrunkCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esDrunkPlayer[survivor].g_bAffected)
			{
				g_esDrunkPlayer[survivor].g_bAffected = true;
				g_esDrunkPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esDrunkPlayer[tank].g_iRangeCooldown == -1 || g_esDrunkPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrunkCache[tank].g_iHumanAbility == 1)
					{
						g_esDrunkPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrunkHuman", g_esDrunkPlayer[tank].g_iAmmoCount, g_esDrunkCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esDrunkCache[tank].g_iDrunkRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrunkCache[tank].g_iHumanAbility == 1 && g_esDrunkPlayer[tank].g_iAmmoCount < g_esDrunkCache[tank].g_iHumanAmmo && g_esDrunkCache[tank].g_iHumanAmmo > 0) ? g_esDrunkCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esDrunkPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esDrunkPlayer[tank].g_iRangeCooldown != -1 && g_esDrunkPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrunkHuman5", (g_esDrunkPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esDrunkPlayer[tank].g_iCooldown == -1 || g_esDrunkPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esDrunkCache[tank].g_iDrunkCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrunkCache[tank].g_iHumanAbility == 1) ? g_esDrunkCache[tank].g_iHumanCooldown : iCooldown;
					g_esDrunkPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esDrunkPlayer[tank].g_iCooldown != -1 && g_esDrunkPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrunkHuman5", (g_esDrunkPlayer[tank].g_iCooldown - iTime));
					}
				}

				int iSurvivorId = GetClientUserId(survivor), iTankId = GetClientUserId(tank), iType = g_esDrunkPlayer[tank].g_iTankType;
				float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esDrunkCache[tank].g_flDrunkTurnInterval,
					flInterval2 = (pos != -1) ? (flInterval + 1.0) : g_esDrunkCache[tank].g_flDrunkSpeedInterval;

				DataPack dpDrunkSpeed;
				CreateDataTimer(flInterval2, tTimerDrunkSpeed, dpDrunkSpeed, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpDrunkSpeed.WriteCell(iSurvivorId);
				dpDrunkSpeed.WriteCell(iTankId);
				dpDrunkSpeed.WriteCell(iType);
				dpDrunkSpeed.WriteCell(enabled);
				dpDrunkSpeed.WriteCell(pos);
				dpDrunkSpeed.WriteCell(iTime);

				DataPack dpDrunkTurn;
				CreateDataTimer(flInterval, tTimerDrunkTurn, dpDrunkTurn, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpDrunkTurn.WriteCell(iSurvivorId);
				dpDrunkTurn.WriteCell(iTankId);
				dpDrunkTurn.WriteCell(iType);
				dpDrunkTurn.WriteCell(messages);
				dpDrunkTurn.WriteCell(enabled);
				dpDrunkTurn.WriteCell(pos);
				dpDrunkTurn.WriteCell(iTime);

				vScreenEffect(survivor, tank, g_esDrunkCache[tank].g_iDrunkEffect, flags);

				if (g_esDrunkCache[tank].g_iDrunkMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Drunk", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Drunk", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esDrunkPlayer[tank].g_iRangeCooldown == -1 || g_esDrunkPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrunkCache[tank].g_iHumanAbility == 1 && !g_esDrunkPlayer[tank].g_bFailed)
				{
					g_esDrunkPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrunkHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrunkCache[tank].g_iHumanAbility == 1 && !g_esDrunkPlayer[tank].g_bNoAmmo)
		{
			g_esDrunkPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrunkAmmo");
		}
	}
}

void vDrunkCopyStats2(int oldTank, int newTank)
{
	g_esDrunkPlayer[newTank].g_iAmmoCount = g_esDrunkPlayer[oldTank].g_iAmmoCount;
	g_esDrunkPlayer[newTank].g_iCooldown = g_esDrunkPlayer[oldTank].g_iCooldown;
	g_esDrunkPlayer[newTank].g_iRangeCooldown = g_esDrunkPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveDrunk(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esDrunkPlayer[iSurvivor].g_bAffected && g_esDrunkPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esDrunkPlayer[iSurvivor].g_bAffected = false;
			g_esDrunkPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vDrunkReset3(tank);
}

void vDrunkReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vDrunkReset3(iPlayer);

			g_esDrunkPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vDrunkReset2(int survivor, int tank, int messages)
{
	g_esDrunkPlayer[survivor].g_bAffected = false;
	g_esDrunkPlayer[survivor].g_iOwner = 0;

	if (g_esDrunkCache[tank].g_iDrunkMessage & messages)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Drunk2", survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Drunk2", LANG_SERVER, survivor);
	}
}

void vDrunkReset3(int tank)
{
	g_esDrunkPlayer[tank].g_bAffected = false;
	g_esDrunkPlayer[tank].g_bFailed = false;
	g_esDrunkPlayer[tank].g_bNoAmmo = false;
	g_esDrunkPlayer[tank].g_iAmmoCount = 0;
	g_esDrunkPlayer[tank].g_iCooldown = -1;
	g_esDrunkPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerDrunkCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDrunkAbility[g_esDrunkPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDrunkPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esDrunkCache[iTank].g_iDrunkAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vDrunkAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerDrunkCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esDrunkPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDrunkAbility[g_esDrunkPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDrunkPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esDrunkCache[iTank].g_iDrunkHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esDrunkCache[iTank].g_iDrunkHitMode == 0 || g_esDrunkCache[iTank].g_iDrunkHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vDrunkHit(iSurvivor, iTank, flRandom, flChance, g_esDrunkCache[iTank].g_iDrunkHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esDrunkCache[iTank].g_iDrunkHitMode == 0 || g_esDrunkCache[iTank].g_iDrunkHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vDrunkHit(iSurvivor, iTank, flRandom, flChance, g_esDrunkCache[iTank].g_iDrunkHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerDrunkSpeed(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor) || !g_esDrunkPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDrunkAbility[g_esDrunkPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDrunkPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esDrunkPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esDrunkPlayer[iTank].g_iTankType, g_esDrunkAbility[g_esDrunkPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esDrunkPlayer[iSurvivor].g_iImmunityFlags))
	{
		return Plugin_Stop;
	}

	int iDrunkEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esDrunkCache[iTank].g_iDrunkDuration,
		iTime = pack.ReadCell();
	if (iDrunkEnabled == 0 || (iTime + iDuration < GetTime()))
	{
		return Plugin_Stop;
	}

	SetEntPropFloat(iSurvivor, Prop_Send, "m_flLaggedMovementValue", MT_GetRandomFloat(1.5, 3.0));
	CreateTimer(MT_GetRandomFloat(1.0, 3.0), tTimerStopDrunkSpeed, GetClientUserId(iSurvivor), TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

Action tTimerDrunkTurn(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor))
	{
		g_esDrunkPlayer[iSurvivor].g_bAffected = false;
		g_esDrunkPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDrunkAbility[g_esDrunkPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDrunkPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDrunkPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esDrunkPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esDrunkPlayer[iTank].g_iTankType, g_esDrunkAbility[g_esDrunkPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esDrunkPlayer[iSurvivor].g_iImmunityFlags) || !g_esDrunkPlayer[iSurvivor].g_bAffected)
	{
		vDrunkReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iDrunkEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esDrunkCache[iTank].g_iDrunkDuration,
		iTime = pack.ReadCell();
	if (iDrunkEnabled == 0 || (iTime + iDuration < GetTime()))
	{
		vDrunkReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	float flPunchAngles[3], flEyeAngles[3], flAngle = MT_GetRandomFloat(-360.0, 360.0);
	flPunchAngles[0] = 0.0;
	flPunchAngles[1] = 0.0;
	flPunchAngles[2] = 0.0;
	GetClientEyeAngles(iSurvivor, flEyeAngles);

	flEyeAngles[1] -= flAngle;
	flPunchAngles[1] += flAngle;

	TeleportEntity(iSurvivor, .angles = flEyeAngles);
	SetEntPropVector(iSurvivor, Prop_Data, "m_vecPunchAngle", flPunchAngles);

	return Plugin_Continue;
}

Action tTimerStopDrunkSpeed(Handle timer, int userid)
{
	int iSurvivor = GetClientOfUserId(userid);
	if (!bIsSurvivor(iSurvivor))
	{
		return Plugin_Stop;
	}

	SetEntPropFloat(iSurvivor, Prop_Send, "m_flLaggedMovementValue", 1.0);

	return Plugin_Continue;
}