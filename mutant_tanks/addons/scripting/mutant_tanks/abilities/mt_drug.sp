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

#define MT_DRUG_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_DRUG_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Drug Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank drugs survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Drug Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_DRUG_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_DRUG_SECTION "drugability"
#define MT_DRUG_SECTION2 "drug ability"
#define MT_DRUG_SECTION3 "drug_ability"
#define MT_DRUG_SECTION4 "drug"

#define MT_MENU_DRUG "Drug Ability"

enum struct esDrugPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flDrugChance;
	float g_flDrugInterval;
	float g_flDrugRange;
	float g_flDrugRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iDrugAbility;
	int g_iDrugCooldown;
	int g_iDrugDuration;
	int g_iDrugEffect;
	int g_iDrugHit;
	int g_iDrugHitMode;
	int g_iDrugMessage;
	int g_iDrugRangeCooldown;
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

esDrugPlayer g_esDrugPlayer[MAXPLAYERS + 1];

enum struct esDrugAbility
{
	float g_flCloseAreasOnly;
	float g_flDrugChance;
	float g_flDrugInterval;
	float g_flDrugRange;
	float g_flDrugRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iDrugAbility;
	int g_iDrugCooldown;
	int g_iDrugDuration;
	int g_iDrugEffect;
	int g_iDrugHit;
	int g_iDrugHitMode;
	int g_iDrugMessage;
	int g_iDrugRangeCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esDrugAbility g_esDrugAbility[MT_MAXTYPES + 1];

enum struct esDrugCache
{
	float g_flCloseAreasOnly;
	float g_flDrugChance;
	float g_flDrugInterval;
	float g_flDrugRange;
	float g_flDrugRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iDrugAbility;
	int g_iDrugCooldown;
	int g_iDrugDuration;
	int g_iDrugEffect;
	int g_iDrugHit;
	int g_iDrugHitMode;
	int g_iDrugMessage;
	int g_iDrugRangeCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
}

esDrugCache g_esDrugCache[MAXPLAYERS + 1];

float g_flDrugAngles[20] =
{
	0.0,
	5.0,
	10.0,
	15.0,
	20.0,
	25.0,
	20.0,
	15.0,
	10.0,
	5.0,
	0.0,
	-5.0,
	-10.0,
	-15.0,
	-20.0,
	-25.0,
	-20.0,
	-15.0,
	-10.0,
	-5.0
};

UserMsg g_umDrugFade;

#if defined MT_ABILITIES_MAIN
void vDrugPluginStart()
#else
public void OnPluginStart()
#endif
{
	g_umDrugFade = GetUserMessageId("Fade");
#if !defined MT_ABILITIES_MAIN
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_drug", cmdDrugInfo, "View information about the Drug ability.");

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
#endif
}

#if defined MT_ABILITIES_MAIN
void vDrugMapStart()
#else
public void OnMapStart()
#endif
{
	vDrugReset();
}

#if defined MT_ABILITIES_MAIN
void vDrugClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnDrugTakeDamage);
	vDrugReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vDrugClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vDrugReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vDrugMapEnd()
#else
public void OnMapEnd()
#endif
{
	vDrugReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdDrugInfo(int client, int args)
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
		case false: vDrugMenu(client, MT_DRUG_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vDrugMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_DRUG_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iDrugMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Drug Ability Information");
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

int iDrugMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esDrugCache[param1].g_iDrugAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esDrugCache[param1].g_iHumanAmmo - g_esDrugPlayer[param1].g_iAmmoCount), g_esDrugCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esDrugCache[param1].g_iHumanAbility == 1) ? g_esDrugCache[param1].g_iHumanCooldown : g_esDrugCache[param1].g_iDrugCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "DrugDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esDrugCache[param1].g_iDrugDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esDrugCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esDrugCache[param1].g_iHumanAbility == 1) ? g_esDrugCache[param1].g_iHumanRangeCooldown : g_esDrugCache[param1].g_iDrugRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vDrugMenu(param1, MT_DRUG_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pDrug = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "DrugMenu", param1);
			pDrug.SetTitle(sMenuTitle);
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
void vDrugDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_DRUG, MT_MENU_DRUG);
}

#if defined MT_ABILITIES_MAIN
void vDrugMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_DRUG, false))
	{
		vDrugMenu(client, MT_DRUG_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vDrugMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_DRUG, false))
	{
		FormatEx(buffer, size, "%T", "DrugMenu2", client);
	}
}

Action OnDrugTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esDrugCache[attacker].g_iDrugHitMode == 0 || g_esDrugCache[attacker].g_iDrugHitMode == 1) && bIsHumanSurvivor(victim) && g_esDrugCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esDrugAbility[g_esDrugPlayer[attacker].g_iTankType].g_iAccessFlags, g_esDrugPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esDrugPlayer[attacker].g_iTankType, g_esDrugAbility[g_esDrugPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esDrugPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vDrugHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esDrugCache[attacker].g_flDrugChance, g_esDrugCache[attacker].g_iDrugHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esDrugCache[victim].g_iDrugHitMode == 0 || g_esDrugCache[victim].g_iDrugHitMode == 2) && bIsHumanSurvivor(attacker) && g_esDrugCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esDrugAbility[g_esDrugPlayer[victim].g_iTankType].g_iAccessFlags, g_esDrugPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esDrugPlayer[victim].g_iTankType, g_esDrugAbility[g_esDrugPlayer[victim].g_iTankType].g_iImmunityFlags, g_esDrugPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vDrugHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esDrugCache[victim].g_flDrugChance, g_esDrugCache[victim].g_iDrugHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vDrugPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_DRUG);
}

#if defined MT_ABILITIES_MAIN
void vDrugAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_DRUG_SECTION);
	list2.PushString(MT_DRUG_SECTION2);
	list3.PushString(MT_DRUG_SECTION3);
	list4.PushString(MT_DRUG_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vDrugCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrugCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_DRUG_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_DRUG_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_DRUG_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_DRUG_SECTION4);
	if (g_esDrugCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_DRUG_SECTION, false) || StrEqual(sSubset[iPos], MT_DRUG_SECTION2, false) || StrEqual(sSubset[iPos], MT_DRUG_SECTION3, false) || StrEqual(sSubset[iPos], MT_DRUG_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esDrugCache[tank].g_iDrugAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vDrugAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerDrugCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esDrugCache[tank].g_iDrugHitMode == 0 || g_esDrugCache[tank].g_iDrugHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vDrugHit(survivor, tank, random, flChance, g_esDrugCache[tank].g_iDrugHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esDrugCache[tank].g_iDrugHitMode == 0 || g_esDrugCache[tank].g_iDrugHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vDrugHit(survivor, tank, random, flChance, g_esDrugCache[tank].g_iDrugHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerDrugCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vDrugConfigsLoad(int mode)
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
				g_esDrugAbility[iIndex].g_iAccessFlags = 0;
				g_esDrugAbility[iIndex].g_iImmunityFlags = 0;
				g_esDrugAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esDrugAbility[iIndex].g_iComboAbility = 0;
				g_esDrugAbility[iIndex].g_iHumanAbility = 0;
				g_esDrugAbility[iIndex].g_iHumanAmmo = 5;
				g_esDrugAbility[iIndex].g_iHumanCooldown = 0;
				g_esDrugAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esDrugAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esDrugAbility[iIndex].g_iRequiresHumans = 1;
				g_esDrugAbility[iIndex].g_iDrugAbility = 0;
				g_esDrugAbility[iIndex].g_iDrugEffect = 0;
				g_esDrugAbility[iIndex].g_iDrugMessage = 0;
				g_esDrugAbility[iIndex].g_flDrugChance = 33.3;
				g_esDrugAbility[iIndex].g_iDrugCooldown = 0;
				g_esDrugAbility[iIndex].g_iDrugDuration = 5;
				g_esDrugAbility[iIndex].g_iDrugHit = 0;
				g_esDrugAbility[iIndex].g_iDrugHitMode = 0;
				g_esDrugAbility[iIndex].g_flDrugInterval = 1.0;
				g_esDrugAbility[iIndex].g_flDrugRange = 150.0;
				g_esDrugAbility[iIndex].g_flDrugRangeChance = 15.0;
				g_esDrugAbility[iIndex].g_iDrugRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esDrugPlayer[iPlayer].g_iAccessFlags = 0;
					g_esDrugPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esDrugPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esDrugPlayer[iPlayer].g_iComboAbility = 0;
					g_esDrugPlayer[iPlayer].g_iHumanAbility = 0;
					g_esDrugPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esDrugPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esDrugPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esDrugPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esDrugPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esDrugPlayer[iPlayer].g_iDrugAbility = 0;
					g_esDrugPlayer[iPlayer].g_iDrugEffect = 0;
					g_esDrugPlayer[iPlayer].g_iDrugMessage = 0;
					g_esDrugPlayer[iPlayer].g_flDrugChance = 0.0;
					g_esDrugPlayer[iPlayer].g_iDrugCooldown = 0;
					g_esDrugPlayer[iPlayer].g_iDrugDuration = 0;
					g_esDrugPlayer[iPlayer].g_iDrugHit = 0;
					g_esDrugPlayer[iPlayer].g_iDrugHitMode = 0;
					g_esDrugPlayer[iPlayer].g_flDrugInterval = 0.0;
					g_esDrugPlayer[iPlayer].g_flDrugRange = 0.0;
					g_esDrugPlayer[iPlayer].g_flDrugRangeChance = 0.0;
					g_esDrugPlayer[iPlayer].g_iDrugRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vDrugConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esDrugPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esDrugPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esDrugPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esDrugPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esDrugPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esDrugPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esDrugPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esDrugPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esDrugPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esDrugPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esDrugPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esDrugPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esDrugPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esDrugPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esDrugPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esDrugPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esDrugPlayer[admin].g_iDrugAbility = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esDrugPlayer[admin].g_iDrugAbility, value, 0, 1);
		g_esDrugPlayer[admin].g_iDrugEffect = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esDrugPlayer[admin].g_iDrugEffect, value, 0, 7);
		g_esDrugPlayer[admin].g_iDrugMessage = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esDrugPlayer[admin].g_iDrugMessage, value, 0, 3);
		g_esDrugPlayer[admin].g_flDrugChance = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugChance", "Drug Chance", "Drug_Chance", "chance", g_esDrugPlayer[admin].g_flDrugChance, value, 0.0, 100.0);
		g_esDrugPlayer[admin].g_iDrugCooldown = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugCooldown", "Drug Cooldown", "Drug_Cooldown", "cooldown", g_esDrugPlayer[admin].g_iDrugCooldown, value, 0, 99999);
		g_esDrugPlayer[admin].g_iDrugDuration = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugDuration", "Drug Duration", "Drug_Duration", "duration", g_esDrugPlayer[admin].g_iDrugDuration, value, 1, 99999);
		g_esDrugPlayer[admin].g_iDrugHit = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugHit", "Drug Hit", "Drug_Hit", "hit", g_esDrugPlayer[admin].g_iDrugHit, value, 0, 1);
		g_esDrugPlayer[admin].g_iDrugHitMode = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugHitMode", "Drug Hit Mode", "Drug_Hit_Mode", "hitmode", g_esDrugPlayer[admin].g_iDrugHitMode, value, 0, 2);
		g_esDrugPlayer[admin].g_flDrugInterval = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugInterval", "Drug Interval", "Drug_Interval", "interval", g_esDrugPlayer[admin].g_flDrugInterval, value, 0.1, 99999.0);
		g_esDrugPlayer[admin].g_flDrugRange = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugRange", "Drug Range", "Drug_Range", "range", g_esDrugPlayer[admin].g_flDrugRange, value, 1.0, 99999.0);
		g_esDrugPlayer[admin].g_flDrugRangeChance = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugRangeChance", "Drug Range Chance", "Drug_Range_Chance", "rangechance", g_esDrugPlayer[admin].g_flDrugRangeChance, value, 0.0, 100.0);
		g_esDrugPlayer[admin].g_iDrugRangeCooldown = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugRangeCooldown", "Drug Range Cooldown", "Drug_Range_Cooldown", "rangecooldown", g_esDrugPlayer[admin].g_iDrugRangeCooldown, value, 0, 99999);
		g_esDrugPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esDrugPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esDrugAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esDrugAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esDrugAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esDrugAbility[type].g_iComboAbility, value, 0, 1);
		g_esDrugAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esDrugAbility[type].g_iHumanAbility, value, 0, 2);
		g_esDrugAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esDrugAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esDrugAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esDrugAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esDrugAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esDrugAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esDrugAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esDrugAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esDrugAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esDrugAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esDrugAbility[type].g_iDrugAbility = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esDrugAbility[type].g_iDrugAbility, value, 0, 1);
		g_esDrugAbility[type].g_iDrugEffect = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esDrugAbility[type].g_iDrugEffect, value, 0, 7);
		g_esDrugAbility[type].g_iDrugMessage = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esDrugAbility[type].g_iDrugMessage, value, 0, 3);
		g_esDrugAbility[type].g_flDrugChance = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugChance", "Drug Chance", "Drug_Chance", "chance", g_esDrugAbility[type].g_flDrugChance, value, 0.0, 100.0);
		g_esDrugAbility[type].g_iDrugCooldown = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugCooldown", "Drug Cooldown", "Drug_Cooldown", "cooldown", g_esDrugAbility[type].g_iDrugCooldown, value, 0, 99999);
		g_esDrugAbility[type].g_iDrugDuration = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugDuration", "Drug Duration", "Drug_Duration", "duration", g_esDrugAbility[type].g_iDrugDuration, value, 1, 99999);
		g_esDrugAbility[type].g_iDrugHit = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugHit", "Drug Hit", "Drug_Hit", "hit", g_esDrugAbility[type].g_iDrugHit, value, 0, 1);
		g_esDrugAbility[type].g_iDrugHitMode = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugHitMode", "Drug Hit Mode", "Drug_Hit_Mode", "hitmode", g_esDrugAbility[type].g_iDrugHitMode, value, 0, 2);
		g_esDrugAbility[type].g_flDrugInterval = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugInterval", "Drug Interval", "Drug_Interval", "interval", g_esDrugAbility[type].g_flDrugInterval, value, 0.1, 99999.0);
		g_esDrugAbility[type].g_flDrugRange = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugRange", "Drug Range", "Drug_Range", "range", g_esDrugAbility[type].g_flDrugRange, value, 1.0, 99999.0);
		g_esDrugAbility[type].g_flDrugRangeChance = flGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugRangeChance", "Drug Range Chance", "Drug_Range_Chance", "rangechance", g_esDrugAbility[type].g_flDrugRangeChance, value, 0.0, 100.0);
		g_esDrugAbility[type].g_iDrugRangeCooldown = iGetKeyValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "DrugRangeCooldown", "Drug Range Cooldown", "Drug_Range_Cooldown", "rangecooldown", g_esDrugAbility[type].g_iDrugRangeCooldown, value, 0, 99999);
		g_esDrugAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esDrugAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_DRUG_SECTION, MT_DRUG_SECTION2, MT_DRUG_SECTION3, MT_DRUG_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vDrugSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esDrugCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_flCloseAreasOnly, g_esDrugAbility[type].g_flCloseAreasOnly);
	g_esDrugCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iComboAbility, g_esDrugAbility[type].g_iComboAbility);
	g_esDrugCache[tank].g_flDrugChance = flGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_flDrugChance, g_esDrugAbility[type].g_flDrugChance);
	g_esDrugCache[tank].g_flDrugInterval = flGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_flDrugInterval, g_esDrugAbility[type].g_flDrugInterval);
	g_esDrugCache[tank].g_flDrugRange = flGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_flDrugRange, g_esDrugAbility[type].g_flDrugRange);
	g_esDrugCache[tank].g_flDrugRangeChance = flGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_flDrugRangeChance, g_esDrugAbility[type].g_flDrugRangeChance);
	g_esDrugCache[tank].g_iDrugAbility = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iDrugAbility, g_esDrugAbility[type].g_iDrugAbility);
	g_esDrugCache[tank].g_iDrugCooldown = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iDrugCooldown, g_esDrugAbility[type].g_iDrugCooldown);
	g_esDrugCache[tank].g_iDrugDuration = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iDrugDuration, g_esDrugAbility[type].g_iDrugDuration);
	g_esDrugCache[tank].g_iDrugEffect = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iDrugEffect, g_esDrugAbility[type].g_iDrugEffect);
	g_esDrugCache[tank].g_iDrugHit = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iDrugHit, g_esDrugAbility[type].g_iDrugHit);
	g_esDrugCache[tank].g_iDrugHitMode = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iDrugHitMode, g_esDrugAbility[type].g_iDrugHitMode);
	g_esDrugCache[tank].g_iDrugMessage = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iDrugMessage, g_esDrugAbility[type].g_iDrugMessage);
	g_esDrugCache[tank].g_iDrugRangeCooldown = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iDrugRangeCooldown, g_esDrugAbility[type].g_iDrugRangeCooldown);
	g_esDrugCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iHumanAbility, g_esDrugAbility[type].g_iHumanAbility);
	g_esDrugCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iHumanAmmo, g_esDrugAbility[type].g_iHumanAmmo);
	g_esDrugCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iHumanCooldown, g_esDrugAbility[type].g_iHumanCooldown);
	g_esDrugCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iHumanRangeCooldown, g_esDrugAbility[type].g_iHumanRangeCooldown);
	g_esDrugCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_flOpenAreasOnly, g_esDrugAbility[type].g_flOpenAreasOnly);
	g_esDrugCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esDrugPlayer[tank].g_iRequiresHumans, g_esDrugAbility[type].g_iRequiresHumans);
	g_esDrugPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vDrugCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vDrugCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveDrug(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vDrugPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			vRemoveDrug(iTank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vDrugEventFired(Event event, const char[] name)
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
			vDrugCopyStats2(iBot, iTank);
			vRemoveDrug(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vDrugCopyStats2(iTank, iBot);
			vRemoveDrug(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iPlayerId = event.GetInt("userid"), iPlayer = GetClientOfUserId(iPlayerId);
		if (MT_IsTankSupported(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveDrug(iPlayer);
		}
		else if (bIsHumanSurvivor(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vDrug(iPlayer, false, g_flDrugAngles);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vDrugReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vDrugAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDrugAbility[g_esDrugPlayer[tank].g_iTankType].g_iAccessFlags, g_esDrugPlayer[tank].g_iAccessFlags)) || g_esDrugCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esDrugCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esDrugCache[tank].g_iDrugAbility == 1 && g_esDrugCache[tank].g_iComboAbility == 0)
	{
		vDrugAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vDrugButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esDrugCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esDrugCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDrugPlayer[tank].g_iTankType) || (g_esDrugCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDrugCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDrugAbility[g_esDrugPlayer[tank].g_iTankType].g_iAccessFlags, g_esDrugPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esDrugCache[tank].g_iDrugAbility == 1 && g_esDrugCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esDrugPlayer[tank].g_iRangeCooldown == -1 || g_esDrugPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vDrugAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrugHuman3", (g_esDrugPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vDrugChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveDrug(tank);
}

void vDrug(int survivor, bool toggle, float angles[20])
{
	float flAngles[3];
	GetClientEyeAngles(survivor, flAngles);
	flAngles[2] = toggle ? angles[MT_GetRandomInt(0, 100) % 20] : 0.0;
	TeleportEntity(survivor, .angles = flAngles);

	int iTargets[1], iColor[4] = {0, 0, 0, 128}, iColor2[4] = {0, 0, 0, 0}, iFlags = toggle ? MT_FADE_OUT : (MT_FADE_IN|MT_FADE_PURGE);
	iTargets[0] = survivor;

	if (toggle)
	{
		for (int iPos = 0; iPos < (sizeof iColor - 1); iPos++)
		{
			iColor[iPos] = MT_GetRandomInt(0, 255);
		}
	}

	Handle hMessage = StartMessageEx(g_umDrugFade, iTargets, 1);
	if (hMessage != null)
	{
		BfWrite bfWrite = UserMessageToBfWrite(hMessage);
		bfWrite.WriteShort(toggle ? 255 : 1536);
		bfWrite.WriteShort(toggle ? 255 : 1536);
		bfWrite.WriteShort(iFlags);

		for (int iPos = 0; iPos < (sizeof iColor); iPos++)
		{
			bfWrite.WriteByte(toggle ? iColor[iPos] : iColor2[iPos]);
		}

		EndMessage();
	}
}

void vDrugAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esDrugCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esDrugCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDrugPlayer[tank].g_iTankType) || (g_esDrugCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDrugCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDrugAbility[g_esDrugPlayer[tank].g_iTankType].g_iAccessFlags, g_esDrugPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esDrugPlayer[tank].g_iAmmoCount < g_esDrugCache[tank].g_iHumanAmmo && g_esDrugCache[tank].g_iHumanAmmo > 0))
	{
		g_esDrugPlayer[tank].g_bFailed = false;
		g_esDrugPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esDrugCache[tank].g_flDrugRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esDrugCache[tank].g_flDrugRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsHumanSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esDrugPlayer[tank].g_iTankType, g_esDrugAbility[g_esDrugPlayer[tank].g_iTankType].g_iImmunityFlags, g_esDrugPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vDrugHit(iSurvivor, tank, random, flChance, g_esDrugCache[tank].g_iDrugAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrugCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrugHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrugCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrugAmmo");
	}
}

void vDrugHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esDrugCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esDrugCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDrugPlayer[tank].g_iTankType) || (g_esDrugCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDrugCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esDrugAbility[g_esDrugPlayer[tank].g_iTankType].g_iAccessFlags, g_esDrugPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esDrugPlayer[tank].g_iTankType, g_esDrugAbility[g_esDrugPlayer[tank].g_iTankType].g_iImmunityFlags, g_esDrugPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esDrugPlayer[tank].g_iRangeCooldown != -1 && g_esDrugPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esDrugPlayer[tank].g_iCooldown != -1 && g_esDrugPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsHumanSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esDrugPlayer[tank].g_iAmmoCount < g_esDrugCache[tank].g_iHumanAmmo && g_esDrugCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esDrugPlayer[survivor].g_bAffected)
			{
				g_esDrugPlayer[survivor].g_bAffected = true;
				g_esDrugPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esDrugPlayer[tank].g_iRangeCooldown == -1 || g_esDrugPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrugCache[tank].g_iHumanAbility == 1)
					{
						g_esDrugPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrugHuman", g_esDrugPlayer[tank].g_iAmmoCount, g_esDrugCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esDrugCache[tank].g_iDrugRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrugCache[tank].g_iHumanAbility == 1 && g_esDrugPlayer[tank].g_iAmmoCount < g_esDrugCache[tank].g_iHumanAmmo && g_esDrugCache[tank].g_iHumanAmmo > 0) ? g_esDrugCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esDrugPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esDrugPlayer[tank].g_iRangeCooldown != -1 && g_esDrugPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrugHuman5", (g_esDrugPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esDrugPlayer[tank].g_iCooldown == -1 || g_esDrugPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esDrugCache[tank].g_iDrugCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrugCache[tank].g_iHumanAbility == 1) ? g_esDrugCache[tank].g_iHumanCooldown : iCooldown;
					g_esDrugPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esDrugPlayer[tank].g_iCooldown != -1 && g_esDrugPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrugHuman5", (g_esDrugPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esDrugCache[tank].g_flDrugInterval;
				DataPack dpDrug;
				CreateDataTimer(flInterval, tTimerDrug, dpDrug, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpDrug.WriteCell(GetClientUserId(survivor));
				dpDrug.WriteCell(GetClientUserId(tank));
				dpDrug.WriteCell(g_esDrugPlayer[tank].g_iTankType);
				dpDrug.WriteCell(messages);
				dpDrug.WriteCell(enabled);
				dpDrug.WriteCell(pos);
				dpDrug.WriteCell(iTime);

				vScreenEffect(survivor, tank, g_esDrugCache[tank].g_iDrugEffect, flags);

				if (g_esDrugCache[tank].g_iDrugMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Drug", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Drug", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esDrugPlayer[tank].g_iRangeCooldown == -1 || g_esDrugPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrugCache[tank].g_iHumanAbility == 1 && !g_esDrugPlayer[tank].g_bFailed)
				{
					g_esDrugPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrugHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esDrugCache[tank].g_iHumanAbility == 1 && !g_esDrugPlayer[tank].g_bNoAmmo)
		{
			g_esDrugPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "DrugAmmo");
		}
	}
}

void vDrugCopyStats2(int oldTank, int newTank)
{
	g_esDrugPlayer[newTank].g_iAmmoCount = g_esDrugPlayer[oldTank].g_iAmmoCount;
	g_esDrugPlayer[newTank].g_iCooldown = g_esDrugPlayer[oldTank].g_iCooldown;
	g_esDrugPlayer[newTank].g_iRangeCooldown = g_esDrugPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveDrug(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsHumanSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esDrugPlayer[iSurvivor].g_bAffected && g_esDrugPlayer[iSurvivor].g_iOwner == tank)
		{
			vDrug(iSurvivor, false, g_flDrugAngles);

			g_esDrugPlayer[iSurvivor].g_bAffected = false;
			g_esDrugPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vDrugReset3(tank);
}

void vDrugReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vDrugReset3(iPlayer);

			g_esDrugPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vDrugReset2(int survivor, int tank, int messages)
{
	g_esDrugPlayer[survivor].g_bAffected = false;
	g_esDrugPlayer[survivor].g_iOwner = 0;

	vDrug(survivor, false, g_flDrugAngles);

	if (g_esDrugCache[tank].g_iDrugMessage & messages)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Drug2", survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Drug2", LANG_SERVER, survivor);
	}
}

void vDrugReset3(int tank)
{
	g_esDrugPlayer[tank].g_bAffected = false;
	g_esDrugPlayer[tank].g_bFailed = false;
	g_esDrugPlayer[tank].g_bNoAmmo = false;
	g_esDrugPlayer[tank].g_iAmmoCount = 0;
	g_esDrugPlayer[tank].g_iCooldown = -1;
	g_esDrugPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerDrugCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDrugAbility[g_esDrugPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDrugPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDrugPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esDrugCache[iTank].g_iDrugAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vDrugAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerDrugCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esDrugPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDrugAbility[g_esDrugPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDrugPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDrugPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esDrugCache[iTank].g_iDrugHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esDrugCache[iTank].g_iDrugHitMode == 0 || g_esDrugCache[iTank].g_iDrugHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vDrugHit(iSurvivor, iTank, flRandom, flChance, g_esDrugCache[iTank].g_iDrugHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esDrugCache[iTank].g_iDrugHitMode == 0 || g_esDrugCache[iTank].g_iDrugHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vDrugHit(iSurvivor, iTank, flRandom, flChance, g_esDrugCache[iTank].g_iDrugHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerDrug(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsHumanSurvivor(iSurvivor))
	{
		g_esDrugPlayer[iSurvivor].g_bAffected = false;
		g_esDrugPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esDrugCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esDrugCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esDrugPlayer[iTank].g_iTankType) || (g_esDrugCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esDrugCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esDrugAbility[g_esDrugPlayer[iTank].g_iTankType].g_iAccessFlags, g_esDrugPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esDrugPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esDrugPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esDrugPlayer[iTank].g_iTankType, g_esDrugAbility[g_esDrugPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esDrugPlayer[iSurvivor].g_iImmunityFlags) || !g_esDrugPlayer[iSurvivor].g_bAffected)
	{
		vDrugReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iDrugEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esDrugCache[iTank].g_iDrugDuration,
		iTime = pack.ReadCell();
	if (iDrugEnabled == 0 || (iTime + iDuration) < GetTime())
	{
		vDrugReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	vDrug(iSurvivor, true, g_flDrugAngles);

	return Plugin_Handled;
}