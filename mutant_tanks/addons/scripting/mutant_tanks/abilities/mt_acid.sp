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

#define MT_ACID_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_ACID_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Acid Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank creates acid puddles.",
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
			strcopy(error, err_max, "\"[MT] Acid Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_ACID_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_ACID_SECTION "acidability"
#define MT_ACID_SECTION2 "acid ability"
#define MT_ACID_SECTION3 "acid_ability"
#define MT_ACID_SECTION4 "acid"

#define MT_MENU_ACID "Acid Ability"

enum struct esAcidPlayer
{
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flAcidChance;
	float g_flAcidDeathChance;
	float g_flAcidDeathRange;
	float g_flAcidRange;
	float g_flAcidRangeChance;
	float g_flAcidRockChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAcidAbility;
	int g_iAcidCooldown;
	int g_iAcidDeath;
	int g_iAcidEffect;
	int g_iAcidHit;
	int g_iAcidHitMode;
	int g_iAcidMessage;
	int g_iAcidRangeCooldown;
	int g_iAcidRockBreak;
	int g_iAcidRockCooldown;
	int g_iAmmoCount;
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

esAcidPlayer g_esAcidPlayer[MAXPLAYERS + 1];

enum struct esAcidAbility
{
	float g_flAcidChance;
	float g_flAcidDeathChance;
	float g_flAcidDeathRange;
	float g_flAcidRange;
	float g_flAcidRangeChance;
	float g_flAcidRockChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAcidAbility;
	int g_iAcidCooldown;
	int g_iAcidDeath;
	int g_iAcidEffect;
	int g_iAcidHit;
	int g_iAcidHitMode;
	int g_iAcidMessage;
	int g_iAcidRangeCooldown;
	int g_iAcidRockBreak;
	int g_iAcidRockCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHumanRockCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esAcidAbility g_esAcidAbility[MT_MAXTYPES + 1];

enum struct esAcidCache
{
	float g_flAcidChance;
	float g_flAcidDeathChance;
	float g_flAcidDeathRange;
	float g_flAcidRange;
	float g_flAcidRangeChance;
	float g_flAcidRockChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAcidAbility;
	int g_iAcidCooldown;
	int g_iAcidDeath;
	int g_iAcidEffect;
	int g_iAcidHit;
	int g_iAcidHitMode;
	int g_iAcidMessage;
	int g_iAcidRangeCooldown;
	int g_iAcidRockBreak;
	int g_iAcidRockCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHumanRockCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esAcidCache g_esAcidCache[MAXPLAYERS + 1];

Handle g_hSDKSpitterProjectileCreate;

#if defined MT_ABILITIES_MAIN
void vAcidAllPluginsLoaded(GameData gdMutantTanks)
#else
public void OnAllPluginsLoaded()
#endif
{
	if (g_bSecondGame)
	{
#if !defined MT_ABILITIES_MAIN
		GameData gdMutantTanks = new GameData(MT_GAMEDATA);
		if (gdMutantTanks == null)
		{
			SetFailState("Unable to load the \"%s\" gamedata file.", MT_GAMEDATA);
		}
#endif
		GameData gdTemp;
		int iPlatformType = gdMutantTanks.GetOffset("OS");
		if (iPlatformType == 0)
		{
			gdTemp = new GameData(MT_GAMEDATA_TEMP);
			if (gdTemp == null)
			{
				LogError("%s Unable to load the \"%s\" gamedata file.", MT_TAG, MT_GAMEDATA_TEMP);
			}
		}

		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(((iPlatformType == 0 && gdTemp != null) ? gdTemp : gdMutantTanks), SDKConf_Signature, ((iPlatformType == 0 && gdTemp != null) ? "MTSignature_SpitterProjectileCreate" : "CSpitterProjectile::Create")))
		{
#if defined MT_ABILITIES_MAIN
			LogError("%s Failed to find signature: CSpitterProjectile::Create", MT_TAG);
#else
			SetFailState("Failed to find signature: CSpitterProjectile::Create");
#endif
			if (!PrepSDKCall_SetFromConf(gdMutantTanks, SDKConf_Signature, "CSpitterProjectile::Create"))
			{
#if defined MT_ABILITIES_MAIN
				delete gdMutantTanks;

				LogError("%s Failed to find signature: CSpitterProjectile::Create", MT_TAG);
#else
				SetFailState("Failed to find signature: CSpitterProjectile::Create");
#endif
			}
		}

		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);

		g_hSDKSpitterProjectileCreate = EndPrepSDKCall();
		if (g_hSDKSpitterProjectileCreate == null)
		{
#if defined MT_ABILITIES_MAIN
			LogError("%s Your \"CSpitterProjectile::Create\" signature is outdated.", MT_TAG);
#else
			SetFailState("Your \"CSpitterProjectile::Create\" signature is outdated.");
#endif
		}

		delete gdTemp;
#if !defined MT_ABILITIES_MAIN
		delete gdMutantTanks;
#endif
	}
}

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_acid", cmdAcidInfo, "View information about the Acid ability.");

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
void vAcidMapStart()
#else
public void OnMapStart()
#endif
{
	vAcidReset();
}

#if defined MT_ABILITIES_MAIN
void vAcidClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnAcidTakeDamage);
	vRemoveAcid(client);
}

#if defined MT_ABILITIES_MAIN
void vAcidClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveAcid(client);
}

#if defined MT_ABILITIES_MAIN
void vAcidMapEnd()
#else
public void OnMapEnd()
#endif
{
	vAcidReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdAcidInfo(int client, int args)
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
		case false: vAcidMenu(client, MT_ACID_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vAcidMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_ACID_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iAcidMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Acid Ability Information");
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

int iAcidMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esAcidCache[param1].g_iAcidAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esAcidCache[param1].g_iHumanAmmo - g_esAcidPlayer[param1].g_iAmmoCount), g_esAcidCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esAcidCache[param1].g_iHumanAbility == 1) ? g_esAcidCache[param1].g_iHumanCooldown : g_esAcidCache[param1].g_iAcidCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AcidDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esAcidCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esAcidCache[param1].g_iHumanAbility == 1) ? g_esAcidCache[param1].g_iHumanRangeCooldown : g_esAcidCache[param1].g_iAcidRangeCooldown));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRockCooldown", ((g_esAcidCache[param1].g_iHumanAbility == 1) ? g_esAcidCache[param1].g_iHumanRockCooldown : g_esAcidCache[param1].g_iAcidRockCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vAcidMenu(param1, MT_ACID_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pAcid = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "AcidMenu", param1);
			pAcid.SetTitle(sMenuTitle);
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
void vAcidDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_ACID, MT_MENU_ACID);
}

#if defined MT_ABILITIES_MAIN
void vAcidMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_ACID, false))
	{
		vAcidMenu(client, MT_ACID_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vAcidMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_ACID, false))
	{
		FormatEx(buffer, size, "%T", "AcidMenu2", client);
	}
}

Action OnAcidTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_bSecondGame && MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esAcidCache[attacker].g_iAcidHitMode == 0 || g_esAcidCache[attacker].g_iAcidHitMode == 1) && bIsSurvivor(victim) && g_esAcidCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esAcidAbility[g_esAcidPlayer[attacker].g_iTankType].g_iAccessFlags, g_esAcidPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esAcidPlayer[attacker].g_iTankType, g_esAcidAbility[g_esAcidPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esAcidPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vAcidHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esAcidCache[attacker].g_flAcidChance, g_esAcidCache[attacker].g_iAcidHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esAcidCache[victim].g_iAcidHitMode == 0 || g_esAcidCache[victim].g_iAcidHitMode == 2) && bIsSurvivor(attacker) && g_esAcidCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esAcidAbility[g_esAcidPlayer[victim].g_iTankType].g_iAccessFlags, g_esAcidPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esAcidPlayer[victim].g_iTankType, g_esAcidAbility[g_esAcidPlayer[victim].g_iTankType].g_iImmunityFlags, g_esAcidPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vAcidHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esAcidCache[victim].g_flAcidChance, g_esAcidCache[victim].g_iAcidHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vAcidPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_ACID);
}

#if defined MT_ABILITIES_MAIN
void vAcidAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_ACID_SECTION);
	list2.PushString(MT_ACID_SECTION2);
	list3.PushString(MT_ACID_SECTION3);
	list4.PushString(MT_ACID_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vAcidCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (!g_bSecondGame || (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAcidCache[tank].g_iHumanAbility != 2))
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_ACID_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_ACID_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_ACID_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_ACID_SECTION4);
	if (g_esAcidCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_ACID_SECTION, false) || StrEqual(sSubset[iPos], MT_ACID_SECTION2, false) || StrEqual(sSubset[iPos], MT_ACID_SECTION3, false) || StrEqual(sSubset[iPos], MT_ACID_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esAcidCache[tank].g_iAcidAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vAcidAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerAcidCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esAcidCache[tank].g_iAcidHitMode == 0 || g_esAcidCache[tank].g_iAcidHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vAcidHit(survivor, tank, random, flChance, g_esAcidCache[tank].g_iAcidHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esAcidCache[tank].g_iAcidHitMode == 0 || g_esAcidCache[tank].g_iAcidHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vAcidHit(survivor, tank, random, flChance, g_esAcidCache[tank].g_iAcidHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerAcidCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
						if (g_esAcidCache[tank].g_iAcidRockBreak == 1 && bIsValidEntity(weapon))
						{
							vAcidRockBreak2(tank, weapon, random, iPos);
						}
					}
					case MT_COMBO_POSTSPAWN: vAcidRange(tank, 0, random, iPos);
					case MT_COMBO_UPONDEATH: vAcidRange(tank, 0, random, iPos);
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vAcidConfigsLoad(int mode)
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
				g_esAcidAbility[iIndex].g_iAccessFlags = 0;
				g_esAcidAbility[iIndex].g_iImmunityFlags = 0;
				g_esAcidAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esAcidAbility[iIndex].g_iComboAbility = 0;
				g_esAcidAbility[iIndex].g_iHumanAbility = 0;
				g_esAcidAbility[iIndex].g_iHumanAmmo = 5;
				g_esAcidAbility[iIndex].g_iHumanCooldown = 0;
				g_esAcidAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esAcidAbility[iIndex].g_iHumanRockCooldown = 0;
				g_esAcidAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esAcidAbility[iIndex].g_iRequiresHumans = 0;
				g_esAcidAbility[iIndex].g_iAcidAbility = 0;
				g_esAcidAbility[iIndex].g_iAcidEffect = 0;
				g_esAcidAbility[iIndex].g_iAcidMessage = 0;
				g_esAcidAbility[iIndex].g_flAcidChance = 33.3;
				g_esAcidAbility[iIndex].g_iAcidCooldown = 0;
				g_esAcidAbility[iIndex].g_iAcidDeath = 0;
				g_esAcidAbility[iIndex].g_flAcidDeathChance = 33.3;
				g_esAcidAbility[iIndex].g_flAcidDeathRange = 200.0;
				g_esAcidAbility[iIndex].g_iAcidHit = 0;
				g_esAcidAbility[iIndex].g_iAcidHitMode = 0;
				g_esAcidAbility[iIndex].g_flAcidRange = 150.0;
				g_esAcidAbility[iIndex].g_flAcidRangeChance = 15.0;
				g_esAcidAbility[iIndex].g_iAcidRangeCooldown = 0;
				g_esAcidAbility[iIndex].g_iAcidRockBreak = 0;
				g_esAcidAbility[iIndex].g_flAcidRockChance = 33.3;
				g_esAcidAbility[iIndex].g_iAcidRockCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esAcidPlayer[iPlayer].g_iAccessFlags = 0;
					g_esAcidPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esAcidPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esAcidPlayer[iPlayer].g_iComboAbility = 0;
					g_esAcidPlayer[iPlayer].g_iHumanAbility = 0;
					g_esAcidPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esAcidPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esAcidPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esAcidPlayer[iPlayer].g_iHumanRockCooldown = 0;
					g_esAcidPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esAcidPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esAcidPlayer[iPlayer].g_iAcidAbility = 0;
					g_esAcidPlayer[iPlayer].g_iAcidEffect = 0;
					g_esAcidPlayer[iPlayer].g_iAcidMessage = 0;
					g_esAcidPlayer[iPlayer].g_flAcidChance = 0.0;
					g_esAcidPlayer[iPlayer].g_iAcidCooldown = 0;
					g_esAcidPlayer[iPlayer].g_iAcidDeath = 0;
					g_esAcidPlayer[iPlayer].g_flAcidDeathChance = 0.0;
					g_esAcidPlayer[iPlayer].g_flAcidDeathRange = 0.0;
					g_esAcidPlayer[iPlayer].g_iAcidHit = 0;
					g_esAcidPlayer[iPlayer].g_iAcidHitMode = 0;
					g_esAcidPlayer[iPlayer].g_flAcidRange = 0.0;
					g_esAcidPlayer[iPlayer].g_flAcidRangeChance = 0.0;
					g_esAcidPlayer[iPlayer].g_iAcidRangeCooldown = 0;
					g_esAcidPlayer[iPlayer].g_iAcidRockBreak = 0;
					g_esAcidPlayer[iPlayer].g_flAcidRockChance = 0.0;
					g_esAcidPlayer[iPlayer].g_iAcidRockCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vAcidConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esAcidPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esAcidPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esAcidPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esAcidPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esAcidPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esAcidPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esAcidPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esAcidPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esAcidPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esAcidPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esAcidPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esAcidPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esAcidPlayer[admin].g_iHumanRockCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanRockCooldown", "Human Rock Cooldown", "Human_Rock_Cooldown", "hrockcooldown", g_esAcidPlayer[admin].g_iHumanRockCooldown, value, 0, 99999);
		g_esAcidPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esAcidPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esAcidPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esAcidPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esAcidPlayer[admin].g_iAcidAbility = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esAcidPlayer[admin].g_iAcidAbility, value, 0, 1);
		g_esAcidPlayer[admin].g_iAcidEffect = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esAcidPlayer[admin].g_iAcidEffect, value, 0, 7);
		g_esAcidPlayer[admin].g_iAcidMessage = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esAcidPlayer[admin].g_iAcidMessage, value, 0, 7);
		g_esAcidPlayer[admin].g_flAcidChance = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidChance", "Acid Chance", "Acid_Chance", "chance", g_esAcidPlayer[admin].g_flAcidChance, value, 0.0, 100.0);
		g_esAcidPlayer[admin].g_iAcidCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidCooldown", "Acid Cooldown", "Acid_Cooldown", "cooldown", g_esAcidPlayer[admin].g_iAcidCooldown, value, 0, 99999);
		g_esAcidPlayer[admin].g_iAcidDeath = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidDeath", "Acid Death", "Acid_Death", "death", g_esAcidPlayer[admin].g_iAcidDeath, value, 0, 1);
		g_esAcidPlayer[admin].g_flAcidDeathChance = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidDeathChance", "Acid Death Chance", "Acid_Death_Chance", "deathchance", g_esAcidPlayer[admin].g_flAcidDeathChance, value, 0.0, 100.0);
		g_esAcidPlayer[admin].g_flAcidDeathRange = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidDeathRange", "Acid Death Range", "Acid_Death_Range", "deathrange", g_esAcidPlayer[admin].g_flAcidDeathRange, value, 1.0, 99999.0);
		g_esAcidPlayer[admin].g_iAcidHit = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidHit", "Acid Hit", "Acid_Hit", "hit", g_esAcidPlayer[admin].g_iAcidHit, value, 0, 1);
		g_esAcidPlayer[admin].g_iAcidHitMode = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidHitMode", "Acid Hit Mode", "Acid_Hit_Mode", "hitmode", g_esAcidPlayer[admin].g_iAcidHitMode, value, 0, 2);
		g_esAcidPlayer[admin].g_flAcidRange = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRange", "Acid Range", "Acid_Range", "range", g_esAcidPlayer[admin].g_flAcidRange, value, 1.0, 99999.0);
		g_esAcidPlayer[admin].g_flAcidRangeChance = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRangeChance", "Acid Range Chance", "Acid_Range_Chance", "rangechance", g_esAcidPlayer[admin].g_flAcidRangeChance, value, 0.0, 100.0);
		g_esAcidPlayer[admin].g_iAcidRangeCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRangeCooldown", "Acid Range Cooldown", "Acid_Range_Cooldown", "rangecooldown", g_esAcidPlayer[admin].g_iAcidRangeCooldown, value, 0, 99999);
		g_esAcidPlayer[admin].g_iAcidRockBreak = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRockBreak", "Acid Rock Break", "Acid_Rock_Break", "rock", g_esAcidPlayer[admin].g_iAcidRockBreak, value, 0, 1);
		g_esAcidPlayer[admin].g_flAcidRockChance = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRockChance", "Acid Rock Chance", "Acid_Rock_Chance", "rockchance", g_esAcidPlayer[admin].g_flAcidRockChance, value, 0.0, 100.0);
		g_esAcidPlayer[admin].g_iAcidRockCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRockCooldown", "Acid Rock Cooldown", "Acid_Rock_Cooldown", "rockcooldown", g_esAcidPlayer[admin].g_iAcidRockCooldown, value, 0, 99999);
		g_esAcidPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esAcidPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esAcidAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esAcidAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esAcidAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esAcidAbility[type].g_iComboAbility, value, 0, 1);
		g_esAcidAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esAcidAbility[type].g_iHumanAbility, value, 0, 2);
		g_esAcidAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esAcidAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esAcidAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esAcidAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esAcidAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esAcidAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esAcidAbility[type].g_iHumanRockCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "HumanRockCooldown", "Human Rock Cooldown", "Human_Rock_Cooldown", "hrockcooldown", g_esAcidAbility[type].g_iHumanRockCooldown, value, 0, 99999);
		g_esAcidAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esAcidAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esAcidAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esAcidAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esAcidAbility[type].g_iAcidAbility = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esAcidAbility[type].g_iAcidAbility, value, 0, 1);
		g_esAcidAbility[type].g_iAcidEffect = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esAcidAbility[type].g_iAcidEffect, value, 0, 7);
		g_esAcidAbility[type].g_iAcidMessage = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esAcidAbility[type].g_iAcidMessage, value, 0, 7);
		g_esAcidAbility[type].g_flAcidChance = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidChance", "Acid Chance", "Acid_Chance", "chance", g_esAcidAbility[type].g_flAcidChance, value, 0.0, 100.0);
		g_esAcidAbility[type].g_iAcidCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidCooldown", "Acid Cooldown", "Acid_Cooldown", "cooldown", g_esAcidAbility[type].g_iAcidCooldown, value, 0, 99999);
		g_esAcidAbility[type].g_iAcidDeath = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidDeath", "Acid Death", "Acid_Death", "death", g_esAcidAbility[type].g_iAcidDeath, value, 0, 1);
		g_esAcidAbility[type].g_flAcidDeathChance = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidDeathChance", "Acid Death Chance", "Acid_Death_Chance", "deathchance", g_esAcidAbility[type].g_flAcidDeathChance, value, 0.0, 100.0);
		g_esAcidAbility[type].g_flAcidDeathRange = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidDeathRange", "Acid Death Range", "Acid_Death_Range", "deathrange", g_esAcidAbility[type].g_flAcidDeathRange, value, 1.0, 99999.0);
		g_esAcidAbility[type].g_iAcidHit = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidHit", "Acid Hit", "Acid_Hit", "hit", g_esAcidAbility[type].g_iAcidHit, value, 0, 1);
		g_esAcidAbility[type].g_iAcidHitMode = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidHitMode", "Acid Hit Mode", "Acid_Hit_Mode", "hitmode", g_esAcidAbility[type].g_iAcidHitMode, value, 0, 2);
		g_esAcidAbility[type].g_flAcidRange = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRange", "Acid Range", "Acid_Range", "range", g_esAcidAbility[type].g_flAcidRange, value, 1.0, 99999.0);
		g_esAcidAbility[type].g_flAcidRangeChance = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRangeChance", "Acid Range Chance", "Acid_Range_Chance", "rangechance", g_esAcidAbility[type].g_flAcidRangeChance, value, 0.0, 100.0);
		g_esAcidAbility[type].g_iAcidRangeCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRangeCooldown", "Acid Range Cooldown", "Acid_Range_Cooldown", "rangecooldown", g_esAcidAbility[type].g_iAcidRangeCooldown, value, 0, 99999);
		g_esAcidAbility[type].g_iAcidRockBreak = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRockBreak", "Acid Rock Break", "Acid_Rock_Break", "rock", g_esAcidAbility[type].g_iAcidRockBreak, value, 0, 1);
		g_esAcidAbility[type].g_flAcidRockChance = flGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRockChance", "Acid Rock Chance", "Acid_Rock_Chance", "rockchance", g_esAcidAbility[type].g_flAcidRockChance, value, 0.0, 100.0);
		g_esAcidAbility[type].g_iAcidRockCooldown = iGetKeyValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AcidRockCooldown", "Acid Rock Cooldown", "Acid_Rock_Cooldown", "rockcooldown", g_esAcidAbility[type].g_iAcidRockCooldown, value, 0, 99999);
		g_esAcidAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esAcidAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ACID_SECTION, MT_ACID_SECTION2, MT_ACID_SECTION3, MT_ACID_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vAcidSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esAcidCache[tank].g_flAcidChance = flGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_flAcidChance, g_esAcidAbility[type].g_flAcidChance);
	g_esAcidCache[tank].g_flAcidDeathChance = flGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_flAcidDeathChance, g_esAcidAbility[type].g_flAcidDeathChance);
	g_esAcidCache[tank].g_flAcidDeathRange = flGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_flAcidDeathRange, g_esAcidAbility[type].g_flAcidDeathRange);
	g_esAcidCache[tank].g_flAcidRange = flGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_flAcidRange, g_esAcidAbility[type].g_flAcidRange);
	g_esAcidCache[tank].g_flAcidRangeChance = flGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_flAcidRangeChance, g_esAcidAbility[type].g_flAcidRangeChance);
	g_esAcidCache[tank].g_flAcidRockChance = flGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_flAcidRockChance, g_esAcidAbility[type].g_flAcidRockChance);
	g_esAcidCache[tank].g_iAcidAbility = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidAbility, g_esAcidAbility[type].g_iAcidAbility);
	g_esAcidCache[tank].g_iAcidCooldown = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidCooldown, g_esAcidAbility[type].g_iAcidCooldown);
	g_esAcidCache[tank].g_iAcidDeath = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidDeath, g_esAcidAbility[type].g_iAcidDeath);
	g_esAcidCache[tank].g_iAcidEffect = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidEffect, g_esAcidAbility[type].g_iAcidEffect);
	g_esAcidCache[tank].g_iAcidHit = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidHit, g_esAcidAbility[type].g_iAcidHit);
	g_esAcidCache[tank].g_iAcidHitMode = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidHitMode, g_esAcidAbility[type].g_iAcidHitMode);
	g_esAcidCache[tank].g_iAcidMessage = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidMessage, g_esAcidAbility[type].g_iAcidMessage);
	g_esAcidCache[tank].g_iAcidRangeCooldown = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidRangeCooldown, g_esAcidAbility[type].g_iAcidRangeCooldown);
	g_esAcidCache[tank].g_iAcidRockBreak = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidRockBreak, g_esAcidAbility[type].g_iAcidRockBreak);
	g_esAcidCache[tank].g_iAcidRockCooldown = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iAcidRockCooldown, g_esAcidAbility[type].g_iAcidRockCooldown);
	g_esAcidCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_flCloseAreasOnly, g_esAcidAbility[type].g_flCloseAreasOnly);
	g_esAcidCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iComboAbility, g_esAcidAbility[type].g_iComboAbility);
	g_esAcidCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iHumanAbility, g_esAcidAbility[type].g_iHumanAbility);
	g_esAcidCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iHumanAmmo, g_esAcidAbility[type].g_iHumanAmmo);
	g_esAcidCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iHumanCooldown, g_esAcidAbility[type].g_iHumanCooldown);
	g_esAcidCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iHumanRangeCooldown, g_esAcidAbility[type].g_iHumanRangeCooldown);
	g_esAcidCache[tank].g_iHumanRockCooldown = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iHumanRockCooldown, g_esAcidAbility[type].g_iHumanRockCooldown);
	g_esAcidCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_flOpenAreasOnly, g_esAcidAbility[type].g_flOpenAreasOnly);
	g_esAcidCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esAcidPlayer[tank].g_iRequiresHumans, g_esAcidAbility[type].g_iRequiresHumans);
	g_esAcidPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vAcidCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vAcidCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveAcid(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vAcidEventFired(Event event, const char[] name)
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
			vAcidCopyStats2(iBot, iTank);
			vRemoveAcid(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vAcidCopyStats2(iTank, iBot);
			vRemoveAcid(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (g_bSecondGame && MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vAcidRange(iTank, 1, MT_GetRandomFloat(0.1, 100.0));
			vRemoveAcid(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vAcidReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vAcidAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (!g_bSecondGame || (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[tank].g_iAccessFlags)) || g_esAcidCache[tank].g_iHumanAbility == 0)))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esAcidCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esAcidCache[tank].g_iAcidAbility == 1 && g_esAcidCache[tank].g_iComboAbility == 0)
	{
		vAcidAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vAcidButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (!g_bSecondGame || bIsAreaNarrow(tank, g_esAcidCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAcidCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAcidPlayer[tank].g_iTankType) || (g_esAcidCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAcidCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esAcidCache[tank].g_iAcidAbility == 1 && g_esAcidCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esAcidPlayer[tank].g_iRangeCooldown == -1 || g_esAcidPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vAcidAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidHuman3", (g_esAcidPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vAcidChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveAcid(tank);

	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esAcidCache[tank].g_iAcidAbility == 1)
	{
		if (!g_bSecondGame || (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[tank].g_iAccessFlags)) || g_esAcidCache[tank].g_iHumanAbility == 0)))
		{
			return;
		}

		vAcid(tank, tank);
	}
}

#if defined MT_ABILITIES_MAIN
void vAcidPostTankSpawn(int tank)
#else
public void MT_OnPostTankSpawn(int tank)
#endif
{
	vAcidRange(tank, 1, MT_GetRandomFloat(0.1, 100.0));
}

#if defined MT_ABILITIES_MAIN
void vAcidRockBreak(int tank, int rock)
#else
public void MT_OnRockBreak(int tank, int rock)
#endif
{
	if (!g_bSecondGame || bIsAreaNarrow(tank, g_esAcidCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAcidCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAcidPlayer[tank].g_iTankType) || (g_esAcidCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAcidCache[tank].g_iRequiresHumans) || (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[tank].g_iAccessFlags)) || g_esAcidCache[tank].g_iHumanAbility == 0)))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esAcidCache[tank].g_iAcidRockBreak == 1 && g_esAcidCache[tank].g_iComboAbility == 0)
	{
		vAcidRockBreak2(tank, rock, MT_GetRandomFloat(0.1, 100.0));
	}
}

void vAcid(int survivor, int tank)
{
	if (!g_bSecondGame || bIsAreaNarrow(tank, g_esAcidCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAcidCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAcidPlayer[tank].g_iTankType) || (g_esAcidCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAcidCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	float flOrigin[3], flAngles[3];
	GetClientAbsOrigin(survivor, flOrigin);
	GetClientAbsAngles(survivor, flAngles);
	SDKCall(g_hSDKSpitterProjectileCreate, flOrigin, flAngles, flAngles, flAngles, tank);
}

void vAcidAbility(int tank, float random, int pos = -1)
{
	if (!g_bSecondGame || bIsAreaNarrow(tank, g_esAcidCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAcidCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAcidPlayer[tank].g_iTankType) || (g_esAcidCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAcidCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esAcidPlayer[tank].g_iAmmoCount < g_esAcidCache[tank].g_iHumanAmmo && g_esAcidCache[tank].g_iHumanAmmo > 0))
	{
		g_esAcidPlayer[tank].g_bFailed = false;
		g_esAcidPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esAcidCache[tank].g_flAcidRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esAcidCache[tank].g_flAcidRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esAcidPlayer[tank].g_iTankType, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iImmunityFlags, g_esAcidPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vAcidHit(iSurvivor, tank, random, flChance, g_esAcidCache[tank].g_iAcidAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAcidCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAcidCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidAmmo");
	}
}

void vAcidHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (!g_bSecondGame || bIsAreaNarrow(tank, g_esAcidCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAcidCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAcidPlayer[tank].g_iTankType) || (g_esAcidCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAcidCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esAcidPlayer[tank].g_iTankType, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iImmunityFlags, g_esAcidPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esAcidPlayer[tank].g_iRangeCooldown != -1 && g_esAcidPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esAcidPlayer[tank].g_iCooldown != -1 && g_esAcidPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esAcidPlayer[tank].g_iAmmoCount < g_esAcidCache[tank].g_iHumanAmmo && g_esAcidCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance)
			{
				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esAcidPlayer[tank].g_iRangeCooldown == -1 || g_esAcidPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAcidCache[tank].g_iHumanAbility == 1)
					{
						g_esAcidPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidHuman", g_esAcidPlayer[tank].g_iAmmoCount, g_esAcidCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esAcidCache[tank].g_iAcidRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAcidCache[tank].g_iHumanAbility == 1 && g_esAcidPlayer[tank].g_iAmmoCount < g_esAcidCache[tank].g_iHumanAmmo && g_esAcidCache[tank].g_iHumanAmmo > 0) ? g_esAcidCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esAcidPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esAcidPlayer[tank].g_iRangeCooldown != -1 && g_esAcidPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidHuman5", (g_esAcidPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esAcidPlayer[tank].g_iCooldown == -1 || g_esAcidPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esAcidCache[tank].g_iAcidCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAcidCache[tank].g_iHumanAbility == 1) ? g_esAcidCache[tank].g_iHumanCooldown : iCooldown;
					g_esAcidPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esAcidPlayer[tank].g_iCooldown != -1 && g_esAcidPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidHuman5", (g_esAcidPlayer[tank].g_iCooldown - iTime));
					}
				}

				vAcid(survivor, tank);
				vScreenEffect(survivor, tank, g_esAcidCache[tank].g_iAcidEffect, flags);

				char sTankName[33];
				MT_GetTankName(tank, sTankName);
				if (g_esAcidCache[tank].g_iAcidMessage & messages)
				{
					MT_PrintToChatAll("%s %t", MT_TAG2, "Acid", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Acid", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esAcidPlayer[tank].g_iRangeCooldown == -1 || g_esAcidPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAcidCache[tank].g_iHumanAbility == 1 && !g_esAcidPlayer[tank].g_bFailed)
				{
					g_esAcidPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAcidCache[tank].g_iHumanAbility == 1 && !g_esAcidPlayer[tank].g_bNoAmmo)
		{
			g_esAcidPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidAmmo");
		}
	}
}

void vAcidRange(int tank, int value, float random, int pos = -1)
{
	float flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 13, pos) : g_esAcidCache[tank].g_flAcidDeathChance;
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(tank) && g_esAcidCache[tank].g_iAcidDeath == 1 && random <= flChance)
	{
		if (!g_bSecondGame || g_esAcidCache[tank].g_iComboAbility == value || bIsAreaNarrow(tank, g_esAcidCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAcidCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAcidPlayer[tank].g_iTankType) || (g_esAcidCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAcidCache[tank].g_iRequiresHumans) || (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAcidAbility[g_esAcidPlayer[tank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[tank].g_iAccessFlags)) || g_esAcidCache[tank].g_iHumanAbility == 0)))
		{
			return;
		}

		vAcid(tank, tank);
	}
}

void vAcidRockBreak2(int tank, int rock, float random, int pos = -1)
{
	float flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 14, pos) : g_esAcidCache[tank].g_flAcidRockChance;
	if (random <= flChance)
	{
		int iTime = GetTime(), iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAcidCache[tank].g_iHumanAbility == 1) ? g_esAcidCache[tank].g_iHumanRockCooldown : g_esAcidCache[tank].g_iAcidRockCooldown;
		iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 15, pos)) : iCooldown;
		if (g_esAcidPlayer[tank].g_iRockCooldown == -1 || g_esAcidPlayer[tank].g_iRockCooldown < iTime)
		{
			g_esAcidPlayer[tank].g_iRockCooldown = (iTime + iCooldown);
			if (g_esAcidPlayer[tank].g_iRockCooldown != -1 && g_esAcidPlayer[tank].g_iRockCooldown > iTime)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidHuman5", (g_esAcidPlayer[tank].g_iRockCooldown - iTime));
			}
		}
		else if (g_esAcidPlayer[tank].g_iRockCooldown != -1 && g_esAcidPlayer[tank].g_iRockCooldown > iTime)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "AcidHuman3", (g_esAcidPlayer[tank].g_iRockCooldown - iTime));

			return;
		}

		float flOrigin[3], flAngles[3];
		GetEntPropVector(rock, Prop_Data, "m_vecOrigin", flOrigin);
		GetEntPropVector(rock, Prop_Data, "m_angRotation", flAngles);
		flOrigin[2] += 40.0;
		SDKCall(g_hSDKSpitterProjectileCreate, flOrigin, flAngles, flAngles, flAngles, tank);

		if (g_esAcidCache[tank].g_iAcidMessage & MT_MESSAGE_SPECIAL)
		{
			char sTankName[33];
			MT_GetTankName(tank, sTankName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Acid2", sTankName);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Acid2", LANG_SERVER, sTankName);
		}
	}
}

void vAcidCopyStats2(int oldTank, int newTank)
{
	g_esAcidPlayer[newTank].g_iAmmoCount = g_esAcidPlayer[oldTank].g_iAmmoCount;
	g_esAcidPlayer[newTank].g_iCooldown = g_esAcidPlayer[oldTank].g_iCooldown;
	g_esAcidPlayer[newTank].g_iRangeCooldown = g_esAcidPlayer[oldTank].g_iRangeCooldown;
	g_esAcidPlayer[newTank].g_iRockCooldown = g_esAcidPlayer[oldTank].g_iRockCooldown;
}

void vRemoveAcid(int tank)
{
	g_esAcidPlayer[tank].g_bFailed = false;
	g_esAcidPlayer[tank].g_bNoAmmo = false;
	g_esAcidPlayer[tank].g_iAmmoCount = 0;
	g_esAcidPlayer[tank].g_iCooldown = -1;
	g_esAcidPlayer[tank].g_iRangeCooldown = -1;
	g_esAcidPlayer[tank].g_iRockCooldown = -1;
}

void vAcidReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveAcid(iPlayer);
		}
	}
}

Action tTimerAcidCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!g_bSecondGame || !MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esAcidAbility[g_esAcidPlayer[iTank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esAcidPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esAcidCache[iTank].g_iAcidAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vAcidAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerAcidCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!g_bSecondGame || !bIsSurvivor(iSurvivor))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esAcidAbility[g_esAcidPlayer[iTank].g_iTankType].g_iAccessFlags, g_esAcidPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esAcidPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esAcidCache[iTank].g_iAcidHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esAcidCache[iTank].g_iAcidHitMode == 0 || g_esAcidCache[iTank].g_iAcidHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vAcidHit(iSurvivor, iTank, flRandom, flChance, g_esAcidCache[iTank].g_iAcidHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esAcidCache[iTank].g_iAcidHitMode == 0 || g_esAcidCache[iTank].g_iAcidHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vAcidHit(iSurvivor, iTank, flRandom, flChance, g_esAcidCache[iTank].g_iAcidHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}