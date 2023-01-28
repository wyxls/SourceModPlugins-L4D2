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

#define MT_ULTIMATE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_ULTIMATE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Ultimate Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank activates ultimate mode when low on health to gain temporary godmode and damage boost.",
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
			strcopy(error, err_max, "\"[MT] Ultimate Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_ULTIMATE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define PARTICLE_ULTIMATE "electrical_arc_01_system"

#define SOUND_EXPLOSION "ambient/explosions/explode_2.wav"
#define SOUND_GROWL1 "player/tank/voice/growl/hulk_growl_1.wav" //Only exists on L4D1
#define SOUND_GROWL2 "player/tank/voice/growl/tank_climb_01.wav" //Only exists on L4D2
#define SOUND_METAL "physics/metal/metal_solid_impact_hard5.wav"
#define SOUND_SMASH1 "player/tank/hit/hulk_punch_1.wav"
#define SOUND_SMASH2 "player/charger/hit/charger_smash_02.wav" //Only exists on L4D2
#define SOUND_ULTIMATE "items/suitchargeok1.wav"

#define MT_ULTIMATE_SECTION "ultimateability"
#define MT_ULTIMATE_SECTION2 "ultimate ability"
#define MT_ULTIMATE_SECTION3 "ultimate_ability"
#define MT_ULTIMATE_SECTION4 "ultimate"

#define MT_MENU_ULTIMATE "Ultimate Ability"

enum struct esUltimatePlayer
{
	bool g_bActivated;
	bool g_bQualified;

	float g_flDamage;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flUltimateChance;
	float g_flUltimateDamageBoost;
	float g_flUltimateDamageRequired;
	float g_flUltimateHealthPortion;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iCount;
	int g_iDuration;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iTankType;
	int g_iUltimateAbility;
	int g_iUltimateAmount;
	int g_iUltimateCooldown;
	int g_iUltimateDuration;
	int g_iUltimateHealthLimit;
	int g_iUltimateMessage;
}

esUltimatePlayer g_esUltimatePlayer[MAXPLAYERS + 1];

enum struct esUltimateAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flUltimateChance;
	float g_flUltimateDamageBoost;
	float g_flUltimateDamageRequired;
	float g_flUltimateHealthPortion;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iUltimateAbility;
	int g_iUltimateAmount;
	int g_iUltimateCooldown;
	int g_iUltimateDuration;
	int g_iUltimateHealthLimit;
	int g_iUltimateMessage;
}

esUltimateAbility g_esUltimateAbility[MT_MAXTYPES + 1];

enum struct esUltimateCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flUltimateChance;
	float g_flUltimateDamageBoost;
	float g_flUltimateDamageRequired;
	float g_flUltimateHealthPortion;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iRequiresHumans;
	int g_iUltimateAbility;
	int g_iUltimateAmount;
	int g_iUltimateCooldown;
	int g_iUltimateDuration;
	int g_iUltimateHealthLimit;
	int g_iUltimateMessage;
}

esUltimateCache g_esUltimateCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_god", cmdUltimateInfo, "View information about the Ultimate ability.");

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
void vUltimateMapStart()
#else
public void OnMapStart()
#endif
{
	iPrecacheParticle(PARTICLE_ULTIMATE);

	PrecacheSound(SOUND_ULTIMATE, true);
	PrecacheSound(SOUND_EXPLOSION, true);

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

	vUltimateReset();
}

#if defined MT_ABILITIES_MAIN2
void vUltimateClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnUltimateTakeDamage);
	vRemoveUltimate(client);
}

#if defined MT_ABILITIES_MAIN2
void vUltimateClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveUltimate(client);
}

#if defined MT_ABILITIES_MAIN2
void vUltimateMapEnd()
#else
public void OnMapEnd()
#endif
{
	vUltimateReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdUltimateInfo(int client, int args)
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
		case false: vUltimateMenu(client, MT_ULTIMATE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vUltimateMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_ULTIMATE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iUltimateMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Ultimate Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iUltimateMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esUltimateCache[param1].g_iUltimateAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esUltimateCache[param1].g_iHumanAmmo - g_esUltimatePlayer[param1].g_iAmmoCount), g_esUltimateCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esUltimateCache[param1].g_iHumanAbility == 1) ? g_esUltimateCache[param1].g_iHumanCooldown : g_esUltimateCache[param1].g_iUltimateCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "UltimateDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esUltimateCache[param1].g_iUltimateDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esUltimateCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vUltimateMenu(param1, MT_ULTIMATE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pUltimate = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "UltimateMenu", param1);
			pUltimate.SetTitle(sMenuTitle);
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
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN2
void vUltimateDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_ULTIMATE, MT_MENU_ULTIMATE);
}

#if defined MT_ABILITIES_MAIN2
void vUltimateMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_ULTIMATE, false))
	{
		vUltimateMenu(client, MT_ULTIMATE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vUltimateMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_ULTIMATE, false))
	{
		FormatEx(buffer, size, "%T", "UltimateMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vUltimatePlayerRunCmd(int client)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsTankSupported(client) || !g_esUltimatePlayer[client].g_bActivated || g_esUltimatePlayer[client].g_iDuration == -1)
	{
#if defined MT_ABILITIES_MAIN2
		return;
#else
		return Plugin_Continue;
#endif
	}

	int iTime = GetTime();
	if (g_esUltimatePlayer[client].g_iDuration < iTime)
	{
		if (g_esUltimatePlayer[client].g_iCooldown == -1 || g_esUltimatePlayer[client].g_iCooldown < iTime)
		{
			int iPos = g_esUltimateAbility[g_esUltimatePlayer[client].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(client, 2, iPos)) : g_esUltimateCache[client].g_iUltimateCooldown;
			iCooldown = (bIsTank(client, MT_CHECK_FAKECLIENT) && g_esUltimateCache[client].g_iHumanAbility == 1 && g_esUltimatePlayer[client].g_iAmmoCount < g_esUltimateCache[client].g_iHumanAmmo && g_esUltimateCache[client].g_iHumanAmmo > 0) ? g_esUltimateCache[client].g_iHumanCooldown : iCooldown;
			g_esUltimatePlayer[client].g_iCooldown = (iTime + iCooldown);
			if (g_esUltimatePlayer[client].g_iCooldown != -1 && g_esUltimatePlayer[client].g_iCooldown > iTime)
			{
				MT_PrintToChat(client, "%s %t", MT_TAG3, "UltimateHuman5", (g_esUltimatePlayer[client].g_iCooldown - iTime));
			}
		}

		g_esUltimatePlayer[client].g_bQualified = false;
		g_esUltimatePlayer[client].g_bActivated = false;
		g_esUltimatePlayer[client].g_iDuration = -1;

		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);

		if (g_esUltimateCache[client].g_iUltimateMessage == 1)
		{
			char sTankName[33];
			MT_GetTankName(client, sTankName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Ultimate2", sTankName);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Ultimate2", LANG_SERVER, sTankName);
		}
	}
#if !defined MT_ABILITIES_MAIN2
	return Plugin_Continue;
#endif
}

Action OnUltimateTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && bIsSurvivor(victim))
		{
			if (bIsAreaNarrow(attacker, g_esUltimateCache[attacker].g_flOpenAreasOnly) || bIsAreaWide(attacker, g_esUltimateCache[attacker].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esUltimatePlayer[attacker].g_iTankType) || (g_esUltimateCache[attacker].g_iRequiresHumans > 0 && iGetHumanCount() < g_esUltimateCache[attacker].g_iRequiresHumans) || (!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esUltimateAbility[g_esUltimatePlayer[attacker].g_iTankType].g_iAccessFlags, g_esUltimatePlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esUltimatePlayer[attacker].g_iTankType, g_esUltimateAbility[g_esUltimatePlayer[attacker].g_iTankType].g_iImmunityFlags, g_esUltimatePlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (g_esUltimateCache[attacker].g_iUltimateAbility == 1)
			{
				if (!g_esUltimatePlayer[attacker].g_bQualified)
				{
					g_esUltimatePlayer[attacker].g_flDamage += damage;

					if (bIsTank(attacker, MT_CHECK_FAKECLIENT))
					{
						MT_PrintToChat(attacker, "%s %t", MT_TAG3, "Ultimate3", g_esUltimatePlayer[attacker].g_flDamage, g_esUltimateCache[attacker].g_flUltimateDamageRequired);
					}

					if (g_esUltimatePlayer[attacker].g_flDamage >= g_esUltimateCache[attacker].g_flUltimateDamageRequired)
					{
						g_esUltimatePlayer[attacker].g_bQualified = true;

						if (bIsTank(attacker, MT_CHECK_FAKECLIENT))
						{
							MT_PrintToChat(attacker, "%s %t", MT_TAG3, "Ultimate4");
						}
					}
				}

				if (g_esUltimatePlayer[attacker].g_bActivated && (g_esUltimatePlayer[attacker].g_iCooldown == -1 || g_esUltimatePlayer[attacker].g_iCooldown < GetTime()))
				{
					damage *= g_esUltimateCache[attacker].g_flUltimateDamageBoost;
					damage = MT_GetScaledDamage(damage);

					return Plugin_Changed;
				}
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && bIsSurvivor(attacker) && !MT_IsAdminImmune(attacker, victim) && !bIsAdminImmune(attacker, g_esUltimatePlayer[victim].g_iTankType, g_esUltimateAbility[g_esUltimatePlayer[victim].g_iTankType].g_iImmunityFlags, g_esUltimatePlayer[attacker].g_iImmunityFlags) && g_esUltimatePlayer[victim].g_bActivated)
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

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vUltimatePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_ULTIMATE);
}

#if defined MT_ABILITIES_MAIN2
void vUltimateAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_ULTIMATE_SECTION);
	list2.PushString(MT_ULTIMATE_SECTION2);
	list3.PushString(MT_ULTIMATE_SECTION3);
	list4.PushString(MT_ULTIMATE_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vUltimateCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esUltimateCache[tank].g_iHumanAbility != 2)
	{
		g_esUltimateAbility[g_esUltimatePlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esUltimateAbility[g_esUltimatePlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_ULTIMATE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_ULTIMATE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_ULTIMATE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_ULTIMATE_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esUltimateCache[tank].g_iUltimateAbility == 1 && g_esUltimateCache[tank].g_iComboAbility == 1 && !g_esUltimatePlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_ULTIMATE_SECTION, false) || StrEqual(sSubset[iPos], MT_ULTIMATE_SECTION2, false) || StrEqual(sSubset[iPos], MT_ULTIMATE_SECTION3, false) || StrEqual(sSubset[iPos], MT_ULTIMATE_SECTION4, false))
				{
					g_esUltimateAbility[g_esUltimatePlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vUltimate(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerUltimateCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteCell(iPos);
							}
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vUltimateConfigsLoad(int mode)
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
				g_esUltimateAbility[iIndex].g_iAccessFlags = 0;
				g_esUltimateAbility[iIndex].g_iImmunityFlags = 0;
				g_esUltimateAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esUltimateAbility[iIndex].g_iComboAbility = 0;
				g_esUltimateAbility[iIndex].g_iComboPosition = -1;
				g_esUltimateAbility[iIndex].g_iHumanAbility = 0;
				g_esUltimateAbility[iIndex].g_iHumanAmmo = 5;
				g_esUltimateAbility[iIndex].g_iHumanCooldown = 0;
				g_esUltimateAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esUltimateAbility[iIndex].g_iRequiresHumans = 0;
				g_esUltimateAbility[iIndex].g_iUltimateAbility = 0;
				g_esUltimateAbility[iIndex].g_iUltimateMessage = 0;
				g_esUltimateAbility[iIndex].g_iUltimateAmount = 1;
				g_esUltimateAbility[iIndex].g_flUltimateChance = 33.3;
				g_esUltimateAbility[iIndex].g_iUltimateCooldown = 0;
				g_esUltimateAbility[iIndex].g_flUltimateDamageBoost = 1.2;
				g_esUltimateAbility[iIndex].g_flUltimateDamageRequired = 200.0;
				g_esUltimateAbility[iIndex].g_iUltimateDuration = 5;
				g_esUltimateAbility[iIndex].g_iUltimateHealthLimit = 100;
				g_esUltimateAbility[iIndex].g_flUltimateHealthPortion = 0.5;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esUltimatePlayer[iPlayer].g_iAccessFlags = 0;
					g_esUltimatePlayer[iPlayer].g_iImmunityFlags = 0;
					g_esUltimatePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esUltimatePlayer[iPlayer].g_iComboAbility = 0;
					g_esUltimatePlayer[iPlayer].g_iHumanAbility = 0;
					g_esUltimatePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esUltimatePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esUltimatePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esUltimatePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esUltimatePlayer[iPlayer].g_iUltimateAbility = 0;
					g_esUltimatePlayer[iPlayer].g_iUltimateMessage = 0;
					g_esUltimatePlayer[iPlayer].g_iUltimateAmount = 0;
					g_esUltimatePlayer[iPlayer].g_flUltimateChance = 0.0;
					g_esUltimatePlayer[iPlayer].g_iUltimateCooldown = 0;
					g_esUltimatePlayer[iPlayer].g_flUltimateDamageBoost = 0.0;
					g_esUltimatePlayer[iPlayer].g_flUltimateDamageRequired = 0.0;
					g_esUltimatePlayer[iPlayer].g_iUltimateDuration = 0;
					g_esUltimatePlayer[iPlayer].g_iUltimateHealthLimit = 0;
					g_esUltimatePlayer[iPlayer].g_flUltimateHealthPortion = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vUltimateConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esUltimatePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esUltimatePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esUltimatePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esUltimatePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esUltimatePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esUltimatePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esUltimatePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esUltimatePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esUltimatePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esUltimatePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esUltimatePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esUltimatePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esUltimatePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esUltimatePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esUltimatePlayer[admin].g_iUltimateAbility = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esUltimatePlayer[admin].g_iUltimateAbility, value, 0, 1);
		g_esUltimatePlayer[admin].g_iUltimateMessage = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esUltimatePlayer[admin].g_iUltimateMessage, value, 0, 1);
		g_esUltimatePlayer[admin].g_iUltimateAmount = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateAmount", "Ultimate Amount", "Ultimate_Amount", "amount", g_esUltimatePlayer[admin].g_iUltimateAmount, value, 1, 99999);
		g_esUltimatePlayer[admin].g_flUltimateChance = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateChance", "Ultimate Chance", "Ultimate_Chance", "chance", g_esUltimatePlayer[admin].g_flUltimateChance, value, 0.1, 100.0);
		g_esUltimatePlayer[admin].g_iUltimateCooldown = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateCooldown", "Ultimate Cooldown", "Ultimate_Cooldown", "cooldown", g_esUltimatePlayer[admin].g_iUltimateCooldown, value, 0, 99999);
		g_esUltimatePlayer[admin].g_flUltimateDamageBoost = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateDamageBoost", "Ultimate Damage Boost", "Ultimate_Damage_Boost", "dmgboost", g_esUltimatePlayer[admin].g_flUltimateDamageBoost, value, 0.1, 99999.0);
		g_esUltimatePlayer[admin].g_flUltimateDamageRequired = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateDamageRequired", "Ultimate Damage Required", "Ultimate_Damage_Required", "dmgrequired", g_esUltimatePlayer[admin].g_flUltimateDamageRequired, value, 0.1, 99999.0);
		g_esUltimatePlayer[admin].g_iUltimateDuration = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateDuration", "Ultimate Duration", "Ultimate_Duration", "duration", g_esUltimatePlayer[admin].g_iUltimateDuration, value, 1, 99999);
		g_esUltimatePlayer[admin].g_iUltimateHealthLimit = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateHealthLimit", "Ultimate Health Limit", "Ultimate_Health_Limit", "healthlimit", g_esUltimatePlayer[admin].g_iUltimateHealthLimit, value, 1, MT_MAXHEALTH);
		g_esUltimatePlayer[admin].g_flUltimateHealthPortion = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateHealthPortion", "Ultimate Health Portion", "Ultimate_Health_Portion", "healthportion", g_esUltimatePlayer[admin].g_flUltimateHealthPortion, value, 0.1, 1.0);
		g_esUltimatePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esUltimatePlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esUltimateAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esUltimateAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esUltimateAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esUltimateAbility[type].g_iComboAbility, value, 0, 1);
		g_esUltimateAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esUltimateAbility[type].g_iHumanAbility, value, 0, 2);
		g_esUltimateAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esUltimateAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esUltimateAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esUltimateAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esUltimateAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esUltimateAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esUltimateAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esUltimateAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esUltimateAbility[type].g_iUltimateAbility = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esUltimateAbility[type].g_iUltimateAbility, value, 0, 1);
		g_esUltimateAbility[type].g_iUltimateMessage = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esUltimateAbility[type].g_iUltimateMessage, value, 0, 1);
		g_esUltimateAbility[type].g_iUltimateAmount = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateAmount", "Ultimate Amount", "Ultimate_Amount", "amount", g_esUltimateAbility[type].g_iUltimateAmount, value, 1, 99999);
		g_esUltimateAbility[type].g_flUltimateChance = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateChance", "Ultimate Chance", "Ultimate_Chance", "chance", g_esUltimateAbility[type].g_flUltimateChance, value, 0.1, 100.0);
		g_esUltimateAbility[type].g_iUltimateCooldown = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateCooldown", "Ultimate Cooldown", "Ultimate_Cooldown", "cooldown", g_esUltimateAbility[type].g_iUltimateCooldown, value, 0, 99999);
		g_esUltimateAbility[type].g_flUltimateDamageBoost = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateDamageBoost", "Ultimate Damage Boost", "Ultimate_Damage_Boost", "dmgboost", g_esUltimateAbility[type].g_flUltimateDamageBoost, value, 0.1, 99999.0);
		g_esUltimateAbility[type].g_flUltimateDamageRequired = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateDamageRequired", "Ultimate Damage Required", "Ultimate_Damage_Required", "dmgrequired", g_esUltimateAbility[type].g_flUltimateDamageRequired, value, 0.1, 99999.0);
		g_esUltimateAbility[type].g_iUltimateDuration = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateDuration", "Ultimate Duration", "Ultimate_Duration", "duration", g_esUltimateAbility[type].g_iUltimateDuration, value, 1, 99999);
		g_esUltimateAbility[type].g_iUltimateHealthLimit = iGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateHealthLimit", "Ultimate Health Limit", "Ultimate_Health_Limit", "healthlimit", g_esUltimateAbility[type].g_iUltimateHealthLimit, value, 1, MT_MAXHEALTH);
		g_esUltimateAbility[type].g_flUltimateHealthPortion = flGetKeyValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "UltimateHealthPortion", "Ultimate Health Portion", "Ultimate_Health_Portion", "healthportion", g_esUltimateAbility[type].g_flUltimateHealthPortion, value, 0.1, 1.0);
		g_esUltimateAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esUltimateAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ULTIMATE_SECTION, MT_ULTIMATE_SECTION2, MT_ULTIMATE_SECTION3, MT_ULTIMATE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vUltimateSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esUltimateCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_flCloseAreasOnly, g_esUltimateAbility[type].g_flCloseAreasOnly);
	g_esUltimateCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iComboAbility, g_esUltimateAbility[type].g_iComboAbility);
	g_esUltimateCache[tank].g_flUltimateChance = flGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_flUltimateChance, g_esUltimateAbility[type].g_flUltimateChance);
	g_esUltimateCache[tank].g_flUltimateDamageBoost = flGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_flUltimateDamageBoost, g_esUltimateAbility[type].g_flUltimateDamageBoost);
	g_esUltimateCache[tank].g_flUltimateDamageRequired = flGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_flUltimateDamageRequired, g_esUltimateAbility[type].g_flUltimateDamageRequired);
	g_esUltimateCache[tank].g_flUltimateHealthPortion = flGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_flUltimateHealthPortion, g_esUltimateAbility[type].g_flUltimateHealthPortion);
	g_esUltimateCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iHumanAbility, g_esUltimateAbility[type].g_iHumanAbility);
	g_esUltimateCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iHumanAmmo, g_esUltimateAbility[type].g_iHumanAmmo);
	g_esUltimateCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iHumanCooldown, g_esUltimateAbility[type].g_iHumanCooldown);
	g_esUltimateCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_flOpenAreasOnly, g_esUltimateAbility[type].g_flOpenAreasOnly);
	g_esUltimateCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iRequiresHumans, g_esUltimateAbility[type].g_iRequiresHumans);
	g_esUltimateCache[tank].g_iUltimateAbility = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iUltimateAbility, g_esUltimateAbility[type].g_iUltimateAbility);
	g_esUltimateCache[tank].g_iUltimateAmount = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iUltimateAmount, g_esUltimateAbility[type].g_iUltimateAmount);
	g_esUltimateCache[tank].g_iUltimateCooldown = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iUltimateCooldown, g_esUltimateAbility[type].g_iUltimateCooldown);
	g_esUltimateCache[tank].g_iUltimateDuration = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iUltimateDuration, g_esUltimateAbility[type].g_iUltimateDuration);
	g_esUltimateCache[tank].g_iUltimateHealthLimit = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iUltimateHealthLimit, g_esUltimateAbility[type].g_iUltimateHealthLimit);
	g_esUltimateCache[tank].g_iUltimateMessage = iGetSettingValue(apply, bHuman, g_esUltimatePlayer[tank].g_iUltimateMessage, g_esUltimateAbility[type].g_iUltimateMessage);
	g_esUltimatePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vUltimateCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vUltimateCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveUltimate(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vUltimatePluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esUltimatePlayer[iTank].g_bActivated)
		{
			SetEntProp(iTank, Prop_Data, "m_takedamage", 2, 1);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vUltimateEventFired(Event event, const char[] name)
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
			vUltimateCopyStats2(iBot, iTank);
			vRemoveUltimate(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vUltimateCopyStats2(iTank, iBot);
			vRemoveUltimate(iTank);
		}
	}
	else if (StrEqual(name, "player_incapacitated") || StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveUltimate(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vUltimateReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vUltimateAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esUltimateAbility[g_esUltimatePlayer[tank].g_iTankType].g_iAccessFlags, g_esUltimatePlayer[tank].g_iAccessFlags)) || g_esUltimateCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esUltimateCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esUltimateCache[tank].g_iUltimateAbility == 1 && g_esUltimateCache[tank].g_iComboAbility == 0 && g_esUltimatePlayer[tank].g_bQualified && !g_esUltimatePlayer[tank].g_bActivated)
	{
		vUltimateAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vUltimateButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esUltimateCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esUltimateCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esUltimatePlayer[tank].g_iTankType) || (g_esUltimateCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esUltimateCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esUltimateAbility[g_esUltimatePlayer[tank].g_iTankType].g_iAccessFlags, g_esUltimatePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esUltimateCache[tank].g_iUltimateAbility == 1 && g_esUltimateCache[tank].g_iHumanAbility == 1)
		{
			if (!g_esUltimatePlayer[tank].g_bQualified)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "UltimateHuman2");

				return;
			}

			int iTime = GetTime();
			bool bRecharging = g_esUltimatePlayer[tank].g_iCooldown != -1 && g_esUltimatePlayer[tank].g_iCooldown > iTime;
			if (!g_esUltimatePlayer[tank].g_bActivated && !bRecharging)
			{
				vUltimateAbility(tank);
			}
			else if (g_esUltimatePlayer[tank].g_bActivated)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "UltimateHuman3");
			}
			else if (bRecharging)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "UltimateHuman4", (g_esUltimatePlayer[tank].g_iCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vUltimateChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveUltimate(tank);
}

void vUltimate(int tank, int pos = -1)
{
	int iTime = GetTime();
	if (g_esUltimatePlayer[tank].g_iCooldown != -1 && g_esUltimatePlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	int iTankHealth = GetEntProp(tank, Prop_Data, "m_iHealth");
	if (iTankHealth <= g_esUltimateCache[tank].g_iUltimateHealthLimit && !bIsPlayerIncapacitated(tank) && g_esUltimatePlayer[tank].g_bQualified && g_esUltimatePlayer[tank].g_iCount < g_esUltimateCache[tank].g_iUltimateAmount)
	{
		int iDuration = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 5, pos)) : g_esUltimateCache[tank].g_iUltimateDuration;
		g_esUltimatePlayer[tank].g_bActivated = true;
		g_esUltimatePlayer[tank].g_iCount++;
		g_esUltimatePlayer[tank].g_flDamage = 0.0;
		g_esUltimatePlayer[tank].g_iDuration = (iTime + iDuration);

		ExtinguishEntity(tank);
		vAttachParticle(tank, PARTICLE_ULTIMATE, 2.0, 30.0);
		EmitSoundToAll(SOUND_ULTIMATE, tank);
		EmitSoundToAll(SOUND_EXPLOSION, tank);

		switch (g_bSecondGame)
		{
			case true:
			{
				EmitSoundToAll(SOUND_GROWL2, tank);
				EmitSoundToAll(SOUND_SMASH2, tank);
			}
			case false:
			{
				EmitSoundToAll(SOUND_GROWL1, tank);
				EmitSoundToAll(SOUND_SMASH1, tank);
			}
		}

		int iValue = RoundToNearest(MT_TankMaxHealth(tank, 2) * g_esUltimateCache[tank].g_flUltimateHealthPortion),
			iMaxHealth = MT_TankMaxHealth(tank, 1),
			iNewHealth = (iTankHealth + iValue),
			iLeftover = (iNewHealth > MT_MAXHEALTH) ? (iNewHealth - MT_MAXHEALTH) : iNewHealth,
			iFinalHealth = (iNewHealth > MT_MAXHEALTH) ? MT_MAXHEALTH : iNewHealth,
			iTotalHealth = (iNewHealth > MT_MAXHEALTH) ? iLeftover : iValue;
		MT_TankMaxHealth(tank, 3, (iMaxHealth + iTotalHealth));
		SetEntProp(tank, Prop_Data, "m_iHealth", iFinalHealth);
		SetEntProp(tank, Prop_Data, "m_takedamage", 0, 1);

		if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esUltimateCache[tank].g_iHumanAbility == 1)
		{
			g_esUltimatePlayer[tank].g_iAmmoCount++;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "UltimateHuman", g_esUltimatePlayer[tank].g_iAmmoCount, g_esUltimateCache[tank].g_iHumanAmmo);
		}

		if (g_esUltimateCache[tank].g_iUltimateMessage == 1)
		{
			char sTankName[33];
			MT_GetTankName(tank, sTankName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Ultimate", sTankName);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Ultimate", LANG_SERVER, sTankName);
		}
	}
}

void vUltimateAbility(int tank)
{
	if ((g_esUltimatePlayer[tank].g_iCooldown != -1 && g_esUltimatePlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esUltimateCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esUltimateCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esUltimatePlayer[tank].g_iTankType) || (g_esUltimateCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esUltimateCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esUltimateAbility[g_esUltimatePlayer[tank].g_iTankType].g_iAccessFlags, g_esUltimatePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (GetEntProp(tank, Prop_Data, "m_iHealth") <= g_esUltimateCache[tank].g_iUltimateHealthLimit && MT_GetRandomFloat(0.1, 100.0) <= g_esUltimateCache[tank].g_flUltimateChance)
	{
		if (g_esUltimatePlayer[tank].g_iCount < g_esUltimateCache[tank].g_iUltimateAmount && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esUltimatePlayer[tank].g_iAmmoCount < g_esUltimateCache[tank].g_iHumanAmmo && g_esUltimateCache[tank].g_iHumanAmmo > 0)))
		{
			vUltimate(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esUltimateCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "UltimateAmmo");
		}
	}
}

void vUltimateCopyStats2(int oldTank, int newTank)
{
	g_esUltimatePlayer[newTank].g_bActivated = g_esUltimatePlayer[oldTank].g_bActivated;
	g_esUltimatePlayer[newTank].g_bQualified = g_esUltimatePlayer[oldTank].g_bQualified;
	g_esUltimatePlayer[newTank].g_flDamage = g_esUltimatePlayer[oldTank].g_flDamage;
	g_esUltimatePlayer[newTank].g_iAmmoCount = g_esUltimatePlayer[oldTank].g_iAmmoCount;
	g_esUltimatePlayer[newTank].g_iCooldown = g_esUltimatePlayer[oldTank].g_iCooldown;
	g_esUltimatePlayer[newTank].g_iCount = g_esUltimatePlayer[oldTank].g_iCount;
	g_esUltimatePlayer[newTank].g_iDuration = g_esUltimatePlayer[oldTank].g_iDuration;
}

void vRemoveUltimate(int tank)
{
	g_esUltimatePlayer[tank].g_bActivated = false;
	g_esUltimatePlayer[tank].g_bQualified = false;
	g_esUltimatePlayer[tank].g_flDamage = 0.0;
	g_esUltimatePlayer[tank].g_iAmmoCount = 0;
	g_esUltimatePlayer[tank].g_iCooldown = -1;
	g_esUltimatePlayer[tank].g_iCount = 0;
	g_esUltimatePlayer[tank].g_iDuration = -1;

	if (MT_IsTankSupported(tank))
	{
		SetEntProp(tank, Prop_Data, "m_takedamage", 2, 1);
	}
}

void vUltimateReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveUltimate(iPlayer);
		}
	}
}

Action tTimerUltimateCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esUltimateAbility[g_esUltimatePlayer[iTank].g_iTankType].g_iAccessFlags, g_esUltimatePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esUltimatePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esUltimateCache[iTank].g_iUltimateAbility == 0 || g_esUltimatePlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vUltimate(iTank, iPos);

	return Plugin_Continue;
}