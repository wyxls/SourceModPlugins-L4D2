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

#define MT_NULLIFY_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_NULLIFY_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Nullify Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank nullifies all of the survivors' damage.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Nullify Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_NULLIFY_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SOUND_METAL "physics/metal/metal_solid_impact_hard5.wav"

#define MT_NULLIFY_SECTION "nullifyability"
#define MT_NULLIFY_SECTION2 "nullify ability"
#define MT_NULLIFY_SECTION3 "nullify_ability"
#define MT_NULLIFY_SECTION4 "nullify"

#define MT_MENU_NULLIFY "Nullify Ability"

enum struct esNullifyPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flNullifyChance;
	float g_flNullifyDuration;
	float g_flNullifyRange;
	float g_flNullifyRangeChance;
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
	int g_iNullifyAbility;
	int g_iNullifyCooldown;
	int g_iNullifyEffect;
	int g_iNullifyHit;
	int g_iNullifyHitMode;
	int g_iNullifyMessage;
	int g_iNullifyRangeCooldown;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esNullifyPlayer g_esNullifyPlayer[MAXPLAYERS + 1];

enum struct esNullifyAbility
{
	float g_flCloseAreasOnly;
	float g_flNullifyChance;
	float g_flNullifyDuration;
	float g_flNullifyRange;
	float g_flNullifyRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iNullifyAbility;
	int g_iNullifyCooldown;
	int g_iNullifyEffect;
	int g_iNullifyHit;
	int g_iNullifyHitMode;
	int g_iNullifyMessage;
	int g_iNullifyRangeCooldown;
	int g_iRequiresHumans;
}

esNullifyAbility g_esNullifyAbility[MT_MAXTYPES + 1];

enum struct esNullifyCache
{
	float g_flCloseAreasOnly;
	float g_flNullifyChance;
	float g_flNullifyDuration;
	float g_flNullifyRange;
	float g_flNullifyRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iNullifyAbility;
	int g_iNullifyCooldown;
	int g_iNullifyEffect;
	int g_iNullifyHit;
	int g_iNullifyHitMode;
	int g_iNullifyMessage;
	int g_iNullifyRangeCooldown;
	int g_iRequiresHumans;
}

esNullifyCache g_esNullifyCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_nullify", cmdNullifyInfo, "View information about the Nullify ability.");

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
void vNullifyMapStart()
#else
public void OnMapStart()
#endif
{
	vNullifyReset();
}

#if defined MT_ABILITIES_MAIN2
void vNullifyClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnNullifyTakeDamage);
	vNullifyReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vNullifyClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vNullifyReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vNullifyMapEnd()
#else
public void OnMapEnd()
#endif
{
	vNullifyReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdNullifyInfo(int client, int args)
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
		case false: vNullifyMenu(client, MT_NULLIFY_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vNullifyMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_NULLIFY_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iNullifyMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Nullify Ability Information");
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

int iNullifyMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esNullifyCache[param1].g_iNullifyAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esNullifyCache[param1].g_iHumanAmmo - g_esNullifyPlayer[param1].g_iAmmoCount), g_esNullifyCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esNullifyCache[param1].g_iHumanAbility == 1) ? g_esNullifyCache[param1].g_iHumanCooldown : g_esNullifyCache[param1].g_iNullifyCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "NullifyDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esNullifyCache[param1].g_flNullifyDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esNullifyCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esNullifyCache[param1].g_iHumanAbility == 1) ? g_esNullifyCache[param1].g_iHumanRangeCooldown : g_esNullifyCache[param1].g_iNullifyRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vNullifyMenu(param1, MT_NULLIFY_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pNullify = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "NullifyMenu", param1);
			pNullify.SetTitle(sMenuTitle);
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
void vNullifyDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_NULLIFY, MT_MENU_NULLIFY);
}

#if defined MT_ABILITIES_MAIN2
void vNullifyMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_NULLIFY, false))
	{
		vNullifyMenu(client, MT_NULLIFY_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vNullifyMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_NULLIFY, false))
	{
		FormatEx(buffer, size, "%T", "NullifyMenu2", client);
	}
}

Action OnNullifyTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		char sClassname[32];
		if (bIsValidEntity(inflictor))
		{
			GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		}

		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esNullifyCache[attacker].g_iNullifyHitMode == 0 || g_esNullifyCache[attacker].g_iNullifyHitMode == 1) && bIsSurvivor(victim) && g_esNullifyCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esNullifyAbility[g_esNullifyPlayer[attacker].g_iTankType].g_iAccessFlags, g_esNullifyPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esNullifyPlayer[attacker].g_iTankType, g_esNullifyAbility[g_esNullifyPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esNullifyPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vNullifyHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esNullifyCache[attacker].g_flNullifyChance, g_esNullifyCache[attacker].g_iNullifyHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && bIsSurvivor(attacker))
		{
			if ((g_esNullifyCache[victim].g_iNullifyHitMode == 0 || g_esNullifyCache[victim].g_iNullifyHitMode == 2) && StrEqual(sClassname[7], "melee") && g_esNullifyCache[victim].g_iComboAbility == 0)
			{
				if ((MT_HasAdminAccess(victim) || bHasAdminAccess(victim, g_esNullifyAbility[g_esNullifyPlayer[victim].g_iTankType].g_iAccessFlags, g_esNullifyPlayer[victim].g_iAccessFlags)) && !MT_IsAdminImmune(attacker, victim) && !bIsAdminImmune(attacker, g_esNullifyPlayer[victim].g_iTankType, g_esNullifyAbility[g_esNullifyPlayer[victim].g_iTankType].g_iImmunityFlags, g_esNullifyPlayer[attacker].g_iImmunityFlags))
				{
					vNullifyHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esNullifyCache[victim].g_flNullifyChance, g_esNullifyCache[victim].g_iNullifyHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
				}
			}

			if (g_esNullifyPlayer[attacker].g_bAffected && !MT_DoesSurvivorHaveRewardType(attacker, MT_REWARD_DAMAGEBOOST))
			{
				EmitSoundToAll(SOUND_METAL, victim);

				if ((damagetype & DMG_SLASH) || (damagetype & DMG_CLUB))
				{
					float flTankPos[3];
					GetClientAbsOrigin(victim, flTankPos);

					switch (MT_DoesSurvivorHaveRewardType(attacker, MT_REWARD_GODMODE))
					{
						case true: vPushNearbyEntities(victim, flTankPos, 300.0, 100.0);
						case false: vPushNearbyEntities(victim, flTankPos);
					}
				}

				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vNullifyPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_NULLIFY);
}

#if defined MT_ABILITIES_MAIN2
void vNullifyAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_NULLIFY_SECTION);
	list2.PushString(MT_NULLIFY_SECTION2);
	list3.PushString(MT_NULLIFY_SECTION3);
	list4.PushString(MT_NULLIFY_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vNullifyCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNullifyCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_NULLIFY_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_NULLIFY_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_NULLIFY_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_NULLIFY_SECTION4);
	if (g_esNullifyCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_NULLIFY_SECTION, false) || StrEqual(sSubset[iPos], MT_NULLIFY_SECTION2, false) || StrEqual(sSubset[iPos], MT_NULLIFY_SECTION3, false) || StrEqual(sSubset[iPos], MT_NULLIFY_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esNullifyCache[tank].g_iNullifyAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vNullifyAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerNullifyCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esNullifyCache[tank].g_iNullifyHitMode == 0 || g_esNullifyCache[tank].g_iNullifyHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vNullifyHit(survivor, tank, random, flChance, g_esNullifyCache[tank].g_iNullifyHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esNullifyCache[tank].g_iNullifyHitMode == 0 || g_esNullifyCache[tank].g_iNullifyHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vNullifyHit(survivor, tank, random, flChance, g_esNullifyCache[tank].g_iNullifyHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerNullifyCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vNullifyConfigsLoad(int mode)
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
				g_esNullifyAbility[iIndex].g_iAccessFlags = 0;
				g_esNullifyAbility[iIndex].g_iImmunityFlags = 0;
				g_esNullifyAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esNullifyAbility[iIndex].g_iComboAbility = 0;
				g_esNullifyAbility[iIndex].g_iHumanAbility = 0;
				g_esNullifyAbility[iIndex].g_iHumanAmmo = 5;
				g_esNullifyAbility[iIndex].g_iHumanCooldown = 0;
				g_esNullifyAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esNullifyAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esNullifyAbility[iIndex].g_iRequiresHumans = 1;
				g_esNullifyAbility[iIndex].g_iNullifyAbility = 0;
				g_esNullifyAbility[iIndex].g_iNullifyEffect = 0;
				g_esNullifyAbility[iIndex].g_iNullifyMessage = 0;
				g_esNullifyAbility[iIndex].g_flNullifyChance = 33.3;
				g_esNullifyAbility[iIndex].g_iNullifyCooldown = 0;
				g_esNullifyAbility[iIndex].g_flNullifyDuration = 5.0;
				g_esNullifyAbility[iIndex].g_iNullifyHit = 0;
				g_esNullifyAbility[iIndex].g_iNullifyHitMode = 0;
				g_esNullifyAbility[iIndex].g_flNullifyRange = 150.0;
				g_esNullifyAbility[iIndex].g_flNullifyRangeChance = 15.0;
				g_esNullifyAbility[iIndex].g_iNullifyRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esNullifyPlayer[iPlayer].g_iAccessFlags = 0;
					g_esNullifyPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esNullifyPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esNullifyPlayer[iPlayer].g_iComboAbility = 0;
					g_esNullifyPlayer[iPlayer].g_iHumanAbility = 0;
					g_esNullifyPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esNullifyPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esNullifyPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esNullifyPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esNullifyPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esNullifyPlayer[iPlayer].g_iNullifyAbility = 0;
					g_esNullifyPlayer[iPlayer].g_iNullifyEffect = 0;
					g_esNullifyPlayer[iPlayer].g_iNullifyMessage = 0;
					g_esNullifyPlayer[iPlayer].g_flNullifyChance = 0.0;
					g_esNullifyPlayer[iPlayer].g_iNullifyCooldown = 0;
					g_esNullifyPlayer[iPlayer].g_flNullifyDuration = 0.0;
					g_esNullifyPlayer[iPlayer].g_iNullifyHit = 0;
					g_esNullifyPlayer[iPlayer].g_iNullifyHitMode = 0;
					g_esNullifyPlayer[iPlayer].g_flNullifyRange = 0.0;
					g_esNullifyPlayer[iPlayer].g_flNullifyRangeChance = 0.0;
					g_esNullifyPlayer[iPlayer].g_iNullifyRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vNullifyConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esNullifyPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esNullifyPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esNullifyPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esNullifyPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esNullifyPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esNullifyPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esNullifyPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esNullifyPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esNullifyPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esNullifyPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esNullifyPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esNullifyPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esNullifyPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esNullifyPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esNullifyPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esNullifyPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esNullifyPlayer[admin].g_iNullifyAbility = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esNullifyPlayer[admin].g_iNullifyAbility, value, 0, 1);
		g_esNullifyPlayer[admin].g_iNullifyEffect = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esNullifyPlayer[admin].g_iNullifyEffect, value, 0, 7);
		g_esNullifyPlayer[admin].g_iNullifyMessage = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esNullifyPlayer[admin].g_iNullifyMessage, value, 0, 3);
		g_esNullifyPlayer[admin].g_flNullifyChance = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyChance", "Nullify Chance", "Nullify_Chance", "chance", g_esNullifyPlayer[admin].g_flNullifyChance, value, 0.0, 100.0);
		g_esNullifyPlayer[admin].g_iNullifyCooldown = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyCooldown", "Nullify Cooldown", "Nullify_Cooldown", "cooldown", g_esNullifyPlayer[admin].g_iNullifyCooldown, value, 0, 99999);
		g_esNullifyPlayer[admin].g_flNullifyDuration = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyDuration", "Nullify Duration", "Nullify_Duration", "duration", g_esNullifyPlayer[admin].g_flNullifyDuration, value, 0.1, 99999.0);
		g_esNullifyPlayer[admin].g_iNullifyHit = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyHit", "Nullify Hit", "Nullify_Hit", "hit", g_esNullifyPlayer[admin].g_iNullifyHit, value, 0, 1);
		g_esNullifyPlayer[admin].g_iNullifyHitMode = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyHitMode", "Nullify Hit Mode", "Nullify_Hit_Mode", "hitmode", g_esNullifyPlayer[admin].g_iNullifyHitMode, value, 0, 2);
		g_esNullifyPlayer[admin].g_flNullifyRange = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyRange", "Nullify Range", "Nullify_Range", "range", g_esNullifyPlayer[admin].g_flNullifyRange, value, 1.0, 99999.0);
		g_esNullifyPlayer[admin].g_flNullifyRangeChance = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyRangeChance", "Nullify Range Chance", "Nullify_Range_Chance", "rangechance", g_esNullifyPlayer[admin].g_flNullifyRangeChance, value, 0.0, 100.0);
		g_esNullifyPlayer[admin].g_iNullifyRangeCooldown = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyRangeCooldown", "Nullify Range Cooldown", "Nullify_Range_Cooldown", "rangecooldown", g_esNullifyPlayer[admin].g_iNullifyRangeCooldown, value, 0, 99999);
		g_esNullifyPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esNullifyPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esNullifyAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esNullifyAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esNullifyAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esNullifyAbility[type].g_iComboAbility, value, 0, 1);
		g_esNullifyAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esNullifyAbility[type].g_iHumanAbility, value, 0, 2);
		g_esNullifyAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esNullifyAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esNullifyAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esNullifyAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esNullifyAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esNullifyAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esNullifyAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esNullifyAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esNullifyAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esNullifyAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esNullifyAbility[type].g_iNullifyAbility = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esNullifyAbility[type].g_iNullifyAbility, value, 0, 1);
		g_esNullifyAbility[type].g_iNullifyEffect = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esNullifyAbility[type].g_iNullifyEffect, value, 0, 7);
		g_esNullifyAbility[type].g_iNullifyMessage = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esNullifyAbility[type].g_iNullifyMessage, value, 0, 3);
		g_esNullifyAbility[type].g_flNullifyChance = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyChance", "Nullify Chance", "Nullify_Chance", "chance", g_esNullifyAbility[type].g_flNullifyChance, value, 0.0, 100.0);
		g_esNullifyAbility[type].g_iNullifyCooldown = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyCooldown", "Nullify Cooldown", "Nullify_Cooldown", "cooldown", g_esNullifyAbility[type].g_iNullifyCooldown, value, 0, 99999);
		g_esNullifyAbility[type].g_flNullifyDuration = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyDuration", "Nullify Duration", "Nullify_Duration", "duration", g_esNullifyAbility[type].g_flNullifyDuration, value, 0.1, 99999.0);
		g_esNullifyAbility[type].g_iNullifyHit = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyHit", "Nullify Hit", "Nullify_Hit", "hit", g_esNullifyAbility[type].g_iNullifyHit, value, 0, 1);
		g_esNullifyAbility[type].g_iNullifyHitMode = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyHitMode", "Nullify Hit Mode", "Nullify_Hit_Mode", "hitmode", g_esNullifyAbility[type].g_iNullifyHitMode, value, 0, 2);
		g_esNullifyAbility[type].g_flNullifyRange = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyRange", "Nullify Range", "Nullify_Range", "range", g_esNullifyAbility[type].g_flNullifyRange, value, 1.0, 99999.0);
		g_esNullifyAbility[type].g_flNullifyRangeChance = flGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyRangeChance", "Nullify Range Chance", "Nullify_Range_Chance", "rangechance", g_esNullifyAbility[type].g_flNullifyRangeChance, value, 0.0, 100.0);
		g_esNullifyAbility[type].g_iNullifyRangeCooldown = iGetKeyValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "NullifyRangeCooldown", "Nullify Range Cooldown", "Nullify_Range_Cooldown", "rangecooldown", g_esNullifyAbility[type].g_iNullifyRangeCooldown, value, 0, 99999);
		g_esNullifyAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esNullifyAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_NULLIFY_SECTION, MT_NULLIFY_SECTION2, MT_NULLIFY_SECTION3, MT_NULLIFY_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vNullifySettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esNullifyCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_flCloseAreasOnly, g_esNullifyAbility[type].g_flCloseAreasOnly);
	g_esNullifyCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iComboAbility, g_esNullifyAbility[type].g_iComboAbility);
	g_esNullifyCache[tank].g_flNullifyChance = flGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_flNullifyChance, g_esNullifyAbility[type].g_flNullifyChance);
	g_esNullifyCache[tank].g_flNullifyDuration = flGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_flNullifyDuration, g_esNullifyAbility[type].g_flNullifyDuration);
	g_esNullifyCache[tank].g_flNullifyRange = flGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_flNullifyRange, g_esNullifyAbility[type].g_flNullifyRange);
	g_esNullifyCache[tank].g_flNullifyRangeChance = flGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_flNullifyRangeChance, g_esNullifyAbility[type].g_flNullifyRangeChance);
	g_esNullifyCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iHumanAbility, g_esNullifyAbility[type].g_iHumanAbility);
	g_esNullifyCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iHumanAmmo, g_esNullifyAbility[type].g_iHumanAmmo);
	g_esNullifyCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iHumanCooldown, g_esNullifyAbility[type].g_iHumanCooldown);
	g_esNullifyCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iHumanRangeCooldown, g_esNullifyAbility[type].g_iHumanRangeCooldown);
	g_esNullifyCache[tank].g_iNullifyAbility = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iNullifyAbility, g_esNullifyAbility[type].g_iNullifyAbility);
	g_esNullifyCache[tank].g_iNullifyCooldown = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iNullifyCooldown, g_esNullifyAbility[type].g_iNullifyCooldown);
	g_esNullifyCache[tank].g_iNullifyEffect = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iNullifyEffect, g_esNullifyAbility[type].g_iNullifyEffect);
	g_esNullifyCache[tank].g_iNullifyHit = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iNullifyHit, g_esNullifyAbility[type].g_iNullifyHit);
	g_esNullifyCache[tank].g_iNullifyHitMode = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iNullifyHitMode, g_esNullifyAbility[type].g_iNullifyHitMode);
	g_esNullifyCache[tank].g_iNullifyMessage = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iNullifyMessage, g_esNullifyAbility[type].g_iNullifyMessage);
	g_esNullifyCache[tank].g_iNullifyRangeCooldown = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iNullifyRangeCooldown, g_esNullifyAbility[type].g_iNullifyRangeCooldown);
	g_esNullifyCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_flOpenAreasOnly, g_esNullifyAbility[type].g_flOpenAreasOnly);
	g_esNullifyCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esNullifyPlayer[tank].g_iRequiresHumans, g_esNullifyAbility[type].g_iRequiresHumans);
	g_esNullifyPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vNullifyCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vNullifyCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveNullify(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vNullifyEventFired(Event event, const char[] name)
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
			vNullifyCopyStats2(iBot, iTank);
			vRemoveNullify(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vNullifyCopyStats2(iTank, iBot);
			vRemoveNullify(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveNullify(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vNullifyReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vNullifyAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esNullifyAbility[g_esNullifyPlayer[tank].g_iTankType].g_iAccessFlags, g_esNullifyPlayer[tank].g_iAccessFlags)) || g_esNullifyCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esNullifyCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esNullifyCache[tank].g_iNullifyAbility == 1 && g_esNullifyCache[tank].g_iComboAbility == 0)
	{
		vNullifyAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vNullifyButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esNullifyCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esNullifyCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esNullifyPlayer[tank].g_iTankType) || (g_esNullifyCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esNullifyCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esNullifyAbility[g_esNullifyPlayer[tank].g_iTankType].g_iAccessFlags, g_esNullifyPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esNullifyCache[tank].g_iNullifyAbility == 1 && g_esNullifyCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esNullifyPlayer[tank].g_iRangeCooldown == -1 || g_esNullifyPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vNullifyAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "NullifyHuman3", (g_esNullifyPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vNullifyChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveNullify(tank);
}

void vNullifyAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esNullifyCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esNullifyCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esNullifyPlayer[tank].g_iTankType) || (g_esNullifyCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esNullifyCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esNullifyAbility[g_esNullifyPlayer[tank].g_iTankType].g_iAccessFlags, g_esNullifyPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esNullifyPlayer[tank].g_iAmmoCount < g_esNullifyCache[tank].g_iHumanAmmo && g_esNullifyCache[tank].g_iHumanAmmo > 0))
	{
		g_esNullifyPlayer[tank].g_bFailed = false;
		g_esNullifyPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esNullifyCache[tank].g_flNullifyRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esNullifyCache[tank].g_flNullifyRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esNullifyPlayer[tank].g_iTankType, g_esNullifyAbility[g_esNullifyPlayer[tank].g_iTankType].g_iImmunityFlags, g_esNullifyPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vNullifyHit(iSurvivor, tank, random, flChance, g_esNullifyCache[tank].g_iNullifyAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNullifyCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "NullifyHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNullifyCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "NullifyAmmo");
	}
}

void vNullifyHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esNullifyCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esNullifyCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esNullifyPlayer[tank].g_iTankType) || (g_esNullifyCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esNullifyCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esNullifyAbility[g_esNullifyPlayer[tank].g_iTankType].g_iAccessFlags, g_esNullifyPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esNullifyPlayer[tank].g_iTankType, g_esNullifyAbility[g_esNullifyPlayer[tank].g_iTankType].g_iImmunityFlags, g_esNullifyPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esNullifyPlayer[tank].g_iRangeCooldown != -1 && g_esNullifyPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esNullifyPlayer[tank].g_iCooldown != -1 && g_esNullifyPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_DAMAGEBOOST))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esNullifyPlayer[tank].g_iAmmoCount < g_esNullifyCache[tank].g_iHumanAmmo && g_esNullifyCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esNullifyPlayer[survivor].g_bAffected)
			{
				g_esNullifyPlayer[survivor].g_bAffected = true;
				g_esNullifyPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esNullifyPlayer[tank].g_iRangeCooldown == -1 || g_esNullifyPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNullifyCache[tank].g_iHumanAbility == 1)
					{
						g_esNullifyPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "NullifyHuman", g_esNullifyPlayer[tank].g_iAmmoCount, g_esNullifyCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esNullifyCache[tank].g_iNullifyRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNullifyCache[tank].g_iHumanAbility == 1 && g_esNullifyPlayer[tank].g_iAmmoCount < g_esNullifyCache[tank].g_iHumanAmmo && g_esNullifyCache[tank].g_iHumanAmmo > 0) ? g_esNullifyCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esNullifyPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esNullifyPlayer[tank].g_iRangeCooldown != -1 && g_esNullifyPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "NullifyHuman5", (g_esNullifyPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esNullifyPlayer[tank].g_iCooldown == -1 || g_esNullifyPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esNullifyCache[tank].g_iNullifyCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNullifyCache[tank].g_iHumanAbility == 1) ? g_esNullifyCache[tank].g_iHumanCooldown : iCooldown;
					g_esNullifyPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esNullifyPlayer[tank].g_iCooldown != -1 && g_esNullifyPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "NullifyHuman5", (g_esNullifyPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esNullifyCache[tank].g_flNullifyDuration;
				DataPack dpStopNullify;
				CreateDataTimer(flDuration, tTimerStopNullify, dpStopNullify, TIMER_FLAG_NO_MAPCHANGE);
				dpStopNullify.WriteCell(GetClientUserId(survivor));
				dpStopNullify.WriteCell(GetClientUserId(tank));
				dpStopNullify.WriteCell(messages);

				vScreenEffect(survivor, tank, g_esNullifyCache[tank].g_iNullifyEffect, flags);

				if (g_esNullifyCache[tank].g_iNullifyMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Nullify", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Nullify", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esNullifyPlayer[tank].g_iRangeCooldown == -1 || g_esNullifyPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNullifyCache[tank].g_iHumanAbility == 1 && !g_esNullifyPlayer[tank].g_bFailed)
				{
					g_esNullifyPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "NullifyHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esNullifyCache[tank].g_iHumanAbility == 1 && !g_esNullifyPlayer[tank].g_bNoAmmo)
		{
			g_esNullifyPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "NullifyAmmo");
		}
	}
}

void vNullifyCopyStats2(int oldTank, int newTank)
{
	g_esNullifyPlayer[newTank].g_iAmmoCount = g_esNullifyPlayer[oldTank].g_iAmmoCount;
	g_esNullifyPlayer[newTank].g_iCooldown = g_esNullifyPlayer[oldTank].g_iCooldown;
	g_esNullifyPlayer[newTank].g_iRangeCooldown = g_esNullifyPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveNullify(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esNullifyPlayer[iSurvivor].g_bAffected && g_esNullifyPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esNullifyPlayer[iSurvivor].g_bAffected = false;
			g_esNullifyPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vNullifyReset2(tank);
}

void vNullifyReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vNullifyReset2(iPlayer);

			g_esNullifyPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vNullifyReset2(int tank)
{
	g_esNullifyPlayer[tank].g_bAffected = false;
	g_esNullifyPlayer[tank].g_bFailed = false;
	g_esNullifyPlayer[tank].g_bNoAmmo = false;
	g_esNullifyPlayer[tank].g_iAmmoCount = 0;
	g_esNullifyPlayer[tank].g_iCooldown = -1;
	g_esNullifyPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerNullifyCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esNullifyAbility[g_esNullifyPlayer[iTank].g_iTankType].g_iAccessFlags, g_esNullifyPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esNullifyPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esNullifyCache[iTank].g_iNullifyAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vNullifyAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerNullifyCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esNullifyPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esNullifyAbility[g_esNullifyPlayer[iTank].g_iTankType].g_iAccessFlags, g_esNullifyPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esNullifyPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esNullifyCache[iTank].g_iNullifyHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esNullifyCache[iTank].g_iNullifyHitMode == 0 || g_esNullifyCache[iTank].g_iNullifyHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vNullifyHit(iSurvivor, iTank, flRandom, flChance, g_esNullifyCache[iTank].g_iNullifyHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esNullifyCache[iTank].g_iNullifyHitMode == 0 || g_esNullifyCache[iTank].g_iNullifyHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vNullifyHit(iSurvivor, iTank, flRandom, flChance, g_esNullifyCache[iTank].g_iNullifyHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopNullify(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || !g_esNullifyPlayer[iSurvivor].g_bAffected)
	{
		g_esNullifyPlayer[iSurvivor].g_bAffected = false;
		g_esNullifyPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank))
	{
		g_esNullifyPlayer[iSurvivor].g_bAffected = false;
		g_esNullifyPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	g_esNullifyPlayer[iSurvivor].g_bAffected = false;
	g_esNullifyPlayer[iSurvivor].g_iOwner = 0;

	int iMessage = pack.ReadCell();
	if (g_esNullifyCache[iTank].g_iNullifyMessage & iMessage)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Nullify2", iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Nullify2", LANG_SERVER, iSurvivor);
	}

	return Plugin_Continue;
}