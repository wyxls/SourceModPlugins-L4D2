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

#define MT_BURY_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_BURY_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Bury Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank buries survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Bury Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_BURY_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_BURY_SECTION "buryability"
#define MT_BURY_SECTION2 "bury ability"
#define MT_BURY_SECTION3 "bury_ability"
#define MT_BURY_SECTION4 "bury"

#define MT_MENU_BURY "Bury Ability"

enum struct esBuryPlayer
{
	bool g_bAffected;
	bool g_bBlockFall;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flBuryBuffer;
	float g_flBuryChance;
	float g_flBuryDuration;
	float g_flBuryHeight;
	float g_flBuryRange;
	float g_flBuryRangeChance;
	float g_flLastPosition[3];
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iBuryAbility;
	int g_iBuryCooldown;
	int g_iBuryEffect;
	int g_iBuryHit;
	int g_iBuryHitMode;
	int g_iBuryMessage;
	int g_iBuryRangeCooldown;
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
	int g_iTankType;
}

esBuryPlayer g_esBuryPlayer[MAXPLAYERS + 1];

enum struct esBuryAbility
{
	float g_flBuryBuffer;
	float g_flBuryChance;
	float g_flBuryDuration;
	float g_flBuryHeight;
	float g_flBuryRange;
	float g_flBuryRangeChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iBuryAbility;
	int g_iBuryCooldown;
	int g_iBuryEffect;
	int g_iBuryHit;
	int g_iBuryHitMode;
	int g_iBuryMessage;
	int g_iBuryRangeCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esBuryAbility g_esBuryAbility[MT_MAXTYPES + 1];

enum struct esBuryCache
{
	float g_flBuryBuffer;
	float g_flBuryChance;
	float g_flBuryDuration;
	float g_flBuryHeight;
	float g_flBuryRange;
	float g_flBuryRangeChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iBuryAbility;
	int g_iBuryCooldown;
	int g_iBuryEffect;
	int g_iBuryHit;
	int g_iBuryHitMode;
	int g_iBuryMessage;
	int g_iBuryRangeCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
}

esBuryCache g_esBuryCache[MAXPLAYERS + 1];

Handle g_hSDKRevive;

#if defined MT_ABILITIES_MAIN
void vBuryAllPluginsLoaded(GameData gdMutantTanks)
#else
public void OnAllPluginsLoaded()
#endif
{
#if !defined MT_ABILITIES_MAIN
	GameData gdMutantTanks = new GameData(MT_GAMEDATA);
	if (gdMutantTanks == null)
	{
		SetFailState("Unable to load the \"%s\" gamedata file.", MT_GAMEDATA);
	}
#endif
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(gdMutantTanks, SDKConf_Signature, "CTerrorPlayer::OnRevived"))
	{
#if defined MT_ABILITIES_MAIN
		delete gdMutantTanks;

		LogError("%s Failed to find signature: CTerrorPlayer::OnRevived", MT_TAG);
#else
		SetFailState("Failed to find signature: CTerrorPlayer::OnRevived");
#endif
	}

	g_hSDKRevive = EndPrepSDKCall();
	if (g_hSDKRevive == null)
	{
#if defined MT_ABILITIES_MAIN
		LogError("%s Your \"CTerrorPlayer::OnRevived\" signature is outdated.", MT_TAG);
#else
		SetFailState("Your \"CTerrorPlayer::OnRevived\" signature is outdated.");
#endif
	}
#if !defined MT_ABILITIES_MAIN
	delete gdMutantTanks;
#endif
}

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_bury", cmdBuryInfo, "View information about the Bury ability.");

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
void vBuryMapStart()
#else
public void OnMapStart()
#endif
{
	vBuryReset();
}

#if defined MT_ABILITIES_MAIN
void vBuryClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnBuryTakeDamage);
	vBuryReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vBuryClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vBuryReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vBuryMapEnd()
#else
public void OnMapEnd()
#endif
{
	vBuryReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdBuryInfo(int client, int args)
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
		case false: vBuryMenu(client, MT_BURY_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vBuryMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_BURY_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iBuryMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Bury Ability Information");
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

int iBuryMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esBuryCache[param1].g_iBuryAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esBuryCache[param1].g_iHumanAmmo - g_esBuryPlayer[param1].g_iAmmoCount), g_esBuryCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esBuryCache[param1].g_iHumanAbility == 1) ? g_esBuryCache[param1].g_iHumanCooldown : g_esBuryCache[param1].g_iBuryCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "BuryDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esBuryCache[param1].g_flBuryDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esBuryCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esBuryCache[param1].g_iHumanAbility == 1) ? g_esBuryCache[param1].g_iHumanRangeCooldown : g_esBuryCache[param1].g_iBuryRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vBuryMenu(param1, MT_BURY_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pBury = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "BuryMenu", param1);
			pBury.SetTitle(sMenuTitle);
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
void vBuryDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_BURY, MT_MENU_BURY);
}

#if defined MT_ABILITIES_MAIN
void vBuryMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_BURY, false))
	{
		vBuryMenu(client, MT_BURY_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vBuryMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_BURY, false))
	{
		FormatEx(buffer, size, "%T", "BuryMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
Action aBuryPlayerRunCmd(int client, int &buttons)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsCorePluginEnabled())
	{
		return Plugin_Continue;
	}

	if (g_esBuryPlayer[client].g_bAffected && ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2) || (buttons & IN_USE)))
	{
		int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (iWeapon > MaxClients)
		{
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", 99999.0);
			SetEntPropFloat(client, Prop_Send, "m_flNextAttack", 99999.0);
		}

		buttons &= IN_ATTACK;
		buttons &= IN_ATTACK2;
		buttons &= IN_USE;

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

Action OnBuryTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		if (bIsSurvivor(victim) && (damagetype & DMG_FALL) && g_esBuryPlayer[victim].g_bBlockFall)
		{
			g_esBuryPlayer[victim].g_bBlockFall = false;

			return Plugin_Handled;
		}
		else if (bIsValidEntity(inflictor))
		{
			char sClassname[32];
			GetEntityClassname(inflictor, sClassname, sizeof sClassname);
			if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esBuryCache[attacker].g_iBuryHitMode == 0 || g_esBuryCache[attacker].g_iBuryHitMode == 1) && bIsSurvivor(victim) && g_esBuryCache[attacker].g_iComboAbility == 0)
			{
				if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esBuryAbility[g_esBuryPlayer[attacker].g_iTankType].g_iAccessFlags, g_esBuryPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esBuryPlayer[attacker].g_iTankType, g_esBuryAbility[g_esBuryPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esBuryPlayer[victim].g_iImmunityFlags))
				{
					return Plugin_Continue;
				}

				if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
				{
					vBuryHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esBuryCache[attacker].g_flBuryChance, g_esBuryCache[attacker].g_iBuryHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
				}
			}
			else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esBuryCache[victim].g_iBuryHitMode == 0 || g_esBuryCache[victim].g_iBuryHitMode == 2) && bIsSurvivor(attacker) && g_esBuryCache[victim].g_iComboAbility == 0)
			{
				if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esBuryAbility[g_esBuryPlayer[victim].g_iTankType].g_iAccessFlags, g_esBuryPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esBuryPlayer[victim].g_iTankType, g_esBuryAbility[g_esBuryPlayer[victim].g_iTankType].g_iImmunityFlags, g_esBuryPlayer[attacker].g_iImmunityFlags))
				{
					return Plugin_Continue;
				}

				if (StrEqual(sClassname[7], "melee"))
				{
					vBuryHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esBuryCache[victim].g_flBuryChance, g_esBuryCache[victim].g_iBuryHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
				}
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vBuryPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_BURY);
}

#if defined MT_ABILITIES_MAIN
void vBuryAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_BURY_SECTION);
	list2.PushString(MT_BURY_SECTION2);
	list3.PushString(MT_BURY_SECTION3);
	list4.PushString(MT_BURY_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vBuryCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBuryCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_BURY_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_BURY_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_BURY_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_BURY_SECTION4);
	if (g_esBuryCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_BURY_SECTION, false) || StrEqual(sSubset[iPos], MT_BURY_SECTION2, false) || StrEqual(sSubset[iPos], MT_BURY_SECTION3, false) || StrEqual(sSubset[iPos], MT_BURY_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esBuryCache[tank].g_iBuryAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vBuryAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerBuryCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esBuryCache[tank].g_iBuryHitMode == 0 || g_esBuryCache[tank].g_iBuryHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vBuryHit(survivor, tank, random, flChance, g_esBuryCache[tank].g_iBuryHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esBuryCache[tank].g_iBuryHitMode == 0 || g_esBuryCache[tank].g_iBuryHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vBuryHit(survivor, tank, random, flChance, g_esBuryCache[tank].g_iBuryHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerBuryCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vBuryConfigsLoad(int mode)
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
				g_esBuryAbility[iIndex].g_iAccessFlags = 0;
				g_esBuryAbility[iIndex].g_iImmunityFlags = 0;
				g_esBuryAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esBuryAbility[iIndex].g_iComboAbility = 0;
				g_esBuryAbility[iIndex].g_iHumanAbility = 0;
				g_esBuryAbility[iIndex].g_iHumanAmmo = 5;
				g_esBuryAbility[iIndex].g_iHumanCooldown = 0;
				g_esBuryAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esBuryAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esBuryAbility[iIndex].g_iRequiresHumans = 0;
				g_esBuryAbility[iIndex].g_iBuryAbility = 0;
				g_esBuryAbility[iIndex].g_iBuryEffect = 0;
				g_esBuryAbility[iIndex].g_iBuryMessage = 0;
				g_esBuryAbility[iIndex].g_flBuryBuffer = 100.0;
				g_esBuryAbility[iIndex].g_flBuryChance = 33.3;
				g_esBuryAbility[iIndex].g_iBuryCooldown = 0;
				g_esBuryAbility[iIndex].g_flBuryDuration = 5.0;
				g_esBuryAbility[iIndex].g_flBuryHeight = 50.0;
				g_esBuryAbility[iIndex].g_iBuryHit = 0;
				g_esBuryAbility[iIndex].g_iBuryHitMode = 0;
				g_esBuryAbility[iIndex].g_flBuryRange = 150.0;
				g_esBuryAbility[iIndex].g_flBuryRangeChance = 15.0;
				g_esBuryAbility[iIndex].g_iBuryRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esBuryPlayer[iPlayer].g_iAccessFlags = 0;
					g_esBuryPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esBuryPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esBuryPlayer[iPlayer].g_iComboAbility = 0;
					g_esBuryPlayer[iPlayer].g_iHumanAbility = 0;
					g_esBuryPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esBuryPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esBuryPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esBuryPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esBuryPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esBuryPlayer[iPlayer].g_iBuryAbility = 0;
					g_esBuryPlayer[iPlayer].g_iBuryEffect = 0;
					g_esBuryPlayer[iPlayer].g_iBuryMessage = 0;
					g_esBuryPlayer[iPlayer].g_flBuryBuffer = 0.0;
					g_esBuryPlayer[iPlayer].g_flBuryChance = 0.0;
					g_esBuryPlayer[iPlayer].g_iBuryCooldown = 0;
					g_esBuryPlayer[iPlayer].g_flBuryDuration = 0.0;
					g_esBuryPlayer[iPlayer].g_flBuryHeight = 0.0;
					g_esBuryPlayer[iPlayer].g_iBuryHit = 0;
					g_esBuryPlayer[iPlayer].g_iBuryHitMode = 0;
					g_esBuryPlayer[iPlayer].g_flBuryRange = 0.0;
					g_esBuryPlayer[iPlayer].g_flBuryRangeChance = 0.0;
					g_esBuryPlayer[iPlayer].g_iBuryRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vBuryConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esBuryPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esBuryPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esBuryPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esBuryPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esBuryPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esBuryPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esBuryPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esBuryPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esBuryPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esBuryPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esBuryPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esBuryPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esBuryPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esBuryPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esBuryPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esBuryPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esBuryPlayer[admin].g_iBuryAbility = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esBuryPlayer[admin].g_iBuryAbility, value, 0, 1);
		g_esBuryPlayer[admin].g_iBuryEffect = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esBuryPlayer[admin].g_iBuryEffect, value, 0, 7);
		g_esBuryPlayer[admin].g_iBuryMessage = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esBuryPlayer[admin].g_iBuryMessage, value, 0, 3);
		g_esBuryPlayer[admin].g_flBuryBuffer = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryBuffer", "Bury Buffer", "Bury_Buffer", "buffer", g_esBuryPlayer[admin].g_flBuryBuffer, value, 0.0, float(MT_MAXHEALTH));
		g_esBuryPlayer[admin].g_flBuryChance = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryChance", "Bury Chance", "Bury_Chance", "chance", g_esBuryPlayer[admin].g_flBuryChance, value, 0.0, 100.0);
		g_esBuryPlayer[admin].g_iBuryCooldown = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryCooldown", "Bury Cooldown", "Bury_Cooldown", "cooldown", g_esBuryPlayer[admin].g_iBuryCooldown, value, 0, 99999);
		g_esBuryPlayer[admin].g_flBuryDuration = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryDuration", "Bury Duration", "Bury_Duration", "duration", g_esBuryPlayer[admin].g_flBuryDuration, value, 0.1, 99999.0);
		g_esBuryPlayer[admin].g_flBuryHeight = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryHeight", "Bury Height", "Bury_Height", "height", g_esBuryPlayer[admin].g_flBuryHeight, value, 0.1, 99999.0);
		g_esBuryPlayer[admin].g_iBuryHit = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryHit", "Bury Hit", "Bury_Hit", "hit", g_esBuryPlayer[admin].g_iBuryHit, value, 0, 1);
		g_esBuryPlayer[admin].g_iBuryHitMode = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryHitMode", "Bury Hit Mode", "Bury_Hit_Mode", "hitmode", g_esBuryPlayer[admin].g_iBuryHitMode, value, 0, 2);
		g_esBuryPlayer[admin].g_flBuryRange = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryRange", "Bury Range", "Bury_Range", "range", g_esBuryPlayer[admin].g_flBuryRange, value, 1.0, 99999.0);
		g_esBuryPlayer[admin].g_flBuryRangeChance = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryRangeChance", "Bury Range Chance", "Bury_Range_Chance", "rangechance", g_esBuryPlayer[admin].g_flBuryRangeChance, value, 0.0, 100.0);
		g_esBuryPlayer[admin].g_iBuryRangeCooldown = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryRangeCooldown", "Bury Range Cooldown", "Bury_Range_Cooldown", "rangecooldown", g_esBuryPlayer[admin].g_iBuryRangeCooldown, value, 0, 99999);
		g_esBuryPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esBuryPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esBuryAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esBuryAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esBuryAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esBuryAbility[type].g_iComboAbility, value, 0, 1);
		g_esBuryAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esBuryAbility[type].g_iHumanAbility, value, 0, 2);
		g_esBuryAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esBuryAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esBuryAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esBuryAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esBuryAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esBuryAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esBuryAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esBuryAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esBuryAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esBuryAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esBuryAbility[type].g_iBuryAbility = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esBuryAbility[type].g_iBuryAbility, value, 0, 1);
		g_esBuryAbility[type].g_iBuryEffect = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esBuryAbility[type].g_iBuryEffect, value, 0, 7);
		g_esBuryAbility[type].g_iBuryMessage = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esBuryAbility[type].g_iBuryMessage, value, 0, 3);
		g_esBuryAbility[type].g_flBuryBuffer = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryBuffer", "Bury Buffer", "Bury_Buffer", "buffer", g_esBuryAbility[type].g_flBuryBuffer, value, 0.0, float(MT_MAXHEALTH));
		g_esBuryAbility[type].g_flBuryChance = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryChance", "Bury Chance", "Bury_Chance", "chance", g_esBuryAbility[type].g_flBuryChance, value, 0.0, 100.0);
		g_esBuryAbility[type].g_iBuryCooldown = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryCooldown", "Bury Cooldown", "Bury_Cooldown", "cooldown", g_esBuryAbility[type].g_iBuryCooldown, value, 0, 99999);
		g_esBuryAbility[type].g_flBuryDuration = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryDuration", "Bury Duration", "Bury_Duration", "duration", g_esBuryAbility[type].g_flBuryDuration, value, 0.1, 99999.0);
		g_esBuryAbility[type].g_flBuryHeight = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryHeight", "Bury Height", "Bury_Height", "height", g_esBuryAbility[type].g_flBuryHeight, value, 0.1, 99999.0);
		g_esBuryAbility[type].g_iBuryHit = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryHit", "Bury Hit", "Bury_Hit", "hit", g_esBuryAbility[type].g_iBuryHit, value, 0, 1);
		g_esBuryAbility[type].g_iBuryHitMode = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryHitMode", "Bury Hit Mode", "Bury_Hit_Mode", "hitmode", g_esBuryAbility[type].g_iBuryHitMode, value, 0, 2);
		g_esBuryAbility[type].g_flBuryRange = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryRange", "Bury Range", "Bury_Range", "range", g_esBuryAbility[type].g_flBuryRange, value, 1.0, 99999.0);
		g_esBuryAbility[type].g_flBuryRangeChance = flGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryRangeChance", "Bury Range Chance", "Bury_Range_Chance", "rangechance", g_esBuryAbility[type].g_flBuryRangeChance, value, 0.0, 100.0);
		g_esBuryAbility[type].g_iBuryRangeCooldown = iGetKeyValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "BuryRangeCooldown", "Bury Range Cooldown", "Bury_Range_Cooldown", "rangecooldown", g_esBuryAbility[type].g_iBuryRangeCooldown, value, 0, 99999);
		g_esBuryAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esBuryAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_BURY_SECTION, MT_BURY_SECTION2, MT_BURY_SECTION3, MT_BURY_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vBurySettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esBuryCache[tank].g_flBuryBuffer = flGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_flBuryBuffer, g_esBuryAbility[type].g_flBuryBuffer);
	g_esBuryCache[tank].g_flBuryChance = flGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_flBuryChance, g_esBuryAbility[type].g_flBuryChance);
	g_esBuryCache[tank].g_flBuryDuration = flGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_flBuryDuration, g_esBuryAbility[type].g_flBuryDuration);
	g_esBuryCache[tank].g_flBuryHeight = flGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_flBuryHeight, g_esBuryAbility[type].g_flBuryHeight);
	g_esBuryCache[tank].g_flBuryRange = flGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_flBuryRange, g_esBuryAbility[type].g_flBuryRange);
	g_esBuryCache[tank].g_flBuryRangeChance = flGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_flBuryRangeChance, g_esBuryAbility[type].g_flBuryRangeChance);
	g_esBuryCache[tank].g_iBuryAbility = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iBuryAbility, g_esBuryAbility[type].g_iBuryAbility);
	g_esBuryCache[tank].g_iBuryCooldown = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iBuryCooldown, g_esBuryAbility[type].g_iBuryCooldown);
	g_esBuryCache[tank].g_iBuryEffect = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iBuryEffect, g_esBuryAbility[type].g_iBuryEffect);
	g_esBuryCache[tank].g_iBuryHit = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iBuryHit, g_esBuryAbility[type].g_iBuryHit);
	g_esBuryCache[tank].g_iBuryHitMode = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iBuryHitMode, g_esBuryAbility[type].g_iBuryHitMode);
	g_esBuryCache[tank].g_iBuryMessage = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iBuryMessage, g_esBuryAbility[type].g_iBuryMessage);
	g_esBuryCache[tank].g_iBuryRangeCooldown = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iBuryRangeCooldown, g_esBuryAbility[type].g_iBuryRangeCooldown);
	g_esBuryCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_flCloseAreasOnly, g_esBuryAbility[type].g_flCloseAreasOnly);
	g_esBuryCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iComboAbility, g_esBuryAbility[type].g_iComboAbility);
	g_esBuryCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iHumanAbility, g_esBuryAbility[type].g_iHumanAbility);
	g_esBuryCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iHumanAmmo, g_esBuryAbility[type].g_iHumanAmmo);
	g_esBuryCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iHumanCooldown, g_esBuryAbility[type].g_iHumanCooldown);
	g_esBuryCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iHumanRangeCooldown, g_esBuryAbility[type].g_iHumanRangeCooldown);
	g_esBuryCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_flOpenAreasOnly, g_esBuryAbility[type].g_flOpenAreasOnly);
	g_esBuryCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esBuryPlayer[tank].g_iRequiresHumans, g_esBuryAbility[type].g_iRequiresHumans);
	g_esBuryPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vBuryCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vBuryCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveBury(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vBuryPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			vRemoveBury(iTank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vBuryEventFired(Event event, const char[] name)
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
			vBuryCopyStats2(iBot, iTank);
			vRemoveBury(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vBuryCopyStats2(iTank, iBot);
			vRemoveBury(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveBury(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vBuryReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vBuryFatalFalling(int survivor)
#else
public Action MT_OnFatalFalling(int survivor)
#endif
{
	if (bIsSurvivor(survivor) && g_esBuryPlayer[survivor].g_bBlockFall)
	{
		g_esBuryPlayer[survivor].g_bBlockFall = false;
	}
#if !defined MT_ABILITIES_MAIN
	return Plugin_Continue;
#endif
}

#if defined MT_ABILITIES_MAIN
void vBuryRewardSurvivor(int survivor, int type, bool apply)
#else
public Action MT_OnRewardSurvivor(int survivor, int tank, int &type, int priority, float &duration, bool apply)
#endif
{
	if (bIsSurvivor(survivor) && apply & ((type & MT_REWARD_HEALTH) || (type & MT_REWARD_REFILL) || (type & MT_REWARD_GODMODE)) && g_esBuryPlayer[survivor].g_bAffected)
	{
		vStopBury(survivor, g_esBuryPlayer[survivor].g_iOwner);
	}
#if !defined MT_ABILITIES_MAIN
	return Plugin_Continue;
#endif
}

#if defined MT_ABILITIES_MAIN
void vBuryAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBuryAbility[g_esBuryPlayer[tank].g_iTankType].g_iAccessFlags, g_esBuryPlayer[tank].g_iAccessFlags)) || g_esBuryCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esBuryCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esBuryCache[tank].g_iBuryAbility == 1 && g_esBuryCache[tank].g_iComboAbility == 0)
	{
		vBuryAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vBuryButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esBuryCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esBuryCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esBuryPlayer[tank].g_iTankType) || (g_esBuryCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esBuryCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBuryAbility[g_esBuryPlayer[tank].g_iTankType].g_iAccessFlags, g_esBuryPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esBuryCache[tank].g_iBuryAbility == 1 && g_esBuryCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esBuryPlayer[tank].g_iRangeCooldown == -1 || g_esBuryPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vBuryAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "BuryHuman3", (g_esBuryPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vBuryChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0 || !MT_IsTankSupported(tank))
	{
		return;
	}

	vRemoveBury(tank);
}

void vBuryAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esBuryCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esBuryCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esBuryPlayer[tank].g_iTankType) || (g_esBuryCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esBuryCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBuryAbility[g_esBuryPlayer[tank].g_iTankType].g_iAccessFlags, g_esBuryPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esBuryPlayer[tank].g_iAmmoCount < g_esBuryCache[tank].g_iHumanAmmo && g_esBuryCache[tank].g_iHumanAmmo > 0))
	{
		g_esBuryPlayer[tank].g_bFailed = false;
		g_esBuryPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esBuryCache[tank].g_flBuryRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esBuryCache[tank].g_flBuryRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esBuryPlayer[tank].g_iTankType, g_esBuryAbility[g_esBuryPlayer[tank].g_iTankType].g_iImmunityFlags, g_esBuryPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vBuryHit(iSurvivor, tank, random, flChance, g_esBuryCache[tank].g_iBuryAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBuryCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "BuryHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBuryCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "BuryAmmo");
	}
}

void vBuryHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esBuryCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esBuryCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esBuryPlayer[tank].g_iTankType) || (g_esBuryCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esBuryCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esBuryAbility[g_esBuryPlayer[tank].g_iTankType].g_iAccessFlags, g_esBuryPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esBuryPlayer[tank].g_iTankType, g_esBuryAbility[g_esBuryPlayer[tank].g_iTankType].g_iImmunityFlags, g_esBuryPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esBuryPlayer[tank].g_iRangeCooldown != -1 && g_esBuryPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esBuryPlayer[tank].g_iCooldown != -1 && g_esBuryPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !bIsSurvivorDisabled(survivor) && bIsEntityGrounded(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_INFAMMO))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esBuryPlayer[tank].g_iAmmoCount < g_esBuryCache[tank].g_iHumanAmmo && g_esBuryCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esBuryPlayer[survivor].g_bAffected)
			{
				g_esBuryPlayer[survivor].g_bAffected = true;
				g_esBuryPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esBuryPlayer[tank].g_iRangeCooldown == -1 || g_esBuryPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBuryCache[tank].g_iHumanAbility == 1)
					{
						g_esBuryPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "BuryHuman", g_esBuryPlayer[tank].g_iAmmoCount, g_esBuryCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esBuryCache[tank].g_iBuryRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBuryCache[tank].g_iHumanAbility == 1 && g_esBuryPlayer[tank].g_iAmmoCount < g_esBuryCache[tank].g_iHumanAmmo && g_esBuryCache[tank].g_iHumanAmmo > 0) ? g_esBuryCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esBuryPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esBuryPlayer[tank].g_iRangeCooldown != -1 && g_esBuryPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "BuryHuman5", (g_esBuryPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esBuryPlayer[tank].g_iCooldown == -1 || g_esBuryPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esBuryCache[tank].g_iBuryCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBuryCache[tank].g_iHumanAbility == 1) ? g_esBuryCache[tank].g_iHumanCooldown : iCooldown;
					g_esBuryPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esBuryPlayer[tank].g_iCooldown != -1 && g_esBuryPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "BuryHuman5", (g_esBuryPlayer[tank].g_iCooldown - iTime));
					}
				}

				GetEntPropVector(survivor, Prop_Data, "m_vecOrigin", g_esBuryPlayer[survivor].g_flLastPosition);

				float flOrigin[3];
				GetEntPropVector(survivor, Prop_Data, "m_vecOrigin", flOrigin);
				flOrigin[2] -= g_esBuryCache[tank].g_flBuryHeight;
				SetEntPropVector(survivor, Prop_Data, "m_vecOrigin", flOrigin);

				SetEntProp(survivor, Prop_Send, "m_isIncapacitated", 1);
				SetEntProp(survivor, Prop_Data, "m_takedamage", 0, 1);

				if (GetEntityMoveType(survivor) != MOVETYPE_NONE)
				{
					SetEntityMoveType(survivor, MOVETYPE_NONE);
				}

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esBuryCache[tank].g_flBuryDuration;
				DataPack dpStopBury;
				CreateDataTimer(flDuration, tTimerStopBury, dpStopBury, TIMER_FLAG_NO_MAPCHANGE);
				dpStopBury.WriteCell(GetClientUserId(survivor));
				dpStopBury.WriteCell(GetClientUserId(tank));
				dpStopBury.WriteCell(messages);

				vScreenEffect(survivor, tank, g_esBuryCache[tank].g_iBuryEffect, flags);

				if (g_esBuryCache[tank].g_iBuryMessage & messages)
				{
					char sTankName[33];
					float flDepth = ((g_esBuryCache[tank].g_flBuryHeight * 0.75) / 12.0);
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Bury", sTankName, survivor, flDepth);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Bury", LANG_SERVER, sTankName, survivor, flDepth);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esBuryPlayer[tank].g_iRangeCooldown == -1 || g_esBuryPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBuryCache[tank].g_iHumanAbility == 1 && !g_esBuryPlayer[tank].g_bFailed)
				{
					g_esBuryPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "BuryHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esBuryCache[tank].g_iHumanAbility == 1 && !g_esBuryPlayer[tank].g_bNoAmmo)
		{
			g_esBuryPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "BuryAmmo");
		}
	}
}

void vBuryCopyStats2(int oldTank, int newTank)
{
	g_esBuryPlayer[newTank].g_iAmmoCount = g_esBuryPlayer[oldTank].g_iAmmoCount;
	g_esBuryPlayer[newTank].g_iCooldown = g_esBuryPlayer[oldTank].g_iCooldown;
	g_esBuryPlayer[newTank].g_iRangeCooldown = g_esBuryPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveBury(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esBuryPlayer[iSurvivor].g_bAffected && g_esBuryPlayer[iSurvivor].g_iOwner == tank)
		{
			vStopBury(iSurvivor, tank);
		}
	}

	vBuryReset2(tank, false);
}

void vBuryReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vBuryReset2(iPlayer);
		}
	}
}

void vBuryReset2(int tank, bool full = true)
{
	g_esBuryPlayer[tank].g_bAffected = false;
	g_esBuryPlayer[tank].g_bFailed = false;
	g_esBuryPlayer[tank].g_bNoAmmo = false;
	g_esBuryPlayer[tank].g_iAmmoCount = 0;
	g_esBuryPlayer[tank].g_iCooldown = -1;
	g_esBuryPlayer[tank].g_iRangeCooldown = -1;

	if (full)
	{
		g_esBuryPlayer[tank].g_bBlockFall = false;
		g_esBuryPlayer[tank].g_iOwner = 0;
	}
}

void vStopBury(int survivor, int tank)
{
	g_esBuryPlayer[survivor].g_bAffected = false;
	g_esBuryPlayer[survivor].g_bBlockFall = true;
	g_esBuryPlayer[survivor].g_iOwner = 0;

	float flOrigin[3];
	GetEntPropVector(survivor, Prop_Data, "m_vecOrigin", flOrigin);
	flOrigin[2] += g_esBuryCache[tank].g_flBuryHeight;
	SetEntPropVector(survivor, Prop_Data, "m_vecOrigin", flOrigin);

	if (bIsPlayerIncapacitated(survivor))
	{
		SDKCall(g_hSDKRevive, survivor);

		if (g_esBuryCache[tank].g_flBuryBuffer > 0.0)
		{
			SetEntPropFloat(survivor, Prop_Send, "m_healthBufferTime", GetGameTime());
			SetEntPropFloat(survivor, Prop_Send, "m_healthBuffer", g_esBuryCache[tank].g_flBuryBuffer);
		}
	}

	if (!MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		SetEntProp(survivor, Prop_Data, "m_takedamage", 2, 1);
	}

	bool bTeleport = true;
	float flAngles[3];
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !bIsSurvivorDisabled(iSurvivor) && !g_esBuryPlayer[iSurvivor].g_bAffected && !g_esBuryPlayer[iSurvivor].g_bBlockFall && iSurvivor != survivor)
		{
			bTeleport = false;

			GetClientAbsOrigin(iSurvivor, flOrigin);
			GetClientEyeAngles(iSurvivor, flAngles);
			flOrigin[2] += g_esBuryCache[tank].g_flBuryHeight;
			TeleportEntity(survivor, flOrigin, flAngles, view_as<float>({0.0, 0.0, 0.0}));

			break;
		}
	}

	if (bTeleport)
	{
		g_esBuryPlayer[survivor].g_flLastPosition[2] += g_esBuryCache[tank].g_flBuryHeight;

		TeleportEntity(survivor, g_esBuryPlayer[survivor].g_flLastPosition, .velocity = view_as<float>({0.0, 0.0, 0.0}));
	}

	int iWeapon = 0;
	for (int iSlot = 0; iSlot < 5; iSlot++)
	{
		iWeapon = GetPlayerWeaponSlot(survivor, iSlot);
		if (iWeapon > MaxClients)
		{
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", 1.0);
		}
	}

	SetEntPropFloat(survivor, Prop_Send, "m_flNextAttack", 1.0);

	if (GetEntityMoveType(survivor) == MOVETYPE_NONE)
	{
		SetEntityMoveType(survivor, MOVETYPE_WALK);
	}
}

Action tTimerBuryCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esBuryAbility[g_esBuryPlayer[iTank].g_iTankType].g_iAccessFlags, g_esBuryPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esBuryPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esBuryCache[iTank].g_iBuryAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vBuryAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerBuryCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esBuryPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esBuryAbility[g_esBuryPlayer[iTank].g_iTankType].g_iAccessFlags, g_esBuryPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esBuryPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esBuryCache[iTank].g_iBuryHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esBuryCache[iTank].g_iBuryHitMode == 0 || g_esBuryCache[iTank].g_iBuryHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vBuryHit(iSurvivor, iTank, flRandom, flChance, g_esBuryCache[iTank].g_iBuryHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esBuryCache[iTank].g_iBuryHitMode == 0 || g_esBuryCache[iTank].g_iBuryHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vBuryHit(iSurvivor, iTank, flRandom, flChance, g_esBuryCache[iTank].g_iBuryHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopBury(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || !g_esBuryPlayer[iSurvivor].g_bAffected)
	{
		g_esBuryPlayer[iSurvivor].g_bAffected = false;
		g_esBuryPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank))
	{
		vStopBury(iSurvivor, iTank);

		return Plugin_Stop;
	}

	vStopBury(iSurvivor, iTank);

	int iMessage = pack.ReadCell();
	if (g_esBuryCache[iTank].g_iBuryMessage & iMessage)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Bury2", iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Bury2", LANG_SERVER, iSurvivor);
	}

	return Plugin_Continue;
}