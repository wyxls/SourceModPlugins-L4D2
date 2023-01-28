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

#define MT_SLOW_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_SLOW_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Slow Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank slows survivors down.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Slow Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_SLOW_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SOUND_DRIP "ambient/water/distant_drip2.wav"
#define SOUND_RAGE "npc/infected/action/rage/female/rage_68.wav"

#define MT_SLOW_SECTION "slowability"
#define MT_SLOW_SECTION2 "slow ability"
#define MT_SLOW_SECTION3 "slow_ability"
#define MT_SLOW_SECTION4 "slow"

#define MT_MENU_SLOW "Slow Ability"

#define MT_STEP_DEFAULTSIZE 18.0 // default step size

enum struct esSlowPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSlowChance;
	float g_flSlowDuration;
	float g_flSlowRange;
	float g_flSlowRangeChance;
	float g_flSlowSpeed;

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
	int g_iSlowAbility;
	int g_iSlowCooldown;
	int g_iSlowEffect;
	int g_iSlowHit;
	int g_iSlowHitMode;
	int g_iSlowIncline;
	int g_iSlowMessage;
	int g_iSlowRangeCooldown;
	int g_iTankType;
}

esSlowPlayer g_esSlowPlayer[MAXPLAYERS + 1];

enum struct esSlowAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSlowChance;
	float g_flSlowDuration;
	float g_flSlowRange;
	float g_flSlowRangeChance;
	float g_flSlowSpeed;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iSlowAbility;
	int g_iSlowCooldown;
	int g_iSlowEffect;
	int g_iSlowHit;
	int g_iSlowHitMode;
	int g_iSlowIncline;
	int g_iSlowMessage;
	int g_iSlowRangeCooldown;
}

esSlowAbility g_esSlowAbility[MT_MAXTYPES + 1];

enum struct esSlowCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSlowChance;
	float g_flSlowDuration;
	float g_flSlowRange;
	float g_flSlowRangeChance;
	float g_flSlowSpeed;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
	int g_iSlowAbility;
	int g_iSlowCooldown;
	int g_iSlowEffect;
	int g_iSlowHit;
	int g_iSlowHitMode;
	int g_iSlowIncline;
	int g_iSlowMessage;
	int g_iSlowRangeCooldown;
}

esSlowCache g_esSlowCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_slow", cmdSlowInfo, "View information about the Slow ability.");

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
void vSlowMapStart()
#else
public void OnMapStart()
#endif
{
	PrecacheSound(SOUND_DRIP, true);
	PrecacheSound(SOUND_RAGE, true);

	vSlowReset();
}

#if defined MT_ABILITIES_MAIN2
void vSlowClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnSlowTakeDamage);
	vSlowReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vSlowClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vSlowReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vSlowMapEnd()
#else
public void OnMapEnd()
#endif
{
	vSlowReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdSlowInfo(int client, int args)
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
		case false: vSlowMenu(client, MT_SLOW_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vSlowMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_SLOW_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iSlowMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Slow Ability Information");
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

int iSlowMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSlowCache[param1].g_iSlowAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esSlowCache[param1].g_iHumanAmmo - g_esSlowPlayer[param1].g_iAmmoCount), g_esSlowCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esSlowCache[param1].g_iHumanAbility == 1) ? g_esSlowCache[param1].g_iHumanCooldown : g_esSlowCache[param1].g_iSlowCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "SlowDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esSlowCache[param1].g_flSlowDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSlowCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esSlowCache[param1].g_iHumanAbility == 1) ? g_esSlowCache[param1].g_iHumanRangeCooldown : g_esSlowCache[param1].g_iSlowRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vSlowMenu(param1, MT_SLOW_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pSlow = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "SlowMenu", param1);
			pSlow.SetTitle(sMenuTitle);
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
void vSlowDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_SLOW, MT_MENU_SLOW);
}

#if defined MT_ABILITIES_MAIN2
void vSlowMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_SLOW, false))
	{
		vSlowMenu(client, MT_SLOW_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSlowMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_SLOW, false))
	{
		FormatEx(buffer, size, "%T", "SlowMenu2", client);
	}
}

Action OnSlowTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esSlowCache[attacker].g_iSlowHitMode == 0 || g_esSlowCache[attacker].g_iSlowHitMode == 1) && bIsSurvivor(victim) && g_esSlowCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esSlowAbility[g_esSlowPlayer[attacker].g_iTankType].g_iAccessFlags, g_esSlowPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esSlowPlayer[attacker].g_iTankType, g_esSlowAbility[g_esSlowPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esSlowPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vSlowHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esSlowCache[attacker].g_flSlowChance, g_esSlowCache[attacker].g_iSlowHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esSlowCache[victim].g_iSlowHitMode == 0 || g_esSlowCache[victim].g_iSlowHitMode == 2) && bIsSurvivor(attacker) && g_esSlowCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esSlowAbility[g_esSlowPlayer[victim].g_iTankType].g_iAccessFlags, g_esSlowPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esSlowPlayer[victim].g_iTankType, g_esSlowAbility[g_esSlowPlayer[victim].g_iTankType].g_iImmunityFlags, g_esSlowPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vSlowHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esSlowCache[victim].g_flSlowChance, g_esSlowCache[victim].g_iSlowHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vSlowPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_SLOW);
}

#if defined MT_ABILITIES_MAIN2
void vSlowAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_SLOW_SECTION);
	list2.PushString(MT_SLOW_SECTION2);
	list3.PushString(MT_SLOW_SECTION3);
	list4.PushString(MT_SLOW_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vSlowCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSlowCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_SLOW_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_SLOW_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_SLOW_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_SLOW_SECTION4);
	if (g_esSlowCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_SLOW_SECTION, false) || StrEqual(sSubset[iPos], MT_SLOW_SECTION2, false) || StrEqual(sSubset[iPos], MT_SLOW_SECTION3, false) || StrEqual(sSubset[iPos], MT_SLOW_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esSlowCache[tank].g_iSlowAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vSlowAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerSlowCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esSlowCache[tank].g_iSlowHitMode == 0 || g_esSlowCache[tank].g_iSlowHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vSlowHit(survivor, tank, random, flChance, g_esSlowCache[tank].g_iSlowHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esSlowCache[tank].g_iSlowHitMode == 0 || g_esSlowCache[tank].g_iSlowHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vSlowHit(survivor, tank, random, flChance, g_esSlowCache[tank].g_iSlowHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerSlowCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vSlowConfigsLoad(int mode)
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
				g_esSlowAbility[iIndex].g_iAccessFlags = 0;
				g_esSlowAbility[iIndex].g_iImmunityFlags = 0;
				g_esSlowAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esSlowAbility[iIndex].g_iComboAbility = 0;
				g_esSlowAbility[iIndex].g_iHumanAbility = 0;
				g_esSlowAbility[iIndex].g_iHumanAmmo = 5;
				g_esSlowAbility[iIndex].g_iHumanCooldown = 0;
				g_esSlowAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esSlowAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esSlowAbility[iIndex].g_iRequiresHumans = 0;
				g_esSlowAbility[iIndex].g_iSlowAbility = 0;
				g_esSlowAbility[iIndex].g_iSlowEffect = 0;
				g_esSlowAbility[iIndex].g_iSlowMessage = 0;
				g_esSlowAbility[iIndex].g_flSlowChance = 33.3;
				g_esSlowAbility[iIndex].g_iSlowCooldown = 0;
				g_esSlowAbility[iIndex].g_flSlowDuration = 5.0;
				g_esSlowAbility[iIndex].g_iSlowHit = 0;
				g_esSlowAbility[iIndex].g_iSlowHitMode = 0;
				g_esSlowAbility[iIndex].g_iSlowIncline = 1;
				g_esSlowAbility[iIndex].g_flSlowRange = 150.0;
				g_esSlowAbility[iIndex].g_flSlowRangeChance = 15.0;
				g_esSlowAbility[iIndex].g_iSlowRangeCooldown = 0;
				g_esSlowAbility[iIndex].g_flSlowSpeed = 0.25;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esSlowPlayer[iPlayer].g_iAccessFlags = 0;
					g_esSlowPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esSlowPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esSlowPlayer[iPlayer].g_iComboAbility = 0;
					g_esSlowPlayer[iPlayer].g_iHumanAbility = 0;
					g_esSlowPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esSlowPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esSlowPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esSlowPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esSlowPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esSlowPlayer[iPlayer].g_iSlowAbility = 0;
					g_esSlowPlayer[iPlayer].g_iSlowEffect = 0;
					g_esSlowPlayer[iPlayer].g_iSlowMessage = 0;
					g_esSlowPlayer[iPlayer].g_flSlowChance = 0.0;
					g_esSlowPlayer[iPlayer].g_iSlowCooldown = 0;
					g_esSlowPlayer[iPlayer].g_flSlowDuration = 0.0;
					g_esSlowPlayer[iPlayer].g_iSlowHit = 0;
					g_esSlowPlayer[iPlayer].g_iSlowHitMode = 0;
					g_esSlowPlayer[iPlayer].g_iSlowIncline = 0;
					g_esSlowPlayer[iPlayer].g_flSlowRange = 0.0;
					g_esSlowPlayer[iPlayer].g_flSlowRangeChance = 0.0;
					g_esSlowPlayer[iPlayer].g_iSlowRangeCooldown = 0;
					g_esSlowPlayer[iPlayer].g_flSlowSpeed = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSlowConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esSlowPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSlowPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSlowPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSlowPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esSlowPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSlowPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esSlowPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSlowPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esSlowPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSlowPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esSlowPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esSlowPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esSlowPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSlowPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSlowPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSlowPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esSlowPlayer[admin].g_iSlowAbility = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSlowPlayer[admin].g_iSlowAbility, value, 0, 1);
		g_esSlowPlayer[admin].g_iSlowEffect = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esSlowPlayer[admin].g_iSlowEffect, value, 0, 7);
		g_esSlowPlayer[admin].g_iSlowMessage = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSlowPlayer[admin].g_iSlowMessage, value, 0, 3);
		g_esSlowPlayer[admin].g_flSlowChance = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowChance", "Slow Chance", "Slow_Chance", "chance", g_esSlowPlayer[admin].g_flSlowChance, value, 0.0, 100.0);
		g_esSlowPlayer[admin].g_iSlowCooldown = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowCooldown", "Slow Cooldown", "Slow_Cooldown", "cooldown", g_esSlowPlayer[admin].g_iSlowCooldown, value, 0, 99999);
		g_esSlowPlayer[admin].g_flSlowDuration = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowDuration", "Slow Duration", "Slow_Duration", "duration", g_esSlowPlayer[admin].g_flSlowDuration, value, 0.1, 99999.0);
		g_esSlowPlayer[admin].g_iSlowHit = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowHit", "Slow Hit", "Slow_Hit", "hit", g_esSlowPlayer[admin].g_iSlowHit, value, 0, 1);
		g_esSlowPlayer[admin].g_iSlowHitMode = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowHitMode", "Slow Hit Mode", "Slow_Hit_Mode", "hitmode", g_esSlowPlayer[admin].g_iSlowHitMode, value, 0, 2);
		g_esSlowPlayer[admin].g_iSlowIncline = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowIncline", "Slow Incline", "Slow_Incline", "incline", g_esSlowPlayer[admin].g_iSlowIncline, value, 0, 1);
		g_esSlowPlayer[admin].g_flSlowRange = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowRange", "Slow Range", "Slow_Range", "range", g_esSlowPlayer[admin].g_flSlowRange, value, 1.0, 99999.0);
		g_esSlowPlayer[admin].g_flSlowRangeChance = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowRangeChance", "Slow Range Chance", "Slow_Range_Chance", "rangechance", g_esSlowPlayer[admin].g_flSlowRangeChance, value, 0.0, 100.0);
		g_esSlowPlayer[admin].g_iSlowRangeCooldown = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowRangeCooldown", "Slow Range Cooldown", "Slow_Range_Cooldown", "rangecooldown", g_esSlowPlayer[admin].g_iSlowRangeCooldown, value, 0, 99999);
		g_esSlowPlayer[admin].g_flSlowSpeed = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowSpeed", "Slow Speed", "Slow_Speed", "speed", g_esSlowPlayer[admin].g_flSlowSpeed, value, 0.1, 0.9);
		g_esSlowPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSlowPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esSlowAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSlowAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSlowAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSlowAbility[type].g_iComboAbility, value, 0, 1);
		g_esSlowAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSlowAbility[type].g_iHumanAbility, value, 0, 2);
		g_esSlowAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSlowAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esSlowAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSlowAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esSlowAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esSlowAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esSlowAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSlowAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSlowAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSlowAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esSlowAbility[type].g_iSlowAbility = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSlowAbility[type].g_iSlowAbility, value, 0, 1);
		g_esSlowAbility[type].g_iSlowEffect = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esSlowAbility[type].g_iSlowEffect, value, 0, 7);
		g_esSlowAbility[type].g_iSlowMessage = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSlowAbility[type].g_iSlowMessage, value, 0, 3);
		g_esSlowAbility[type].g_flSlowChance = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowChance", "Slow Chance", "Slow_Chance", "chance", g_esSlowAbility[type].g_flSlowChance, value, 0.0, 100.0);
		g_esSlowAbility[type].g_iSlowCooldown = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowCooldown", "Slow Cooldown", "Slow_Cooldown", "cooldown", g_esSlowAbility[type].g_iSlowCooldown, value, 0, 99999);
		g_esSlowAbility[type].g_flSlowDuration = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowDuration", "Slow Duration", "Slow_Duration", "duration", g_esSlowAbility[type].g_flSlowDuration, value, 0.1, 99999.0);
		g_esSlowAbility[type].g_iSlowHit = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowHit", "Slow Hit", "Slow_Hit", "hit", g_esSlowAbility[type].g_iSlowHit, value, 0, 1);
		g_esSlowAbility[type].g_iSlowHitMode = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowHitMode", "Slow Hit Mode", "Slow_Hit_Mode", "hitmode", g_esSlowAbility[type].g_iSlowHitMode, value, 0, 2);
		g_esSlowAbility[type].g_iSlowIncline = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowIncline", "Slow Incline", "Slow_Incline", "incline", g_esSlowAbility[type].g_iSlowIncline, value, 0, 1);
		g_esSlowAbility[type].g_flSlowRange = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowRange", "Slow Range", "Slow_Range", "range", g_esSlowAbility[type].g_flSlowRange, value, 1.0, 99999.0);
		g_esSlowAbility[type].g_flSlowRangeChance = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowRangeChance", "Slow Range Chance", "Slow_Range_Chance", "rangechance", g_esSlowAbility[type].g_flSlowRangeChance, value, 0.0, 100.0);
		g_esSlowAbility[type].g_iSlowRangeCooldown = iGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowRangeCooldown", "Slow Range Cooldown", "Slow_Range_Cooldown", "rangecooldown", g_esSlowAbility[type].g_iSlowRangeCooldown, value, 0, 99999);
		g_esSlowAbility[type].g_flSlowSpeed = flGetKeyValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "SlowSpeed", "Slow Speed", "Slow_Speed", "speed", g_esSlowAbility[type].g_flSlowSpeed, value, 0.1, 0.9);
		g_esSlowAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSlowAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SLOW_SECTION, MT_SLOW_SECTION2, MT_SLOW_SECTION3, MT_SLOW_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSlowSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esSlowCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_flCloseAreasOnly, g_esSlowAbility[type].g_flCloseAreasOnly);
	g_esSlowCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iComboAbility, g_esSlowAbility[type].g_iComboAbility);
	g_esSlowCache[tank].g_flSlowChance = flGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_flSlowChance, g_esSlowAbility[type].g_flSlowChance);
	g_esSlowCache[tank].g_flSlowDuration = flGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_flSlowDuration, g_esSlowAbility[type].g_flSlowDuration);
	g_esSlowCache[tank].g_flSlowRange = flGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_flSlowRange, g_esSlowAbility[type].g_flSlowRange);
	g_esSlowCache[tank].g_flSlowRangeChance = flGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_flSlowRangeChance, g_esSlowAbility[type].g_flSlowRangeChance);
	g_esSlowCache[tank].g_flSlowSpeed = flGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_flSlowSpeed, g_esSlowAbility[type].g_flSlowSpeed);
	g_esSlowCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iHumanAbility, g_esSlowAbility[type].g_iHumanAbility);
	g_esSlowCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iHumanAmmo, g_esSlowAbility[type].g_iHumanAmmo);
	g_esSlowCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iHumanCooldown, g_esSlowAbility[type].g_iHumanCooldown);
	g_esSlowCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iHumanRangeCooldown, g_esSlowAbility[type].g_iHumanRangeCooldown);
	g_esSlowCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_flOpenAreasOnly, g_esSlowAbility[type].g_flOpenAreasOnly);
	g_esSlowCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iRequiresHumans, g_esSlowAbility[type].g_iRequiresHumans);
	g_esSlowCache[tank].g_iSlowAbility = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iSlowAbility, g_esSlowAbility[type].g_iSlowAbility);
	g_esSlowCache[tank].g_iSlowCooldown = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iSlowCooldown, g_esSlowAbility[type].g_iSlowCooldown);
	g_esSlowCache[tank].g_iSlowEffect = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iSlowEffect, g_esSlowAbility[type].g_iSlowEffect);
	g_esSlowCache[tank].g_iSlowHit = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iSlowHit, g_esSlowAbility[type].g_iSlowHit);
	g_esSlowCache[tank].g_iSlowHitMode = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iSlowHitMode, g_esSlowAbility[type].g_iSlowHitMode);
	g_esSlowCache[tank].g_iSlowIncline = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iSlowIncline, g_esSlowAbility[type].g_iSlowIncline);
	g_esSlowCache[tank].g_iSlowMessage = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iSlowMessage, g_esSlowAbility[type].g_iSlowMessage);
	g_esSlowCache[tank].g_iSlowRangeCooldown = iGetSettingValue(apply, bHuman, g_esSlowPlayer[tank].g_iSlowRangeCooldown, g_esSlowAbility[type].g_iSlowRangeCooldown);
	g_esSlowPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vSlowCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vSlowCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveSlow(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vSlowPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			vRemoveSlow(iTank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSlowEventFired(Event event, const char[] name)
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
			vSlowCopyStats2(iBot, iTank);
			vRemoveSlow(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vSlowCopyStats2(iTank, iBot);
			vRemoveSlow(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iPlayerId = event.GetInt("userid"), iPlayer = GetClientOfUserId(iPlayerId);
		if (MT_IsTankSupported(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveSlow(iPlayer);
		}
		else if (bIsSurvivor(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vStopSlow(iPlayer, false);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vSlowReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vSlowRewardSurvivor(int survivor, int &type, bool apply)
#else
public Action MT_OnRewardSurvivor(int survivor, int tank, int &type, int priority, float &duration, bool apply)
#endif
{
	if (bIsSurvivor(survivor) && apply && (type & MT_REWARD_SPEEDBOOST) && g_esSlowPlayer[survivor].g_bAffected)
	{
		vStopSlow(survivor);
	}
#if !defined MT_ABILITIES_MAIN2
	return Plugin_Continue;
#endif
}

#if defined MT_ABILITIES_MAIN2
void vSlowAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSlowAbility[g_esSlowPlayer[tank].g_iTankType].g_iAccessFlags, g_esSlowPlayer[tank].g_iAccessFlags)) || g_esSlowCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esSlowCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esSlowCache[tank].g_iSlowAbility == 1 && g_esSlowCache[tank].g_iComboAbility == 0)
	{
		vSlowAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vSlowButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esSlowCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSlowCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSlowPlayer[tank].g_iTankType) || (g_esSlowCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSlowCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSlowAbility[g_esSlowPlayer[tank].g_iTankType].g_iAccessFlags, g_esSlowPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esSlowCache[tank].g_iSlowAbility == 1 && g_esSlowCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esSlowPlayer[tank].g_iRangeCooldown == -1 || g_esSlowPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vSlowAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "SlowHuman3", (g_esSlowPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSlowChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveSlow(tank);
}

void vSlowAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esSlowCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSlowCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSlowPlayer[tank].g_iTankType) || (g_esSlowCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSlowCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSlowAbility[g_esSlowPlayer[tank].g_iTankType].g_iAccessFlags, g_esSlowPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esSlowPlayer[tank].g_iAmmoCount < g_esSlowCache[tank].g_iHumanAmmo && g_esSlowCache[tank].g_iHumanAmmo > 0))
	{
		g_esSlowPlayer[tank].g_bFailed = false;
		g_esSlowPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esSlowCache[tank].g_flSlowRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esSlowCache[tank].g_flSlowRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esSlowPlayer[tank].g_iTankType, g_esSlowAbility[g_esSlowPlayer[tank].g_iTankType].g_iImmunityFlags, g_esSlowPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vSlowHit(iSurvivor, tank, random, flChance, g_esSlowCache[tank].g_iSlowAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSlowCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "SlowHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSlowCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SlowAmmo");
	}
}

void vSlowHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esSlowCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSlowCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSlowPlayer[tank].g_iTankType) || (g_esSlowCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSlowCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSlowAbility[g_esSlowPlayer[tank].g_iTankType].g_iAccessFlags, g_esSlowPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esSlowPlayer[tank].g_iTankType, g_esSlowAbility[g_esSlowPlayer[tank].g_iTankType].g_iImmunityFlags, g_esSlowPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esSlowPlayer[tank].g_iRangeCooldown != -1 && g_esSlowPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esSlowPlayer[tank].g_iCooldown != -1 && g_esSlowPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_SPEEDBOOST))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esSlowPlayer[tank].g_iAmmoCount < g_esSlowCache[tank].g_iHumanAmmo && g_esSlowCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esSlowPlayer[survivor].g_bAffected)
			{
				g_esSlowPlayer[survivor].g_bAffected = true;
				g_esSlowPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esSlowPlayer[tank].g_iRangeCooldown == -1 || g_esSlowPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSlowCache[tank].g_iHumanAbility == 1)
					{
						g_esSlowPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SlowHuman", g_esSlowPlayer[tank].g_iAmmoCount, g_esSlowCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esSlowCache[tank].g_iSlowRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSlowCache[tank].g_iHumanAbility == 1 && g_esSlowPlayer[tank].g_iAmmoCount < g_esSlowCache[tank].g_iHumanAmmo && g_esSlowCache[tank].g_iHumanAmmo > 0) ? g_esSlowCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esSlowPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esSlowPlayer[tank].g_iRangeCooldown != -1 && g_esSlowPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SlowHuman5", (g_esSlowPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esSlowPlayer[tank].g_iCooldown == -1 || g_esSlowPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esSlowCache[tank].g_iSlowCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSlowCache[tank].g_iHumanAbility == 1) ? g_esSlowCache[tank].g_iHumanCooldown : iCooldown;
					g_esSlowPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esSlowPlayer[tank].g_iCooldown != -1 && g_esSlowPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SlowHuman5", (g_esSlowPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flSpeed = (pos != -1) ? MT_GetCombinationSetting(tank, 16, pos) : g_esSlowCache[tank].g_flSlowSpeed;
				SetEntPropFloat(survivor, Prop_Send, "m_flLaggedMovementValue", flSpeed);

				if (g_esSlowCache[tank].g_iSlowIncline == 1)
				{
					SetEntPropFloat(survivor, Prop_Send, "m_flStepSize", 1.0);
				}

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esSlowCache[tank].g_flSlowDuration;
				DataPack dpStopSlow;
				CreateDataTimer(flDuration, tTimerStopSlow, dpStopSlow, TIMER_FLAG_NO_MAPCHANGE);
				dpStopSlow.WriteCell(GetClientUserId(survivor));
				dpStopSlow.WriteCell(GetClientUserId(tank));
				dpStopSlow.WriteCell(messages);

				vScreenEffect(survivor, tank, g_esSlowCache[tank].g_iSlowEffect, flags);
				EmitSoundToAll(SOUND_RAGE, survivor);

				if (g_esSlowCache[tank].g_iSlowMessage & messages)
				{
					char sTankName[33];
					float flPercent = (flSpeed * 100.0);
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Slow", sTankName, survivor, flPercent);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Slow", LANG_SERVER, sTankName, survivor, flPercent);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esSlowPlayer[tank].g_iRangeCooldown == -1 || g_esSlowPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSlowCache[tank].g_iHumanAbility == 1 && !g_esSlowPlayer[tank].g_bFailed)
				{
					g_esSlowPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "SlowHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSlowCache[tank].g_iHumanAbility == 1 && !g_esSlowPlayer[tank].g_bNoAmmo)
		{
			g_esSlowPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "SlowAmmo");
		}
	}
}

void vSlowCopyStats2(int oldTank, int newTank)
{
	g_esSlowPlayer[newTank].g_iAmmoCount = g_esSlowPlayer[oldTank].g_iAmmoCount;
	g_esSlowPlayer[newTank].g_iCooldown = g_esSlowPlayer[oldTank].g_iCooldown;
	g_esSlowPlayer[newTank].g_iRangeCooldown = g_esSlowPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveSlow(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esSlowPlayer[iSurvivor].g_bAffected && g_esSlowPlayer[iSurvivor].g_iOwner == tank)
		{
			vStopSlow(iSurvivor);
		}
	}

	vSlowReset2(tank);
}

void vSlowReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vSlowReset2(iPlayer);
		}
	}
}

void vSlowReset2(int tank)
{
	g_esSlowPlayer[tank].g_bAffected = false;
	g_esSlowPlayer[tank].g_bFailed = false;
	g_esSlowPlayer[tank].g_bNoAmmo = false;
	g_esSlowPlayer[tank].g_iAmmoCount = 0;
	g_esSlowPlayer[tank].g_iCooldown = -1;
	g_esSlowPlayer[tank].g_iRangeCooldown = -1;
}

void vStopSlow(int survivor, bool all = true)
{
	g_esSlowPlayer[survivor].g_bAffected = false;
	g_esSlowPlayer[survivor].g_iOwner = 0;

	SetEntPropFloat(survivor, Prop_Send, "m_flLaggedMovementValue", 1.0);
	SetEntPropFloat(survivor, Prop_Send, "m_flStepSize", MT_STEP_DEFAULTSIZE);

	if (all)
	{
		EmitSoundToAll(SOUND_DRIP, survivor);
	}
}

Action tTimerSlowCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSlowAbility[g_esSlowPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSlowPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSlowPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSlowCache[iTank].g_iSlowAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vSlowAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerSlowCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esSlowPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSlowAbility[g_esSlowPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSlowPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSlowPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSlowCache[iTank].g_iSlowHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esSlowCache[iTank].g_iSlowHitMode == 0 || g_esSlowCache[iTank].g_iSlowHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vSlowHit(iSurvivor, iTank, flRandom, flChance, g_esSlowCache[iTank].g_iSlowHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esSlowCache[iTank].g_iSlowHitMode == 0 || g_esSlowCache[iTank].g_iSlowHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vSlowHit(iSurvivor, iTank, flRandom, flChance, g_esSlowCache[iTank].g_iSlowHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopSlow(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor))
	{
		g_esSlowPlayer[iSurvivor].g_bAffected = false;
		g_esSlowPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank) || !g_esSlowPlayer[iSurvivor].g_bAffected)
	{
		vStopSlow(iSurvivor);

		return Plugin_Stop;
	}

	vStopSlow(iSurvivor);

	int iMessage = pack.ReadCell();
	if (g_esSlowCache[iTank].g_iSlowMessage & iMessage)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Slow2", iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Slow2", LANG_SERVER, iSurvivor);
	}

	return Plugin_Continue;
}