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

#define MT_SHIELD_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_SHIELD_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Shield Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank protects itself with a shield and throws propane tanks or gas cans.",
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
			strcopy(error, err_max, "\"[MT] Shield Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_SHIELD_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MODEL_GASCAN "models/props_junk/gascan001a.mdl"
#define MODEL_PROPANETANK "models/props_junk/propanecanister001a.mdl"
#define MODEL_SHIELD "models/props_unique/airport/atlas_break_ball.mdl"

#define SOUND_METAL "physics/metal/metal_solid_impact_hard5.wav"

#define MT_SHIELD_SECTION "shieldability"
#define MT_SHIELD_SECTION2 "shield ability"
#define MT_SHIELD_SECTION3 "shield_ability"
#define MT_SHIELD_SECTION4 "shield"

#define MT_SHIELD_BULLET (1 << 0) // requires bullet damage
#define MT_SHIELD_EXPLOSIVE (1 << 1) // requires explosive damage
#define MT_SHIELD_FIRE (1 << 2) // requires fire damage
#define MT_SHIELD_MELEE (1 << 3) // requires melee damage

#define MT_MENU_SHIELD "Shield Ability"

enum struct esShieldPlayer
{
	bool g_bActivated;
	bool g_bRainbowColor;

	char g_sShieldColor[16];
	char g_sShieldHealthChars[4];

	float g_flHealth;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flShieldChance;
	float g_flShieldHealth;
	float g_flShieldThrowChance;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iCooldown2;
	int g_iDuration;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iShield;
	int g_iShieldAbility;
	int g_iShieldColor[4];
	int g_iShieldCooldown;
	int g_iShieldDelay;
	int g_iShieldDisplayHP;
	int g_iShieldDisplayHPType;
	int g_iShieldDuration;
	int g_iShieldGlow;
	int g_iShieldMessage;
	int g_iShieldType;
	int g_iTankType;
}

esShieldPlayer g_esShieldPlayer[MAXPLAYERS + 1];

enum struct esShieldAbility
{
	char g_sShieldColor[16];
	char g_sShieldHealthChars[4];

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flShieldChance;
	float g_flShieldHealth;
	float g_flShieldThrowChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iShieldAbility;
	int g_iShieldColor[4];
	int g_iShieldCooldown;
	int g_iShieldDelay;
	int g_iShieldDisplayHP;
	int g_iShieldDisplayHPType;
	int g_iShieldDuration;
	int g_iShieldGlow;
	int g_iShieldMessage;
	int g_iShieldType;
}

esShieldAbility g_esShieldAbility[MT_MAXTYPES + 1];

enum struct esShieldCache
{
	char g_sShieldColor[16];
	char g_sShieldHealthChars[4];

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flShieldChance;
	float g_flShieldHealth;
	float g_flShieldThrowChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
	int g_iShieldAbility;
	int g_iShieldColor[4];
	int g_iShieldCooldown;
	int g_iShieldDelay;
	int g_iShieldDisplayHP;
	int g_iShieldDisplayHPType;
	int g_iShieldDuration;
	int g_iShieldGlow;
	int g_iShieldMessage;
	int g_iShieldType;
}

esShieldCache g_esShieldCache[MAXPLAYERS + 1];

ConVar g_cvMTShieldTankThrowForce;

#if defined MT_ABILITIES_MAIN2
void vShieldPluginStart()
#else
public void OnPluginStart()
#endif
{
	g_cvMTShieldTankThrowForce = FindConVar("z_tank_throw_force");
#if !defined MT_ABILITIES_MAIN2
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_shield", cmdShieldInfo, "View information about the Shield ability.");

	if (g_bLateLoad)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
			{
				OnClientPutInServer(iPlayer);
			}
		}

		int iInfected = -1;
		while ((iInfected = FindEntityByClassname(iInfected, "infected")) != INVALID_ENT_REFERENCE)
		{
			SDKHook(iInfected, SDKHook_OnTakeDamage, OnShieldTakeDamage);
		}

		iInfected = -1;
		while ((iInfected = FindEntityByClassname(iInfected, "witch")) != INVALID_ENT_REFERENCE)
		{
			SDKHook(iInfected, SDKHook_OnTakeDamage, OnShieldTakeDamage);
		}

		g_bLateLoad = false;
	}
#endif
}

#if defined MT_ABILITIES_MAIN2
void vShieldLateLoad()
{
	int iInfected = -1;
	while ((iInfected = FindEntityByClassname(iInfected, "infected")) != INVALID_ENT_REFERENCE)
	{
		SDKHook(iInfected, SDKHook_OnTakeDamage, OnShieldTakeDamage);
	}

	iInfected = -1;
	while ((iInfected = FindEntityByClassname(iInfected, "witch")) != INVALID_ENT_REFERENCE)
	{
		SDKHook(iInfected, SDKHook_OnTakeDamage, OnShieldTakeDamage);
	}
}

void vShieldMapStart()
#else
public void OnMapStart()
#endif
{
	PrecacheModel(MODEL_SHIELD, true);

	vShieldReset();
}

#if defined MT_ABILITIES_MAIN2
void vShieldClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnShieldTakeDamage);
	vShieldReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vShieldClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vShieldReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vShieldMapEnd()
#else
public void OnMapEnd()
#endif
{
	vShieldReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdShieldInfo(int client, int args)
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
		case false: vShieldMenu(client, MT_SHIELD_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vShieldMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_SHIELD_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iShieldMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Shield Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Button Mode", "Button Mode");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iShieldMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esShieldCache[param1].g_iShieldAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esShieldCache[param1].g_iHumanAmmo - g_esShieldPlayer[param1].g_iAmmoCount), g_esShieldCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esShieldCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esShieldCache[param1].g_iHumanAbility == 1) ? g_esShieldCache[param1].g_iHumanCooldown : g_esShieldCache[param1].g_iShieldCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "ShieldDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esShieldCache[param1].g_iHumanAbility == 1) ? g_esShieldCache[param1].g_iHumanDuration : g_esShieldCache[param1].g_iShieldDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esShieldCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vShieldMenu(param1, MT_SHIELD_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pShield = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "ShieldMenu", param1);
			pShield.SetTitle(sMenuTitle);
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
					case 3: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "ButtonMode", param1);
					case 4: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Cooldown", param1);
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Duration", param1);
					case 7: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN2
void vShieldDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_SHIELD, MT_MENU_SHIELD);
}

#if defined MT_ABILITIES_MAIN2
void vShieldMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_SHIELD, false))
	{
		vShieldMenu(client, MT_SHIELD_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_SHIELD, false))
	{
		FormatEx(buffer, size, "%T", "ShieldMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldEntityCreated(int entity, const char[] classname)
#else
public void OnEntityCreated(int entity, const char[] classname)
#endif
{
	if (bIsValidEntity(entity) && (StrEqual(classname, "infected") || StrEqual(classname, "witch")))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnInfectedSpawnPost);
	}
}

public void OnGameFrame()
{
	if (MT_IsCorePluginEnabled())
	{
		char sClassname[32], sHealthBar[51], sSet[2][2], sTankName[33];
		float flPercentage = 0.0;
		int iTarget = 0;
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT))
			{
				iTarget = GetClientAimTarget(iPlayer);
				if (bIsTank(iTarget))
				{
					GetEntityClassname(iTarget, sClassname, sizeof sClassname);
					if (StrEqual(sClassname, "player") && g_esShieldPlayer[iTarget].g_bActivated && g_esShieldPlayer[iTarget].g_flHealth > 0.0 && g_esShieldCache[iTarget].g_flShieldHealth > 0.0)
					{
						MT_GetTankName(iTarget, sTankName);

						sHealthBar[0] = '\0';
						flPercentage = ((g_esShieldPlayer[iTarget].g_flHealth / g_esShieldCache[iTarget].g_flShieldHealth) * 100.0);

						ReplaceString(g_esShieldCache[iTarget].g_sShieldHealthChars, sizeof esShieldCache::g_sShieldHealthChars, " ", "");
						ExplodeString(g_esShieldCache[iTarget].g_sShieldHealthChars, ",", sSet, sizeof sSet, sizeof sSet[]);

						for (int iCount = 0; iCount < ((g_esShieldPlayer[iTarget].g_flHealth / g_esShieldCache[iTarget].g_flShieldHealth) * (sizeof sHealthBar - 1)) && iCount < (sizeof sHealthBar - 1); iCount++)
						{
							StrCat(sHealthBar, sizeof sHealthBar, sSet[0]);
						}

						for (int iCount = 0; iCount < (sizeof sHealthBar - 1); iCount++)
						{
							StrCat(sHealthBar, sizeof sHealthBar, sSet[1]);
						}

						switch (g_esShieldCache[iTarget].g_iShieldDisplayHPType)
						{
							case 1:
							{
								switch (g_esShieldCache[iTarget].g_iShieldDisplayHP)
								{
									case 1: PrintHintText(iPlayer, "%t", "ShieldOwner", sTankName);
									case 2: PrintHintText(iPlayer, "Shield: %.0f HP", g_esShieldPlayer[iTarget].g_flHealth);
									case 3: PrintHintText(iPlayer, "Shield: %.0f/%.0f HP (%.0f%s)", g_esShieldPlayer[iTarget].g_flHealth, g_esShieldCache[iTarget].g_flShieldHealth, flPercentage, "%%");
									case 4: PrintHintText(iPlayer, "Shield\nHP: |-<%s>-|", sHealthBar);
									case 5: PrintHintText(iPlayer, "%t (%.0f HP)", "ShieldOwner", sTankName, g_esShieldPlayer[iTarget].g_flHealth);
									case 6: PrintHintText(iPlayer, "%t [%.0f/%.0f HP (%.0f%s)]", "ShieldOwner", sTankName, g_esShieldPlayer[iTarget].g_flHealth, g_esShieldCache[iTarget].g_flShieldHealth, flPercentage, "%%");
									case 7: PrintHintText(iPlayer, "%t\nHP: |-<%s>-|", "ShieldOwner", sTankName, sHealthBar);
									case 8: PrintHintText(iPlayer, "Shield: %.0f HP\nHP: |-<%s>-|", g_esShieldPlayer[iTarget].g_flHealth, sHealthBar);
									case 9: PrintHintText(iPlayer, "Shield: %.0f/%.0f HP (%.0f%s)\nHP: |-<%s>-|", g_esShieldPlayer[iTarget].g_flHealth, g_esShieldCache[iTarget].g_flShieldHealth, flPercentage, "%%", sHealthBar);
									case 10: PrintHintText(iPlayer, "%t (%.0f HP)\nHP: |-<%s>-|", "ShieldOwner", sTankName, g_esShieldPlayer[iTarget].g_flHealth, sHealthBar);
									case 11: PrintHintText(iPlayer, "%t [%.0f/%.0f HP (%.0f%s)]\nHP: |-<%s>-|", "ShieldOwner", sTankName, g_esShieldPlayer[iTarget].g_flHealth, g_esShieldCache[iTarget].g_flShieldHealth, flPercentage, "%%", sHealthBar);
								}
							}
							case 2:
							{
								switch (g_esShieldCache[iTarget].g_iShieldDisplayHP)
								{
									case 1: PrintCenterText(iPlayer, "%t", "ShieldOwner", sTankName);
									case 2: PrintCenterText(iPlayer, "Shield: %.0f HP", g_esShieldPlayer[iTarget].g_flHealth);
									case 3: PrintCenterText(iPlayer, "Shield: %.0f/%.0f HP (%.0f%s)", g_esShieldPlayer[iTarget].g_flHealth, g_esShieldCache[iTarget].g_flShieldHealth, flPercentage, "%%");
									case 4: PrintCenterText(iPlayer, "Shield\nHP: |-<%s>-|", sHealthBar);
									case 5: PrintCenterText(iPlayer, "%t (%.0f HP)", "ShieldOwner", sTankName, g_esShieldPlayer[iTarget].g_flHealth);
									case 6: PrintCenterText(iPlayer, "%t [%.0f/%.0f HP (%.0f%s)]", "ShieldOwner", sTankName, g_esShieldPlayer[iTarget].g_flHealth, g_esShieldCache[iTarget].g_flShieldHealth, flPercentage, "%%");
									case 7: PrintCenterText(iPlayer, "%t\nHP: |-<%s>-|", "ShieldOwner", sTankName, sHealthBar);
									case 8: PrintCenterText(iPlayer, "Shield: %.0f HP\nHP: |-<%s>-|", g_esShieldPlayer[iTarget].g_flHealth, sHealthBar);
									case 9: PrintCenterText(iPlayer, "Shield: %.0f/%.0f HP (%.0f%s)\nHP: |-<%s>-|", g_esShieldPlayer[iTarget].g_flHealth, g_esShieldCache[iTarget].g_flShieldHealth, flPercentage, "%%", sHealthBar);
									case 10: PrintCenterText(iPlayer, "%t (%.0f HP)\nHP: |-<%s>-|", "ShieldOwner", sTankName, g_esShieldPlayer[iTarget].g_flHealth, sHealthBar);
									case 11: PrintCenterText(iPlayer, "%t [%.0f/%.0f HP (%.0f%s)]\nHP: |-<%s>-|", "ShieldOwner", sTankName, g_esShieldPlayer[iTarget].g_flHealth, g_esShieldCache[iTarget].g_flShieldHealth, flPercentage, "%%", sHealthBar);
								}
							}
						}
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldPlayerRunCmd(int client)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsTankSupported(client) || (bIsTank(client, MT_CHECK_FAKECLIENT) && g_esShieldCache[client].g_iHumanMode == 1) || (g_esShieldPlayer[client].g_iDuration == -1 && g_esShieldPlayer[client].g_iCooldown2 == -1))
	{
#if defined MT_ABILITIES_MAIN2
		return;
#else
		return Plugin_Continue;
#endif
	}

	int iTime = GetTime();
	if (g_esShieldPlayer[client].g_bActivated && g_esShieldPlayer[client].g_iDuration != -1 && g_esShieldPlayer[client].g_iDuration < iTime)
	{
		if (g_esShieldPlayer[client].g_iCooldown == -1 || g_esShieldPlayer[client].g_iCooldown < iTime)
		{
			vShieldReset3(client);
		}

		vShieldAbility(client, false);
	}
	else if (g_esShieldPlayer[client].g_iCooldown2 != -1 && g_esShieldPlayer[client].g_iCooldown2 < iTime)
	{
		vShieldAbility(client, true);
	}
#if !defined MT_ABILITIES_MAIN2
	return Plugin_Continue;
#endif
}

void OnInfectedSpawnPost(int entity)
{
	if (bIsValidEntity(entity))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnShieldTakeDamage);
	}
}

Action OnShieldTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && g_esShieldPlayer[victim].g_bActivated && damage > 0.0)
	{
		bool bCommon = bIsCommonInfected(attacker), bSpecial = bIsSpecialInfected(attacker), bSurvivor = bIsSurvivor(attacker),
			bRewarded = bSurvivor && MT_DoesSurvivorHaveRewardType(attacker, MT_REWARD_DAMAGEBOOST);
		if ((damagetype & DMG_FALL) || ((damagetype & DMG_DROWN) && GetEntProp(victim, Prop_Send, "m_nWaterLevel") > 0) || (!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esShieldAbility[g_esShieldPlayer[victim].g_iTankType].g_iAccessFlags, g_esShieldPlayer[victim].g_iAccessFlags)) || (bSurvivor && (MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esShieldPlayer[victim].g_iTankType, g_esShieldAbility[g_esShieldPlayer[victim].g_iTankType].g_iImmunityFlags, g_esShieldPlayer[attacker].g_iImmunityFlags))))
		{
			vShieldAbility(victim, false);

			return Plugin_Continue;
		}

		if (bSurvivor || bSpecial || bCommon)
		{
			bool bBulletDamage = (damagetype & DMG_BULLET) && (g_esShieldCache[victim].g_iShieldType & MT_SHIELD_BULLET),
				bExplosiveDamage = ((damagetype & DMG_BLAST) || (damagetype & DMG_BLAST_SURFACE) || (damagetype & DMG_AIRBOAT) || (damagetype & DMG_PLASMA)) && (g_esShieldCache[victim].g_iShieldType & MT_SHIELD_EXPLOSIVE),
				bFireDamage = ((damagetype & DMG_BURN) || (damagetype & DMG_DIRECT)) && (g_esShieldCache[victim].g_iShieldType & MT_SHIELD_FIRE),
				bMeleeDamage = ((damagetype & DMG_SLASH) || (damagetype & DMG_CLUB)) && (g_esShieldCache[victim].g_iShieldType & MT_SHIELD_MELEE);
			if (bRewarded || bSpecial || bCommon || bBulletDamage || bExplosiveDamage || bFireDamage || bMeleeDamage)
			{
				g_esShieldPlayer[victim].g_flHealth -= damage;
				if (g_esShieldCache[victim].g_flShieldHealth == 0.0 || g_esShieldPlayer[victim].g_flHealth < 1.0)
				{
					vShieldAbility(victim, false);
				}
			}
		}

		EmitSoundToAll(SOUND_METAL, victim);

		if ((damagetype & DMG_BURN) || (damagetype & DMG_DIRECT))
		{
			ExtinguishEntity(victim);
		}

		if (((damagetype & DMG_SLASH) || (damagetype & DMG_CLUB)) && !(g_esShieldCache[victim].g_iShieldType & MT_SHIELD_MELEE))
		{
			if (bRewarded)
			{
				return Plugin_Handled;
			}

			float flTankPos[3];
			GetClientAbsOrigin(victim, flTankPos);

			switch (bSurvivor && MT_DoesSurvivorHaveRewardType(attacker, MT_REWARD_GODMODE))
			{
				case true: vPushNearbyEntities(victim, flTankPos, 300.0, 100.0);
				case false: vPushNearbyEntities(victim, flTankPos);
			}
		}

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vShieldPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_SHIELD);
}

#if defined MT_ABILITIES_MAIN2
void vShieldAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_SHIELD_SECTION);
	list2.PushString(MT_SHIELD_SECTION2);
	list3.PushString(MT_SHIELD_SECTION3);
	list4.PushString(MT_SHIELD_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vShieldCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShieldCache[tank].g_iHumanAbility != 2)
	{
		g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_SHIELD_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_SHIELD_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_SHIELD_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_SHIELD_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esShieldCache[tank].g_iShieldAbility == 1 && g_esShieldCache[tank].g_iComboAbility == 1 && !g_esShieldPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_SHIELD_SECTION, false) || StrEqual(sSubset[iPos], MT_SHIELD_SECTION2, false) || StrEqual(sSubset[iPos], MT_SHIELD_SECTION3, false) || StrEqual(sSubset[iPos], MT_SHIELD_SECTION4, false))
				{
					g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vShieldAbility(tank, true);
							default: CreateTimer(flDelay, tTimerShieldCombo, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldConfigsLoad(int mode)
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
				g_esShieldAbility[iIndex].g_sShieldColor = "255,255,255,255";
				g_esShieldAbility[iIndex].g_iAccessFlags = 0;
				g_esShieldAbility[iIndex].g_iImmunityFlags = 0;
				g_esShieldAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esShieldAbility[iIndex].g_iComboAbility = 0;
				g_esShieldAbility[iIndex].g_iComboPosition = -1;
				g_esShieldAbility[iIndex].g_iHumanAbility = 0;
				g_esShieldAbility[iIndex].g_iHumanAmmo = 5;
				g_esShieldAbility[iIndex].g_iHumanCooldown = 0;
				g_esShieldAbility[iIndex].g_iHumanDuration = 5;
				g_esShieldAbility[iIndex].g_iHumanMode = 1;
				g_esShieldAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esShieldAbility[iIndex].g_iRequiresHumans = 1;
				g_esShieldAbility[iIndex].g_iShieldAbility = 0;
				g_esShieldAbility[iIndex].g_iShieldMessage = 0;
				g_esShieldAbility[iIndex].g_flShieldChance = 33.3;
				g_esShieldAbility[iIndex].g_iShieldCooldown = 0;
				g_esShieldAbility[iIndex].g_iShieldDelay = 5;
				g_esShieldAbility[iIndex].g_iShieldDisplayHP = 11;
				g_esShieldAbility[iIndex].g_iShieldDisplayHPType = 2;
				g_esShieldAbility[iIndex].g_iShieldDuration = 0;
				g_esShieldAbility[iIndex].g_iShieldGlow = 1;
				g_esShieldAbility[iIndex].g_flShieldHealth = 0.0;
				g_esShieldAbility[iIndex].g_sShieldHealthChars = "],=";
				g_esShieldAbility[iIndex].g_flShieldThrowChance = 100.0;
				g_esShieldAbility[iIndex].g_iShieldType = 2;

				for (int iPos = 0; iPos < (sizeof esShieldAbility::g_iShieldColor); iPos++)
				{
					g_esShieldAbility[iIndex].g_iShieldColor[iPos] = 255;
				}
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esShieldPlayer[iPlayer].g_sShieldColor[0] = '\0';
					g_esShieldPlayer[iPlayer].g_iAccessFlags = 0;
					g_esShieldPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esShieldPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esShieldPlayer[iPlayer].g_iComboAbility = 0;
					g_esShieldPlayer[iPlayer].g_iHumanAbility = 0;
					g_esShieldPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esShieldPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esShieldPlayer[iPlayer].g_iHumanDuration = 0;
					g_esShieldPlayer[iPlayer].g_iHumanMode = 0;
					g_esShieldPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esShieldPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esShieldPlayer[iPlayer].g_iShieldAbility = 0;
					g_esShieldPlayer[iPlayer].g_iShieldMessage = 0;
					g_esShieldPlayer[iPlayer].g_flShieldChance = 0.0;
					g_esShieldPlayer[iPlayer].g_iShieldCooldown = 0;
					g_esShieldPlayer[iPlayer].g_iShieldDelay = 0;
					g_esShieldPlayer[iPlayer].g_iShieldDisplayHP = 0;
					g_esShieldPlayer[iPlayer].g_iShieldDisplayHPType = 0;
					g_esShieldPlayer[iPlayer].g_iShieldDuration = 0;
					g_esShieldPlayer[iPlayer].g_iShieldGlow = 0;
					g_esShieldPlayer[iPlayer].g_flShieldHealth = 0.0;
					g_esShieldPlayer[iPlayer].g_sShieldHealthChars[0] = '\0';
					g_esShieldPlayer[iPlayer].g_flShieldThrowChance = 0.0;
					g_esShieldPlayer[iPlayer].g_iShieldType = 0;

					for (int iPos = 0; iPos < (sizeof esShieldPlayer::g_iShieldColor); iPos++)
					{
						g_esShieldPlayer[iPlayer].g_iShieldColor[iPos] = -1;
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esShieldPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esShieldPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esShieldPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esShieldPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esShieldPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esShieldPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esShieldPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esShieldPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esShieldPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esShieldPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esShieldPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esShieldPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esShieldPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esShieldPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esShieldPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esShieldPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esShieldPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esShieldPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esShieldPlayer[admin].g_iShieldAbility = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esShieldPlayer[admin].g_iShieldAbility, value, 0, 1);
		g_esShieldPlayer[admin].g_iShieldMessage = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esShieldPlayer[admin].g_iShieldMessage, value, 0, 1);
		g_esShieldPlayer[admin].g_flShieldChance = flGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldChance", "Shield Chance", "Shield_Chance", "chance", g_esShieldPlayer[admin].g_flShieldChance, value, 0.0, 100.0);
		g_esShieldPlayer[admin].g_iShieldCooldown = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldCooldown", "Shield Cooldown", "Shield_Cooldown", "cooldown", g_esShieldPlayer[admin].g_iShieldCooldown, value, 0, 99999);
		g_esShieldPlayer[admin].g_iShieldDelay = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldDelay", "Shield Delay", "Shield_Delay", "delay", g_esShieldPlayer[admin].g_iShieldDelay, value, 1, 99999);
		g_esShieldPlayer[admin].g_iShieldDisplayHP = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldDisplayHealth", "Shield Display Health", "Shield_Display_Health", "displayhp", g_esShieldPlayer[admin].g_iShieldDisplayHP, value, 0, 11);
		g_esShieldPlayer[admin].g_iShieldDisplayHPType = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldDisplayHealthType", "Shield Display Health Type", "Shield_Display_Health_Type", "displaytype", g_esShieldPlayer[admin].g_iShieldDisplayHPType, value, 0, 2);
		g_esShieldPlayer[admin].g_iShieldDuration = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldDuration", "Shield Duration", "Shield_Duration", "duration", g_esShieldPlayer[admin].g_iShieldDuration, value, 0, 99999);
		g_esShieldPlayer[admin].g_iShieldGlow = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldGlow", "Shield Glow", "Shield_Glow", "glow", g_esShieldPlayer[admin].g_iShieldGlow, value, 0, 1);
		g_esShieldPlayer[admin].g_flShieldHealth = flGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldHealth", "Shield Health", "Shield_Health", "health", g_esShieldPlayer[admin].g_flShieldHealth, value, 0.0, 99999.0);
		g_esShieldPlayer[admin].g_flShieldThrowChance = flGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldThrowChance", "Shield Throw Chance", "Shield_Throw_Chance", "throwchance", g_esShieldPlayer[admin].g_flShieldThrowChance, value, 0.0, 100.0);
		g_esShieldPlayer[admin].g_iShieldType = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldType", "Shield Type", "Shield_Type", "type", g_esShieldPlayer[admin].g_iShieldType, value, 0, 15);
		g_esShieldPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esShieldPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

		vGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldHealthCharacters", "Shield Health Characters", "Shield_Characters", "hpchars", g_esShieldPlayer[admin].g_sShieldHealthChars, sizeof esShieldPlayer::g_sShieldHealthChars, value);

		if (StrEqual(subsection, MT_SHIELD_SECTION, false) || StrEqual(subsection, MT_SHIELD_SECTION2, false) || StrEqual(subsection, MT_SHIELD_SECTION3, false) || StrEqual(subsection, MT_SHIELD_SECTION4, false))
		{
			if (StrEqual(key, "ShieldColor", false) || StrEqual(key, "Shield Color", false) || StrEqual(key, "Shield_Color", false) || StrEqual(key, "color", false))
			{
				char sSet[4][4], sValue[16];
				MT_GetConfigColors(sValue, sizeof sValue, value);
				strcopy(g_esShieldPlayer[admin].g_sShieldColor, sizeof esShieldPlayer::g_sShieldColor, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof sSet); iPos++)
				{
					g_esShieldPlayer[admin].g_iShieldColor[iPos] = (sSet[iPos][0] != '\0' && StringToInt(sSet[iPos]) >= 0) ? iClamp(StringToInt(sSet[iPos]), 0, 255) : -1;
				}
			}
		}
	}

	if (mode < 3 && type > 0)
	{
		g_esShieldAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esShieldAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esShieldAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esShieldAbility[type].g_iComboAbility, value, 0, 1);
		g_esShieldAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esShieldAbility[type].g_iHumanAbility, value, 0, 2);
		g_esShieldAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esShieldAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esShieldAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esShieldAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esShieldAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esShieldAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esShieldAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esShieldAbility[type].g_iHumanMode, value, 0, 1);
		g_esShieldAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esShieldAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esShieldAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esShieldAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esShieldAbility[type].g_iShieldAbility = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esShieldAbility[type].g_iShieldAbility, value, 0, 1);
		g_esShieldAbility[type].g_iShieldMessage = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esShieldAbility[type].g_iShieldMessage, value, 0, 1);
		g_esShieldAbility[type].g_flShieldChance = flGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldChance", "Shield Chance", "Shield_Chance", "chance", g_esShieldAbility[type].g_flShieldChance, value, 0.0, 100.0);
		g_esShieldAbility[type].g_iShieldCooldown = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldCooldown", "Shield Cooldown", "Shield_Cooldown", "cooldown", g_esShieldAbility[type].g_iShieldCooldown, value, 0, 99999);
		g_esShieldAbility[type].g_iShieldDelay = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldDelay", "Shield Delay", "Shield_Delay", "delay", g_esShieldAbility[type].g_iShieldDelay, value, 1, 99999);
		g_esShieldAbility[type].g_iShieldDisplayHP = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldDisplayHealth", "Shield Display Health", "Shield_Display_Health", "displayhp", g_esShieldAbility[type].g_iShieldDisplayHP, value, 0, 11);
		g_esShieldAbility[type].g_iShieldDisplayHPType = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldDisplayHealthType", "Shield Display Health Type", "Shield_Display_Health_Type", "displaytype", g_esShieldAbility[type].g_iShieldDisplayHPType, value, 0, 2);
		g_esShieldAbility[type].g_iShieldDuration = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldDuration", "Shield Duration", "Shield_Duration", "duration", g_esShieldAbility[type].g_iShieldDuration, value, 0, 99999);
		g_esShieldAbility[type].g_iShieldGlow = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldGlow", "Shield Glow", "Shield_Glow", "glow", g_esShieldAbility[type].g_iShieldGlow, value, 0, 1);
		g_esShieldAbility[type].g_flShieldHealth = flGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldHealth", "Shield Health", "Shield_Health", "health", g_esShieldAbility[type].g_flShieldHealth, value, 0.0, 99999.0);
		g_esShieldAbility[type].g_flShieldThrowChance = flGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldThrowChance", "Shield Throw Chance", "Shield_Throw_Chance", "throwchance", g_esShieldAbility[type].g_flShieldThrowChance, value, 0.0, 100.0);
		g_esShieldAbility[type].g_iShieldType = iGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldType", "Shield Type", "Shield_Type", "type", g_esShieldAbility[type].g_iShieldType, value, 0, 15);
		g_esShieldAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esShieldAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

		vGetKeyValue(subsection, MT_SHIELD_SECTION, MT_SHIELD_SECTION2, MT_SHIELD_SECTION3, MT_SHIELD_SECTION4, key, "ShieldHealthCharacters", "Shield Health Characters", "Shield_Characters", "hpchars", g_esShieldAbility[type].g_sShieldHealthChars, sizeof esShieldAbility::g_sShieldHealthChars, value);

		if (StrEqual(subsection, MT_SHIELD_SECTION, false) || StrEqual(subsection, MT_SHIELD_SECTION2, false) || StrEqual(subsection, MT_SHIELD_SECTION3, false) || StrEqual(subsection, MT_SHIELD_SECTION4, false))
		{
			if (StrEqual(key, "ShieldColor", false) || StrEqual(key, "Shield Color", false) || StrEqual(key, "Shield_Color", false) || StrEqual(key, "color", false))
			{
				char sSet[4][4], sValue[16];
				MT_GetConfigColors(sValue, sizeof sValue, value);
				strcopy(g_esShieldAbility[type].g_sShieldColor, sizeof esShieldAbility::g_sShieldColor, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof sSet); iPos++)
				{
					g_esShieldAbility[type].g_iShieldColor[iPos] = (sSet[iPos][0] != '\0' && StringToInt(sSet[iPos]) >= 0) ? iClamp(StringToInt(sSet[iPos]), 0, 255) : -1;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esShieldCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_flCloseAreasOnly, g_esShieldAbility[type].g_flCloseAreasOnly);
	g_esShieldCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iComboAbility, g_esShieldAbility[type].g_iComboAbility);
	g_esShieldCache[tank].g_flShieldChance = flGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_flShieldChance, g_esShieldAbility[type].g_flShieldChance);
	g_esShieldCache[tank].g_flShieldHealth = flGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_flShieldHealth, g_esShieldAbility[type].g_flShieldHealth);
	g_esShieldCache[tank].g_flShieldThrowChance = flGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_flShieldThrowChance, g_esShieldAbility[type].g_flShieldThrowChance);
	g_esShieldCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iHumanAbility, g_esShieldAbility[type].g_iHumanAbility);
	g_esShieldCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iHumanAmmo, g_esShieldAbility[type].g_iHumanAmmo);
	g_esShieldCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iHumanCooldown, g_esShieldAbility[type].g_iHumanCooldown);
	g_esShieldCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iHumanDuration, g_esShieldAbility[type].g_iHumanDuration);
	g_esShieldCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iHumanMode, g_esShieldAbility[type].g_iHumanMode);
	g_esShieldCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_flOpenAreasOnly, g_esShieldAbility[type].g_flOpenAreasOnly);
	g_esShieldCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iRequiresHumans, g_esShieldAbility[type].g_iRequiresHumans);
	g_esShieldCache[tank].g_iShieldAbility = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldAbility, g_esShieldAbility[type].g_iShieldAbility);
	g_esShieldCache[tank].g_iShieldCooldown = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldCooldown, g_esShieldAbility[type].g_iShieldCooldown);
	g_esShieldCache[tank].g_iShieldDelay = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldDelay, g_esShieldAbility[type].g_iShieldDelay);
	g_esShieldCache[tank].g_iShieldDisplayHP = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldDisplayHP, g_esShieldAbility[type].g_iShieldDisplayHP);
	g_esShieldCache[tank].g_iShieldDisplayHPType = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldDisplayHPType, g_esShieldAbility[type].g_iShieldDisplayHPType);
	g_esShieldCache[tank].g_iShieldDuration = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldDuration, g_esShieldAbility[type].g_iShieldDuration);
	g_esShieldCache[tank].g_iShieldGlow = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldGlow, g_esShieldAbility[type].g_iShieldGlow);
	g_esShieldCache[tank].g_iShieldMessage = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldMessage, g_esShieldAbility[type].g_iShieldMessage);
	g_esShieldCache[tank].g_iShieldType = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldType, g_esShieldAbility[type].g_iShieldType);
	g_esShieldPlayer[tank].g_iTankType = apply ? type : 0;

	vGetSettingValue(apply, bHuman, g_esShieldCache[tank].g_sShieldColor, sizeof esShieldCache::g_sShieldColor, g_esShieldPlayer[tank].g_sShieldColor, g_esShieldAbility[type].g_sShieldColor);
	vGetSettingValue(apply, bHuman, g_esShieldCache[tank].g_sShieldHealthChars, sizeof esShieldCache::g_sShieldHealthChars, g_esShieldPlayer[tank].g_sShieldHealthChars, g_esShieldAbility[type].g_sShieldHealthChars);

	for (int iPos = 0; iPos < (sizeof esShieldCache::g_iShieldColor); iPos++)
	{
		g_esShieldCache[tank].g_iShieldColor[iPos] = iGetSettingValue(apply, bHuman, g_esShieldPlayer[tank].g_iShieldColor[iPos], g_esShieldAbility[type].g_iShieldColor[iPos], 1);
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vShieldCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveShield(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vShieldPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esShieldPlayer[iTank].g_bActivated)
		{
			vRemoveShield(iTank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldEventFired(Event event, const char[] name)
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
			vShieldCopyStats2(iBot, iTank);
			vRemoveShield(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vShieldCopyStats2(iTank, iBot);
			vRemoveShield(iTank);
		}
	}
	else if (StrEqual(name, "player_incapacitated") || StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveShield(iTank);
			vShieldReset2(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vShieldReset();
	}
}

#if defined MT_ABILITIES_MAIN2
Action aShieldPlayerHitByVomitJar(int player, int thrower)
#else
public Action MT_OnPlayerHitByVomitJar(int player, int thrower)
#endif
{
	if (MT_IsTankSupported(player) && g_esShieldPlayer[player].g_bActivated && bIsSurvivor(thrower, MT_CHECK_INDEX|MT_CHECK_INGAME) && !MT_DoesSurvivorHaveRewardType(thrower, MT_REWARD_DAMAGEBOOST))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
Action aShieldPlayerShovedBySurvivor(int player, int survivor)
#else
public Action MT_OnPlayerShovedBySurvivor(int player, int survivor, const float direction[3])
#endif
{
	if (MT_IsTankSupported(player) && g_esShieldPlayer[player].g_bActivated && !(g_esShieldCache[player].g_iShieldType & MT_SHIELD_MELEE) && bIsSurvivor(survivor, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vShieldAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if ((MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iAccessFlags, g_esShieldPlayer[tank].g_iAccessFlags)) || g_esShieldCache[tank].g_iHumanAbility == 0)) || bIsPlayerIncapacitated(tank))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esShieldCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esShieldCache[tank].g_iShieldAbility == 1 && g_esShieldCache[tank].g_iComboAbility == 0 && !g_esShieldPlayer[tank].g_bActivated)
	{
		vShieldAbility(tank, true);
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esShieldCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esShieldCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShieldPlayer[tank].g_iTankType) || (g_esShieldCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShieldCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iAccessFlags, g_esShieldPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esShieldCache[tank].g_iShieldAbility == 1 && g_esShieldCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esShieldPlayer[tank].g_iCooldown != -1 && g_esShieldPlayer[tank].g_iCooldown > iTime;

			switch (g_esShieldCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esShieldPlayer[tank].g_bActivated && !bRecharging)
					{
						vShieldAbility(tank, true);
					}
					else if (g_esShieldPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldHuman4", (g_esShieldPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esShieldPlayer[tank].g_iAmmoCount < g_esShieldCache[tank].g_iHumanAmmo && g_esShieldCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esShieldPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esShieldPlayer[tank].g_bActivated = true;
							g_esShieldPlayer[tank].g_iAmmoCount++;

							g_esShieldPlayer[tank].g_iShield = CreateEntityByName("prop_dynamic");
							if (bIsValidEntity(g_esShieldPlayer[tank].g_iShield))
							{
								vShield(tank);
							}

							MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldHuman", g_esShieldPlayer[tank].g_iAmmoCount, g_esShieldCache[tank].g_iHumanAmmo);
						}
						else if (g_esShieldPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldHuman4", (g_esShieldPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esShieldCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esShieldCache[tank].g_iHumanMode == 1 && g_esShieldPlayer[tank].g_bActivated && (g_esShieldPlayer[tank].g_iCooldown == -1 || g_esShieldPlayer[tank].g_iCooldown < GetTime()))
		{
			g_esShieldPlayer[tank].g_bActivated = false;

			vRemoveShield(tank);
			vShieldReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vShieldChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		vRemoveShield(tank);
	}

	vShieldReset2(tank);
}

#if defined MT_ABILITIES_MAIN2
void vShieldRockThrow(int tank, int rock)
#else
public void MT_OnRockThrow(int tank, int rock)
#endif
{
	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esShieldCache[tank].g_iShieldAbility == 1 && MT_GetRandomFloat(0.1, 100.0) <= g_esShieldCache[tank].g_flShieldThrowChance && ((g_esShieldCache[tank].g_iShieldType & MT_SHIELD_EXPLOSIVE) || (g_esShieldCache[tank].g_iShieldType & MT_SHIELD_FIRE)))
	{
		if (bIsAreaNarrow(tank, g_esShieldCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esShieldCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShieldPlayer[tank].g_iTankType) || (g_esShieldCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShieldCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iAccessFlags, g_esShieldPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		DataPack dpShieldThrow;
		CreateDataTimer(0.1, tTimerShieldThrow, dpShieldThrow, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		dpShieldThrow.WriteCell(EntIndexToEntRef(rock));
		dpShieldThrow.WriteCell(GetClientUserId(tank));
		dpShieldThrow.WriteCell(g_esShieldPlayer[tank].g_iTankType);
	}
}

void vSetShieldGlow(int entity, int color, int flashing, int min, int max, int type)
{
	if (!g_bSecondGame)
	{
		return;
	}

	SetEntProp(entity, Prop_Send, "m_glowColorOverride", color);
	SetEntProp(entity, Prop_Send, "m_bFlashing", flashing);
	SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", min);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", max);
	SetEntProp(entity, Prop_Send, "m_iGlowType", type);
}

void vShield(int tank)
{
	if ((g_esShieldPlayer[tank].g_iCooldown != -1 && g_esShieldPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esShieldCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esShieldCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShieldPlayer[tank].g_iTankType) || (g_esShieldCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShieldCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iAccessFlags, g_esShieldPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	float flOrigin[3];
	GetClientAbsOrigin(tank, flOrigin);
	flOrigin[2] -= 120.0;

	SetEntityModel(g_esShieldPlayer[tank].g_iShield, MODEL_SHIELD);
	DispatchKeyValueVector(g_esShieldPlayer[tank].g_iShield, "origin", flOrigin);
	DispatchSpawn(g_esShieldPlayer[tank].g_iShield);
	vSetEntityParent(g_esShieldPlayer[tank].g_iShield, tank, true);

	switch (StrEqual(g_esShieldCache[tank].g_sShieldColor, "rainbow", false))
	{
		case true:
		{
			if (!g_esShieldPlayer[tank].g_bRainbowColor)
			{
				g_esShieldPlayer[tank].g_bRainbowColor = SDKHookEx(tank, SDKHook_PreThinkPost, OnShieldPreThinkPost);
			}
		}
		case false:
		{
			SetEntityRenderMode(g_esShieldPlayer[tank].g_iShield, RENDER_TRANSTEXTURE);
			SetEntityRenderColor(g_esShieldPlayer[tank].g_iShield, iGetRandomColor(g_esShieldCache[tank].g_iShieldColor[0]), iGetRandomColor(g_esShieldCache[tank].g_iShieldColor[1]), iGetRandomColor(g_esShieldCache[tank].g_iShieldColor[2]), iGetRandomColor(g_esShieldCache[tank].g_iShieldColor[3]));
		}
	}

	if (g_esShieldCache[tank].g_iShieldGlow == 1)
	{
		vSetShieldGlow(tank, 0, 0, 0, 0, 0);
		int iGlowColor[4];
		MT_GetTankColors(tank, 2, iGlowColor[0], iGlowColor[1], iGlowColor[2], iGlowColor[3]);

		switch (iGlowColor[0] == -2 && iGlowColor[1] == -2 && iGlowColor[2] == -2)
		{
			case true:
			{
				if (!g_esShieldPlayer[tank].g_bRainbowColor)
				{
					g_esShieldPlayer[tank].g_bRainbowColor = SDKHookEx(tank, SDKHook_PreThinkPost, OnShieldPreThinkPost);
				}
			}
			case false: vSetShieldGlow(g_esShieldPlayer[tank].g_iShield, iGetRGBColor(iGlowColor[0], iGlowColor[1], iGlowColor[2]), !!MT_IsGlowFlashing(tank), MT_GetGlowRange(tank, false), MT_GetGlowRange(tank, true), ((MT_GetGlowType(tank) == 1) ? 3 : 2));
		}
	}

	SetEntProp(g_esShieldPlayer[tank].g_iShield, Prop_Send, "m_CollisionGroup", 1);
	MT_HideEntity(g_esShieldPlayer[tank].g_iShield, true);
	g_esShieldPlayer[tank].g_iShield = EntIndexToEntRef(g_esShieldPlayer[tank].g_iShield);
}

void vShieldAbility(int tank, bool shield)
{
	int iTime = GetTime();

	switch (shield)
	{
		case true:
		{
			if ((g_esShieldPlayer[tank].g_iCooldown != -1 && g_esShieldPlayer[tank].g_iCooldown > iTime) || bIsAreaNarrow(tank, g_esShieldCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esShieldCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShieldPlayer[tank].g_iTankType) || (g_esShieldCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShieldCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iAccessFlags, g_esShieldPlayer[tank].g_iAccessFlags)) || ((!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esShieldCache[tank].g_iHumanAbility != 1) && g_esShieldPlayer[tank].g_iCooldown2 != -1 && g_esShieldPlayer[tank].g_iCooldown2 > iTime))
			{
				return;
			}

			if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esShieldPlayer[tank].g_iAmmoCount < g_esShieldCache[tank].g_iHumanAmmo && g_esShieldCache[tank].g_iHumanAmmo > 0))
			{
				if (MT_GetRandomFloat(0.1, 100.0) <= g_esShieldCache[tank].g_flShieldChance)
				{
					g_esShieldPlayer[tank].g_iShield = CreateEntityByName("prop_dynamic");
					if (bIsValidEntity(g_esShieldPlayer[tank].g_iShield))
					{
						g_esShieldPlayer[tank].g_bActivated = true;
						g_esShieldPlayer[tank].g_iCooldown2 = -1;
						g_esShieldPlayer[tank].g_flHealth = g_esShieldCache[tank].g_flShieldHealth;

						vShield(tank);
						ExtinguishEntity(tank);

						if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShieldCache[tank].g_iHumanAbility == 1)
						{
							int iPos = g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iComboPosition, iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 5, iPos)) : g_esShieldCache[tank].g_iShieldDuration;
							iDuration = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShieldCache[tank].g_iHumanAbility == 1) ? g_esShieldCache[tank].g_iHumanDuration : iDuration;
							g_esShieldPlayer[tank].g_iAmmoCount++;
							g_esShieldPlayer[tank].g_iDuration = (iTime + iDuration);

							vExternalView(tank, 1.5);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldHuman", g_esShieldPlayer[tank].g_iAmmoCount, g_esShieldCache[tank].g_iHumanAmmo);
						}

						if (g_esShieldCache[tank].g_iShieldMessage == 1)
						{
							char sTankName[33];
							MT_GetTankName(tank, sTankName);
							MT_PrintToChatAll("%s %t", MT_TAG2, "Shield", sTankName);
							MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Shield", LANG_SERVER, sTankName);
						}
					}
				}
				else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShieldCache[tank].g_iHumanAbility == 1)
				{
					MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldHuman2");
				}
			}
			else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShieldCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldAmmo");
			}
		}
		case false:
		{
			g_esShieldPlayer[tank].g_bActivated = false;
			g_esShieldPlayer[tank].g_iDuration = -1;
			g_esShieldPlayer[tank].g_flHealth = 0.0;

			vRemoveShield(tank);

			switch (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esShieldCache[tank].g_iHumanAbility == 1)
			{
				case true:
				{
					vExternalView(tank, 1.5);
					vShieldReset3(tank);
				}
				case false: g_esShieldPlayer[tank].g_iCooldown2 = (iTime + g_esShieldCache[tank].g_iShieldDelay);
			}

			if (g_esShieldCache[tank].g_iShieldMessage == 1)
			{
				char sTankName[33];
				MT_GetTankName(tank, sTankName);
				MT_PrintToChatAll("%s %t", MT_TAG2, "Shield2", sTankName);
				MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Shield2", LANG_SERVER, sTankName);
			}
		}
	}
}

void OnShieldPreThinkPost(int tank)
{
	if (!g_bSecondGame || !MT_IsTankSupported(tank) || !MT_IsCustomTankSupported(tank) || !g_esShieldPlayer[tank].g_bRainbowColor)
	{
		g_esShieldPlayer[tank].g_bRainbowColor = false;

		SDKUnhook(tank, SDKHook_PreThinkPost, OnShieldPreThinkPost);

		return;
	}

	int iShield = EntRefToEntIndex(g_esShieldPlayer[tank].g_iShield);
	if (iShield == INVALID_ENT_REFERENCE || !bIsValidEntity(iShield))
	{
		g_esShieldPlayer[tank].g_bRainbowColor = false;

		SDKUnhook(tank, SDKHook_PreThinkPost, OnShieldPreThinkPost);

		return;
	}

	bool bHook = false;
	int iColor[4];
	iColor[0] = RoundToNearest((Cosine((GetGameTime() * 1.0) + tank) * 127.5) + 127.5);
	iColor[1] = RoundToNearest((Cosine((GetGameTime() * 1.0) + tank + 2) * 127.5) + 127.5);
	iColor[2] = RoundToNearest((Cosine((GetGameTime() * 1.0) + tank + 4) * 127.5) + 127.5);
	iColor[3] = 50;

	if (StrEqual(g_esShieldCache[tank].g_sShieldColor, "rainbow", false))
	{
		bHook = true;

		SetEntityRenderMode(iShield, RENDER_TRANSTEXTURE);
		SetEntityRenderColor(iShield, iColor[0], iColor[1], iColor[2], iColor[3]);
	}

	int iTempColor[4];
	MT_GetTankColors(tank, 2, iTempColor[0], iTempColor[1], iTempColor[2], iTempColor[3]);
	if (iTempColor[0] == -2 && iTempColor[1] == -2 && iTempColor[2] == -2 && g_esShieldCache[tank].g_iShieldGlow == 1)
	{
		bHook = true;

		vSetShieldGlow(tank, 0, 0, 0, 0, 0);
		vSetShieldGlow(iShield, iGetRGBColor(iColor[0], iColor[1], iColor[2]), !!MT_IsGlowFlashing(tank), MT_GetGlowRange(tank, false), MT_GetGlowRange(tank, true), ((MT_GetGlowType(tank) == 1) ? 3 : 2));
	}

	if (!bHook)
	{
		g_esShieldPlayer[tank].g_bRainbowColor = false;

		SDKUnhook(tank, SDKHook_PreThinkPost, OnShieldPreThinkPost);
	}
}

void vShieldCopyStats2(int oldTank, int newTank)
{
	g_esShieldPlayer[newTank].g_iAmmoCount = g_esShieldPlayer[oldTank].g_iAmmoCount;
	g_esShieldPlayer[newTank].g_iCooldown = g_esShieldPlayer[oldTank].g_iCooldown;
	g_esShieldPlayer[newTank].g_iCooldown2 = g_esShieldPlayer[oldTank].g_iCooldown2;
}

void vRemoveShield(int tank)
{
	if (bIsValidEntRef(g_esShieldPlayer[tank].g_iShield))
	{
		g_esShieldPlayer[tank].g_iShield = EntRefToEntIndex(g_esShieldPlayer[tank].g_iShield);
		if (bIsValidEntity(g_esShieldPlayer[tank].g_iShield))
		{
			vSetShieldGlow(g_esShieldPlayer[tank].g_iShield, 0, 0, 0, 0, 0);

			if (bIsValidClient(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && MT_IsGlowEnabled(tank))
			{
				int iGlowColor[4];
				MT_GetTankColors(tank, 2, iGlowColor[0], iGlowColor[1], iGlowColor[2], iGlowColor[3]);
				vSetShieldGlow(tank, iGetRGBColor(iGlowColor[0], iGlowColor[1], iGlowColor[2]), !!MT_IsGlowFlashing(tank), MT_GetGlowRange(tank, false), MT_GetGlowRange(tank, true), ((MT_GetGlowType(tank) == 1) ? 3 : 2));
			}

			MT_HideEntity(g_esShieldPlayer[tank].g_iShield, false);
			RemoveEntity(g_esShieldPlayer[tank].g_iShield);
		}
	}

	g_esShieldPlayer[tank].g_bActivated = false;
	g_esShieldPlayer[tank].g_bRainbowColor = false;
	g_esShieldPlayer[tank].g_iShield = INVALID_ENT_REFERENCE;
}

void vShieldReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vShieldAbility(iPlayer, false);
			vShieldReset2(iPlayer);
		}
	}
}

void vShieldReset2(int tank)
{
	g_esShieldPlayer[tank].g_bRainbowColor = false;
	g_esShieldPlayer[tank].g_flHealth = 0.0;
	g_esShieldPlayer[tank].g_iAmmoCount = 0;
	g_esShieldPlayer[tank].g_iCooldown = -1;
	g_esShieldPlayer[tank].g_iCooldown2 = -1;
	g_esShieldPlayer[tank].g_iDuration = -1;
	g_esShieldPlayer[tank].g_iShield = INVALID_ENT_REFERENCE;
}

void vShieldReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esShieldAbility[g_esShieldPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esShieldCache[tank].g_iShieldCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esShieldCache[tank].g_iHumanAbility == 1 && g_esShieldCache[tank].g_iHumanMode == 0 && g_esShieldPlayer[tank].g_iAmmoCount < g_esShieldCache[tank].g_iHumanAmmo && g_esShieldCache[tank].g_iHumanAmmo > 0) ? g_esShieldCache[tank].g_iHumanCooldown : iCooldown;
	g_esShieldPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esShieldPlayer[tank].g_iCooldown != -1 && g_esShieldPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "ShieldHuman5", (g_esShieldPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerShieldCombo(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esShieldAbility[g_esShieldPlayer[iTank].g_iTankType].g_iAccessFlags, g_esShieldPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esShieldPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esShieldCache[iTank].g_iShieldAbility == 0 || g_esShieldPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	vShieldAbility(iTank, true);

	return Plugin_Continue;
}

Action tTimerShieldThrow(Handle timer, DataPack pack)
{
	pack.Reset();

	int iRock = EntRefToEntIndex(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || iRock == INVALID_ENT_REFERENCE || !bIsValidEntity(iRock))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esShieldCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esShieldCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esShieldPlayer[iTank].g_iTankType) || (g_esShieldCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esShieldCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esShieldAbility[g_esShieldPlayer[iTank].g_iTankType].g_iAccessFlags, g_esShieldPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esShieldPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esShieldPlayer[iTank].g_iTankType || g_esShieldCache[iTank].g_iShieldAbility == 0 || !g_esShieldPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	if (!(g_esShieldCache[iTank].g_iShieldType & MT_SHIELD_EXPLOSIVE) && !(g_esShieldCache[iTank].g_iShieldType & MT_SHIELD_FIRE))
	{
		return Plugin_Stop;
	}

	float flVelocity[3];
	GetEntPropVector(iRock, Prop_Data, "m_vecVelocity", flVelocity);

	float flVector = GetVectorLength(flVelocity);
	if (flVector > 500.0)
	{
		int iTypeCount = 0, iTypes[4], iFlag = 0;
		for (int iBit = 0; iBit < (sizeof iTypes); iBit++)
		{
			iFlag = (1 << iBit);
			if (!(g_esShieldCache[iTank].g_iShieldType & iFlag))
			{
				continue;
			}

			iTypes[iTypeCount] = iFlag;
			iTypeCount++;
		}

		int iChosen = iTypes[MT_GetRandomInt(0, (iTypeCount - 1))];
		if (iChosen == 2 || iChosen == 4)
		{
			int iThrowable = CreateEntityByName("prop_physics");
			if (bIsValidEntity(iThrowable))
			{
				switch (iChosen)
				{
					case 2: SetEntityModel(iThrowable, MODEL_PROPANETANK);
					case 4: SetEntityModel(iThrowable, MODEL_GASCAN);
				}

				float flPos[3];
				GetEntPropVector(iRock, Prop_Data, "m_vecOrigin", flPos);
				RemoveEntity(iRock);

				NormalizeVector(flVelocity, flVelocity);
				ScaleVector(flVelocity, (g_cvMTShieldTankThrowForce.FloatValue * 1.4));

				TeleportEntity(iThrowable, flPos);
				DispatchSpawn(iThrowable);
				TeleportEntity(iThrowable, .velocity = flVelocity);
			}
		}

		return Plugin_Stop;
	}

	return Plugin_Continue;
}