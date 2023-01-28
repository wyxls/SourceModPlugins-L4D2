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

#define MT_SMASH_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_SMASH_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Smash Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank smashes survivors to death.",
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
			strcopy(error, err_max, "\"[MT] Smash Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_SMASH_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define PARTICLE_BLOOD "boomer_explode_D"

#define SOUND_GROWL2 "player/tank/voice/growl/tank_climb_01.wav" // Only available in L4D2
#define SOUND_GROWL1 "player/tank/voice/growl/hulk_growl_1.wav" // Only available in L4D1
#define SOUND_SMASH2 "player/charger/hit/charger_smash_02.wav" // Only available in L4D2
#define SOUND_SMASH1 "player/tank/hit/hulk_punch_1.wav"

#define MT_SMASH_SECTION "smashability"
#define MT_SMASH_SECTION2 "smash ability"
#define MT_SMASH_SECTION3 "smash_ability"
#define MT_SMASH_SECTION4 "smash"

#define MT_MENU_SMASH "Smash Ability"

enum struct esSmashPlayer
{
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSmashChance;
	float g_flSmashRange;
	float g_flSmashRangeChance;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iSmashAbility;
	int g_iSmashBody;
	int g_iSmashCooldown;
	int g_iSmashEffect;
	int g_iSmashHit;
	int g_iSmashHitMode;
	int g_iSmashMessage;
	int g_iSmashRangeCooldown;
	int g_iTankType;
}

esSmashPlayer g_esSmashPlayer[MAXPLAYERS + 1];

enum struct esSmashAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSmashChance;
	float g_flSmashRange;
	float g_flSmashRangeChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iSmashAbility;
	int g_iSmashBody;
	int g_iSmashCooldown;
	int g_iSmashEffect;
	int g_iSmashHit;
	int g_iSmashHitMode;
	int g_iSmashMessage;
	int g_iSmashRangeCooldown;
}

esSmashAbility g_esSmashAbility[MT_MAXTYPES + 1];

enum struct esSmashCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSmashChance;
	float g_flSmashRange;
	float g_flSmashRangeChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
	int g_iSmashAbility;
	int g_iSmashBody;
	int g_iSmashCooldown;
	int g_iSmashEffect;
	int g_iSmashHit;
	int g_iSmashHitMode;
	int g_iSmashMessage;
	int g_iSmashRangeCooldown;
}

esSmashCache g_esSmashCache[MAXPLAYERS + 1];

int g_iSmashDeathModelOwner = 0;

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_smash", cmdSmashInfo, "View information about the Smash ability.");

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
void vSmashMapStart()
#else
public void OnMapStart()
#endif
{
	iPrecacheParticle(PARTICLE_BLOOD);

	if (g_bSecondGame)
	{
		PrecacheSound(SOUND_GROWL2, true);
		PrecacheSound(SOUND_SMASH2, true);
	}
	else
	{
		PrecacheSound(SOUND_GROWL1, true);
		PrecacheSound(SOUND_SMASH1, true);
	}

	vSmashReset();
}

#if defined MT_ABILITIES_MAIN2
void vSmashClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnSmashTakeDamage);
	vRemoveSmash(client);
}

#if defined MT_ABILITIES_MAIN2
void vSmashClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveSmash(client);
}

#if defined MT_ABILITIES_MAIN2
void vSmashMapEnd()
#else
public void OnMapEnd()
#endif
{
	vSmashReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdSmashInfo(int client, int args)
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
		case false: vSmashMenu(client, MT_SMASH_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vSmashMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_SMASH_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iSmashMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Smash Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iSmashMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSmashCache[param1].g_iSmashAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esSmashCache[param1].g_iHumanAmmo - g_esSmashPlayer[param1].g_iAmmoCount), g_esSmashCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esSmashCache[param1].g_iHumanAbility == 1) ? g_esSmashCache[param1].g_iHumanCooldown : g_esSmashCache[param1].g_iSmashCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "SmashDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSmashCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esSmashCache[param1].g_iHumanAbility == 1) ? g_esSmashCache[param1].g_iHumanRangeCooldown : g_esSmashCache[param1].g_iSmashRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vSmashMenu(param1, MT_SMASH_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pSmash = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "SmashMenu", param1);
			pSmash.SetTitle(sMenuTitle);
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
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN2
void vSmashDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_SMASH, MT_MENU_SMASH);
}

#if defined MT_ABILITIES_MAIN2
void vSmashMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_SMASH, false))
	{
		vSmashMenu(client, MT_SMASH_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmashMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_SMASH, false))
	{
		FormatEx(buffer, size, "%T", "SmashMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmashEntityCreated(int entity, const char[] classname)
#else
public void OnEntityCreated(int entity, const char[] classname)
#endif
{
	if (bIsValidEntity(entity) && StrEqual(classname, "survivor_death_model"))
	{
		int iOwner = GetClientOfUserId(g_iSmashDeathModelOwner);
		if (bIsValidClient(iOwner))
		{
			SDKHook(entity, SDKHook_SpawnPost, OnSmashModelSpawnPost);
		}

		g_iSmashDeathModelOwner = 0;
	}
}

void OnSmashModelSpawnPost(int model)
{
	g_iSmashDeathModelOwner = 0;

	SDKUnhook(model, SDKHook_SpawnPost, OnSmashModelSpawnPost);

	if (!bIsValidEntity(model))
	{
		return;
	}

	RemoveEntity(model);
}

Action OnSmashTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esSmashCache[attacker].g_iSmashHitMode == 0 || g_esSmashCache[attacker].g_iSmashHitMode == 1) && bIsSurvivor(victim) && g_esSmashCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esSmashAbility[g_esSmashPlayer[attacker].g_iTankType].g_iAccessFlags, g_esSmashPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esSmashPlayer[attacker].g_iTankType, g_esSmashAbility[g_esSmashPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esSmashPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vSmashHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esSmashCache[attacker].g_flSmashChance, g_esSmashCache[attacker].g_iSmashHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esSmashCache[victim].g_iSmashHitMode == 0 || g_esSmashCache[victim].g_iSmashHitMode == 2) && bIsSurvivor(attacker) && g_esSmashCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esSmashAbility[g_esSmashPlayer[victim].g_iTankType].g_iAccessFlags, g_esSmashPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esSmashPlayer[victim].g_iTankType, g_esSmashAbility[g_esSmashPlayer[victim].g_iTankType].g_iImmunityFlags, g_esSmashPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vSmashHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esSmashCache[victim].g_flSmashChance, g_esSmashCache[victim].g_iSmashHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vSmashPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_SMASH);
}

#if defined MT_ABILITIES_MAIN2
void vSmashAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_SMASH_SECTION);
	list2.PushString(MT_SMASH_SECTION2);
	list3.PushString(MT_SMASH_SECTION3);
	list4.PushString(MT_SMASH_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vSmashCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmashCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_SMASH_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_SMASH_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_SMASH_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_SMASH_SECTION4);
	if (g_esSmashCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_SMASH_SECTION, false) || StrEqual(sSubset[iPos], MT_SMASH_SECTION2, false) || StrEqual(sSubset[iPos], MT_SMASH_SECTION3, false) || StrEqual(sSubset[iPos], MT_SMASH_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esSmashCache[tank].g_iSmashAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vSmashAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerSmashCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esSmashCache[tank].g_iSmashHitMode == 0 || g_esSmashCache[tank].g_iSmashHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vSmashHit(survivor, tank, random, flChance, g_esSmashCache[tank].g_iSmashHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esSmashCache[tank].g_iSmashHitMode == 0 || g_esSmashCache[tank].g_iSmashHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vSmashHit(survivor, tank, random, flChance, g_esSmashCache[tank].g_iSmashHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerSmashCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vSmashConfigsLoad(int mode)
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
				g_esSmashAbility[iIndex].g_iAccessFlags = 0;
				g_esSmashAbility[iIndex].g_iImmunityFlags = 0;
				g_esSmashAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esSmashAbility[iIndex].g_iComboAbility = 0;
				g_esSmashAbility[iIndex].g_iHumanAbility = 0;
				g_esSmashAbility[iIndex].g_iHumanAmmo = 5;
				g_esSmashAbility[iIndex].g_iHumanCooldown = 0;
				g_esSmashAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esSmashAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esSmashAbility[iIndex].g_iRequiresHumans = 0;
				g_esSmashAbility[iIndex].g_iSmashAbility = 0;
				g_esSmashAbility[iIndex].g_iSmashEffect = 0;
				g_esSmashAbility[iIndex].g_iSmashMessage = 0;
				g_esSmashAbility[iIndex].g_iSmashBody = 1;
				g_esSmashAbility[iIndex].g_flSmashChance = 33.3;
				g_esSmashAbility[iIndex].g_iSmashCooldown = 0;
				g_esSmashAbility[iIndex].g_iSmashHit = 0;
				g_esSmashAbility[iIndex].g_iSmashHitMode = 0;
				g_esSmashAbility[iIndex].g_flSmashRange = 150.0;
				g_esSmashAbility[iIndex].g_flSmashRangeChance = 15.0;
				g_esSmashAbility[iIndex].g_iSmashRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esSmashPlayer[iPlayer].g_iAccessFlags = 0;
					g_esSmashPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esSmashPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esSmashPlayer[iPlayer].g_iComboAbility = 0;
					g_esSmashPlayer[iPlayer].g_iHumanAbility = 0;
					g_esSmashPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esSmashPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esSmashPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esSmashPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esSmashPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esSmashPlayer[iPlayer].g_iSmashAbility = 0;
					g_esSmashPlayer[iPlayer].g_iSmashEffect = 0;
					g_esSmashPlayer[iPlayer].g_iSmashMessage = 0;
					g_esSmashPlayer[iPlayer].g_iSmashBody = 0;
					g_esSmashPlayer[iPlayer].g_flSmashChance = 0.0;
					g_esSmashPlayer[iPlayer].g_iSmashCooldown = 0;
					g_esSmashPlayer[iPlayer].g_iSmashHit = 0;
					g_esSmashPlayer[iPlayer].g_iSmashHitMode = 0;
					g_esSmashPlayer[iPlayer].g_flSmashRange = 0.0;
					g_esSmashPlayer[iPlayer].g_flSmashRangeChance = 0.0;
					g_esSmashPlayer[iPlayer].g_iSmashRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmashConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esSmashPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSmashPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSmashPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSmashPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esSmashPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSmashPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esSmashPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSmashPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esSmashPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSmashPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esSmashPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esSmashPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esSmashPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSmashPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSmashPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSmashPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esSmashPlayer[admin].g_iSmashAbility = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSmashPlayer[admin].g_iSmashAbility, value, 0, 1);
		g_esSmashPlayer[admin].g_iSmashEffect = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esSmashPlayer[admin].g_iSmashEffect, value, 0, 7);
		g_esSmashPlayer[admin].g_iSmashMessage = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSmashPlayer[admin].g_iSmashMessage, value, 0, 3);
		g_esSmashPlayer[admin].g_iSmashBody = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashBody", "Smash Body", "Smash_Body", "body", g_esSmashPlayer[admin].g_iSmashBody, value, 0, 1);
		g_esSmashPlayer[admin].g_flSmashChance = flGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashChance", "Smash Chance", "Smash_Chance", "chance", g_esSmashPlayer[admin].g_flSmashChance, value, 0.0, 100.0);
		g_esSmashPlayer[admin].g_iSmashCooldown = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashCooldown", "Smash Cooldown", "Smash_Cooldown", "cooldown", g_esSmashPlayer[admin].g_iSmashCooldown, value, 0, 99999);
		g_esSmashPlayer[admin].g_iSmashHit = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashHit", "Smash Hit", "Smash_Hit", "hit", g_esSmashPlayer[admin].g_iSmashHit, value, 0, 1);
		g_esSmashPlayer[admin].g_iSmashHitMode = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashHitMode", "Smash Hit Mode", "Smash_Hit_Mode", "hitmode", g_esSmashPlayer[admin].g_iSmashHitMode, value, 0, 2);
		g_esSmashPlayer[admin].g_flSmashRange = flGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashRange", "Smash Range", "Smash_Range", "range", g_esSmashPlayer[admin].g_flSmashRange, value, 1.0, 99999.0);
		g_esSmashPlayer[admin].g_flSmashRangeChance = flGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashRangeChance", "Smash Range Chance", "Smash_Range_Chance", "rangechance", g_esSmashPlayer[admin].g_flSmashRangeChance, value, 0.0, 100.0);
		g_esSmashPlayer[admin].g_iSmashRangeCooldown = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashRangeCooldown", "Smash Range Cooldown", "Smash_Range_Cooldown", "rangecooldown", g_esSmashPlayer[admin].g_iSmashRangeCooldown, value, 0, 99999);
		g_esSmashPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSmashPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esSmashAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSmashAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSmashAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSmashAbility[type].g_iComboAbility, value, 0, 1);
		g_esSmashAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSmashAbility[type].g_iHumanAbility, value, 0, 2);
		g_esSmashAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSmashAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esSmashAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSmashAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esSmashAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esSmashAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esSmashAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSmashAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSmashAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSmashAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esSmashAbility[type].g_iSmashAbility = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSmashAbility[type].g_iSmashAbility, value, 0, 1);
		g_esSmashAbility[type].g_iSmashEffect = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esSmashAbility[type].g_iSmashEffect, value, 0, 7);
		g_esSmashAbility[type].g_iSmashMessage = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSmashAbility[type].g_iSmashMessage, value, 0, 3);
		g_esSmashAbility[type].g_iSmashBody = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashBody", "Smash Body", "Smash_Body", "body", g_esSmashAbility[type].g_iSmashBody, value, 0, 1);
		g_esSmashAbility[type].g_flSmashChance = flGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashChance", "Smash Chance", "Smash_Chance", "chance", g_esSmashAbility[type].g_flSmashChance, value, 0.0, 100.0);
		g_esSmashAbility[type].g_iSmashCooldown = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashCooldown", "Smash Cooldown", "Smash_Cooldown", "cooldown", g_esSmashAbility[type].g_iSmashCooldown, value, 0, 99999);
		g_esSmashAbility[type].g_iSmashHit = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashHit", "Smash Hit", "Smash_Hit", "hit", g_esSmashAbility[type].g_iSmashHit, value, 0, 1);
		g_esSmashAbility[type].g_iSmashHitMode = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashHitMode", "Smash Hit Mode", "Smash_Hit_Mode", "hitmode", g_esSmashAbility[type].g_iSmashHitMode, value, 0, 2);
		g_esSmashAbility[type].g_flSmashRange = flGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashRange", "Smash Range", "Smash_Range", "range", g_esSmashAbility[type].g_flSmashRange, value, 1.0, 99999.0);
		g_esSmashAbility[type].g_flSmashRangeChance = flGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashRangeChance", "Smash Range Chance", "Smash_Range_Chance", "rangechance", g_esSmashAbility[type].g_flSmashRangeChance, value, 0.0, 100.0);
		g_esSmashAbility[type].g_iSmashRangeCooldown = iGetKeyValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "SmashRangeCooldown", "Smash Range Cooldown", "Smash_Range_Cooldown", "rangecooldown", g_esSmashAbility[type].g_iSmashRangeCooldown, value, 0, 99999);
		g_esSmashAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSmashAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SMASH_SECTION, MT_SMASH_SECTION2, MT_SMASH_SECTION3, MT_SMASH_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmashSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esSmashCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_flCloseAreasOnly, g_esSmashAbility[type].g_flCloseAreasOnly);
	g_esSmashCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iComboAbility, g_esSmashAbility[type].g_iComboAbility);
	g_esSmashCache[tank].g_flSmashChance = flGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_flSmashChance, g_esSmashAbility[type].g_flSmashChance);
	g_esSmashCache[tank].g_flSmashRange = flGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_flSmashRange, g_esSmashAbility[type].g_flSmashRange);
	g_esSmashCache[tank].g_flSmashRangeChance = flGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_flSmashRangeChance, g_esSmashAbility[type].g_flSmashRangeChance);
	g_esSmashCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iHumanAbility, g_esSmashAbility[type].g_iHumanAbility);
	g_esSmashCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iHumanAmmo, g_esSmashAbility[type].g_iHumanAmmo);
	g_esSmashCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iHumanCooldown, g_esSmashAbility[type].g_iHumanCooldown);
	g_esSmashCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iHumanRangeCooldown, g_esSmashAbility[type].g_iHumanRangeCooldown);
	g_esSmashCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_flOpenAreasOnly, g_esSmashAbility[type].g_flOpenAreasOnly);
	g_esSmashCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iRequiresHumans, g_esSmashAbility[type].g_iRequiresHumans);
	g_esSmashCache[tank].g_iSmashAbility = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iSmashAbility, g_esSmashAbility[type].g_iSmashAbility);
	g_esSmashCache[tank].g_iSmashBody = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iSmashBody, g_esSmashAbility[type].g_iSmashBody);
	g_esSmashCache[tank].g_iSmashCooldown = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iSmashCooldown, g_esSmashAbility[type].g_iSmashCooldown);
	g_esSmashCache[tank].g_iSmashEffect = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iSmashEffect, g_esSmashAbility[type].g_iSmashEffect);
	g_esSmashCache[tank].g_iSmashHit = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iSmashHit, g_esSmashAbility[type].g_iSmashHit);
	g_esSmashCache[tank].g_iSmashHitMode = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iSmashHitMode, g_esSmashAbility[type].g_iSmashHitMode);
	g_esSmashCache[tank].g_iSmashMessage = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iSmashMessage, g_esSmashAbility[type].g_iSmashMessage);
	g_esSmashCache[tank].g_iSmashRangeCooldown = iGetSettingValue(apply, bHuman, g_esSmashPlayer[tank].g_iSmashRangeCooldown, g_esSmashAbility[type].g_iSmashRangeCooldown);
	g_esSmashPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vSmashCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vSmashCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveSmash(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vSmashEventFired(Event event, const char[] name)
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
			vSmashCopyStats2(iBot, iTank);
			vRemoveSmash(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vSmashCopyStats2(iTank, iBot);
			vRemoveSmash(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveSmash(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vSmashReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmashAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSmashAbility[g_esSmashPlayer[tank].g_iTankType].g_iAccessFlags, g_esSmashPlayer[tank].g_iAccessFlags)) || g_esSmashCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esSmashCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esSmashCache[tank].g_iSmashAbility == 1 && g_esSmashCache[tank].g_iComboAbility == 0)
	{
		vSmashAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmashButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esSmashCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSmashCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSmashPlayer[tank].g_iTankType) || (g_esSmashCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSmashCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSmashAbility[g_esSmashPlayer[tank].g_iTankType].g_iAccessFlags, g_esSmashPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esSmashCache[tank].g_iSmashAbility == 1 && g_esSmashCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esSmashPlayer[tank].g_iRangeCooldown == -1 || g_esSmashPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vSmashAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmashHuman3", (g_esSmashPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSmashChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveSmash(tank);
}

void vSmash(int survivor, int tank)
{
	if (bIsAreaNarrow(tank, g_esSmashCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSmashCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSmashPlayer[tank].g_iTankType) || (g_esSmashCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSmashCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSmashAbility[g_esSmashPlayer[tank].g_iTankType].g_iAccessFlags, g_esSmashPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esSmashPlayer[tank].g_iTankType, g_esSmashAbility[g_esSmashPlayer[tank].g_iTankType].g_iImmunityFlags, g_esSmashPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	switch (g_bSecondGame)
	{
		case true:
		{
			EmitSoundToAll(SOUND_SMASH2, survivor);
			EmitSoundToAll(SOUND_GROWL2, tank);
		}
		case false:
		{
			EmitSoundToAll(SOUND_SMASH1, survivor);
			EmitSoundToAll(SOUND_GROWL1, tank);
		}
	}

	vAttachParticle(survivor, PARTICLE_BLOOD, 0.1);
}

void vSmashAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esSmashCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSmashCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSmashPlayer[tank].g_iTankType) || (g_esSmashCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSmashCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSmashAbility[g_esSmashPlayer[tank].g_iTankType].g_iAccessFlags, g_esSmashPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esSmashPlayer[tank].g_iAmmoCount < g_esSmashCache[tank].g_iHumanAmmo && g_esSmashCache[tank].g_iHumanAmmo > 0))
	{
		g_esSmashPlayer[tank].g_bFailed = false;
		g_esSmashPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esSmashCache[tank].g_flSmashRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esSmashCache[tank].g_flSmashRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esSmashPlayer[tank].g_iTankType, g_esSmashAbility[g_esSmashPlayer[tank].g_iTankType].g_iImmunityFlags, g_esSmashPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vSmashHit(iSurvivor, tank, random, flChance, g_esSmashCache[tank].g_iSmashAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmashCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmashHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmashCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmashAmmo");
	}
}

void vSmashHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esSmashCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSmashCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSmashPlayer[tank].g_iTankType) || (g_esSmashCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSmashCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSmashAbility[g_esSmashPlayer[tank].g_iTankType].g_iAccessFlags, g_esSmashPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esSmashPlayer[tank].g_iTankType, g_esSmashAbility[g_esSmashPlayer[tank].g_iTankType].g_iImmunityFlags, g_esSmashPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esSmashPlayer[tank].g_iRangeCooldown != -1 && g_esSmashPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esSmashPlayer[tank].g_iCooldown != -1 && g_esSmashPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esSmashPlayer[tank].g_iAmmoCount < g_esSmashCache[tank].g_iHumanAmmo && g_esSmashCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance)
			{
				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esSmashPlayer[tank].g_iRangeCooldown == -1 || g_esSmashPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmashCache[tank].g_iHumanAbility == 1)
					{
						g_esSmashPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmashHuman", g_esSmashPlayer[tank].g_iAmmoCount, g_esSmashCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esSmashCache[tank].g_iSmashRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmashCache[tank].g_iHumanAbility == 1 && g_esSmashPlayer[tank].g_iAmmoCount < g_esSmashCache[tank].g_iHumanAmmo && g_esSmashCache[tank].g_iHumanAmmo > 0) ? g_esSmashCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esSmashPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esSmashPlayer[tank].g_iRangeCooldown != -1 && g_esSmashPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmashHuman5", (g_esSmashPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esSmashPlayer[tank].g_iCooldown == -1 || g_esSmashPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esSmashCache[tank].g_iSmashCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmashCache[tank].g_iHumanAbility == 1) ? g_esSmashCache[tank].g_iHumanCooldown : iCooldown;
					g_esSmashPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esSmashPlayer[tank].g_iCooldown != -1 && g_esSmashPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmashHuman5", (g_esSmashPlayer[tank].g_iCooldown - iTime));
					}
				}

				if (g_esSmashCache[tank].g_iSmashBody == 1)
				{
					g_iSmashDeathModelOwner = GetClientUserId(survivor);
				}

				vSmash(survivor, tank);
				ForcePlayerSuicide(survivor);
				vScreenEffect(survivor, tank, g_esSmashCache[tank].g_iSmashEffect, flags);

				if (g_esSmashCache[tank].g_iSmashMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Smash", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Smash", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esSmashPlayer[tank].g_iRangeCooldown == -1 || g_esSmashPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmashCache[tank].g_iHumanAbility == 1 && !g_esSmashPlayer[tank].g_bFailed)
				{
					g_esSmashPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmashHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSmashCache[tank].g_iHumanAbility == 1 && !g_esSmashPlayer[tank].g_bNoAmmo)
		{
			g_esSmashPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "SmashAmmo");
		}
	}
}

void vSmashCopyStats2(int oldTank, int newTank)
{
	g_esSmashPlayer[newTank].g_iAmmoCount = g_esSmashPlayer[oldTank].g_iAmmoCount;
	g_esSmashPlayer[newTank].g_iCooldown = g_esSmashPlayer[oldTank].g_iCooldown;
	g_esSmashPlayer[newTank].g_iRangeCooldown = g_esSmashPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveSmash(int tank)
{
	g_esSmashPlayer[tank].g_bFailed = false;
	g_esSmashPlayer[tank].g_bNoAmmo = false;
	g_esSmashPlayer[tank].g_iAmmoCount = 0;
	g_esSmashPlayer[tank].g_iCooldown = -1;
	g_esSmashPlayer[tank].g_iRangeCooldown = -1;
}

void vSmashReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveSmash(iPlayer);
		}
	}
}

Action tTimerSmashCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSmashAbility[g_esSmashPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSmashPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSmashPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSmashCache[iTank].g_iSmashAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vSmashAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerSmashCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSmashAbility[g_esSmashPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSmashPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSmashPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSmashCache[iTank].g_iSmashHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esSmashCache[iTank].g_iSmashHitMode == 0 || g_esSmashCache[iTank].g_iSmashHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vSmashHit(iSurvivor, iTank, flRandom, flChance, g_esSmashCache[iTank].g_iSmashHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esSmashCache[iTank].g_iSmashHitMode == 0 || g_esSmashCache[iTank].g_iSmashHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vSmashHit(iSurvivor, iTank, flRandom, flChance, g_esSmashCache[iTank].g_iSmashHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}