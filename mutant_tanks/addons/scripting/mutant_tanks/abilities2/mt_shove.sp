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

#define MT_SHOVE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_SHOVE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Shove Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank repeatedly shoves survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Shove Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_SHOVE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_SHOVE_SECTION "shoveability"
#define MT_SHOVE_SECTION2 "shove ability"
#define MT_SHOVE_SECTION3 "shove_ability"
#define MT_SHOVE_SECTION4 "shove"

#define MT_MENU_SHOVE "Shove Ability"

enum struct esShovePlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flShoveChance;
	float g_flShoveDeathChance;
	float g_flShoveDeathRange;
	float g_flShoveInterval;
	float g_flShoveRange;
	float g_flShoveRangeChance;

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
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iShoveAbility;
	int g_iShoveCooldown;
	int g_iShoveDeath;
	int g_iShoveDuration;
	int g_iShoveEffect;
	int g_iShoveHit;
	int g_iShoveHitMode;
	int g_iShoveMessage;
	int g_iShoveRangeCooldown;
	int g_iTankType;
}

esShovePlayer g_esShovePlayer[MAXPLAYERS + 1];

enum struct esShoveAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flShoveChance;
	float g_flShoveDeathChance;
	float g_flShoveDeathRange;
	float g_flShoveInterval;
	float g_flShoveRange;
	float g_flShoveRangeChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iShoveAbility;
	int g_iShoveCooldown;
	int g_iShoveDeath;
	int g_iShoveDuration;
	int g_iShoveEffect;
	int g_iShoveHit;
	int g_iShoveHitMode;
	int g_iShoveMessage;
	int g_iShoveRangeCooldown;
}

esShoveAbility g_esShoveAbility[MT_MAXTYPES + 1];

enum struct esShoveCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flShoveChance;
	float g_flShoveDeathChance;
	float g_flShoveDeathRange;
	float g_flShoveInterval;
	float g_flShoveRange;
	float g_flShoveRangeChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
	int g_iShoveAbility;
	int g_iShoveCooldown;
	int g_iShoveDeath;
	int g_iShoveDuration;
	int g_iShoveEffect;
	int g_iShoveHit;
	int g_iShoveHitMode;
	int g_iShoveMessage;
	int g_iShoveRangeCooldown;
}

esShoveCache g_esShoveCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_shove", cmdShoveInfo, "View information about the Shove ability.");

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
void vShoveMapStart()
#else
public void OnMapStart()
#endif
{
	vShoveReset();
}

#if defined MT_ABILITIES_MAIN2
void vShoveClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnShoveTakeDamage);
	vShoveReset3(client);
}

#if defined MT_ABILITIES_MAIN2
void vShoveClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vShoveReset3(client);
}

#if defined MT_ABILITIES_MAIN2
void vShoveMapEnd()
#else
public void OnMapEnd()
#endif
{
	vShoveReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdShoveInfo(int client, int args)
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
		case false: vShoveMenu(client, MT_SHOVE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vShoveMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_SHOVE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iShoveMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Shove Ability Information");
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

int iShoveMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esShoveCache[param1].g_iShoveAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esShoveCache[param1].g_iHumanAmmo - g_esShovePlayer[param1].g_iAmmoCount), g_esShoveCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esShoveCache[param1].g_iHumanAbility == 1) ? g_esShoveCache[param1].g_iHumanCooldown : g_esShoveCache[param1].g_iShoveCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "ShoveDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esShoveCache[param1].g_iShoveDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esShoveCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esShoveCache[param1].g_iHumanAbility == 1) ? g_esShoveCache[param1].g_iHumanRangeCooldown : g_esShoveCache[param1].g_iShoveRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vShoveMenu(param1, MT_SHOVE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pShove = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "ShoveMenu", param1);
			pShove.SetTitle(sMenuTitle);
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
void vShoveDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_SHOVE, MT_MENU_SHOVE);
}

#if defined MT_ABILITIES_MAIN2
void vShoveMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_SHOVE, false))
	{
		vShoveMenu(client, MT_SHOVE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vShoveMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_SHOVE, false))
	{
		FormatEx(buffer, size, "%T", "ShoveMenu2", client);
	}
}

Action OnShoveTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esShoveCache[attacker].g_iShoveHitMode == 0 || g_esShoveCache[attacker].g_iShoveHitMode == 1) && bIsSurvivor(victim) && g_esShoveCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esShoveAbility[g_esShovePlayer[attacker].g_iTankType].g_iAccessFlags, g_esShovePlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esShovePlayer[attacker].g_iTankType, g_esShoveAbility[g_esShovePlayer[attacker].g_iTankType].g_iImmunityFlags, g_esShovePlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vShoveHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esShoveCache[attacker].g_flShoveChance, g_esShoveCache[attacker].g_iShoveHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esShoveCache[victim].g_iShoveHitMode == 0 || g_esShoveCache[victim].g_iShoveHitMode == 2) && bIsSurvivor(attacker) && g_esShoveCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esShoveAbility[g_esShovePlayer[victim].g_iTankType].g_iAccessFlags, g_esShovePlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esShovePlayer[victim].g_iTankType, g_esShoveAbility[g_esShovePlayer[victim].g_iTankType].g_iImmunityFlags, g_esShovePlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vShoveHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esShoveCache[victim].g_flShoveChance, g_esShoveCache[victim].g_iShoveHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vShovePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_SHOVE);
}

#if defined MT_ABILITIES_MAIN2
void vShoveAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_SHOVE_SECTION);
	list2.PushString(MT_SHOVE_SECTION2);
	list3.PushString(MT_SHOVE_SECTION3);
	list4.PushString(MT_SHOVE_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vShoveCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShoveCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_SHOVE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_SHOVE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_SHOVE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_SHOVE_SECTION4);
	if (g_esShoveCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_SHOVE_SECTION, false) || StrEqual(sSubset[iPos], MT_SHOVE_SECTION2, false) || StrEqual(sSubset[iPos], MT_SHOVE_SECTION3, false) || StrEqual(sSubset[iPos], MT_SHOVE_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esShoveCache[tank].g_iShoveAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vShoveAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerShoveCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esShoveCache[tank].g_iShoveHitMode == 0 || g_esShoveCache[tank].g_iShoveHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vShoveHit(survivor, tank, random, flChance, g_esShoveCache[tank].g_iShoveHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esShoveCache[tank].g_iShoveHitMode == 0 || g_esShoveCache[tank].g_iShoveHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vShoveHit(survivor, tank, random, flChance, g_esShoveCache[tank].g_iShoveHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerShoveCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(survivor));
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteFloat(random);
								dpCombo.WriteFloat(flChance);
								dpCombo.WriteCell(iPos);
								dpCombo.WriteString(classname);
							}
						}
					}
					case MT_COMBO_POSTSPAWN: vShoveRange(tank, 0, random, iPos);
					case MT_COMBO_UPONDEATH: vShoveRange(tank, 0, random, iPos);
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShoveConfigsLoad(int mode)
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
				g_esShoveAbility[iIndex].g_iAccessFlags = 0;
				g_esShoveAbility[iIndex].g_iImmunityFlags = 0;
				g_esShoveAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esShoveAbility[iIndex].g_iComboAbility = 0;
				g_esShoveAbility[iIndex].g_iHumanAbility = 0;
				g_esShoveAbility[iIndex].g_iHumanAmmo = 5;
				g_esShoveAbility[iIndex].g_iHumanCooldown = 0;
				g_esShoveAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esShoveAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esShoveAbility[iIndex].g_iRequiresHumans = 0;
				g_esShoveAbility[iIndex].g_iShoveAbility = 0;
				g_esShoveAbility[iIndex].g_iShoveEffect = 0;
				g_esShoveAbility[iIndex].g_iShoveMessage = 0;
				g_esShoveAbility[iIndex].g_flShoveChance = 33.3;
				g_esShoveAbility[iIndex].g_iShoveCooldown = 0;
				g_esShoveAbility[iIndex].g_iShoveDeath = 0;
				g_esShoveAbility[iIndex].g_flShoveDeathChance = 33.3;
				g_esShoveAbility[iIndex].g_flShoveDeathRange = 200.0;
				g_esShoveAbility[iIndex].g_iShoveDuration = 5;
				g_esShoveAbility[iIndex].g_iShoveHit = 0;
				g_esShoveAbility[iIndex].g_iShoveHitMode = 0;
				g_esShoveAbility[iIndex].g_flShoveInterval = 1.0;
				g_esShoveAbility[iIndex].g_flShoveRange = 150.0;
				g_esShoveAbility[iIndex].g_flShoveRangeChance = 15.0;
				g_esShoveAbility[iIndex].g_iShoveRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esShovePlayer[iPlayer].g_iAccessFlags = 0;
					g_esShovePlayer[iPlayer].g_iImmunityFlags = 0;
					g_esShovePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esShovePlayer[iPlayer].g_iComboAbility = 0;
					g_esShovePlayer[iPlayer].g_iHumanAbility = 0;
					g_esShovePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esShovePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esShovePlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esShovePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esShovePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esShovePlayer[iPlayer].g_iShoveAbility = 0;
					g_esShovePlayer[iPlayer].g_iShoveEffect = 0;
					g_esShovePlayer[iPlayer].g_iShoveMessage = 0;
					g_esShovePlayer[iPlayer].g_flShoveChance = 0.0;
					g_esShovePlayer[iPlayer].g_iShoveCooldown = 0;
					g_esShovePlayer[iPlayer].g_iShoveDeath = 0;
					g_esShovePlayer[iPlayer].g_flShoveDeathChance = 0.0;
					g_esShovePlayer[iPlayer].g_flShoveDeathRange = 0.0;
					g_esShovePlayer[iPlayer].g_iShoveDuration = 0;
					g_esShovePlayer[iPlayer].g_iShoveHit = 0;
					g_esShovePlayer[iPlayer].g_iShoveHitMode = 0;
					g_esShovePlayer[iPlayer].g_flShoveInterval = 0.0;
					g_esShovePlayer[iPlayer].g_flShoveRange = 0.0;
					g_esShovePlayer[iPlayer].g_flShoveRangeChance = 0.0;
					g_esShovePlayer[iPlayer].g_iShoveRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShoveConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esShovePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esShovePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esShovePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esShovePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esShovePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esShovePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esShovePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esShovePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esShovePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esShovePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esShovePlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esShovePlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esShovePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esShovePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esShovePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esShovePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esShovePlayer[admin].g_iShoveAbility = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esShovePlayer[admin].g_iShoveAbility, value, 0, 1);
		g_esShovePlayer[admin].g_iShoveEffect = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esShovePlayer[admin].g_iShoveEffect, value, 0, 7);
		g_esShovePlayer[admin].g_iShoveMessage = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esShovePlayer[admin].g_iShoveMessage, value, 0, 3);
		g_esShovePlayer[admin].g_flShoveChance = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveChance", "Shove Chance", "Shove_Chance", "chance", g_esShovePlayer[admin].g_flShoveChance, value, 0.0, 100.0);
		g_esShovePlayer[admin].g_iShoveCooldown = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveCooldown", "Shove Cooldown", "Shove_Cooldown", "cooldown", g_esShovePlayer[admin].g_iShoveCooldown, value, 0, 99999);
		g_esShovePlayer[admin].g_iShoveDeath = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveDeath", "Shove Death", "Shove_Death", "death", g_esShovePlayer[admin].g_iShoveDeath, value, 0, 1);
		g_esShovePlayer[admin].g_flShoveDeathChance = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveDeathChance", "Shove Death Chance", "Shove_Death_Chance", "deathchance", g_esShovePlayer[admin].g_flShoveDeathChance, value, 0.0, 100.0);
		g_esShovePlayer[admin].g_flShoveDeathRange = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveDeathRange", "Shove Death Range", "Shove_Death_Range", "deathrange", g_esShovePlayer[admin].g_flShoveDeathRange, value, 1.0, 99999.0);
		g_esShovePlayer[admin].g_iShoveDuration = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveDuration", "Shove Duration", "Shove_Duration", "duration", g_esShovePlayer[admin].g_iShoveDuration, value, 1, 99999);
		g_esShovePlayer[admin].g_iShoveHit = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveHit", "Shove Hit", "Shove_Hit", "hit", g_esShovePlayer[admin].g_iShoveHit, value, 0, 1);
		g_esShovePlayer[admin].g_iShoveHitMode = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveHitMode", "Shove Hit Mode", "Shove_Hit_Mode", "hitmode", g_esShovePlayer[admin].g_iShoveHitMode, value, 0, 2);
		g_esShovePlayer[admin].g_flShoveInterval = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveInterval", "Shove Interval", "Shove_Interval", "interval", g_esShovePlayer[admin].g_flShoveInterval, value, 0.1, 99999.0);
		g_esShovePlayer[admin].g_flShoveRange = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveRange", "Shove Range", "Shove_Range", "range", g_esShovePlayer[admin].g_flShoveRange, value, 1.0, 99999.0);
		g_esShovePlayer[admin].g_flShoveRangeChance = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveRangeChance", "Shove Range Chance", "Shove_Range_Chance", "rangechance", g_esShovePlayer[admin].g_flShoveRangeChance, value, 0.0, 100.0);
		g_esShovePlayer[admin].g_iShoveRangeCooldown = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveRangeCooldown", "Shove Range Cooldown", "Shove_Range_Cooldown", "rangecooldown", g_esShovePlayer[admin].g_iShoveRangeCooldown, value, 0, 99999);
		g_esShovePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esShovePlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esShoveAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esShoveAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esShoveAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esShoveAbility[type].g_iComboAbility, value, 0, 1);
		g_esShoveAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esShoveAbility[type].g_iHumanAbility, value, 0, 2);
		g_esShoveAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esShoveAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esShoveAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esShoveAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esShoveAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esShoveAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esShoveAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esShoveAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esShoveAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esShoveAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esShoveAbility[type].g_iShoveAbility = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esShoveAbility[type].g_iShoveAbility, value, 0, 1);
		g_esShoveAbility[type].g_iShoveEffect = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esShoveAbility[type].g_iShoveEffect, value, 0, 7);
		g_esShoveAbility[type].g_iShoveMessage = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esShoveAbility[type].g_iShoveMessage, value, 0, 3);
		g_esShoveAbility[type].g_flShoveChance = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveChance", "Shove Chance", "Shove_Chance", "chance", g_esShoveAbility[type].g_flShoveChance, value, 0.0, 100.0);
		g_esShoveAbility[type].g_iShoveCooldown = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveCooldown", "Shove Cooldown", "Shove_Cooldown", "cooldown", g_esShoveAbility[type].g_iShoveCooldown, value, 0, 99999);
		g_esShoveAbility[type].g_iShoveDeath = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveDeath", "Shove Death", "Shove_Death", "death", g_esShoveAbility[type].g_iShoveDeath, value, 0, 1);
		g_esShoveAbility[type].g_flShoveDeathChance = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveDeathChance", "Shove Death Chance", "Shove_Death_Chance", "deathchance", g_esShoveAbility[type].g_flShoveDeathChance, value, 0.0, 100.0);
		g_esShoveAbility[type].g_flShoveDeathRange = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveDeathRange", "Shove Death Range", "Shove_Death_Range", "deathrange", g_esShoveAbility[type].g_flShoveDeathRange, value, 1.0, 99999.0);
		g_esShoveAbility[type].g_iShoveDuration = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveDuration", "Shove Duration", "Shove_Duration", "duration", g_esShoveAbility[type].g_iShoveDuration, value, 1, 99999);
		g_esShoveAbility[type].g_iShoveHit = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveHit", "Shove Hit", "Shove_Hit", "hit", g_esShoveAbility[type].g_iShoveHit, value, 0, 1);
		g_esShoveAbility[type].g_iShoveHitMode = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveHitMode", "Shove Hit Mode", "Shove_Hit_Mode", "hitmode", g_esShoveAbility[type].g_iShoveHitMode, value, 0, 2);
		g_esShoveAbility[type].g_flShoveInterval = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveInterval", "Shove Interval", "Shove_Interval", "interval", g_esShoveAbility[type].g_flShoveInterval, value, 0.1, 99999.0);
		g_esShoveAbility[type].g_flShoveRange = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveRange", "Shove Range", "Shove_Range", "range", g_esShoveAbility[type].g_flShoveRange, value, 1.0, 99999.0);
		g_esShoveAbility[type].g_flShoveRangeChance = flGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveRangeChance", "Shove Range Chance", "Shove_Range_Chance", "rangechance", g_esShoveAbility[type].g_flShoveRangeChance, value, 0.0, 100.0);
		g_esShoveAbility[type].g_iShoveRangeCooldown = iGetKeyValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ShoveRangeCooldown", "Shove Range Cooldown", "Shove_Range_Cooldown", "rangecooldown", g_esShoveAbility[type].g_iShoveRangeCooldown, value, 0, 99999);
		g_esShoveAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esShoveAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SHOVE_SECTION, MT_SHOVE_SECTION2, MT_SHOVE_SECTION3, MT_SHOVE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vShoveSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esShoveCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_flCloseAreasOnly, g_esShoveAbility[type].g_flCloseAreasOnly);
	g_esShoveCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iComboAbility, g_esShoveAbility[type].g_iComboAbility);
	g_esShoveCache[tank].g_flShoveChance = flGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_flShoveChance, g_esShoveAbility[type].g_flShoveChance);
	g_esShoveCache[tank].g_flShoveDeathChance = flGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_flShoveDeathChance, g_esShoveAbility[type].g_flShoveDeathChance);
	g_esShoveCache[tank].g_flShoveDeathRange = flGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_flShoveDeathRange, g_esShoveAbility[type].g_flShoveDeathRange);
	g_esShoveCache[tank].g_flShoveInterval = flGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_flShoveInterval, g_esShoveAbility[type].g_flShoveInterval);
	g_esShoveCache[tank].g_flShoveRange = flGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_flShoveRange, g_esShoveAbility[type].g_flShoveRange);
	g_esShoveCache[tank].g_flShoveRangeChance = flGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_flShoveRangeChance, g_esShoveAbility[type].g_flShoveRangeChance);
	g_esShoveCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iHumanAbility, g_esShoveAbility[type].g_iHumanAbility);
	g_esShoveCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iHumanAmmo, g_esShoveAbility[type].g_iHumanAmmo);
	g_esShoveCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iHumanCooldown, g_esShoveAbility[type].g_iHumanCooldown);
	g_esShoveCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iHumanRangeCooldown, g_esShoveAbility[type].g_iHumanRangeCooldown);
	g_esShoveCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_flOpenAreasOnly, g_esShoveAbility[type].g_flOpenAreasOnly);
	g_esShoveCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iRequiresHumans, g_esShoveAbility[type].g_iRequiresHumans);
	g_esShoveCache[tank].g_iShoveAbility = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iShoveAbility, g_esShoveAbility[type].g_iShoveAbility);
	g_esShoveCache[tank].g_iShoveCooldown = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iShoveCooldown, g_esShoveAbility[type].g_iShoveCooldown);
	g_esShoveCache[tank].g_iShoveDeath = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iShoveDeath, g_esShoveAbility[type].g_iShoveDeath);
	g_esShoveCache[tank].g_iShoveDuration = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iShoveDuration, g_esShoveAbility[type].g_iShoveDuration);
	g_esShoveCache[tank].g_iShoveEffect = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iShoveEffect, g_esShoveAbility[type].g_iShoveEffect);
	g_esShoveCache[tank].g_iShoveHit = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iShoveHit, g_esShoveAbility[type].g_iShoveHit);
	g_esShoveCache[tank].g_iShoveHitMode = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iShoveHitMode, g_esShoveAbility[type].g_iShoveHitMode);
	g_esShoveCache[tank].g_iShoveMessage = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iShoveMessage, g_esShoveAbility[type].g_iShoveMessage);
	g_esShoveCache[tank].g_iShoveRangeCooldown = iGetSettingValue(apply, bHuman, g_esShovePlayer[tank].g_iShoveRangeCooldown, g_esShoveAbility[type].g_iShoveRangeCooldown);
	g_esShovePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vShoveCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vShoveCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveShove(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vShoveEventFired(Event event, const char[] name)
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
			vShoveCopyStats2(iBot, iTank);
			vRemoveShove(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vShoveCopyStats2(iTank, iBot);
			vRemoveShove(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vShoveRange(iTank, 1, MT_GetRandomFloat(0.1, 100.0));
			vRemoveShove(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vShoveReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vShoveAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShoveAbility[g_esShovePlayer[tank].g_iTankType].g_iAccessFlags, g_esShovePlayer[tank].g_iAccessFlags)) || g_esShoveCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esShoveCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esShoveCache[tank].g_iShoveAbility == 1 && g_esShoveCache[tank].g_iComboAbility == 0)
	{
		vShoveAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vShoveButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esShoveCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esShoveCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShovePlayer[tank].g_iTankType) || (g_esShoveCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShoveCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShoveAbility[g_esShovePlayer[tank].g_iTankType].g_iAccessFlags, g_esShovePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esShoveCache[tank].g_iShoveAbility == 1 && g_esShoveCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esShovePlayer[tank].g_iRangeCooldown == -1 || g_esShovePlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vShoveAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShoveHuman3", (g_esShovePlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShoveChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveShove(tank);
}

#if defined MT_ABILITIES_MAIN2
void vShovePostTankSpawn(int tank)
#else
public void MT_OnPostTankSpawn(int tank)
#endif
{
	vShoveRange(tank, 1, MT_GetRandomFloat(0.1, 100.0));
}

void vShoveAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esShoveCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esShoveCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShovePlayer[tank].g_iTankType) || (g_esShoveCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShoveCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShoveAbility[g_esShovePlayer[tank].g_iTankType].g_iAccessFlags, g_esShovePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esShovePlayer[tank].g_iAmmoCount < g_esShoveCache[tank].g_iHumanAmmo && g_esShoveCache[tank].g_iHumanAmmo > 0))
	{
		g_esShovePlayer[tank].g_bFailed = false;
		g_esShovePlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esShoveCache[tank].g_flShoveRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esShoveCache[tank].g_flShoveRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esShovePlayer[tank].g_iTankType, g_esShoveAbility[g_esShovePlayer[tank].g_iTankType].g_iImmunityFlags, g_esShovePlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vShoveHit(iSurvivor, tank, random, flChance, g_esShoveCache[tank].g_iShoveAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShoveCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShoveHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShoveCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShoveAmmo");
	}
}

void vShoveHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esShoveCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esShoveCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShovePlayer[tank].g_iTankType) || (g_esShoveCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShoveCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShoveAbility[g_esShovePlayer[tank].g_iTankType].g_iAccessFlags, g_esShovePlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esShovePlayer[tank].g_iTankType, g_esShoveAbility[g_esShovePlayer[tank].g_iTankType].g_iImmunityFlags, g_esShovePlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esShovePlayer[tank].g_iRangeCooldown != -1 && g_esShovePlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esShovePlayer[tank].g_iCooldown != -1 && g_esShovePlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !bIsSurvivorDisabled(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esShovePlayer[tank].g_iAmmoCount < g_esShoveCache[tank].g_iHumanAmmo && g_esShoveCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esShovePlayer[survivor].g_bAffected)
			{
				g_esShovePlayer[survivor].g_bAffected = true;
				g_esShovePlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esShovePlayer[tank].g_iRangeCooldown == -1 || g_esShovePlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShoveCache[tank].g_iHumanAbility == 1)
					{
						g_esShovePlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShoveHuman", g_esShovePlayer[tank].g_iAmmoCount, g_esShoveCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esShoveCache[tank].g_iShoveRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShoveCache[tank].g_iHumanAbility == 1 && g_esShovePlayer[tank].g_iAmmoCount < g_esShoveCache[tank].g_iHumanAmmo && g_esShoveCache[tank].g_iHumanAmmo > 0) ? g_esShoveCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esShovePlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esShovePlayer[tank].g_iRangeCooldown != -1 && g_esShovePlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShoveHuman5", (g_esShovePlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esShovePlayer[tank].g_iCooldown == -1 || g_esShovePlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esShoveCache[tank].g_iShoveCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShoveCache[tank].g_iHumanAbility == 1) ? g_esShoveCache[tank].g_iHumanCooldown : iCooldown;
					g_esShovePlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esShovePlayer[tank].g_iCooldown != -1 && g_esShovePlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShoveHuman5", (g_esShovePlayer[tank].g_iCooldown - iTime));
					}
				}

				float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esShoveCache[tank].g_flShoveInterval;
				DataPack dpShove;
				CreateDataTimer(flInterval, tTimerShove, dpShove, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpShove.WriteCell(GetClientUserId(survivor));
				dpShove.WriteCell(GetClientUserId(tank));
				dpShove.WriteCell(g_esShovePlayer[tank].g_iTankType);
				dpShove.WriteCell(messages);
				dpShove.WriteCell(enabled);
				dpShove.WriteCell(pos);
				dpShove.WriteCell(iTime);

				vScreenEffect(survivor, tank, g_esShoveCache[tank].g_iShoveEffect, flags);

				if (g_esShoveCache[tank].g_iShoveMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Shove", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Shove", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esShovePlayer[tank].g_iRangeCooldown == -1 || g_esShovePlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShoveCache[tank].g_iHumanAbility == 1 && !g_esShovePlayer[tank].g_bFailed)
				{
					g_esShovePlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShoveHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShoveCache[tank].g_iHumanAbility == 1 && !g_esShovePlayer[tank].g_bNoAmmo)
		{
			g_esShovePlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShoveAmmo");
		}
	}
}

void vShoveRange(int tank, int value, float random, int pos = -1)
{
	float flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 13, pos) : g_esShoveCache[tank].g_flShoveDeathChance;
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(tank) && g_esShoveCache[tank].g_iShoveDeath == 1 && random <= flChance)
	{
		if (g_esShoveCache[tank].g_iComboAbility == value || bIsAreaNarrow(tank, g_esShoveCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esShoveCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShovePlayer[tank].g_iTankType) || (g_esShoveCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShoveCache[tank].g_iRequiresHumans) || (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShoveAbility[g_esShovePlayer[tank].g_iTankType].g_iAccessFlags, g_esShovePlayer[tank].g_iAccessFlags)) || g_esShoveCache[tank].g_iHumanAbility == 0)))
		{
			return;
		}

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 12, pos) : g_esShoveCache[tank].g_flShoveDeathRange;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !bIsSurvivorDisabled(iSurvivor) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esShovePlayer[tank].g_iTankType, g_esShoveAbility[g_esShovePlayer[tank].g_iTankType].g_iImmunityFlags, g_esShovePlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					MT_StaggerPlayer(iSurvivor, tank, flTankPos);
				}
			}
		}
	}
}

void vShoveCopyStats2(int oldTank, int newTank)
{
	g_esShovePlayer[newTank].g_iAmmoCount = g_esShovePlayer[oldTank].g_iAmmoCount;
	g_esShovePlayer[newTank].g_iCooldown = g_esShovePlayer[oldTank].g_iCooldown;
	g_esShovePlayer[newTank].g_iRangeCooldown = g_esShovePlayer[oldTank].g_iRangeCooldown;
}

void vRemoveShove(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esShovePlayer[iSurvivor].g_bAffected && g_esShovePlayer[iSurvivor].g_iOwner == tank)
		{
			g_esShovePlayer[iSurvivor].g_bAffected = false;
			g_esShovePlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vShoveReset3(tank);
}

void vShoveReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vShoveReset3(iPlayer);

			g_esShovePlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vShoveReset2(int survivor, int tank, int messages)
{
	g_esShovePlayer[survivor].g_bAffected = false;
	g_esShovePlayer[survivor].g_iOwner = 0;

	if (g_esShoveCache[tank].g_iShoveMessage & messages)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Shove2", survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Shove2", LANG_SERVER, survivor);
	}
}

void vShoveReset3(int tank)
{
	g_esShovePlayer[tank].g_bAffected = false;
	g_esShovePlayer[tank].g_bFailed = false;
	g_esShovePlayer[tank].g_bNoAmmo = false;
	g_esShovePlayer[tank].g_iAmmoCount = 0;
	g_esShovePlayer[tank].g_iCooldown = -1;
	g_esShovePlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerShoveCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esShoveAbility[g_esShovePlayer[iTank].g_iTankType].g_iAccessFlags, g_esShovePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esShovePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esShoveCache[iTank].g_iShoveAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vShoveAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerShoveCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esShovePlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esShoveAbility[g_esShovePlayer[iTank].g_iTankType].g_iAccessFlags, g_esShovePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esShovePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esShoveCache[iTank].g_iShoveHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esShoveCache[iTank].g_iShoveHitMode == 0 || g_esShoveCache[iTank].g_iShoveHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vShoveHit(iSurvivor, iTank, flRandom, flChance, g_esShoveCache[iTank].g_iShoveHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esShoveCache[iTank].g_iShoveHitMode == 0 || g_esShoveCache[iTank].g_iShoveHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vShoveHit(iSurvivor, iTank, flRandom, flChance, g_esShoveCache[iTank].g_iShoveHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerShove(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor))
	{
		g_esShovePlayer[iSurvivor].g_bAffected = false;
		g_esShovePlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esShoveCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esShoveCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShovePlayer[iTank].g_iTankType) || (g_esShoveCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShoveCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esShoveAbility[g_esShovePlayer[iTank].g_iTankType].g_iAccessFlags, g_esShovePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esShovePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esShovePlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esShovePlayer[iTank].g_iTankType, g_esShoveAbility[g_esShovePlayer[iTank].g_iTankType].g_iImmunityFlags, g_esShovePlayer[iSurvivor].g_iImmunityFlags) || !g_esShovePlayer[iSurvivor].g_bAffected || MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE))
	{
		vShoveReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iShoveEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esShoveCache[iTank].g_iShoveDuration,
		iTime = pack.ReadCell();
	if (iShoveEnabled == 0 || (iTime + iDuration) < GetTime())
	{
		vShoveReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	float flOrigin[3];
	GetClientAbsOrigin(iTank, flOrigin);
	MT_StaggerPlayer(iSurvivor, iTank, flOrigin);

	return Plugin_Continue;
}