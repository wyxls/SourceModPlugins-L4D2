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

#define MT_BOMB_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_BOMB_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Bomb Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank creates explosions.",
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
			strcopy(error, err_max, "\"[MT] Bomb Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_BOMB_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MODEL_PROPANETANK "models/props_junk/propanecanister001a.mdl"

#define SOUND_HIT "animation/van_inside_hit_wall.wav"
#define SOUND_BOMB2 "animation/bombing_run_01.wav" // Only available in L4D2
#define SOUND_BOMB1 "animation/van_inside_debris.wav"

#define MT_BOMB_SECTION "bombability"
#define MT_BOMB_SECTION2 "bomb ability"
#define MT_BOMB_SECTION3 "bomb_ability"
#define MT_BOMB_SECTION4 "bomb"

#define MT_MENU_BOMB "Bomb Ability"

enum struct esBombPlayer
{
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flBombChance;
	float g_flBombDeathChance;
	float g_flBombRange;
	float g_flBombRangeChance;
	float g_flBombRockChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iBombAbility;
	int g_iBombCooldown;
	int g_iBombDeath;
	int g_iBombEffect;
	int g_iBombHit;
	int g_iBombHitMode;
	int g_iBombMessage;
	int g_iBombRangeCooldown;
	int g_iBombRockBreak;
	int g_iBombRockCooldown;
	int g_iComboAbility;
	int g_iCooldown;
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

esBombPlayer g_esBombPlayer[MAXPLAYERS + 1];

enum struct esBombAbility
{
	float g_flBombChance;
	float g_flBombDeathChance;
	float g_flBombRange;
	float g_flBombRangeChance;
	float g_flBombRockChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iBombAbility;
	int g_iBombCooldown;
	int g_iBombDeath;
	int g_iBombEffect;
	int g_iBombHit;
	int g_iBombHitMode;
	int g_iBombMessage;
	int g_iBombRangeCooldown;
	int g_iBombRockBreak;
	int g_iBombRockCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHumanRockCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esBombAbility g_esBombAbility[MT_MAXTYPES + 1];

enum struct esBombCache
{
	float g_flBombChance;
	float g_flBombDeathChance;
	float g_flBombRange;
	float g_flBombRangeChance;
	float g_flBombRockChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iBombAbility;
	int g_iBombCooldown;
	int g_iBombDeath;
	int g_iBombEffect;
	int g_iBombHit;
	int g_iBombHitMode;
	int g_iBombMessage;
	int g_iBombRangeCooldown;
	int g_iBombRockBreak;
	int g_iBombRockCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHumanRockCooldown;
	int g_iRequiresHumans;
}

esBombCache g_esBombCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_bomb", cmdBombInfo, "View information about the Bomb ability.");

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
void vBombMapStart()
#else
public void OnMapStart()
#endif
{
	PrecacheSound(SOUND_HIT, true);

	switch (g_bSecondGame)
	{
		case true: PrecacheSound(SOUND_BOMB2, true);
		case false: PrecacheSound(SOUND_BOMB1, true);
	}

	vBombReset();
}

#if defined MT_ABILITIES_MAIN
void vBombClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnBombTakeDamage);
	vRemoveBomb(client);
}

#if defined MT_ABILITIES_MAIN
void vBombClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveBomb(client);
}

#if defined MT_ABILITIES_MAIN
void vBombMapEnd()
#else
public void OnMapEnd()
#endif
{
	vBombReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdBombInfo(int client, int args)
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
		case false: vBombMenu(client, MT_BOMB_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vBombMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_BOMB_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iBombMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Bomb Ability Information");
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

int iBombMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esBombCache[param1].g_iBombAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esBombCache[param1].g_iHumanAmmo - g_esBombPlayer[param1].g_iAmmoCount), g_esBombCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esBombCache[param1].g_iHumanAbility == 1) ? g_esBombCache[param1].g_iHumanCooldown : g_esBombCache[param1].g_iBombCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "BombDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esBombCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esBombCache[param1].g_iHumanAbility == 1) ? g_esBombCache[param1].g_iHumanRangeCooldown : g_esBombCache[param1].g_iBombRangeCooldown));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRockCooldown", ((g_esBombCache[param1].g_iHumanAbility == 1) ? g_esBombCache[param1].g_iHumanRockCooldown : g_esBombCache[param1].g_iBombRockCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vBombMenu(param1, MT_BOMB_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pBomb = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "BombMenu", param1);
			pBomb.SetTitle(sMenuTitle);
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
void vBombDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_BOMB, MT_MENU_BOMB);
}

#if defined MT_ABILITIES_MAIN
void vBombMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_BOMB, false))
	{
		vBombMenu(client, MT_BOMB_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vBombMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_BOMB, false))
	{
		FormatEx(buffer, size, "%T", "BombMenu2", client);
	}
}

Action OnBombTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esBombCache[attacker].g_iBombHitMode == 0 || g_esBombCache[attacker].g_iBombHitMode == 1) && bIsSurvivor(victim) && g_esBombCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esBombAbility[g_esBombPlayer[attacker].g_iTankType].g_iAccessFlags, g_esBombPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esBombPlayer[attacker].g_iTankType, g_esBombAbility[g_esBombPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esBombPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vBombHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esBombCache[attacker].g_flBombChance, g_esBombCache[attacker].g_iBombHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esBombCache[victim].g_iBombHitMode == 0 || g_esBombCache[victim].g_iBombHitMode == 2) && bIsSurvivor(attacker) && g_esBombCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esBombAbility[g_esBombPlayer[victim].g_iTankType].g_iAccessFlags, g_esBombPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esBombPlayer[victim].g_iTankType, g_esBombAbility[g_esBombPlayer[victim].g_iTankType].g_iImmunityFlags, g_esBombPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vBombHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esBombCache[victim].g_flBombChance, g_esBombCache[victim].g_iBombHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vBombPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_BOMB);
}

#if defined MT_ABILITIES_MAIN
void vBombAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_BOMB_SECTION);
	list2.PushString(MT_BOMB_SECTION2);
	list3.PushString(MT_BOMB_SECTION3);
	list4.PushString(MT_BOMB_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vBombCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBombCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_BOMB_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_BOMB_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_BOMB_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_BOMB_SECTION4);
	if (g_esBombCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_BOMB_SECTION, false) || StrEqual(sSubset[iPos], MT_BOMB_SECTION2, false) || StrEqual(sSubset[iPos], MT_BOMB_SECTION3, false) || StrEqual(sSubset[iPos], MT_BOMB_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esBombCache[tank].g_iBombAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vBombAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerBombCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esBombCache[tank].g_iBombHitMode == 0 || g_esBombCache[tank].g_iBombHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vBombHit(survivor, tank, random, flChance, g_esBombCache[tank].g_iBombHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esBombCache[tank].g_iBombHitMode == 0 || g_esBombCache[tank].g_iBombHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vBombHit(survivor, tank, random, flChance, g_esBombCache[tank].g_iBombHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerBombCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
						if (g_esBombCache[tank].g_iBombRockBreak == 1 && bIsValidEntity(weapon))
						{
							vBombRockBreak2(tank, weapon, random, iPos);
						}
					}
					case MT_COMBO_POSTSPAWN: vBombRange(tank, 0, random, iPos);
					case MT_COMBO_UPONDEATH: vBombRange(tank, 0, random, iPos);
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vBombConfigsLoad(int mode)
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
				g_esBombAbility[iIndex].g_iAccessFlags = 0;
				g_esBombAbility[iIndex].g_iImmunityFlags = 0;
				g_esBombAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esBombAbility[iIndex].g_iComboAbility = 0;
				g_esBombAbility[iIndex].g_iHumanAbility = 0;
				g_esBombAbility[iIndex].g_iHumanAmmo = 5;
				g_esBombAbility[iIndex].g_iHumanCooldown = 0;
				g_esBombAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esBombAbility[iIndex].g_iHumanRockCooldown = 0;
				g_esBombAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esBombAbility[iIndex].g_iRequiresHumans = 0;
				g_esBombAbility[iIndex].g_iBombAbility = 0;
				g_esBombAbility[iIndex].g_iBombEffect = 0;
				g_esBombAbility[iIndex].g_iBombMessage = 0;
				g_esBombAbility[iIndex].g_flBombChance = 33.3;
				g_esBombAbility[iIndex].g_iBombCooldown = 0;
				g_esBombAbility[iIndex].g_iBombDeath = 0;
				g_esBombAbility[iIndex].g_flBombDeathChance = 200.0;
				g_esBombAbility[iIndex].g_iBombHit = 0;
				g_esBombAbility[iIndex].g_iBombHitMode = 0;
				g_esBombAbility[iIndex].g_flBombRange = 150.0;
				g_esBombAbility[iIndex].g_flBombRangeChance = 15.0;
				g_esBombAbility[iIndex].g_iBombRangeCooldown = 0;
				g_esBombAbility[iIndex].g_iBombRockBreak = 0;
				g_esBombAbility[iIndex].g_flBombRockChance = 33.3;
				g_esBombAbility[iIndex].g_iBombRockCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esBombPlayer[iPlayer].g_iAccessFlags = 0;
					g_esBombPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esBombPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esBombPlayer[iPlayer].g_iComboAbility = 0;
					g_esBombPlayer[iPlayer].g_iHumanAbility = 0;
					g_esBombPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esBombPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esBombPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esBombPlayer[iPlayer].g_iHumanRockCooldown = 0;
					g_esBombPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esBombPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esBombPlayer[iPlayer].g_iBombAbility = 0;
					g_esBombPlayer[iPlayer].g_iBombEffect = 0;
					g_esBombPlayer[iPlayer].g_iBombMessage = 0;
					g_esBombPlayer[iPlayer].g_flBombChance = 0.0;
					g_esBombPlayer[iPlayer].g_iBombCooldown = 0;
					g_esBombPlayer[iPlayer].g_iBombDeath = 0;
					g_esBombPlayer[iPlayer].g_flBombDeathChance = 0.0;
					g_esBombPlayer[iPlayer].g_iBombHit = 0;
					g_esBombPlayer[iPlayer].g_iBombHitMode = 0;
					g_esBombPlayer[iPlayer].g_flBombRange = 0.0;
					g_esBombPlayer[iPlayer].g_flBombRangeChance = 0.0;
					g_esBombPlayer[iPlayer].g_iBombRangeCooldown = 0;
					g_esBombPlayer[iPlayer].g_iBombRockBreak = 0;
					g_esBombPlayer[iPlayer].g_flBombRockChance = 0.0;
					g_esBombPlayer[iPlayer].g_iBombRockCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vBombConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esBombPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esBombPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esBombPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esBombPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esBombPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esBombPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esBombPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esBombPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esBombPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esBombPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esBombPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esBombPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esBombPlayer[admin].g_iHumanRockCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanRockCooldown", "Human Rock Cooldown", "Human_Rock_Cooldown", "hrockcooldown", g_esBombPlayer[admin].g_iHumanRockCooldown, value, 0, 99999);
		g_esBombPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esBombPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esBombPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esBombPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esBombPlayer[admin].g_iBombAbility = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esBombPlayer[admin].g_iBombAbility, value, 0, 1);
		g_esBombPlayer[admin].g_iBombEffect = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esBombPlayer[admin].g_iBombEffect, value, 0, 7);
		g_esBombPlayer[admin].g_iBombMessage = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esBombPlayer[admin].g_iBombMessage, value, 0, 7);
		g_esBombPlayer[admin].g_flBombChance = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombChance", "Bomb Chance", "Bomb_Chance", "chance", g_esBombPlayer[admin].g_flBombChance, value, 0.0, 100.0);
		g_esBombPlayer[admin].g_iBombCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombCooldown", "Bomb Cooldown", "Bomb_Cooldown", "cooldown", g_esBombPlayer[admin].g_iBombCooldown, value, 0, 99999);
		g_esBombPlayer[admin].g_iBombDeath = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombDeath", "Bomb Death", "Bomb_Death", "death", g_esBombPlayer[admin].g_iBombDeath, value, 0, 1);
		g_esBombPlayer[admin].g_flBombDeathChance = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombDeathChance", "Bomb Death Chance", "Bomb_Death_Chance", "deathchance", g_esBombPlayer[admin].g_flBombDeathChance, value, 1.0, 99999.0);
		g_esBombPlayer[admin].g_iBombHit = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombHit", "Bomb Hit", "Bomb_Hit", "hit", g_esBombPlayer[admin].g_iBombHit, value, 0, 1);
		g_esBombPlayer[admin].g_iBombHitMode = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombHitMode", "Bomb Hit Mode", "Bomb_Hit_Mode", "hitmode", g_esBombPlayer[admin].g_iBombHitMode, value, 0, 2);
		g_esBombPlayer[admin].g_flBombRange = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRange", "Bomb Range", "Bomb_Range", "range", g_esBombPlayer[admin].g_flBombRange, value, 1.0, 99999.0);
		g_esBombPlayer[admin].g_flBombRangeChance = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRangeChance", "Bomb Range Chance", "Bomb_Range_Chance", "rangechance", g_esBombPlayer[admin].g_flBombRangeChance, value, 0.0, 100.0);
		g_esBombPlayer[admin].g_iBombRangeCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRangeCooldown", "Bomb Range Cooldown", "Bomb_Range_Cooldown", "rangecooldown", g_esBombPlayer[admin].g_iBombRangeCooldown, value, 0, 99999);
		g_esBombPlayer[admin].g_iBombRockBreak = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRockBreak", "Bomb Rock Break", "Bomb_Rock_Break", "rock", g_esBombPlayer[admin].g_iBombRockBreak, value, 0, 1);
		g_esBombPlayer[admin].g_flBombRockChance = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRockChance", "Bomb Rock Chance", "Bomb_Rock_Chance", "rockchance", g_esBombPlayer[admin].g_flBombRockChance, value, 0.0, 100.0);
		g_esBombPlayer[admin].g_iBombRockCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRockCooldown", "Bomb Rock Cooldown", "Bomb_Rock_Cooldown", "rockcooldown", g_esBombPlayer[admin].g_iBombRockCooldown, value, 0, 99999);
		g_esBombPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esBombPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esBombAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esBombAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esBombAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esBombAbility[type].g_iComboAbility, value, 0, 1);
		g_esBombAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esBombAbility[type].g_iHumanAbility, value, 0, 2);
		g_esBombAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esBombAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esBombAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esBombAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esBombAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esBombAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esBombAbility[type].g_iHumanRockCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "HumanRockCooldown", "Human Rock Cooldown", "Human_Rock_Cooldown", "hrockcooldown", g_esBombAbility[type].g_iHumanRockCooldown, value, 0, 99999);
		g_esBombAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esBombAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esBombAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esBombAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esBombAbility[type].g_iBombAbility = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esBombAbility[type].g_iBombAbility, value, 0, 1);
		g_esBombAbility[type].g_iBombEffect = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esBombAbility[type].g_iBombEffect, value, 0, 7);
		g_esBombAbility[type].g_iBombMessage = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esBombAbility[type].g_iBombMessage, value, 0, 7);
		g_esBombAbility[type].g_flBombChance = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombChance", "Bomb Chance", "Bomb_Chance", "chance", g_esBombAbility[type].g_flBombChance, value, 0.0, 100.0);
		g_esBombAbility[type].g_iBombCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombCooldown", "Bomb Cooldown", "Bomb_Cooldown", "cooldown", g_esBombAbility[type].g_iBombCooldown, value, 0, 99999);
		g_esBombAbility[type].g_iBombDeath = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombDeath", "Bomb Death", "Bomb_Death", "death", g_esBombAbility[type].g_iBombDeath, value, 0, 1);
		g_esBombAbility[type].g_flBombDeathChance = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombDeathChance", "Bomb Death Chance", "Bomb_Death_Chance", "deathchance", g_esBombAbility[type].g_flBombDeathChance, value, 1.0, 99999.0);
		g_esBombAbility[type].g_iBombHit = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombHit", "Bomb Hit", "Bomb_Hit", "hit", g_esBombAbility[type].g_iBombHit, value, 0, 1);
		g_esBombAbility[type].g_iBombHitMode = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombHitMode", "Bomb Hit Mode", "Bomb_Hit_Mode", "hitmode", g_esBombAbility[type].g_iBombHitMode, value, 0, 2);
		g_esBombAbility[type].g_flBombRange = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRange", "Bomb Range", "Bomb_Range", "range", g_esBombAbility[type].g_flBombRange, value, 1.0, 99999.0);
		g_esBombAbility[type].g_flBombRangeChance = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRangeChance", "Bomb Range Chance", "Bomb_Range_Chance", "rangechance", g_esBombAbility[type].g_flBombRangeChance, value, 0.0, 100.0);
		g_esBombAbility[type].g_iBombRangeCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRangeCooldown", "Bomb Range Cooldown", "Bomb_Range_Cooldown", "rangecooldown", g_esBombAbility[type].g_iBombRangeCooldown, value, 0, 99999);
		g_esBombAbility[type].g_iBombRockBreak = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRockBreak", "Bomb Rock Break", "Bomb_Rock_Break", "rock", g_esBombAbility[type].g_iBombRockBreak, value, 0, 1);
		g_esBombAbility[type].g_flBombRockChance = flGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRockChance", "Bomb Rock Chance", "Bomb_Rock_Chance", "rockchance", g_esBombAbility[type].g_flBombRockChance, value, 0.0, 100.0);
		g_esBombAbility[type].g_iBombRockCooldown = iGetKeyValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "BombRockCooldown", "Bomb Rock Cooldown", "Bomb_Rock_Cooldown", "rockcooldown", g_esBombAbility[type].g_iBombRockCooldown, value, 0, 99999);
		g_esBombAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esBombAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_BOMB_SECTION, MT_BOMB_SECTION2, MT_BOMB_SECTION3, MT_BOMB_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vBombSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esBombCache[tank].g_flBombChance = flGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_flBombChance, g_esBombAbility[type].g_flBombChance);
	g_esBombCache[tank].g_flBombDeathChance = flGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_flBombDeathChance, g_esBombAbility[type].g_flBombDeathChance);
	g_esBombCache[tank].g_flBombRange = flGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_flBombRange, g_esBombAbility[type].g_flBombRange);
	g_esBombCache[tank].g_flBombRangeChance = flGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_flBombRangeChance, g_esBombAbility[type].g_flBombRangeChance);
	g_esBombCache[tank].g_flBombRockChance = flGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_flBombRockChance, g_esBombAbility[type].g_flBombRockChance);
	g_esBombCache[tank].g_iBombAbility = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombAbility, g_esBombAbility[type].g_iBombAbility);
	g_esBombCache[tank].g_iBombCooldown = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombCooldown, g_esBombAbility[type].g_iBombCooldown);
	g_esBombCache[tank].g_iBombDeath = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombDeath, g_esBombAbility[type].g_iBombDeath);
	g_esBombCache[tank].g_iBombEffect = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombEffect, g_esBombAbility[type].g_iBombEffect);
	g_esBombCache[tank].g_iBombHit = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombHit, g_esBombAbility[type].g_iBombHit);
	g_esBombCache[tank].g_iBombHitMode = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombHitMode, g_esBombAbility[type].g_iBombHitMode);
	g_esBombCache[tank].g_iBombMessage = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombMessage, g_esBombAbility[type].g_iBombMessage);
	g_esBombCache[tank].g_iBombRangeCooldown = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombRangeCooldown, g_esBombAbility[type].g_iBombRangeCooldown);
	g_esBombCache[tank].g_iBombRockBreak = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombRockBreak, g_esBombAbility[type].g_iBombRockBreak);
	g_esBombCache[tank].g_iBombRockCooldown = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iBombRockCooldown, g_esBombAbility[type].g_iBombRockCooldown);
	g_esBombCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_flCloseAreasOnly, g_esBombAbility[type].g_flCloseAreasOnly);
	g_esBombCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iComboAbility, g_esBombAbility[type].g_iComboAbility);
	g_esBombCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iHumanAbility, g_esBombAbility[type].g_iHumanAbility);
	g_esBombCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iHumanAmmo, g_esBombAbility[type].g_iHumanAmmo);
	g_esBombCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iHumanCooldown, g_esBombAbility[type].g_iHumanCooldown);
	g_esBombCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iHumanRangeCooldown, g_esBombAbility[type].g_iHumanRangeCooldown);
	g_esBombCache[tank].g_iHumanRockCooldown = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iHumanRockCooldown, g_esBombAbility[type].g_iHumanRockCooldown);
	g_esBombCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_flOpenAreasOnly, g_esBombAbility[type].g_flOpenAreasOnly);
	g_esBombCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esBombPlayer[tank].g_iRequiresHumans, g_esBombAbility[type].g_iRequiresHumans);
	g_esBombPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vBombCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vBombCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveBomb(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vBombEventFired(Event event, const char[] name)
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
			vBombCopyStats2(iBot, iTank);
			vRemoveBomb(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vBombCopyStats2(iTank, iBot);
			vRemoveBomb(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vBombRange(iTank, 1, MT_GetRandomFloat(0.1, 100.0));
			vRemoveBomb(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vBombReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vBombAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBombAbility[g_esBombPlayer[tank].g_iTankType].g_iAccessFlags, g_esBombPlayer[tank].g_iAccessFlags)) || g_esBombCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esBombCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esBombCache[tank].g_iBombAbility == 1 && g_esBombCache[tank].g_iComboAbility == 0)
	{
		vBombAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vBombButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esBombCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esBombCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esBombPlayer[tank].g_iTankType) || (g_esBombCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esBombCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBombAbility[g_esBombPlayer[tank].g_iTankType].g_iAccessFlags, g_esBombPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esBombCache[tank].g_iBombAbility == 1 && g_esBombCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esBombPlayer[tank].g_iRangeCooldown == -1 || g_esBombPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vBombAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombHuman3", (g_esBombPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vBombChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveBomb(tank);

	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esBombCache[tank].g_iBombAbility == 1)
	{
		if (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBombAbility[g_esBombPlayer[tank].g_iTankType].g_iAccessFlags, g_esBombPlayer[tank].g_iAccessFlags)) || g_esBombCache[tank].g_iHumanAbility == 0))
		{
			return;
		}

		float flPos[3];
		GetClientAbsOrigin(tank, flPos);
		vSpawnBreakProp(tank, flPos, 10.0, MODEL_PROPANETANK);

		switch (g_bSecondGame)
		{
			case true: EmitSoundToAll(SOUND_BOMB2, tank);
			case false: EmitSoundToAll(SOUND_BOMB1, tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vBombPostTankSpawn(int tank)
#else
public void MT_OnPostTankSpawn(int tank)
#endif
{
	vBombRange(tank, 1, MT_GetRandomFloat(0.1, 100.0));
}

#if defined MT_ABILITIES_MAIN
void vBombRockBreak(int tank, int rock)
#else
public void MT_OnRockBreak(int tank, int rock)
#endif
{
	if (bIsAreaNarrow(tank, g_esBombCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esBombCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esBombPlayer[tank].g_iTankType) || (g_esBombCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esBombCache[tank].g_iRequiresHumans) || (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBombAbility[g_esBombPlayer[tank].g_iTankType].g_iAccessFlags, g_esBombPlayer[tank].g_iAccessFlags)) || g_esBombCache[tank].g_iHumanAbility == 0)))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esBombCache[tank].g_iBombRockBreak == 1 && g_esBombCache[tank].g_iComboAbility == 0)
	{
		vBombRockBreak2(tank, rock, MT_GetRandomFloat(0.1, 100.0));
	}
}

void vBombAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esBombCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esBombCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esBombPlayer[tank].g_iTankType) || (g_esBombCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esBombCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBombAbility[g_esBombPlayer[tank].g_iTankType].g_iAccessFlags, g_esBombPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esBombPlayer[tank].g_iAmmoCount < g_esBombCache[tank].g_iHumanAmmo && g_esBombCache[tank].g_iHumanAmmo > 0))
	{
		g_esBombPlayer[tank].g_bFailed = false;
		g_esBombPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esBombCache[tank].g_flBombRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esBombCache[tank].g_flBombRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esBombPlayer[tank].g_iTankType, g_esBombAbility[g_esBombPlayer[tank].g_iTankType].g_iImmunityFlags, g_esBombPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vBombHit(iSurvivor, tank, random, flChance, g_esBombCache[tank].g_iBombAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBombCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBombCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombAmmo");
	}
}

void vBombHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esBombCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esBombCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esBombPlayer[tank].g_iTankType) || (g_esBombCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esBombCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBombAbility[g_esBombPlayer[tank].g_iTankType].g_iAccessFlags, g_esBombPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esBombPlayer[tank].g_iTankType, g_esBombAbility[g_esBombPlayer[tank].g_iTankType].g_iImmunityFlags, g_esBombPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esBombPlayer[tank].g_iRangeCooldown != -1 && g_esBombPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esBombPlayer[tank].g_iCooldown != -1 && g_esBombPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esBombPlayer[tank].g_iAmmoCount < g_esBombCache[tank].g_iHumanAmmo && g_esBombCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance)
			{
				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esBombPlayer[tank].g_iRangeCooldown == -1 || g_esBombPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBombCache[tank].g_iHumanAbility == 1)
					{
						g_esBombPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombHuman", g_esBombPlayer[tank].g_iAmmoCount, g_esBombCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esBombCache[tank].g_iBombRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBombCache[tank].g_iHumanAbility == 1 && g_esBombPlayer[tank].g_iAmmoCount < g_esBombCache[tank].g_iHumanAmmo && g_esBombCache[tank].g_iHumanAmmo > 0) ? g_esBombCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esBombPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esBombPlayer[tank].g_iRangeCooldown != -1 && g_esBombPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombHuman5", (g_esBombPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esBombPlayer[tank].g_iCooldown == -1 || g_esBombPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esBombCache[tank].g_iBombCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBombCache[tank].g_iHumanAbility == 1) ? g_esBombCache[tank].g_iHumanCooldown : iCooldown;
					g_esBombPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esBombPlayer[tank].g_iCooldown != -1 && g_esBombPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombHuman5", (g_esBombPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flPos[3];
				GetClientAbsOrigin(survivor, flPos);
				vSpawnBreakProp(tank, flPos, 10.0, MODEL_PROPANETANK);
				vScreenEffect(survivor, tank, g_esBombCache[tank].g_iBombEffect, flags);
				EmitSoundToAll(SOUND_HIT, survivor);

				if (g_esBombCache[tank].g_iBombMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Bomb", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Bomb", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esBombPlayer[tank].g_iRangeCooldown == -1 || g_esBombPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBombCache[tank].g_iHumanAbility == 1 && !g_esBombPlayer[tank].g_bFailed)
				{
					g_esBombPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBombCache[tank].g_iHumanAbility == 1 && !g_esBombPlayer[tank].g_bNoAmmo)
		{
			g_esBombPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombAmmo");
		}
	}
}

void vBombRange(int tank, int value, float random, int pos = -1)
{
	float flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 13, pos) : g_esBombCache[tank].g_flBombDeathChance;
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(tank) && g_esBombCache[tank].g_iBombDeath == 1 && random <= flChance)
	{
		if (g_esBombCache[tank].g_iComboAbility == value || bIsAreaNarrow(tank, g_esBombCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esBombCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esBombPlayer[tank].g_iTankType) || (g_esBombCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esBombCache[tank].g_iRequiresHumans) || (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBombAbility[g_esBombPlayer[tank].g_iTankType].g_iAccessFlags, g_esBombPlayer[tank].g_iAccessFlags)) || g_esBombCache[tank].g_iHumanAbility == 0)))
		{
			return;
		}

		float flPos[3];
		GetClientAbsOrigin(tank, flPos);
		vSpawnBreakProp(tank, flPos, 10.0, MODEL_PROPANETANK);

		switch (g_bSecondGame)
		{
			case true: EmitSoundToAll(SOUND_BOMB2, tank);
			case false: EmitSoundToAll(SOUND_BOMB1, tank);
		}
	}
}

void vBombRockBreak2(int tank, int rock, float random, int pos = -1)
{
	float flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 14, pos) : g_esBombCache[tank].g_flBombRockChance;
	if (random <= flChance)
	{
		int iTime = GetTime(), iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBombCache[tank].g_iHumanAbility == 1) ? g_esBombCache[tank].g_iHumanRockCooldown : g_esBombCache[tank].g_iBombRockCooldown;
		iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 15, pos)) : iCooldown;
		if (g_esBombPlayer[tank].g_iRockCooldown == -1 || g_esBombPlayer[tank].g_iRockCooldown < iTime)
		{
			g_esBombPlayer[tank].g_iRockCooldown = (iTime + iCooldown);
			if (g_esBombPlayer[tank].g_iRockCooldown != -1 && g_esBombPlayer[tank].g_iRockCooldown > iTime)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombHuman5", (g_esBombPlayer[tank].g_iRockCooldown - iTime));
			}
		}
		else if (g_esBombPlayer[tank].g_iRockCooldown != -1 && g_esBombPlayer[tank].g_iRockCooldown > iTime)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "BombHuman3", (g_esBombPlayer[tank].g_iRockCooldown - iTime));

			return;
		}

		float flPos[3];
		GetEntPropVector(rock, Prop_Data, "m_vecOrigin", flPos);
		vSpawnBreakProp(tank, flPos, 10.0, MODEL_PROPANETANK);

		switch (g_bSecondGame)
		{
			case true: EmitSoundToAll(SOUND_BOMB2, tank);
			case false: EmitSoundToAll(SOUND_BOMB1, tank);
		}

		if (g_esBombCache[tank].g_iBombMessage & MT_MESSAGE_SPECIAL)
		{
			char sTankName[33];
			MT_GetTankName(tank, sTankName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Bomb2", sTankName);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Bomb2", LANG_SERVER, sTankName);
		}
	}
}

void vBombCopyStats2(int oldTank, int newTank)
{
	g_esBombPlayer[newTank].g_iAmmoCount = g_esBombPlayer[oldTank].g_iAmmoCount;
	g_esBombPlayer[newTank].g_iCooldown = g_esBombPlayer[oldTank].g_iCooldown;
	g_esBombPlayer[newTank].g_iRangeCooldown = g_esBombPlayer[oldTank].g_iRangeCooldown;
	g_esBombPlayer[newTank].g_iRockCooldown = g_esBombPlayer[oldTank].g_iRockCooldown;
}

void vRemoveBomb(int tank)
{
	g_esBombPlayer[tank].g_bFailed = false;
	g_esBombPlayer[tank].g_bNoAmmo = false;
	g_esBombPlayer[tank].g_iAmmoCount = 0;
	g_esBombPlayer[tank].g_iCooldown = -1;
	g_esBombPlayer[tank].g_iRangeCooldown = -1;
	g_esBombPlayer[tank].g_iRockCooldown = -1;
}

void vBombReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveBomb(iPlayer);
		}
	}
}

Action tTimerBombCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esBombAbility[g_esBombPlayer[iTank].g_iTankType].g_iAccessFlags, g_esBombPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esBombPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esBombCache[iTank].g_iBombAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vBombAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerBombCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esBombAbility[g_esBombPlayer[iTank].g_iTankType].g_iAccessFlags, g_esBombPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esBombPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esBombCache[iTank].g_iBombHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esBombCache[iTank].g_iBombHitMode == 0 || g_esBombCache[iTank].g_iBombHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vBombHit(iSurvivor, iTank, flRandom, flChance, g_esBombCache[iTank].g_iBombHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esBombCache[iTank].g_iBombHitMode == 0 || g_esBombCache[iTank].g_iBombHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vBombHit(iSurvivor, iTank, flRandom, flChance, g_esBombCache[iTank].g_iBombHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}