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

#define MT_RECOIL_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_RECOIL_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Recoil Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank gives survivors strong gun recoil.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Recoil Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_RECOIL_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_RECOIL_SECTION "recoilability"
#define MT_RECOIL_SECTION2 "recoil ability"
#define MT_RECOIL_SECTION3 "recoil_ability"
#define MT_RECOIL_SECTION4 "recoil"

#define MT_MENU_RECOIL "Recoil Ability"

enum struct esRecoilPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flRecoilChance;
	float g_flRecoilDuration;
	float g_flRecoilRange;
	float g_flRecoilRangeChance;

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
	int g_iRecoilAbility;
	int g_iRecoilCooldown;
	int g_iRecoilEffect;
	int g_iRecoilHit;
	int g_iRecoilHitMode;
	int g_iRecoilMessage;
	int g_iRecoilRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esRecoilPlayer g_esRecoilPlayer[MAXPLAYERS + 1];

enum struct esRecoilAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flRecoilChance;
	float g_flRecoilDuration;
	float g_flRecoilRange;
	float g_flRecoilRangeChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRecoilAbility;
	int g_iRecoilCooldown;
	int g_iRecoilEffect;
	int g_iRecoilHit;
	int g_iRecoilHitMode;
	int g_iRecoilMessage;
	int g_iRecoilRangeCooldown;
	int g_iRequiresHumans;
}

esRecoilAbility g_esRecoilAbility[MT_MAXTYPES + 1];

enum struct esRecoilCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flRecoilChance;
	float g_flRecoilDuration;
	float g_flRecoilRange;
	float g_flRecoilRangeChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRecoilAbility;
	int g_iRecoilCooldown;
	int g_iRecoilEffect;
	int g_iRecoilHit;
	int g_iRecoilHitMode;
	int g_iRecoilMessage;
	int g_iRecoilRangeCooldown;
	int g_iRequiresHumans;
}

esRecoilCache g_esRecoilCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_recoil", cmdRecoilInfo, "View information about the Recoil ability.");

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
void vRecoilMapStart()
#else
public void OnMapStart()
#endif
{
	vRecoilReset();
}

#if defined MT_ABILITIES_MAIN2
void vRecoilClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnRecoilTakeDamage);
	vRecoilReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vRecoilClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRecoilReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vRecoilMapEnd()
#else
public void OnMapEnd()
#endif
{
	vRecoilReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdRecoilInfo(int client, int args)
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
		case false: vRecoilMenu(client, MT_RECOIL_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vRecoilMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_RECOIL_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iRecoilMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Recoil Ability Information");
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

int iRecoilMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esRecoilCache[param1].g_iRecoilAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esRecoilCache[param1].g_iHumanAmmo - g_esRecoilPlayer[param1].g_iAmmoCount), g_esRecoilCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esRecoilCache[param1].g_iHumanAbility == 1) ? g_esRecoilCache[param1].g_iHumanCooldown : g_esRecoilCache[param1].g_iRecoilCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "RecoilDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esRecoilCache[param1].g_flRecoilDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esRecoilCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esRecoilCache[param1].g_iHumanAbility == 1) ? g_esRecoilCache[param1].g_iHumanRangeCooldown : g_esRecoilCache[param1].g_iRecoilRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vRecoilMenu(param1, MT_RECOIL_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pRecoil = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "RecoilMenu", param1);
			pRecoil.SetTitle(sMenuTitle);
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
void vRecoilDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_RECOIL, MT_MENU_RECOIL);
}

#if defined MT_ABILITIES_MAIN2
void vRecoilMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_RECOIL, false))
	{
		vRecoilMenu(client, MT_RECOIL_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vRecoilMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_RECOIL, false))
	{
		FormatEx(buffer, size, "%T", "RecoilMenu2", client);
	}
}

Action OnRecoilTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esRecoilCache[attacker].g_iRecoilHitMode == 0 || g_esRecoilCache[attacker].g_iRecoilHitMode == 1) && bIsSurvivor(victim) && g_esRecoilCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esRecoilAbility[g_esRecoilPlayer[attacker].g_iTankType].g_iAccessFlags, g_esRecoilPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esRecoilPlayer[attacker].g_iTankType, g_esRecoilAbility[g_esRecoilPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esRecoilPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vRecoilHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esRecoilCache[attacker].g_flRecoilChance, g_esRecoilCache[attacker].g_iRecoilHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esRecoilCache[victim].g_iRecoilHitMode == 0 || g_esRecoilCache[victim].g_iRecoilHitMode == 2) && bIsSurvivor(attacker) && g_esRecoilCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esRecoilAbility[g_esRecoilPlayer[victim].g_iTankType].g_iAccessFlags, g_esRecoilPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esRecoilPlayer[victim].g_iTankType, g_esRecoilAbility[g_esRecoilPlayer[victim].g_iTankType].g_iImmunityFlags, g_esRecoilPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vRecoilHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esRecoilCache[victim].g_flRecoilChance, g_esRecoilCache[victim].g_iRecoilHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vRecoilPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_RECOIL);
}

#if defined MT_ABILITIES_MAIN2
void vRecoilAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_RECOIL_SECTION);
	list2.PushString(MT_RECOIL_SECTION2);
	list3.PushString(MT_RECOIL_SECTION3);
	list4.PushString(MT_RECOIL_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vRecoilCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRecoilCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_RECOIL_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_RECOIL_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_RECOIL_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_RECOIL_SECTION4);
	if (g_esRecoilCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_RECOIL_SECTION, false) || StrEqual(sSubset[iPos], MT_RECOIL_SECTION2, false) || StrEqual(sSubset[iPos], MT_RECOIL_SECTION3, false) || StrEqual(sSubset[iPos], MT_RECOIL_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esRecoilCache[tank].g_iRecoilAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vRecoilAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerRecoilCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esRecoilCache[tank].g_iRecoilHitMode == 0 || g_esRecoilCache[tank].g_iRecoilHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vRecoilHit(survivor, tank, random, flChance, g_esRecoilCache[tank].g_iRecoilHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esRecoilCache[tank].g_iRecoilHitMode == 0 || g_esRecoilCache[tank].g_iRecoilHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vRecoilHit(survivor, tank, random, flChance, g_esRecoilCache[tank].g_iRecoilHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerRecoilCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vRecoilConfigsLoad(int mode)
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
				g_esRecoilAbility[iIndex].g_iAccessFlags = 0;
				g_esRecoilAbility[iIndex].g_iImmunityFlags = 0;
				g_esRecoilAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esRecoilAbility[iIndex].g_iComboAbility = 0;
				g_esRecoilAbility[iIndex].g_iHumanAbility = 0;
				g_esRecoilAbility[iIndex].g_iHumanAmmo = 5;
				g_esRecoilAbility[iIndex].g_iHumanCooldown = 0;
				g_esRecoilAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esRecoilAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esRecoilAbility[iIndex].g_iRequiresHumans = 1;
				g_esRecoilAbility[iIndex].g_iRecoilAbility = 0;
				g_esRecoilAbility[iIndex].g_iRecoilEffect = 0;
				g_esRecoilAbility[iIndex].g_iRecoilMessage = 0;
				g_esRecoilAbility[iIndex].g_flRecoilChance = 33.3;
				g_esRecoilAbility[iIndex].g_iRecoilCooldown = 0;
				g_esRecoilAbility[iIndex].g_flRecoilDuration = 5.0;
				g_esRecoilAbility[iIndex].g_iRecoilHit = 0;
				g_esRecoilAbility[iIndex].g_iRecoilHitMode = 0;
				g_esRecoilAbility[iIndex].g_flRecoilRange = 150.0;
				g_esRecoilAbility[iIndex].g_flRecoilRangeChance = 15.0;
				g_esRecoilAbility[iIndex].g_iRecoilRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esRecoilPlayer[iPlayer].g_iAccessFlags = 0;
					g_esRecoilPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esRecoilPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esRecoilPlayer[iPlayer].g_iComboAbility = 0;
					g_esRecoilPlayer[iPlayer].g_iHumanAbility = 0;
					g_esRecoilPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esRecoilPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esRecoilPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esRecoilPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esRecoilPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esRecoilPlayer[iPlayer].g_iRecoilAbility = 0;
					g_esRecoilPlayer[iPlayer].g_iRecoilEffect = 0;
					g_esRecoilPlayer[iPlayer].g_iRecoilMessage = 0;
					g_esRecoilPlayer[iPlayer].g_flRecoilChance = 0.0;
					g_esRecoilPlayer[iPlayer].g_iRecoilCooldown = 0;
					g_esRecoilPlayer[iPlayer].g_flRecoilDuration = 0.0;
					g_esRecoilPlayer[iPlayer].g_iRecoilHit = 0;
					g_esRecoilPlayer[iPlayer].g_iRecoilHitMode = 0;
					g_esRecoilPlayer[iPlayer].g_flRecoilRange = 0.0;
					g_esRecoilPlayer[iPlayer].g_flRecoilRangeChance = 0.0;
					g_esRecoilPlayer[iPlayer].g_iRecoilRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRecoilConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esRecoilPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esRecoilPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esRecoilPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esRecoilPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esRecoilPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esRecoilPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esRecoilPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esRecoilPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esRecoilPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esRecoilPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esRecoilPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esRecoilPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esRecoilPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esRecoilPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esRecoilPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esRecoilPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esRecoilPlayer[admin].g_iRecoilAbility = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esRecoilPlayer[admin].g_iRecoilAbility, value, 0, 1);
		g_esRecoilPlayer[admin].g_iRecoilEffect = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esRecoilPlayer[admin].g_iRecoilEffect, value, 0, 7);
		g_esRecoilPlayer[admin].g_iRecoilMessage = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esRecoilPlayer[admin].g_iRecoilMessage, value, 0, 3);
		g_esRecoilPlayer[admin].g_flRecoilChance = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilChance", "Recoil Chance", "Recoil_Chance", "chance", g_esRecoilPlayer[admin].g_flRecoilChance, value, 0.0, 100.0);
		g_esRecoilPlayer[admin].g_iRecoilCooldown = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilCooldown", "Recoil Cooldown", "Recoil_Cooldown", "cooldown", g_esRecoilPlayer[admin].g_iRecoilCooldown, value, 0, 99999);
		g_esRecoilPlayer[admin].g_flRecoilDuration = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilDuration", "Recoil Duration", "Recoil_Duration", "duration", g_esRecoilPlayer[admin].g_flRecoilDuration, value, 0.1, 99999.0);
		g_esRecoilPlayer[admin].g_iRecoilHit = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilHit", "Recoil Hit", "Recoil_Hit", "hit", g_esRecoilPlayer[admin].g_iRecoilHit, value, 0, 1);
		g_esRecoilPlayer[admin].g_iRecoilHitMode = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilHitMode", "Recoil Hit Mode", "Recoil_Hit_Mode", "hitmode", g_esRecoilPlayer[admin].g_iRecoilHitMode, value, 0, 2);
		g_esRecoilPlayer[admin].g_flRecoilRange = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilRange", "Recoil Range", "Recoil_Range", "range", g_esRecoilPlayer[admin].g_flRecoilRange, value, 1.0, 99999.0);
		g_esRecoilPlayer[admin].g_flRecoilRangeChance = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilRangeChance", "Recoil Range Chance", "Recoil_Range_Chance", "rangechance", g_esRecoilPlayer[admin].g_flRecoilRangeChance, value, 0.0, 100.0);
		g_esRecoilPlayer[admin].g_iRecoilRangeCooldown = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilRangeCooldown", "Recoil Range Cooldown", "Recoil_Range_Cooldown", "rangecooldown", g_esRecoilPlayer[admin].g_iRecoilRangeCooldown, value, 0, 99999);
		g_esRecoilPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esRecoilPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esRecoilAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esRecoilAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esRecoilAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esRecoilAbility[type].g_iComboAbility, value, 0, 1);
		g_esRecoilAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esRecoilAbility[type].g_iHumanAbility, value, 0, 2);
		g_esRecoilAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esRecoilAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esRecoilAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esRecoilAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esRecoilAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esRecoilAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esRecoilAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esRecoilAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esRecoilAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esRecoilAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esRecoilAbility[type].g_iRecoilAbility = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esRecoilAbility[type].g_iRecoilAbility, value, 0, 1);
		g_esRecoilAbility[type].g_iRecoilEffect = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esRecoilAbility[type].g_iRecoilEffect, value, 0, 7);
		g_esRecoilAbility[type].g_iRecoilMessage = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esRecoilAbility[type].g_iRecoilMessage, value, 0, 3);
		g_esRecoilAbility[type].g_flRecoilChance = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilChance", "Recoil Chance", "Recoil_Chance", "chance", g_esRecoilAbility[type].g_flRecoilChance, value, 0.0, 100.0);
		g_esRecoilAbility[type].g_iRecoilCooldown = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilCooldown", "Recoil Cooldown", "Recoil_Cooldown", "cooldown", g_esRecoilAbility[type].g_iRecoilCooldown, value, 0, 99999);
		g_esRecoilAbility[type].g_flRecoilDuration = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilDuration", "Recoil Duration", "Recoil_Duration", "duration", g_esRecoilAbility[type].g_flRecoilDuration, value, 0.1, 99999.0);
		g_esRecoilAbility[type].g_iRecoilHit = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilHit", "Recoil Hit", "Recoil_Hit", "hit", g_esRecoilAbility[type].g_iRecoilHit, value, 0, 1);
		g_esRecoilAbility[type].g_iRecoilHitMode = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilHitMode", "Recoil Hit Mode", "Recoil_Hit_Mode", "hitmode", g_esRecoilAbility[type].g_iRecoilHitMode, value, 0, 2);
		g_esRecoilAbility[type].g_flRecoilRange = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilRange", "Recoil Range", "Recoil_Range", "range", g_esRecoilAbility[type].g_flRecoilRange, value, 1.0, 99999.0);
		g_esRecoilAbility[type].g_flRecoilRangeChance = flGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilRangeChance", "Recoil Range Chance", "Recoil_Range_Chance", "rangechance", g_esRecoilAbility[type].g_flRecoilRangeChance, value, 0.0, 100.0);
		g_esRecoilAbility[type].g_iRecoilRangeCooldown = iGetKeyValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "RecoilRangeCooldown", "Recoil Range Cooldown", "Recoil_Range_Cooldown", "rangecooldown", g_esRecoilAbility[type].g_iRecoilRangeCooldown, value, 0, 99999);
		g_esRecoilAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esRecoilAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_RECOIL_SECTION, MT_RECOIL_SECTION2, MT_RECOIL_SECTION3, MT_RECOIL_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vRecoilSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esRecoilCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_flCloseAreasOnly, g_esRecoilAbility[type].g_flCloseAreasOnly);
	g_esRecoilCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iComboAbility, g_esRecoilAbility[type].g_iComboAbility);
	g_esRecoilCache[tank].g_flRecoilChance = flGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_flRecoilChance, g_esRecoilAbility[type].g_flRecoilChance);
	g_esRecoilCache[tank].g_flRecoilDuration = flGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_flRecoilDuration, g_esRecoilAbility[type].g_flRecoilDuration);
	g_esRecoilCache[tank].g_flRecoilRange = flGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_flRecoilRange, g_esRecoilAbility[type].g_flRecoilRange);
	g_esRecoilCache[tank].g_flRecoilRangeChance = flGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_flRecoilRangeChance, g_esRecoilAbility[type].g_flRecoilRangeChance);
	g_esRecoilCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iHumanAbility, g_esRecoilAbility[type].g_iHumanAbility);
	g_esRecoilCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iHumanAmmo, g_esRecoilAbility[type].g_iHumanAmmo);
	g_esRecoilCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iHumanCooldown, g_esRecoilAbility[type].g_iHumanCooldown);
	g_esRecoilCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iHumanRangeCooldown, g_esRecoilAbility[type].g_iHumanRangeCooldown);
	g_esRecoilCache[tank].g_iRecoilAbility = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iRecoilAbility, g_esRecoilAbility[type].g_iRecoilAbility);
	g_esRecoilCache[tank].g_iRecoilCooldown = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iRecoilCooldown, g_esRecoilAbility[type].g_iRecoilCooldown);
	g_esRecoilCache[tank].g_iRecoilEffect = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iRecoilEffect, g_esRecoilAbility[type].g_iRecoilEffect);
	g_esRecoilCache[tank].g_iRecoilHit = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iRecoilHit, g_esRecoilAbility[type].g_iRecoilHit);
	g_esRecoilCache[tank].g_iRecoilHitMode = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iRecoilHitMode, g_esRecoilAbility[type].g_iRecoilHitMode);
	g_esRecoilCache[tank].g_iRecoilMessage = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iRecoilMessage, g_esRecoilAbility[type].g_iRecoilMessage);
	g_esRecoilCache[tank].g_iRecoilRangeCooldown = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iRecoilRangeCooldown, g_esRecoilAbility[type].g_iRecoilRangeCooldown);
	g_esRecoilCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_flOpenAreasOnly, g_esRecoilAbility[type].g_flOpenAreasOnly);
	g_esRecoilCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esRecoilPlayer[tank].g_iRequiresHumans, g_esRecoilAbility[type].g_iRequiresHumans);
	g_esRecoilPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vRecoilCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vRecoilCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveRecoil(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vRecoilHookEvent(bool hooked)
#else
public void MT_OnHookEvent(bool hooked)
#endif
{
	static bool bCheck;

	switch (hooked)
	{
		case true: bCheck = HookEventEx("weapon_fire", MT_OnEventFired);
		case false:
		{
			if (bCheck)
			{
				bCheck = false;
				UnhookEvent("weapon_fire", MT_OnEventFired);
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRecoilEventFired(Event event, const char[] name)
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
			vRecoilCopyStats2(iBot, iTank);
			vRemoveRecoil(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vRecoilCopyStats2(iTank, iBot);
			vRemoveRecoil(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveRecoil(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vRecoilReset();
	}
	else if (StrEqual(name, "weapon_fire"))
	{
		int iSurvivorId = event.GetInt("userid"), iSurvivor = GetClientOfUserId(iSurvivorId);
		if (bIsSurvivor(iSurvivor) && bIsGunWeapon(iSurvivor) && !MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_INFAMMO) && g_esRecoilPlayer[iSurvivor].g_bAffected)
		{
			float flRecoil[3];
			flRecoil[0] = MT_GetRandomFloat(-20.0, -80.0);
			flRecoil[1] = MT_GetRandomFloat(-25.0, 25.0);
			flRecoil[2] = MT_GetRandomFloat(-25.0, 25.0);
			SetEntPropVector(iSurvivor, Prop_Data, "m_vecPunchAngle", flRecoil);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRecoilAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRecoilAbility[g_esRecoilPlayer[tank].g_iTankType].g_iAccessFlags, g_esRecoilPlayer[tank].g_iAccessFlags)) || g_esRecoilCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esRecoilCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esRecoilCache[tank].g_iRecoilAbility == 1 && g_esRecoilCache[tank].g_iComboAbility == 0)
	{
		vRecoilAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vRecoilButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esRecoilCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esRecoilCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRecoilPlayer[tank].g_iTankType) || (g_esRecoilCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRecoilCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRecoilAbility[g_esRecoilPlayer[tank].g_iTankType].g_iAccessFlags, g_esRecoilPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esRecoilCache[tank].g_iRecoilAbility == 1 && g_esRecoilCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esRecoilPlayer[tank].g_iRangeCooldown == -1 || g_esRecoilPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vRecoilAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "RecoilHuman3", (g_esRecoilPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRecoilChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveRecoil(tank);
}

void vRecoilAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esRecoilCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esRecoilCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRecoilPlayer[tank].g_iTankType) || (g_esRecoilCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRecoilCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRecoilAbility[g_esRecoilPlayer[tank].g_iTankType].g_iAccessFlags, g_esRecoilPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esRecoilPlayer[tank].g_iAmmoCount < g_esRecoilCache[tank].g_iHumanAmmo && g_esRecoilCache[tank].g_iHumanAmmo > 0))
	{
		g_esRecoilPlayer[tank].g_bFailed = false;
		g_esRecoilPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esRecoilCache[tank].g_flRecoilRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esRecoilCache[tank].g_flRecoilRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esRecoilPlayer[tank].g_iTankType, g_esRecoilAbility[g_esRecoilPlayer[tank].g_iTankType].g_iImmunityFlags, g_esRecoilPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vRecoilHit(iSurvivor, tank, random, flChance, g_esRecoilCache[tank].g_iRecoilAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRecoilCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "RecoilHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRecoilCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "RecoilAmmo");
	}
}

void vRecoilHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esRecoilCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esRecoilCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRecoilPlayer[tank].g_iTankType) || (g_esRecoilCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRecoilCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRecoilAbility[g_esRecoilPlayer[tank].g_iTankType].g_iAccessFlags, g_esRecoilPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esRecoilPlayer[tank].g_iTankType, g_esRecoilAbility[g_esRecoilPlayer[tank].g_iTankType].g_iImmunityFlags, g_esRecoilPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esRecoilPlayer[tank].g_iRangeCooldown != -1 && g_esRecoilPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esRecoilPlayer[tank].g_iCooldown != -1 && g_esRecoilPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_INFAMMO))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esRecoilPlayer[tank].g_iAmmoCount < g_esRecoilCache[tank].g_iHumanAmmo && g_esRecoilCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esRecoilPlayer[survivor].g_bAffected)
			{
				g_esRecoilPlayer[survivor].g_bAffected = true;
				g_esRecoilPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esRecoilPlayer[tank].g_iRangeCooldown == -1 || g_esRecoilPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRecoilCache[tank].g_iHumanAbility == 1)
					{
						g_esRecoilPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "RecoilHuman", g_esRecoilPlayer[tank].g_iAmmoCount, g_esRecoilCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esRecoilCache[tank].g_iRecoilRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRecoilCache[tank].g_iHumanAbility == 1 && g_esRecoilPlayer[tank].g_iAmmoCount < g_esRecoilCache[tank].g_iHumanAmmo && g_esRecoilCache[tank].g_iHumanAmmo > 0) ? g_esRecoilCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esRecoilPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esRecoilPlayer[tank].g_iRangeCooldown != -1 && g_esRecoilPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "RecoilHuman5", (g_esRecoilPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esRecoilPlayer[tank].g_iCooldown == -1 || g_esRecoilPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esRecoilCache[tank].g_iRecoilCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRecoilCache[tank].g_iHumanAbility == 1) ? g_esRecoilCache[tank].g_iHumanCooldown : iCooldown;
					g_esRecoilPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esRecoilPlayer[tank].g_iCooldown != -1 && g_esRecoilPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "RecoilHuman5", (g_esRecoilPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esRecoilCache[tank].g_flRecoilDuration;
				DataPack dpStopRecoil;
				CreateDataTimer(flDuration, tTimerStopRecoil, dpStopRecoil, TIMER_FLAG_NO_MAPCHANGE);
				dpStopRecoil.WriteCell(GetClientUserId(survivor));
				dpStopRecoil.WriteCell(GetClientUserId(tank));
				dpStopRecoil.WriteCell(messages);

				vScreenEffect(survivor, tank, g_esRecoilCache[tank].g_iRecoilEffect, flags);

				if (g_esRecoilCache[tank].g_iRecoilMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Recoil", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Recoil", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esRecoilPlayer[tank].g_iRangeCooldown == -1 || g_esRecoilPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRecoilCache[tank].g_iHumanAbility == 1 && !g_esRecoilPlayer[tank].g_bFailed)
				{
					g_esRecoilPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "RecoilHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRecoilCache[tank].g_iHumanAbility == 1 && !g_esRecoilPlayer[tank].g_bNoAmmo)
		{
			g_esRecoilPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "RecoilAmmo");
		}
	}
}

void vRecoilCopyStats2(int oldTank, int newTank)
{
	g_esRecoilPlayer[newTank].g_iAmmoCount = g_esRecoilPlayer[oldTank].g_iAmmoCount;
	g_esRecoilPlayer[newTank].g_iCooldown = g_esRecoilPlayer[oldTank].g_iCooldown;
	g_esRecoilPlayer[newTank].g_iRangeCooldown = g_esRecoilPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveRecoil(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esRecoilPlayer[iSurvivor].g_bAffected && g_esRecoilPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esRecoilPlayer[iSurvivor].g_bAffected = false;
			g_esRecoilPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vRecoilReset2(tank);
}

void vRecoilReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRecoilReset2(iPlayer);

			g_esRecoilPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vRecoilReset2(int tank)
{
	g_esRecoilPlayer[tank].g_bAffected = false;
	g_esRecoilPlayer[tank].g_bFailed = false;
	g_esRecoilPlayer[tank].g_bNoAmmo = false;
	g_esRecoilPlayer[tank].g_iAmmoCount = 0;
	g_esRecoilPlayer[tank].g_iCooldown = -1;
	g_esRecoilPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerRecoilCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esRecoilAbility[g_esRecoilPlayer[iTank].g_iTankType].g_iAccessFlags, g_esRecoilPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esRecoilPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esRecoilCache[iTank].g_iRecoilAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vRecoilAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerRecoilCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esRecoilPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esRecoilAbility[g_esRecoilPlayer[iTank].g_iTankType].g_iAccessFlags, g_esRecoilPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esRecoilPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esRecoilCache[iTank].g_iRecoilHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esRecoilCache[iTank].g_iRecoilHitMode == 0 || g_esRecoilCache[iTank].g_iRecoilHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vRecoilHit(iSurvivor, iTank, flRandom, flChance, g_esRecoilCache[iTank].g_iRecoilHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esRecoilCache[iTank].g_iRecoilHitMode == 0 || g_esRecoilCache[iTank].g_iRecoilHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vRecoilHit(iSurvivor, iTank, flRandom, flChance, g_esRecoilCache[iTank].g_iRecoilHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopRecoil(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor) || !g_esRecoilPlayer[iSurvivor].g_bAffected)
	{
		g_esRecoilPlayer[iSurvivor].g_bAffected = false;
		g_esRecoilPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank))
	{
		g_esRecoilPlayer[iSurvivor].g_bAffected = false;
		g_esRecoilPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	g_esRecoilPlayer[iSurvivor].g_bAffected = false;
	g_esRecoilPlayer[iSurvivor].g_iOwner = 0;

	int iMessage = pack.ReadCell();
	if (g_esRecoilCache[iTank].g_iRecoilMessage & iMessage)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Recoil2", iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Recoil2", LANG_SERVER, iSurvivor);
	}

	return Plugin_Continue;
}