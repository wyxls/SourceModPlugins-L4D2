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

#define MT_FIRE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_FIRE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Fire Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank creates fires.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad, g_bSecondGame;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bSecondGame = false;
		case Engine_Left4Dead2: g_bSecondGame = true;
		default:
		{
			strcopy(error, err_max, "\"[MT] Fire Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_FIRE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MODEL_GASCAN "models/props_junk/gascan001a.mdl"

#define SOUND_EXPLODE2 "weapons/grenade_launcher/grenadefire/grenade_launcher_explode_1.wav" // Only available in L4D2
#define SOUND_EXPLODE1 "weapons/hegrenade/explode4.wav"

#define MT_FIRE_SECTION "fireability"
#define MT_FIRE_SECTION2 "fire ability"
#define MT_FIRE_SECTION3 "fire_ability"
#define MT_FIRE_SECTION4 "fire"

#define MT_MENU_FIRE "Fire Ability"

enum struct esFirePlayer
{
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flFireChance;
	float g_flFireDeathChance;
	float g_flFireRange;
	float g_flFireRangeChance;
	float g_flFireRockChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iFireAbility;
	int g_iFireCooldown;
	int g_iFireDeath;
	int g_iFireEffect;
	int g_iFireHit;
	int g_iFireHitMode;
	int g_iFireMessage;
	int g_iFireRangeCooldown;
	int g_iFireRockBreak;
	int g_iFireRockCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHumanRockCooldown;
	int g_iImmunityFlags;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iRockCooldown;
	int g_iTankType;
}

esFirePlayer g_esFirePlayer[MAXPLAYERS + 1];

enum struct esFireAbility
{
	float g_flCloseAreasOnly;
	float g_flFireChance;
	float g_flFireDeathChance;
	float g_flFireRange;
	float g_flFireRangeChance;
	float g_flFireRockChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iFireAbility;
	int g_iFireCooldown;
	int g_iFireDeath;
	int g_iFireEffect;
	int g_iFireHit;
	int g_iFireHitMode;
	int g_iFireMessage;
	int g_iFireRangeCooldown;
	int g_iFireRockBreak;
	int g_iFireRockCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHumanRockCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esFireAbility g_esFireAbility[MT_MAXTYPES + 1];

enum struct esFireCache
{
	float g_flCloseAreasOnly;
	float g_flFireChance;
	float g_flFireDeathChance;
	float g_flFireRange;
	float g_flFireRangeChance;
	float g_flFireRockChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iFireAbility;
	int g_iFireCooldown;
	int g_iFireDeath;
	int g_iFireEffect;
	int g_iFireHit;
	int g_iFireHitMode;
	int g_iFireMessage;
	int g_iFireRangeCooldown;
	int g_iFireRockBreak;
	int g_iFireRockCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHumanRockCooldown;
	int g_iRequiresHumans;
}

esFireCache g_esFireCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_fire", cmdFireInfo, "View information about the Fire ability.");

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
void vFireMapStart()
#else
public void OnMapStart()
#endif
{
	switch (g_bSecondGame)
	{
		case true: PrecacheSound(SOUND_EXPLODE2, true);
		case false: PrecacheSound(SOUND_EXPLODE1, true);
	}

	vFireReset();
}

#if defined MT_ABILITIES_MAIN
void vFireClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnFireTakeDamage);
	vRemoveFire(client);
}

#if defined MT_ABILITIES_MAIN
void vFireClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveFire(client);
}

#if defined MT_ABILITIES_MAIN
void vFireMapEnd()
#else
public void OnMapEnd()
#endif
{
	vFireReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdFireInfo(int client, int args)
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
		case false: vFireMenu(client, MT_FIRE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vFireMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_FIRE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iFireMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Fire Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.AddItem("Rock Cooldown", "Rock Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iFireMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFireCache[param1].g_iFireAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esFireCache[param1].g_iHumanAmmo - g_esFirePlayer[param1].g_iAmmoCount), g_esFireCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esFireCache[param1].g_iHumanAbility == 1) ? g_esFireCache[param1].g_iHumanCooldown : g_esFireCache[param1].g_iFireCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "FireDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFireCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esFireCache[param1].g_iHumanAbility == 1) ? g_esFireCache[param1].g_iHumanRangeCooldown : g_esFireCache[param1].g_iFireRangeCooldown));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRockCooldown", ((g_esFireCache[param1].g_iHumanAbility == 1) ? g_esFireCache[param1].g_iHumanRockCooldown : g_esFireCache[param1].g_iFireRockCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vFireMenu(param1, MT_FIRE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pFire = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "FireMenu", param1);
			pFire.SetTitle(sMenuTitle);
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
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "RangeCooldown", param1);
					case 7: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "RockCooldown", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vFireDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_FIRE, MT_MENU_FIRE);
}

#if defined MT_ABILITIES_MAIN
void vFireMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_FIRE, false))
	{
		vFireMenu(client, MT_FIRE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vFireMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_FIRE, false))
	{
		FormatEx(buffer, size, "%T", "FireMenu2", client);
	}
}

Action OnFireTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esFireCache[attacker].g_iFireHitMode == 0 || g_esFireCache[attacker].g_iFireHitMode == 1) && bIsSurvivor(victim) && g_esFireCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esFireAbility[g_esFirePlayer[attacker].g_iTankType].g_iAccessFlags, g_esFirePlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esFirePlayer[attacker].g_iTankType, g_esFireAbility[g_esFirePlayer[attacker].g_iTankType].g_iImmunityFlags, g_esFirePlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vFireHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esFireCache[attacker].g_flFireChance, g_esFireCache[attacker].g_iFireHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esFireCache[victim].g_iFireHitMode == 0 || g_esFireCache[victim].g_iFireHitMode == 2) && bIsSurvivor(attacker) && g_esFireCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esFireAbility[g_esFirePlayer[victim].g_iTankType].g_iAccessFlags, g_esFirePlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esFirePlayer[victim].g_iTankType, g_esFireAbility[g_esFirePlayer[victim].g_iTankType].g_iImmunityFlags, g_esFirePlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vFireHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esFireCache[victim].g_flFireChance, g_esFireCache[victim].g_iFireHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vFirePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_FIRE);
}

#if defined MT_ABILITIES_MAIN
void vFireAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_FIRE_SECTION);
	list2.PushString(MT_FIRE_SECTION2);
	list3.PushString(MT_FIRE_SECTION3);
	list4.PushString(MT_FIRE_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vFireCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFireCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_FIRE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_FIRE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_FIRE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_FIRE_SECTION4);
	if (g_esFireCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_FIRE_SECTION, false) || StrEqual(sSubset[iPos], MT_FIRE_SECTION2, false) || StrEqual(sSubset[iPos], MT_FIRE_SECTION3, false) || StrEqual(sSubset[iPos], MT_FIRE_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esFireCache[tank].g_iFireAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vFireAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerFireCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esFireCache[tank].g_iFireHitMode == 0 || g_esFireCache[tank].g_iFireHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vFireHit(survivor, tank, random, flChance, g_esFireCache[tank].g_iFireHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esFireCache[tank].g_iFireHitMode == 0 || g_esFireCache[tank].g_iFireHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vFireHit(survivor, tank, random, flChance, g_esFireCache[tank].g_iFireHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerFireCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(survivor));
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteFloat(random);
								dpCombo.WriteFloat(flChance);
								dpCombo.WriteCell(iPos);
								dpCombo.WriteString(classname);
							}
						}
					}
					case MT_COMBO_ROCKBREAK:
					{
						if (g_esFireCache[tank].g_iFireRockBreak == 1 && bIsValidEntity(weapon))
						{
							vFireRockBreak2(tank, weapon, random, iPos);
						}
					}
					case MT_COMBO_POSTSPAWN: vFireRange(tank, 0, random, iPos);
					case MT_COMBO_UPONDEATH: vFireRange(tank, 0, random, iPos);
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFireConfigsLoad(int mode)
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
				g_esFireAbility[iIndex].g_iAccessFlags = 0;
				g_esFireAbility[iIndex].g_iImmunityFlags = 0;
				g_esFireAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esFireAbility[iIndex].g_iComboAbility = 0;
				g_esFireAbility[iIndex].g_iHumanAbility = 0;
				g_esFireAbility[iIndex].g_iHumanAmmo = 5;
				g_esFireAbility[iIndex].g_iHumanCooldown = 0;
				g_esFireAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esFireAbility[iIndex].g_iHumanRockCooldown = 0;
				g_esFireAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esFireAbility[iIndex].g_iRequiresHumans = 0;
				g_esFireAbility[iIndex].g_iFireAbility = 0;
				g_esFireAbility[iIndex].g_iFireEffect = 0;
				g_esFireAbility[iIndex].g_iFireMessage = 0;
				g_esFireAbility[iIndex].g_flFireChance = 33.3;
				g_esFireAbility[iIndex].g_iFireCooldown = 0;
				g_esFireAbility[iIndex].g_iFireDeath = 0;
				g_esFireAbility[iIndex].g_flFireDeathChance = 200.0;
				g_esFireAbility[iIndex].g_iFireHit = 0;
				g_esFireAbility[iIndex].g_iFireHitMode = 0;
				g_esFireAbility[iIndex].g_flFireRange = 150.0;
				g_esFireAbility[iIndex].g_flFireRangeChance = 15.0;
				g_esFireAbility[iIndex].g_iFireRangeCooldown = 0;
				g_esFireAbility[iIndex].g_iFireRockBreak = 0;
				g_esFireAbility[iIndex].g_flFireRockChance = 33.3;
				g_esFireAbility[iIndex].g_iFireRockCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esFirePlayer[iPlayer].g_iAccessFlags = 0;
					g_esFirePlayer[iPlayer].g_iImmunityFlags = 0;
					g_esFirePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esFirePlayer[iPlayer].g_iComboAbility = 0;
					g_esFirePlayer[iPlayer].g_iHumanAbility = 0;
					g_esFirePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esFirePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esFirePlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esFirePlayer[iPlayer].g_iHumanRockCooldown = 0;
					g_esFirePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esFirePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esFirePlayer[iPlayer].g_iFireAbility = 0;
					g_esFirePlayer[iPlayer].g_iFireEffect = 0;
					g_esFirePlayer[iPlayer].g_iFireMessage = 0;
					g_esFirePlayer[iPlayer].g_flFireChance = 0.0;
					g_esFirePlayer[iPlayer].g_iFireCooldown = 0;
					g_esFirePlayer[iPlayer].g_iFireDeath = 0;
					g_esFirePlayer[iPlayer].g_flFireDeathChance = 0.0;
					g_esFirePlayer[iPlayer].g_iFireHit = 0;
					g_esFirePlayer[iPlayer].g_iFireHitMode = 0;
					g_esFirePlayer[iPlayer].g_flFireRange = 0.0;
					g_esFirePlayer[iPlayer].g_flFireRangeChance = 0.0;
					g_esFirePlayer[iPlayer].g_iFireRangeCooldown = 0;
					g_esFirePlayer[iPlayer].g_iFireRockBreak = 0;
					g_esFirePlayer[iPlayer].g_flFireRockChance = 0.0;
					g_esFirePlayer[iPlayer].g_iFireRockCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFireConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esFirePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esFirePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esFirePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esFirePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esFirePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esFirePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esFirePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esFirePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esFirePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esFirePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esFirePlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esFirePlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esFirePlayer[admin].g_iHumanRockCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanRockCooldown", "Human Rock Cooldown", "Human_Rock_Cooldown", "hrockcooldown", g_esFirePlayer[admin].g_iHumanRockCooldown, value, 0, 99999);
		g_esFirePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esFirePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esFirePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esFirePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esFirePlayer[admin].g_iFireAbility = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esFirePlayer[admin].g_iFireAbility, value, 0, 1);
		g_esFirePlayer[admin].g_iFireEffect = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esFirePlayer[admin].g_iFireEffect, value, 0, 7);
		g_esFirePlayer[admin].g_iFireMessage = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esFirePlayer[admin].g_iFireMessage, value, 0, 7);
		g_esFirePlayer[admin].g_flFireChance = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireChance", "Fire Chance", "Fire_Chance", "chance", g_esFirePlayer[admin].g_flFireChance, value, 0.0, 100.0);
		g_esFirePlayer[admin].g_iFireCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireCooldown", "Fire Cooldown", "Fire_Cooldown", "cooldown", g_esFirePlayer[admin].g_iFireCooldown, value, 0, 99999);
		g_esFirePlayer[admin].g_iFireDeath = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireDeath", "Fire Death", "Fire_Death", "death", g_esFirePlayer[admin].g_iFireDeath, value, 0, 1);
		g_esFirePlayer[admin].g_flFireDeathChance = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireDeathChance", "Fire Death Chance", "Fire_Death_Chance", "deathchance", g_esFirePlayer[admin].g_flFireDeathChance, value, 1.0, 99999.0);
		g_esFirePlayer[admin].g_iFireHit = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireHit", "Fire Hit", "Fire_Hit", "hit", g_esFirePlayer[admin].g_iFireHit, value, 0, 1);
		g_esFirePlayer[admin].g_iFireHitMode = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireHitMode", "Fire Hit Mode", "Fire_Hit_Mode", "hitmode", g_esFirePlayer[admin].g_iFireHitMode, value, 0, 2);
		g_esFirePlayer[admin].g_flFireRange = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRange", "Fire Range", "Fire_Range", "range", g_esFirePlayer[admin].g_flFireRange, value, 1.0, 99999.0);
		g_esFirePlayer[admin].g_flFireRangeChance = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRangeChance", "Fire Range Chance", "Fire_Range_Chance", "rangechance", g_esFirePlayer[admin].g_flFireRangeChance, value, 0.0, 100.0);
		g_esFirePlayer[admin].g_iFireRangeCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRangeCooldown", "Fire Range Cooldown", "Fire_Range_Cooldown", "rangecooldown", g_esFirePlayer[admin].g_iFireRangeCooldown, value, 0, 99999);
		g_esFirePlayer[admin].g_iFireRockBreak = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRockBreak", "Fire Rock Break", "Fire_Rock_Break", "rock", g_esFirePlayer[admin].g_iFireRockBreak, value, 0, 1);
		g_esFirePlayer[admin].g_flFireRockChance = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRockChance", "Fire Rock Chance", "Fire_Rock_Chance", "rockchance", g_esFirePlayer[admin].g_flFireRockChance, value, 0.0, 100.0);
		g_esFirePlayer[admin].g_iFireRockCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRockCooldown", "Fire Rock Cooldown", "Fire_Rock_Cooldown", "rockcooldown", g_esFirePlayer[admin].g_iFireRockCooldown, value, 0, 99999);
		g_esFirePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esFirePlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esFireAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esFireAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esFireAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esFireAbility[type].g_iComboAbility, value, 0, 1);
		g_esFireAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esFireAbility[type].g_iHumanAbility, value, 0, 2);
		g_esFireAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esFireAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esFireAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esFireAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esFireAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esFireAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esFireAbility[type].g_iHumanRockCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "HumanRockCooldown", "Human Rock Cooldown", "Human_Rock_Cooldown", "hrockcooldown", g_esFireAbility[type].g_iHumanRockCooldown, value, 0, 99999);
		g_esFireAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esFireAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esFireAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esFireAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esFireAbility[type].g_iFireAbility = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esFireAbility[type].g_iFireAbility, value, 0, 1);
		g_esFireAbility[type].g_iFireEffect = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esFireAbility[type].g_iFireEffect, value, 0, 7);
		g_esFireAbility[type].g_iFireMessage = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esFireAbility[type].g_iFireMessage, value, 0, 7);
		g_esFireAbility[type].g_flFireChance = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireChance", "Fire Chance", "Fire_Chance", "chance", g_esFireAbility[type].g_flFireChance, value, 0.0, 100.0);
		g_esFireAbility[type].g_iFireCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireCooldown", "Fire Cooldown", "Fire_Cooldown", "cooldown", g_esFireAbility[type].g_iFireCooldown, value, 0, 99999);
		g_esFireAbility[type].g_iFireDeath = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireDeath", "Fire Death", "Fire_Death", "death", g_esFireAbility[type].g_iFireDeath, value, 0, 1);
		g_esFireAbility[type].g_flFireDeathChance = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireDeathChance", "Fire Death Chance", "Fire_Death_Chance", "deathchance", g_esFireAbility[type].g_flFireDeathChance, value, 1.0, 99999.0);
		g_esFireAbility[type].g_iFireHit = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireHit", "Fire Hit", "Fire_Hit", "hit", g_esFireAbility[type].g_iFireHit, value, 0, 1);
		g_esFireAbility[type].g_iFireHitMode = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireHitMode", "Fire Hit Mode", "Fire_Hit_Mode", "hitmode", g_esFireAbility[type].g_iFireHitMode, value, 0, 2);
		g_esFireAbility[type].g_flFireRange = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRange", "Fire Range", "Fire_Range", "range", g_esFireAbility[type].g_flFireRange, value, 1.0, 99999.0);
		g_esFireAbility[type].g_flFireRangeChance = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRangeChance", "Fire Range Chance", "Fire_Range_Chance", "rangechance", g_esFireAbility[type].g_flFireRangeChance, value, 0.0, 100.0);
		g_esFireAbility[type].g_iFireRangeCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRangeCooldown", "Fire Range Cooldown", "Fire_Range_Cooldown", "rangecooldown", g_esFireAbility[type].g_iFireRangeCooldown, value, 0, 99999);
		g_esFireAbility[type].g_iFireRockBreak = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRockBreak", "Fire Rock Break", "Fire_Rock_Break", "rock", g_esFireAbility[type].g_iFireRockBreak, value, 0, 1);
		g_esFireAbility[type].g_flFireRockChance = flGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRockChance", "Fire Rock Chance", "Fire_Rock_Chance", "rockchance", g_esFireAbility[type].g_flFireRockChance, value, 0.0, 100.0);
		g_esFireAbility[type].g_iFireRockCooldown = iGetKeyValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "FireRockCooldown", "Fire Rock Cooldown", "Fire_Rock_Cooldown", "rockcooldown", g_esFireAbility[type].g_iFireRockCooldown, value, 0, 99999);
		g_esFireAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esFireAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_FIRE_SECTION, MT_FIRE_SECTION2, MT_FIRE_SECTION3, MT_FIRE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vFireSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esFireCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_flCloseAreasOnly, g_esFireAbility[type].g_flCloseAreasOnly);
	g_esFireCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iComboAbility, g_esFireAbility[type].g_iComboAbility);
	g_esFireCache[tank].g_flFireChance = flGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_flFireChance, g_esFireAbility[type].g_flFireChance);
	g_esFireCache[tank].g_iFireCooldown = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireCooldown, g_esFireAbility[type].g_iFireCooldown);
	g_esFireCache[tank].g_flFireDeathChance = flGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_flFireDeathChance, g_esFireAbility[type].g_flFireDeathChance);
	g_esFireCache[tank].g_flFireRange = flGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_flFireRange, g_esFireAbility[type].g_flFireRange);
	g_esFireCache[tank].g_flFireRangeChance = flGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_flFireRangeChance, g_esFireAbility[type].g_flFireRangeChance);
	g_esFireCache[tank].g_flFireRockChance = flGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_flFireRockChance, g_esFireAbility[type].g_flFireRockChance);
	g_esFireCache[tank].g_iFireAbility = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireAbility, g_esFireAbility[type].g_iFireAbility);
	g_esFireCache[tank].g_iFireDeath = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireDeath, g_esFireAbility[type].g_iFireDeath);
	g_esFireCache[tank].g_iFireEffect = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireEffect, g_esFireAbility[type].g_iFireEffect);
	g_esFireCache[tank].g_iFireHit = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireHit, g_esFireAbility[type].g_iFireHit);
	g_esFireCache[tank].g_iFireHitMode = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireHitMode, g_esFireAbility[type].g_iFireHitMode);
	g_esFireCache[tank].g_iFireMessage = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireMessage, g_esFireAbility[type].g_iFireMessage);
	g_esFireCache[tank].g_iFireRangeCooldown = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireRangeCooldown, g_esFireAbility[type].g_iFireRangeCooldown);
	g_esFireCache[tank].g_iFireRockBreak = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireRockBreak, g_esFireAbility[type].g_iFireRockBreak);
	g_esFireCache[tank].g_iFireRockCooldown = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iFireRockCooldown, g_esFireAbility[type].g_iFireRockCooldown);
	g_esFireCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iHumanAbility, g_esFireAbility[type].g_iHumanAbility);
	g_esFireCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iHumanAmmo, g_esFireAbility[type].g_iHumanAmmo);
	g_esFireCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iHumanCooldown, g_esFireAbility[type].g_iHumanCooldown);
	g_esFireCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iHumanRangeCooldown, g_esFireAbility[type].g_iHumanRangeCooldown);
	g_esFireCache[tank].g_iHumanRockCooldown = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iHumanRockCooldown, g_esFireAbility[type].g_iHumanRockCooldown);
	g_esFireCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_flOpenAreasOnly, g_esFireAbility[type].g_flOpenAreasOnly);
	g_esFireCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esFirePlayer[tank].g_iRequiresHumans, g_esFireAbility[type].g_iRequiresHumans);
	g_esFirePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vFireCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vFireCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveFire(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vFireEventFired(Event event, const char[] name)
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
			vFireCopyStats2(iBot, iTank);
			vRemoveFire(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vFireCopyStats2(iTank, iBot);
			vRemoveFire(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vFireRange(iTank, 1, MT_GetRandomFloat(0.1, 100.0));
			vRemoveFire(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vFireReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vFireAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFireAbility[g_esFirePlayer[tank].g_iTankType].g_iAccessFlags, g_esFirePlayer[tank].g_iAccessFlags)) || g_esFireCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esFireCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esFireCache[tank].g_iFireAbility == 1 && g_esFireCache[tank].g_iComboAbility == 0)
	{
		vFireAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vFireButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esFireCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFireCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFirePlayer[tank].g_iTankType) || (g_esFireCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFireCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFireAbility[g_esFirePlayer[tank].g_iTankType].g_iAccessFlags, g_esFirePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esFireCache[tank].g_iFireAbility == 1 && g_esFireCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esFirePlayer[tank].g_iRangeCooldown == -1 || g_esFirePlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vFireAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireHuman3", (g_esFirePlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFireChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveFire(tank);

	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esFireCache[tank].g_iFireAbility == 1)
	{
		if (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFireAbility[g_esFirePlayer[tank].g_iTankType].g_iAccessFlags, g_esFirePlayer[tank].g_iAccessFlags)) || g_esFireCache[tank].g_iHumanAbility == 0))
		{
			return;
		}

		float flPos[3];
		GetClientAbsOrigin(tank, flPos);
		vSpawnBreakProp(tank, flPos, 10.0, MODEL_GASCAN);
	}
}

#if defined MT_ABILITIES_MAIN
void vFirePostTankSpawn(int tank)
#else
public void MT_OnPostTankSpawn(int tank)
#endif
{
	vFireRange(tank, 1, MT_GetRandomFloat(0.1, 100.0));
}

#if defined MT_ABILITIES_MAIN
void vFireRockBreak(int tank, int rock)
#else
public void MT_OnRockBreak(int tank, int rock)
#endif
{
	if (bIsAreaNarrow(tank, g_esFireCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFireCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFirePlayer[tank].g_iTankType) || (g_esFireCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFireCache[tank].g_iRequiresHumans) || (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFireAbility[g_esFirePlayer[tank].g_iTankType].g_iAccessFlags, g_esFirePlayer[tank].g_iAccessFlags)) || g_esFireCache[tank].g_iHumanAbility == 0)))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esFireCache[tank].g_iFireRockBreak == 1 && g_esFireCache[tank].g_iComboAbility == 0)
	{
		vFireRockBreak2(tank, rock, MT_GetRandomFloat(0.1, 100.0));
	}
}

void vFireAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esFireCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFireCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFirePlayer[tank].g_iTankType) || (g_esFireCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFireCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFireAbility[g_esFirePlayer[tank].g_iTankType].g_iAccessFlags, g_esFirePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esFirePlayer[tank].g_iAmmoCount < g_esFireCache[tank].g_iHumanAmmo && g_esFireCache[tank].g_iHumanAmmo > 0))
	{
		g_esFirePlayer[tank].g_bFailed = false;
		g_esFirePlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esFireCache[tank].g_flFireRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esFireCache[tank].g_flFireRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esFirePlayer[tank].g_iTankType, g_esFireAbility[g_esFirePlayer[tank].g_iTankType].g_iImmunityFlags, g_esFirePlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vFireHit(iSurvivor, tank, random, flChance, g_esFireCache[tank].g_iFireAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFireCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFireCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireAmmo");
	}
}

void vFireHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esFireCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFireCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFirePlayer[tank].g_iTankType) || (g_esFireCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFireCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFireAbility[g_esFirePlayer[tank].g_iTankType].g_iAccessFlags, g_esFirePlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esFirePlayer[tank].g_iTankType, g_esFireAbility[g_esFirePlayer[tank].g_iTankType].g_iImmunityFlags, g_esFirePlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esFirePlayer[tank].g_iRangeCooldown != -1 && g_esFirePlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esFirePlayer[tank].g_iCooldown != -1 && g_esFirePlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esFirePlayer[tank].g_iAmmoCount < g_esFireCache[tank].g_iHumanAmmo && g_esFireCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance)
			{
				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esFirePlayer[tank].g_iRangeCooldown == -1 || g_esFirePlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFireCache[tank].g_iHumanAbility == 1)
					{
						g_esFirePlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireHuman", g_esFirePlayer[tank].g_iAmmoCount, g_esFireCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esFireCache[tank].g_iFireRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFireCache[tank].g_iHumanAbility == 1 && g_esFirePlayer[tank].g_iAmmoCount < g_esFireCache[tank].g_iHumanAmmo && g_esFireCache[tank].g_iHumanAmmo > 0) ? g_esFireCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esFirePlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esFirePlayer[tank].g_iRangeCooldown != -1 && g_esFirePlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireHuman5", (g_esFirePlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esFirePlayer[tank].g_iCooldown == -1 || g_esFirePlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esFireCache[tank].g_iFireCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFireCache[tank].g_iHumanAbility == 1) ? g_esFireCache[tank].g_iHumanCooldown : iCooldown;
					g_esFirePlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esFirePlayer[tank].g_iCooldown != -1 && g_esFirePlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireHuman5", (g_esFirePlayer[tank].g_iCooldown - iTime));
					}
				}

				float flPos[3];
				GetClientAbsOrigin(survivor, flPos);
				vSpawnBreakProp(tank, flPos, 10.0, MODEL_GASCAN);
				vScreenEffect(survivor, tank, g_esFireCache[tank].g_iFireEffect, flags);

				switch (g_bSecondGame)
				{
					case true: EmitSoundToAll(SOUND_EXPLODE2, survivor);
					case false: EmitSoundToAll(SOUND_EXPLODE1, survivor);
				}

				if (g_esFireCache[tank].g_iFireMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Fire", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Fire", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esFirePlayer[tank].g_iRangeCooldown == -1 || g_esFirePlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFireCache[tank].g_iHumanAbility == 1 && !g_esFirePlayer[tank].g_bFailed)
				{
					g_esFirePlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFireCache[tank].g_iHumanAbility == 1 && !g_esFirePlayer[tank].g_bNoAmmo)
		{
			g_esFirePlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireAmmo");
		}
	}
}

void vFireRange(int tank, int value, float random, int pos = -1)
{
	float flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 13, pos) : g_esFireCache[tank].g_flFireDeathChance;
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(tank) && g_esFireCache[tank].g_iFireDeath == 1 && random <= flChance)
	{
		if (g_esFireCache[tank].g_iComboAbility == value || bIsAreaNarrow(tank, g_esFireCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFireCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFirePlayer[tank].g_iTankType) || (g_esFireCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFireCache[tank].g_iRequiresHumans) || (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFireAbility[g_esFirePlayer[tank].g_iTankType].g_iAccessFlags, g_esFirePlayer[tank].g_iAccessFlags)) || g_esFireCache[tank].g_iHumanAbility == 0)))
		{
			return;
		}

		float flPos[3];
		GetClientAbsOrigin(tank, flPos);
		vSpawnBreakProp(tank, flPos, 10.0, MODEL_GASCAN);
	}
}

void vFireRockBreak2(int tank, int rock, float random, int pos = -1)
{
	float flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 14, pos) : g_esFireCache[tank].g_flFireRockChance;
	if (random <= flChance)
	{
		int iTime = GetTime(), iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFireCache[tank].g_iHumanAbility == 1) ? g_esFireCache[tank].g_iHumanRockCooldown : g_esFireCache[tank].g_iFireRockCooldown;
		iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 15, pos)) : iCooldown;
		if (g_esFirePlayer[tank].g_iRockCooldown == -1 || g_esFirePlayer[tank].g_iRockCooldown < iTime)
		{
			g_esFirePlayer[tank].g_iRockCooldown = (iTime + iCooldown);
			if (g_esFirePlayer[tank].g_iRockCooldown != -1 && g_esFirePlayer[tank].g_iRockCooldown > iTime)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireHuman5", (g_esFirePlayer[tank].g_iRockCooldown - iTime));
			}
		}
		else if (g_esFirePlayer[tank].g_iRockCooldown != -1 && g_esFirePlayer[tank].g_iRockCooldown > iTime)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "FireHuman3", (g_esFirePlayer[tank].g_iRockCooldown - iTime));

			return;
		}

		float flPos[3];
		GetEntPropVector(rock, Prop_Data, "m_vecOrigin", flPos);
		vSpawnBreakProp(tank, flPos, 10.0, MODEL_GASCAN);

		if (g_esFireCache[tank].g_iFireMessage & MT_MESSAGE_SPECIAL)
		{
			char sTankName[33];
			MT_GetTankName(tank, sTankName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Fire2", sTankName);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Fire2", LANG_SERVER, sTankName);
		}
	}
}

void vFireCopyStats2(int oldTank, int newTank)
{
	g_esFirePlayer[newTank].g_iAmmoCount = g_esFirePlayer[oldTank].g_iAmmoCount;
	g_esFirePlayer[newTank].g_iCooldown = g_esFirePlayer[oldTank].g_iCooldown;
	g_esFirePlayer[newTank].g_iRangeCooldown = g_esFirePlayer[oldTank].g_iRangeCooldown;
	g_esFirePlayer[newTank].g_iRockCooldown = g_esFirePlayer[oldTank].g_iRockCooldown;
}

void vRemoveFire(int tank)
{
	g_esFirePlayer[tank].g_bFailed = false;
	g_esFirePlayer[tank].g_bNoAmmo = false;
	g_esFirePlayer[tank].g_iAmmoCount = 0;
	g_esFirePlayer[tank].g_iCooldown = -1;
	g_esFirePlayer[tank].g_iRangeCooldown = -1;
	g_esFirePlayer[tank].g_iRockCooldown = -1;
}

void vFireReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveFire(iPlayer);
		}
	}
}

Action tTimerFireCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esFireAbility[g_esFirePlayer[iTank].g_iTankType].g_iAccessFlags, g_esFirePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esFirePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esFireCache[iTank].g_iFireAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vFireAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerFireCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esFireAbility[g_esFirePlayer[iTank].g_iTankType].g_iAccessFlags, g_esFirePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esFirePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esFireCache[iTank].g_iFireHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esFireCache[iTank].g_iFireHitMode == 0 || g_esFireCache[iTank].g_iFireHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vFireHit(iSurvivor, iTank, flRandom, flChance, g_esFireCache[iTank].g_iFireHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esFireCache[iTank].g_iFireHitMode == 0 || g_esFireCache[iTank].g_iFireHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vFireHit(iSurvivor, iTank, flRandom, flChance, g_esFireCache[iTank].g_iFireHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}