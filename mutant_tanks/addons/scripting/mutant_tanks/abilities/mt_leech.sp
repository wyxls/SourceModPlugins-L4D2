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

#define MT_LEECH_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_LEECH_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Leech Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank leeches health off of survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Leech Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_LEECH_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_LEECH_SECTION "leechability"
#define MT_LEECH_SECTION2 "leech ability"
#define MT_LEECH_SECTION3 "leech_ability"
#define MT_LEECH_SECTION4 "leech"

#define MT_MENU_LEECH "Leech Ability"

enum struct esLeechPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flLeechChance;
	float g_flLeechInterval;
	float g_flLeechRange;
	float g_flLeechRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iLeechAbility;
	int g_iLeechCooldown;
	int g_iLeechDuration;
	int g_iLeechEffect;
	int g_iLeechHit;
	int g_iLeechHitMode;
	int g_iLeechMessage;
	int g_iLeechRangeCooldown;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esLeechPlayer g_esLeechPlayer[MAXPLAYERS + 1];

enum struct esLeechAbility
{
	float g_flCloseAreasOnly;
	float g_flLeechChance;
	float g_flLeechInterval;
	float g_flLeechRange;
	float g_flLeechRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iLeechAbility;
	int g_iLeechCooldown;
	int g_iLeechDuration;
	int g_iLeechEffect;
	int g_iLeechHit;
	int g_iLeechHitMode;
	int g_iLeechMessage;
	int g_iLeechRangeCooldown;
	int g_iRequiresHumans;
}

esLeechAbility g_esLeechAbility[MT_MAXTYPES + 1];

enum struct esLeechCache
{
	float g_flCloseAreasOnly;
	float g_flLeechChance;
	float g_flLeechInterval;
	float g_flLeechRange;
	float g_flLeechRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iLeechAbility;
	int g_iLeechCooldown;
	int g_iLeechDuration;
	int g_iLeechEffect;
	int g_iLeechHit;
	int g_iLeechHitMode;
	int g_iLeechMessage;
	int g_iLeechRangeCooldown;
	int g_iRequiresHumans;
}

esLeechCache g_esLeechCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_leech", cmdLeechInfo, "View information about the Leech ability.");

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
void vLeechMapStart()
#else
public void OnMapStart()
#endif
{
	vLeechReset();
}

#if defined MT_ABILITIES_MAIN
void vLeechClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnLeechTakeDamage);
	vLeechReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vLeechClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vLeechReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vLeechMapEnd()
#else
public void OnMapEnd()
#endif
{
	vLeechReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdLeechInfo(int client, int args)
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
		case false: vLeechMenu(client, MT_LEECH_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vLeechMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_LEECH_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iLeechMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Leech Ability Information");
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

int iLeechMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLeechCache[param1].g_iLeechAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esLeechCache[param1].g_iHumanAmmo - g_esLeechPlayer[param1].g_iAmmoCount), g_esLeechCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esLeechCache[param1].g_iHumanAbility == 1) ? g_esLeechCache[param1].g_iHumanCooldown : g_esLeechCache[param1].g_iLeechCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "LeechDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esLeechCache[param1].g_iLeechDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLeechCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esLeechCache[param1].g_iHumanAbility == 1) ? g_esLeechCache[param1].g_iHumanRangeCooldown : g_esLeechCache[param1].g_iLeechRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vLeechMenu(param1, MT_LEECH_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pLeech = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "LeechMenu", param1);
			pLeech.SetTitle(sMenuTitle);
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
void vLeechDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_LEECH, MT_MENU_LEECH);
}

#if defined MT_ABILITIES_MAIN
void vLeechMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_LEECH, false))
	{
		vLeechMenu(client, MT_LEECH_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vLeechMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_LEECH, false))
	{
		FormatEx(buffer, size, "%T", "LeechMenu2", client);
	}
}

Action OnLeechTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esLeechCache[attacker].g_iLeechHitMode == 0 || g_esLeechCache[attacker].g_iLeechHitMode == 1) && bIsSurvivor(victim) && g_esLeechCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esLeechAbility[g_esLeechPlayer[attacker].g_iTankType].g_iAccessFlags, g_esLeechPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esLeechPlayer[attacker].g_iTankType, g_esLeechAbility[g_esLeechPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esLeechPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vLeechHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esLeechCache[attacker].g_flLeechChance, g_esLeechCache[attacker].g_iLeechHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esLeechCache[victim].g_iLeechHitMode == 0 || g_esLeechCache[victim].g_iLeechHitMode == 2) && bIsSurvivor(attacker) && g_esLeechCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esLeechAbility[g_esLeechPlayer[victim].g_iTankType].g_iAccessFlags, g_esLeechPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esLeechPlayer[victim].g_iTankType, g_esLeechAbility[g_esLeechPlayer[victim].g_iTankType].g_iImmunityFlags, g_esLeechPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vLeechHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esLeechCache[victim].g_flLeechChance, g_esLeechCache[victim].g_iLeechHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vLeechPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_LEECH);
}

#if defined MT_ABILITIES_MAIN
void vLeechAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_LEECH_SECTION);
	list2.PushString(MT_LEECH_SECTION2);
	list3.PushString(MT_LEECH_SECTION3);
	list4.PushString(MT_LEECH_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vLeechCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLeechCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_LEECH_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_LEECH_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_LEECH_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_LEECH_SECTION4);
	if (g_esLeechCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_LEECH_SECTION, false) || StrEqual(sSubset[iPos], MT_LEECH_SECTION2, false) || StrEqual(sSubset[iPos], MT_LEECH_SECTION3, false) || StrEqual(sSubset[iPos], MT_LEECH_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esLeechCache[tank].g_iLeechAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vLeechAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerLeechCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esLeechCache[tank].g_iLeechHitMode == 0 || g_esLeechCache[tank].g_iLeechHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vLeechHit(survivor, tank, random, flChance, g_esLeechCache[tank].g_iLeechHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esLeechCache[tank].g_iLeechHitMode == 0 || g_esLeechCache[tank].g_iLeechHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vLeechHit(survivor, tank, random, flChance, g_esLeechCache[tank].g_iLeechHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerLeechCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vLeechConfigsLoad(int mode)
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
				g_esLeechAbility[iIndex].g_iAccessFlags = 0;
				g_esLeechAbility[iIndex].g_iImmunityFlags = 0;
				g_esLeechAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esLeechAbility[iIndex].g_iComboAbility = 0;
				g_esLeechAbility[iIndex].g_iHumanAbility = 0;
				g_esLeechAbility[iIndex].g_iHumanAmmo = 5;
				g_esLeechAbility[iIndex].g_iHumanCooldown = 0;
				g_esLeechAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esLeechAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esLeechAbility[iIndex].g_iRequiresHumans = 0;
				g_esLeechAbility[iIndex].g_iLeechAbility = 0;
				g_esLeechAbility[iIndex].g_iLeechEffect = 0;
				g_esLeechAbility[iIndex].g_iLeechMessage = 0;
				g_esLeechAbility[iIndex].g_flLeechChance = 33.3;
				g_esLeechAbility[iIndex].g_iLeechCooldown = 0;
				g_esLeechAbility[iIndex].g_iLeechDuration = 5;
				g_esLeechAbility[iIndex].g_iLeechHit = 0;
				g_esLeechAbility[iIndex].g_iLeechHitMode = 0;
				g_esLeechAbility[iIndex].g_flLeechInterval = 1.0;
				g_esLeechAbility[iIndex].g_flLeechRange = 150.0;
				g_esLeechAbility[iIndex].g_flLeechRangeChance = 15.0;
				g_esLeechAbility[iIndex].g_iLeechRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esLeechPlayer[iPlayer].g_iAccessFlags = 0;
					g_esLeechPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esLeechPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esLeechPlayer[iPlayer].g_iComboAbility = 0;
					g_esLeechPlayer[iPlayer].g_iHumanAbility = 0;
					g_esLeechPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esLeechPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esLeechPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esLeechPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esLeechPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esLeechPlayer[iPlayer].g_iLeechAbility = 0;
					g_esLeechPlayer[iPlayer].g_iLeechEffect = 0;
					g_esLeechPlayer[iPlayer].g_iLeechMessage = 0;
					g_esLeechPlayer[iPlayer].g_flLeechChance = 0.0;
					g_esLeechPlayer[iPlayer].g_iLeechCooldown = 0;
					g_esLeechPlayer[iPlayer].g_iLeechDuration = 0;
					g_esLeechPlayer[iPlayer].g_iLeechHit = 0;
					g_esLeechPlayer[iPlayer].g_iLeechHitMode = 0;
					g_esLeechPlayer[iPlayer].g_flLeechInterval = 0.0;
					g_esLeechPlayer[iPlayer].g_flLeechRange = 0.0;
					g_esLeechPlayer[iPlayer].g_flLeechRangeChance = 0.0;
					g_esLeechPlayer[iPlayer].g_iLeechRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLeechConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esLeechPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esLeechPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esLeechPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esLeechPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esLeechPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esLeechPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esLeechPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esLeechPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esLeechPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esLeechPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esLeechPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esLeechPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esLeechPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esLeechPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esLeechPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esLeechPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esLeechPlayer[admin].g_iLeechAbility = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esLeechPlayer[admin].g_iLeechAbility, value, 0, 1);
		g_esLeechPlayer[admin].g_iLeechEffect = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esLeechPlayer[admin].g_iLeechEffect, value, 0, 7);
		g_esLeechPlayer[admin].g_iLeechMessage = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esLeechPlayer[admin].g_iLeechMessage, value, 0, 3);
		g_esLeechPlayer[admin].g_flLeechChance = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechChance", "Leech Chance", "Leech_Chance", "chance", g_esLeechPlayer[admin].g_flLeechChance, value, 0.0, 100.0);
		g_esLeechPlayer[admin].g_iLeechCooldown = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechCooldown", "Leech Cooldown", "Leech_Cooldown", "cooldown", g_esLeechPlayer[admin].g_iLeechCooldown, value, 0, 99999);
		g_esLeechPlayer[admin].g_iLeechDuration = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechDuration", "Leech Duration", "Leech_Duration", "duration", g_esLeechPlayer[admin].g_iLeechDuration, value, 1, 99999);
		g_esLeechPlayer[admin].g_iLeechHit = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechHit", "Leech Hit", "Leech_Hit", "hit", g_esLeechPlayer[admin].g_iLeechHit, value, 0, 1);
		g_esLeechPlayer[admin].g_iLeechHitMode = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechHitMode", "Leech Hit Mode", "Leech_Hit_Mode", "hitmode", g_esLeechPlayer[admin].g_iLeechHitMode, value, 0, 2);
		g_esLeechPlayer[admin].g_flLeechInterval = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechInterval", "Leech Interval", "Leech_Interval", "interval", g_esLeechPlayer[admin].g_flLeechInterval, value, 0.1, 99999.0);
		g_esLeechPlayer[admin].g_flLeechRange = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechRange", "Leech Range", "Leech_Range", "range", g_esLeechPlayer[admin].g_flLeechRange, value, 1.0, 99999.0);
		g_esLeechPlayer[admin].g_flLeechRangeChance = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechRangeChance", "Leech Range Chance", "Leech_Range_Chance", "rangechance", g_esLeechPlayer[admin].g_flLeechRangeChance, value, 0.0, 100.0);
		g_esLeechPlayer[admin].g_iLeechRangeCooldown = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechRangeCooldown", "Leech Range Cooldown", "Leech_Range_Cooldown", "rangecooldown", g_esLeechPlayer[admin].g_iLeechRangeCooldown, value, 0, 99999);
		g_esLeechPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esLeechPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esLeechAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esLeechAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esLeechAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esLeechAbility[type].g_iComboAbility, value, 0, 1);
		g_esLeechAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esLeechAbility[type].g_iHumanAbility, value, 0, 2);
		g_esLeechAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esLeechAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esLeechAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esLeechAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esLeechAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esLeechAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esLeechAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esLeechAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esLeechAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esLeechAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esLeechAbility[type].g_iLeechAbility = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esLeechAbility[type].g_iLeechAbility, value, 0, 1);
		g_esLeechAbility[type].g_iLeechEffect = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esLeechAbility[type].g_iLeechEffect, value, 0, 7);
		g_esLeechAbility[type].g_iLeechMessage = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esLeechAbility[type].g_iLeechMessage, value, 0, 3);
		g_esLeechAbility[type].g_flLeechChance = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechChance", "Leech Chance", "Leech_Chance", "chance", g_esLeechAbility[type].g_flLeechChance, value, 0.0, 100.0);
		g_esLeechAbility[type].g_iLeechCooldown = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechCooldown", "Leech Cooldown", "Leech_Cooldown", "cooldown", g_esLeechAbility[type].g_iLeechCooldown, value, 0, 99999);
		g_esLeechAbility[type].g_iLeechDuration = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechDuration", "Leech Duration", "Leech_Duration", "duration", g_esLeechAbility[type].g_iLeechDuration, value, 1, 99999);
		g_esLeechAbility[type].g_iLeechHit = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechHit", "Leech Hit", "Leech_Hit", "hit", g_esLeechAbility[type].g_iLeechHit, value, 0, 1);
		g_esLeechAbility[type].g_iLeechHitMode = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechHitMode", "Leech Hit Mode", "Leech_Hit_Mode", "hitmode", g_esLeechAbility[type].g_iLeechHitMode, value, 0, 2);
		g_esLeechAbility[type].g_flLeechInterval = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechInterval", "Leech Interval", "Leech_Interval", "interval", g_esLeechAbility[type].g_flLeechInterval, value, 0.1, 99999.0);
		g_esLeechAbility[type].g_flLeechRange = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechRange", "Leech Range", "Leech_Range", "range", g_esLeechAbility[type].g_flLeechRange, value, 1.0, 99999.0);
		g_esLeechAbility[type].g_flLeechRangeChance = flGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechRangeChance", "Leech Range Chance", "Leech_Range_Chance", "rangechance", g_esLeechAbility[type].g_flLeechRangeChance, value, 0.0, 100.0);
		g_esLeechAbility[type].g_iLeechRangeCooldown = iGetKeyValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "LeechRangeCooldown", "Leech Range Cooldown", "Leech_Range_Cooldown", "rangecooldown", g_esLeechAbility[type].g_iLeechRangeCooldown, value, 0, 99999);
		g_esLeechAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esLeechAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_LEECH_SECTION, MT_LEECH_SECTION2, MT_LEECH_SECTION3, MT_LEECH_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vLeechSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esLeechCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_flCloseAreasOnly, g_esLeechAbility[type].g_flCloseAreasOnly);
	g_esLeechCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iComboAbility, g_esLeechAbility[type].g_iComboAbility);
	g_esLeechCache[tank].g_flLeechChance = flGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_flLeechChance, g_esLeechAbility[type].g_flLeechChance);
	g_esLeechCache[tank].g_flLeechInterval = flGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_flLeechInterval, g_esLeechAbility[type].g_flLeechInterval);
	g_esLeechCache[tank].g_flLeechRange = flGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_flLeechRange, g_esLeechAbility[type].g_flLeechRange);
	g_esLeechCache[tank].g_flLeechRangeChance = flGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_flLeechRangeChance, g_esLeechAbility[type].g_flLeechRangeChance);
	g_esLeechCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iHumanAbility, g_esLeechAbility[type].g_iHumanAbility);
	g_esLeechCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iHumanAmmo, g_esLeechAbility[type].g_iHumanAmmo);
	g_esLeechCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iHumanCooldown, g_esLeechAbility[type].g_iHumanCooldown);
	g_esLeechCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iHumanRangeCooldown, g_esLeechAbility[type].g_iHumanRangeCooldown);
	g_esLeechCache[tank].g_iLeechAbility = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iLeechAbility, g_esLeechAbility[type].g_iLeechAbility);
	g_esLeechCache[tank].g_iLeechCooldown = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iLeechCooldown, g_esLeechAbility[type].g_iLeechCooldown);
	g_esLeechCache[tank].g_iLeechDuration = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iLeechDuration, g_esLeechAbility[type].g_iLeechDuration);
	g_esLeechCache[tank].g_iLeechEffect = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iLeechEffect, g_esLeechAbility[type].g_iLeechEffect);
	g_esLeechCache[tank].g_iLeechHit = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iLeechHit, g_esLeechAbility[type].g_iLeechHit);
	g_esLeechCache[tank].g_iLeechHitMode = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iLeechHitMode, g_esLeechAbility[type].g_iLeechHitMode);
	g_esLeechCache[tank].g_iLeechMessage = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iLeechMessage, g_esLeechAbility[type].g_iLeechMessage);
	g_esLeechCache[tank].g_iLeechRangeCooldown = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iLeechRangeCooldown, g_esLeechAbility[type].g_iLeechRangeCooldown);
	g_esLeechCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_flOpenAreasOnly, g_esLeechAbility[type].g_flOpenAreasOnly);
	g_esLeechCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esLeechPlayer[tank].g_iRequiresHumans, g_esLeechAbility[type].g_iRequiresHumans);
	g_esLeechPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vLeechCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vLeechCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveLeech(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vLeechEventFired(Event event, const char[] name)
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
			vLeechCopyStats2(iBot, iTank);
			vRemoveLeech(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vLeechCopyStats2(iTank, iBot);
			vRemoveLeech(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveLeech(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vLeechReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vLeechAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLeechAbility[g_esLeechPlayer[tank].g_iTankType].g_iAccessFlags, g_esLeechPlayer[tank].g_iAccessFlags)) || g_esLeechCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esLeechCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esLeechCache[tank].g_iLeechAbility == 1 && g_esLeechCache[tank].g_iComboAbility == 0)
	{
		vLeechAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vLeechButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esLeechCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLeechCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLeechPlayer[tank].g_iTankType) || (g_esLeechCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLeechCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLeechAbility[g_esLeechPlayer[tank].g_iTankType].g_iAccessFlags, g_esLeechPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esLeechCache[tank].g_iLeechAbility == 1 && g_esLeechCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esLeechPlayer[tank].g_iRangeCooldown == -1 || g_esLeechPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vLeechAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "LeechHuman3", (g_esLeechPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLeechChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveLeech(tank);
}

void vLeechAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esLeechCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLeechCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLeechPlayer[tank].g_iTankType) || (g_esLeechCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLeechCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLeechAbility[g_esLeechPlayer[tank].g_iTankType].g_iAccessFlags, g_esLeechPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esLeechPlayer[tank].g_iAmmoCount < g_esLeechCache[tank].g_iHumanAmmo && g_esLeechCache[tank].g_iHumanAmmo > 0))
	{
		g_esLeechPlayer[tank].g_bFailed = false;
		g_esLeechPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esLeechCache[tank].g_flLeechRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esLeechCache[tank].g_flLeechRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esLeechPlayer[tank].g_iTankType, g_esLeechAbility[g_esLeechPlayer[tank].g_iTankType].g_iImmunityFlags, g_esLeechPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vLeechHit(iSurvivor, tank, random, flChance, g_esLeechCache[tank].g_iLeechAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLeechCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "LeechHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLeechCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "LeechAmmo");
	}
}

void vLeechHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esLeechCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLeechCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLeechPlayer[tank].g_iTankType) || (g_esLeechCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLeechCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLeechAbility[g_esLeechPlayer[tank].g_iTankType].g_iAccessFlags, g_esLeechPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esLeechPlayer[tank].g_iTankType, g_esLeechAbility[g_esLeechPlayer[tank].g_iTankType].g_iImmunityFlags, g_esLeechPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esLeechPlayer[tank].g_iRangeCooldown != -1 && g_esLeechPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esLeechPlayer[tank].g_iCooldown != -1 && g_esLeechPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esLeechPlayer[tank].g_iAmmoCount < g_esLeechCache[tank].g_iHumanAmmo && g_esLeechCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esLeechPlayer[survivor].g_bAffected)
			{
				g_esLeechPlayer[survivor].g_bAffected = true;
				g_esLeechPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esLeechPlayer[tank].g_iRangeCooldown == -1 || g_esLeechPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLeechCache[tank].g_iHumanAbility == 1)
					{
						g_esLeechPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LeechHuman", g_esLeechPlayer[tank].g_iAmmoCount, g_esLeechCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esLeechCache[tank].g_iLeechRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLeechCache[tank].g_iHumanAbility == 1 && g_esLeechPlayer[tank].g_iAmmoCount < g_esLeechCache[tank].g_iHumanAmmo && g_esLeechCache[tank].g_iHumanAmmo > 0) ? g_esLeechCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esLeechPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esLeechPlayer[tank].g_iRangeCooldown != -1 && g_esLeechPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LeechHuman5", (g_esLeechPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esLeechPlayer[tank].g_iCooldown == -1 || g_esLeechPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esLeechCache[tank].g_iLeechCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLeechCache[tank].g_iHumanAbility == 1) ? g_esLeechCache[tank].g_iHumanCooldown : iCooldown;
					g_esLeechPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esLeechPlayer[tank].g_iCooldown != -1 && g_esLeechPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LeechHuman5", (g_esLeechPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esLeechCache[tank].g_flLeechInterval;
				DataPack dpLeech;
				CreateDataTimer(flInterval, tTimerLeech, dpLeech, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpLeech.WriteCell(GetClientUserId(survivor));
				dpLeech.WriteCell(GetClientUserId(tank));
				dpLeech.WriteCell(g_esLeechPlayer[tank].g_iTankType);
				dpLeech.WriteCell(messages);
				dpLeech.WriteCell(enabled);
				dpLeech.WriteCell(pos);
				dpLeech.WriteCell(iTime);

				vScreenEffect(survivor, tank, g_esLeechCache[tank].g_iLeechEffect, flags);

				if (g_esLeechCache[tank].g_iLeechMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Leech", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Leech", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esLeechPlayer[tank].g_iRangeCooldown == -1 || g_esLeechPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLeechCache[tank].g_iHumanAbility == 1 && !g_esLeechPlayer[tank].g_bFailed)
				{
					g_esLeechPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "LeechHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLeechCache[tank].g_iHumanAbility == 1 && !g_esLeechPlayer[tank].g_bNoAmmo)
		{
			g_esLeechPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "LeechAmmo");
		}
	}
}

void vLeechCopyStats2(int oldTank, int newTank)
{
	g_esLeechPlayer[newTank].g_iAmmoCount = g_esLeechPlayer[oldTank].g_iAmmoCount;
	g_esLeechPlayer[newTank].g_iCooldown = g_esLeechPlayer[oldTank].g_iCooldown;
	g_esLeechPlayer[newTank].g_iRangeCooldown = g_esLeechPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveLeech(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esLeechPlayer[iSurvivor].g_bAffected && g_esLeechPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esLeechPlayer[iSurvivor].g_bAffected = false;
			g_esLeechPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vLeechReset3(tank);
}

void vLeechReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vLeechReset3(iPlayer);

			g_esLeechPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vLeechReset2(int survivor, int tank, int messages)
{
	g_esLeechPlayer[survivor].g_bAffected = false;
	g_esLeechPlayer[survivor].g_iOwner = 0;

	if (g_esLeechCache[tank].g_iLeechMessage & messages)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Leech2", sTankName, survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Leech2", LANG_SERVER, sTankName, survivor);
	}
}

void vLeechReset3(int tank)
{
	g_esLeechPlayer[tank].g_bAffected = false;
	g_esLeechPlayer[tank].g_bFailed = false;
	g_esLeechPlayer[tank].g_bNoAmmo = false;
	g_esLeechPlayer[tank].g_iAmmoCount = 0;
	g_esLeechPlayer[tank].g_iCooldown = -1;
	g_esLeechPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerLeechCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLeechAbility[g_esLeechPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLeechPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLeechPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esLeechCache[iTank].g_iLeechAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vLeechAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerLeechCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esLeechPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLeechAbility[g_esLeechPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLeechPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLeechPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esLeechCache[iTank].g_iLeechHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esLeechCache[iTank].g_iLeechHitMode == 0 || g_esLeechCache[iTank].g_iLeechHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vLeechHit(iSurvivor, iTank, flRandom, flChance, g_esLeechCache[iTank].g_iLeechHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esLeechCache[iTank].g_iLeechHitMode == 0 || g_esLeechCache[iTank].g_iLeechHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vLeechHit(iSurvivor, iTank, flRandom, flChance, g_esLeechCache[iTank].g_iLeechHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerLeech(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor))
	{
		g_esLeechPlayer[iSurvivor].g_bAffected = false;
		g_esLeechPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsPlayerIncapacitated(iTank) || bIsAreaNarrow(iTank, g_esLeechCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esLeechCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLeechPlayer[iTank].g_iTankType) || (g_esLeechCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLeechCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLeechAbility[g_esLeechPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLeechPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLeechPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esLeechPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esLeechPlayer[iTank].g_iTankType, g_esLeechAbility[g_esLeechPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esLeechPlayer[iSurvivor].g_iImmunityFlags) || !g_esLeechPlayer[iSurvivor].g_bAffected)
	{
		vLeechReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iLeechEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esLeechCache[iTank].g_iLeechDuration,
		iTime = pack.ReadCell();
	if (iLeechEnabled == 0 || (iTime + iDuration) < GetTime())
	{
		vLeechReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iTankHealth = GetEntProp(iTank, Prop_Data, "m_iHealth"),
		iMaxHealth = MT_TankMaxHealth(iTank, 1),
		iNewHealth = (iTankHealth + 1),
		iLeftover = (iNewHealth > MT_MAXHEALTH) ? (iNewHealth - MT_MAXHEALTH) : iNewHealth,
		iFinalHealth = (iNewHealth > MT_MAXHEALTH) ? MT_MAXHEALTH : iNewHealth,
		iTotalHealth = (iNewHealth > MT_MAXHEALTH) ? iLeftover : 1;
	MT_TankMaxHealth(iTank, 3, (iMaxHealth + iTotalHealth));
	SetEntProp(iTank, Prop_Data, "m_iHealth", iFinalHealth);
	vDamagePlayer(iSurvivor, iTank, 1.0);

	return Plugin_Continue;
}