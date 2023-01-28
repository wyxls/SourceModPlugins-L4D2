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

#define MT_ENFORCE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_ENFORCE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Enforce Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank forces survivors to only use a certain weapon slot.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Enforce Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_ENFORCE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_ENFORCE_SECTION "enforceability"
#define MT_ENFORCE_SECTION2 "enforce ability"
#define MT_ENFORCE_SECTION3 "enforce_ability"
#define MT_ENFORCE_SECTION4 "enforce"

#define MT_MENU_ENFORCE "Enforce Ability"

enum struct esEnforcePlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flEnforceChance;
	float g_flEnforceDuration;
	float g_flEnforceRange;
	float g_flEnforceRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iEnforceAbility;
	int g_iEnforceCooldown;
	int g_iEnforceEffect;
	int g_iEnforceHit;
	int g_iEnforceHitMode;
	int g_iEnforceMessage;
	int g_iEnforceRangeCooldown;
	int g_iEnforceWeaponSlots;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iSlot;
	int g_iTankType;
}

esEnforcePlayer g_esEnforcePlayer[MAXPLAYERS + 1];

enum struct esEnforceAbility
{
	float g_flCloseAreasOnly;
	float g_flEnforceChance;
	float g_flEnforceDuration;
	float g_flEnforceRange;
	float g_flEnforceRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iEnforceAbility;
	int g_iEnforceCooldown;
	int g_iEnforceEffect;
	int g_iEnforceHit;
	int g_iEnforceHitMode;
	int g_iEnforceMessage;
	int g_iEnforceRangeCooldown;
	int g_iEnforceWeaponSlots;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esEnforceAbility g_esEnforceAbility[MT_MAXTYPES + 1];

enum struct esEnforceCache
{
	float g_flCloseAreasOnly;
	float g_flEnforceChance;
	float g_flEnforceDuration;
	float g_flEnforceRange;
	float g_flEnforceRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iEnforceAbility;
	int g_iEnforceCooldown;
	int g_iEnforceEffect;
	int g_iEnforceHit;
	int g_iEnforceHitMode;
	int g_iEnforceMessage;
	int g_iEnforceRangeCooldown;
	int g_iEnforceWeaponSlots;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
}

esEnforceCache g_esEnforceCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_enforce", cmdEnforceInfo, "View information about the Enforce ability.");

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
void vEnforceMapStart()
#else
public void OnMapStart()
#endif
{
	vEnforceReset();
}

#if defined MT_ABILITIES_MAIN
void vEnforceClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnEnforceTakeDamage);
	vEnforceReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vEnforceClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vEnforceReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vEnforceMapEnd()
#else
public void OnMapEnd()
#endif
{
	vEnforceReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdEnforceInfo(int client, int args)
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
		case false: vEnforceMenu(client, MT_ENFORCE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vEnforceMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_ENFORCE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iEnforceMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Enforce Ability Information");
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

int iEnforceMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esEnforceCache[param1].g_iEnforceAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esEnforceCache[param1].g_iHumanAmmo - g_esEnforcePlayer[param1].g_iAmmoCount), g_esEnforceCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esEnforceCache[param1].g_iHumanAbility == 1) ? g_esEnforceCache[param1].g_iHumanCooldown : g_esEnforceCache[param1].g_iEnforceCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "EnforceDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esEnforceCache[param1].g_flEnforceDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esEnforceCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esEnforceCache[param1].g_iHumanAbility == 1) ? g_esEnforceCache[param1].g_iHumanRangeCooldown : g_esEnforceCache[param1].g_iEnforceRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vEnforceMenu(param1, MT_ENFORCE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pEnforce = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "EnforceMenu", param1);
			pEnforce.SetTitle(sMenuTitle);
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
void vEnforceDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_ENFORCE, MT_MENU_ENFORCE);
}

#if defined MT_ABILITIES_MAIN
void vEnforceMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_ENFORCE, false))
	{
		vEnforceMenu(client, MT_ENFORCE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vEnforceMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_ENFORCE, false))
	{
		FormatEx(buffer, size, "%T", "EnforceMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
Action aEnforcePlayerRunCmd(int client, int &weapon)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsCorePluginEnabled())
	{
		return Plugin_Continue;
	}

	if (bIsSurvivor(client) && g_esEnforcePlayer[client].g_bAffected)
	{
		if (MT_DoesSurvivorHaveRewardType(client, MT_REWARD_GODMODE) && g_esEnforcePlayer[client].g_iSlot != 0)
		{
			g_esEnforcePlayer[client].g_iSlot = 0;
		}

		int iWeapon = GetPlayerWeaponSlot(client, g_esEnforcePlayer[client].g_iSlot);
		if (iWeapon > MaxClients)
		{
			weapon = iWeapon;

			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

Action OnEnforceTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esEnforceCache[attacker].g_iEnforceHitMode == 0 || g_esEnforceCache[attacker].g_iEnforceHitMode == 1) && bIsSurvivor(victim) && g_esEnforceCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esEnforceAbility[g_esEnforcePlayer[attacker].g_iTankType].g_iAccessFlags, g_esEnforcePlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esEnforcePlayer[attacker].g_iTankType, g_esEnforceAbility[g_esEnforcePlayer[attacker].g_iTankType].g_iImmunityFlags, g_esEnforcePlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vEnforceHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esEnforceCache[attacker].g_flEnforceChance, g_esEnforceCache[attacker].g_iEnforceHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esEnforceCache[victim].g_iEnforceHitMode == 0 || g_esEnforceCache[victim].g_iEnforceHitMode == 2) && bIsSurvivor(attacker) && g_esEnforceCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esEnforceAbility[g_esEnforcePlayer[victim].g_iTankType].g_iAccessFlags, g_esEnforcePlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esEnforcePlayer[victim].g_iTankType, g_esEnforceAbility[g_esEnforcePlayer[victim].g_iTankType].g_iImmunityFlags, g_esEnforcePlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vEnforceHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esEnforceCache[victim].g_flEnforceChance, g_esEnforceCache[victim].g_iEnforceHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vEnforcePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_ENFORCE);
}

#if defined MT_ABILITIES_MAIN
void vEnforceAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_ENFORCE_SECTION);
	list2.PushString(MT_ENFORCE_SECTION2);
	list3.PushString(MT_ENFORCE_SECTION3);
	list4.PushString(MT_ENFORCE_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vEnforceCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esEnforceCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_ENFORCE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_ENFORCE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_ENFORCE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_ENFORCE_SECTION4);
	if (g_esEnforceCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_ENFORCE_SECTION, false) || StrEqual(sSubset[iPos], MT_ENFORCE_SECTION2, false) || StrEqual(sSubset[iPos], MT_ENFORCE_SECTION3, false) || StrEqual(sSubset[iPos], MT_ENFORCE_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esEnforceCache[tank].g_iEnforceAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vEnforceAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerEnforceCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esEnforceCache[tank].g_iEnforceHitMode == 0 || g_esEnforceCache[tank].g_iEnforceHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vEnforceHit(survivor, tank, random, flChance, g_esEnforceCache[tank].g_iEnforceHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esEnforceCache[tank].g_iEnforceHitMode == 0 || g_esEnforceCache[tank].g_iEnforceHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vEnforceHit(survivor, tank, random, flChance, g_esEnforceCache[tank].g_iEnforceHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerEnforceCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vEnforceConfigsLoad(int mode)
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
				g_esEnforceAbility[iIndex].g_iAccessFlags = 0;
				g_esEnforceAbility[iIndex].g_iImmunityFlags = 0;
				g_esEnforceAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esEnforceAbility[iIndex].g_iComboAbility = 0;
				g_esEnforceAbility[iIndex].g_iHumanAbility = 0;
				g_esEnforceAbility[iIndex].g_iHumanAmmo = 5;
				g_esEnforceAbility[iIndex].g_iHumanCooldown = 0;
				g_esEnforceAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esEnforceAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esEnforceAbility[iIndex].g_iRequiresHumans = 0;
				g_esEnforceAbility[iIndex].g_iEnforceAbility = 0;
				g_esEnforceAbility[iIndex].g_iEnforceEffect = 0;
				g_esEnforceAbility[iIndex].g_iEnforceMessage = 0;
				g_esEnforceAbility[iIndex].g_flEnforceChance = 33.3;
				g_esEnforceAbility[iIndex].g_iEnforceCooldown = 0;
				g_esEnforceAbility[iIndex].g_flEnforceDuration = 5.0;
				g_esEnforceAbility[iIndex].g_iEnforceHit = 0;
				g_esEnforceAbility[iIndex].g_iEnforceHitMode = 0;
				g_esEnforceAbility[iIndex].g_flEnforceRange = 150.0;
				g_esEnforceAbility[iIndex].g_flEnforceRangeChance = 15.0;
				g_esEnforceAbility[iIndex].g_iEnforceRangeCooldown = 0;
				g_esEnforceAbility[iIndex].g_iEnforceWeaponSlots = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esEnforcePlayer[iPlayer].g_iAccessFlags = 0;
					g_esEnforcePlayer[iPlayer].g_iImmunityFlags = 0;
					g_esEnforcePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esEnforcePlayer[iPlayer].g_iComboAbility = 0;
					g_esEnforcePlayer[iPlayer].g_iHumanAbility = 0;
					g_esEnforcePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esEnforcePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esEnforcePlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esEnforcePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esEnforcePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esEnforcePlayer[iPlayer].g_iEnforceAbility = 0;
					g_esEnforcePlayer[iPlayer].g_iEnforceEffect = 0;
					g_esEnforcePlayer[iPlayer].g_iEnforceMessage = 0;
					g_esEnforcePlayer[iPlayer].g_flEnforceChance = 0.0;
					g_esEnforcePlayer[iPlayer].g_iEnforceCooldown = 0;
					g_esEnforcePlayer[iPlayer].g_flEnforceDuration = 0.0;
					g_esEnforcePlayer[iPlayer].g_iEnforceHit = 0;
					g_esEnforcePlayer[iPlayer].g_iEnforceHitMode = 0;
					g_esEnforcePlayer[iPlayer].g_flEnforceRange = 0.0;
					g_esEnforcePlayer[iPlayer].g_flEnforceRangeChance = 0.0;
					g_esEnforcePlayer[iPlayer].g_iEnforceRangeCooldown = 0;
					g_esEnforcePlayer[iPlayer].g_iEnforceWeaponSlots = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vEnforceConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esEnforcePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esEnforcePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esEnforcePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esEnforcePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esEnforcePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esEnforcePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esEnforcePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esEnforcePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esEnforcePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esEnforcePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esEnforcePlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esEnforcePlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esEnforcePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esEnforcePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esEnforcePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esEnforcePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esEnforcePlayer[admin].g_iEnforceAbility = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esEnforcePlayer[admin].g_iEnforceAbility, value, 0, 1);
		g_esEnforcePlayer[admin].g_iEnforceEffect = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esEnforcePlayer[admin].g_iEnforceEffect, value, 0, 7);
		g_esEnforcePlayer[admin].g_iEnforceMessage = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esEnforcePlayer[admin].g_iEnforceMessage, value, 0, 3);
		g_esEnforcePlayer[admin].g_flEnforceChance = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceChance", "Enforce Chance", "Enforce_Chance", "chance", g_esEnforcePlayer[admin].g_flEnforceChance, value, 0.0, 100.0);
		g_esEnforcePlayer[admin].g_iEnforceCooldown = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceCooldown", "Enforce Cooldown", "Enforce_Cooldown", "cooldown", g_esEnforcePlayer[admin].g_iEnforceCooldown, value, 0, 99999);
		g_esEnforcePlayer[admin].g_flEnforceDuration = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceDuration", "Enforce Duration", "Enforce_Duration", "duration", g_esEnforcePlayer[admin].g_flEnforceDuration, value, 0.1, 99999.0);
		g_esEnforcePlayer[admin].g_iEnforceHit = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceHit", "Enforce Hit", "Enforce_Hit", "hit", g_esEnforcePlayer[admin].g_iEnforceHit, value, 0, 1);
		g_esEnforcePlayer[admin].g_iEnforceHitMode = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceHitMode", "Enforce Hit Mode", "Enforce_Hit_Mode", "hitmode", g_esEnforcePlayer[admin].g_iEnforceHitMode, value, 0, 2);
		g_esEnforcePlayer[admin].g_flEnforceRange = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceRange", "Enforce Range", "Enforce_Range", "range", g_esEnforcePlayer[admin].g_flEnforceRange, value, 1.0, 99999.0);
		g_esEnforcePlayer[admin].g_flEnforceRangeChance = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceRangeChance", "Enforce Range Chance", "Enforce_Range_Chance", "rangechance", g_esEnforcePlayer[admin].g_flEnforceRangeChance, value, 0.0, 100.0);
		g_esEnforcePlayer[admin].g_iEnforceRangeCooldown = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceRangeCooldown", "Enforce Range Cooldown", "Enforce_Range_Cooldown", "rangecooldown", g_esEnforcePlayer[admin].g_iEnforceRangeCooldown, value, 0, 99999);
		g_esEnforcePlayer[admin].g_iEnforceWeaponSlots = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceWeaponSlots", "Enforce Weapon Slots", "Enforce_Weapon_Slots", "slots", g_esEnforcePlayer[admin].g_iEnforceWeaponSlots, value, 0, 31);
		g_esEnforcePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esEnforcePlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esEnforceAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esEnforceAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esEnforceAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esEnforceAbility[type].g_iComboAbility, value, 0, 1);
		g_esEnforceAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esEnforceAbility[type].g_iHumanAbility, value, 0, 2);
		g_esEnforceAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esEnforceAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esEnforceAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esEnforceAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esEnforceAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esEnforceAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esEnforceAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esEnforceAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esEnforceAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esEnforceAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esEnforceAbility[type].g_iEnforceAbility = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esEnforceAbility[type].g_iEnforceAbility, value, 0, 1);
		g_esEnforceAbility[type].g_iEnforceEffect = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esEnforceAbility[type].g_iEnforceEffect, value, 0, 7);
		g_esEnforceAbility[type].g_iEnforceMessage = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esEnforceAbility[type].g_iEnforceMessage, value, 0, 3);
		g_esEnforceAbility[type].g_flEnforceChance = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceChance", "Enforce Chance", "Enforce_Chance", "chance", g_esEnforceAbility[type].g_flEnforceChance, value, 0.0, 100.0);
		g_esEnforceAbility[type].g_iEnforceCooldown = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceCooldown", "Enforce Cooldown", "Enforce_Cooldown", "cooldown", g_esEnforceAbility[type].g_iEnforceCooldown, value, 0, 99999);
		g_esEnforceAbility[type].g_flEnforceDuration = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceDuration", "Enforce Duration", "Enforce_Duration", "duration", g_esEnforceAbility[type].g_flEnforceDuration, value, 0.1, 99999.0);
		g_esEnforceAbility[type].g_iEnforceHit = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceHit", "Enforce Hit", "Enforce_Hit", "hit", g_esEnforceAbility[type].g_iEnforceHit, value, 0, 1);
		g_esEnforceAbility[type].g_iEnforceHitMode = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceHitMode", "Enforce Hit Mode", "Enforce_Hit_Mode", "hitmode", g_esEnforceAbility[type].g_iEnforceHitMode, value, 0, 2);
		g_esEnforceAbility[type].g_flEnforceRange = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceRange", "Enforce Range", "Enforce_Range", "range", g_esEnforceAbility[type].g_flEnforceRange, value, 1.0, 99999.0);
		g_esEnforceAbility[type].g_flEnforceRangeChance = flGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceRangeChance", "Enforce Range Chance", "Enforce_Range_Chance", "rangechance", g_esEnforceAbility[type].g_flEnforceRangeChance, value, 0.0, 100.0);
		g_esEnforceAbility[type].g_iEnforceRangeCooldown = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceRangeCooldown", "Enforce Range Cooldown", "Enforce_Range_Cooldown", "rangecooldown", g_esEnforceAbility[type].g_iEnforceRangeCooldown, value, 0, 99999);
		g_esEnforceAbility[type].g_iEnforceWeaponSlots = iGetKeyValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "EnforceWeaponSlots", "Enforce Weapon Slots", "Enforce_Weapon_Slots", "slots", g_esEnforceAbility[type].g_iEnforceWeaponSlots, value, 0, 31);
		g_esEnforceAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esEnforceAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ENFORCE_SECTION, MT_ENFORCE_SECTION2, MT_ENFORCE_SECTION3, MT_ENFORCE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vEnforceSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esEnforceCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_flCloseAreasOnly, g_esEnforceAbility[type].g_flCloseAreasOnly);
	g_esEnforceCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iComboAbility, g_esEnforceAbility[type].g_iComboAbility);
	g_esEnforceCache[tank].g_flEnforceChance = flGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_flEnforceChance, g_esEnforceAbility[type].g_flEnforceChance);
	g_esEnforceCache[tank].g_flEnforceDuration = flGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_flEnforceDuration, g_esEnforceAbility[type].g_flEnforceDuration);
	g_esEnforceCache[tank].g_flEnforceRange = flGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_flEnforceRange, g_esEnforceAbility[type].g_flEnforceRange);
	g_esEnforceCache[tank].g_flEnforceRangeChance = flGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_flEnforceRangeChance, g_esEnforceAbility[type].g_flEnforceRangeChance);
	g_esEnforceCache[tank].g_iEnforceAbility = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iEnforceAbility, g_esEnforceAbility[type].g_iEnforceAbility);
	g_esEnforceCache[tank].g_iEnforceCooldown = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iEnforceCooldown, g_esEnforceAbility[type].g_iEnforceCooldown);
	g_esEnforceCache[tank].g_iEnforceEffect = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iEnforceEffect, g_esEnforceAbility[type].g_iEnforceEffect);
	g_esEnforceCache[tank].g_iEnforceHit = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iEnforceHit, g_esEnforceAbility[type].g_iEnforceHit);
	g_esEnforceCache[tank].g_iEnforceHitMode = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iEnforceHitMode, g_esEnforceAbility[type].g_iEnforceHitMode);
	g_esEnforceCache[tank].g_iEnforceMessage = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iEnforceMessage, g_esEnforceAbility[type].g_iEnforceMessage);
	g_esEnforceCache[tank].g_iEnforceRangeCooldown = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iEnforceRangeCooldown, g_esEnforceAbility[type].g_iEnforceRangeCooldown);
	g_esEnforceCache[tank].g_iEnforceWeaponSlots = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iEnforceWeaponSlots, g_esEnforceAbility[type].g_iEnforceWeaponSlots);
	g_esEnforceCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iHumanAbility, g_esEnforceAbility[type].g_iHumanAbility);
	g_esEnforceCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iHumanAmmo, g_esEnforceAbility[type].g_iHumanAmmo);
	g_esEnforceCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iHumanCooldown, g_esEnforceAbility[type].g_iHumanCooldown);
	g_esEnforceCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iHumanRangeCooldown, g_esEnforceAbility[type].g_iHumanRangeCooldown);
	g_esEnforceCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_flOpenAreasOnly, g_esEnforceAbility[type].g_flOpenAreasOnly);
	g_esEnforceCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esEnforcePlayer[tank].g_iRequiresHumans, g_esEnforceAbility[type].g_iRequiresHumans);
	g_esEnforcePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vEnforceCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vEnforceCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveEnforce(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vEnforceEventFired(Event event, const char[] name)
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
			vEnforceCopyStats2(iBot, iTank);
			vRemoveEnforce(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vEnforceCopyStats2(iTank, iBot);
			vRemoveEnforce(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveEnforce(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vEnforceReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vEnforceAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esEnforceAbility[g_esEnforcePlayer[tank].g_iTankType].g_iAccessFlags, g_esEnforcePlayer[tank].g_iAccessFlags)) || g_esEnforceCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esEnforceCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esEnforceCache[tank].g_iEnforceAbility == 1 && g_esEnforceCache[tank].g_iComboAbility == 0)
	{
		vEnforceAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vEnforceButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esEnforceCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esEnforceCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esEnforcePlayer[tank].g_iTankType) || (g_esEnforceCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esEnforceCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esEnforceAbility[g_esEnforcePlayer[tank].g_iTankType].g_iAccessFlags, g_esEnforcePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esEnforceCache[tank].g_iEnforceAbility == 1 && g_esEnforceCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esEnforcePlayer[tank].g_iRangeCooldown == -1 || g_esEnforcePlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vEnforceAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "EnforceHuman3", (g_esEnforcePlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vEnforceChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveEnforce(tank);
}

void vEnforceAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esEnforceCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esEnforceCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esEnforcePlayer[tank].g_iTankType) || (g_esEnforceCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esEnforceCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esEnforceAbility[g_esEnforcePlayer[tank].g_iTankType].g_iAccessFlags, g_esEnforcePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esEnforcePlayer[tank].g_iAmmoCount < g_esEnforceCache[tank].g_iHumanAmmo && g_esEnforceCache[tank].g_iHumanAmmo > 0))
	{
		g_esEnforcePlayer[tank].g_bFailed = false;
		g_esEnforcePlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esEnforceCache[tank].g_flEnforceRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esEnforceCache[tank].g_flEnforceRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esEnforcePlayer[tank].g_iTankType, g_esEnforceAbility[g_esEnforcePlayer[tank].g_iTankType].g_iImmunityFlags, g_esEnforcePlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vEnforceHit(iSurvivor, tank, random, flChance, g_esEnforceCache[tank].g_iEnforceAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esEnforceCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "EnforceHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esEnforceCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "EnforceAmmo");
	}
}

void vEnforceHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esEnforceCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esEnforceCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esEnforcePlayer[tank].g_iTankType) || (g_esEnforceCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esEnforceCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esEnforceAbility[g_esEnforcePlayer[tank].g_iTankType].g_iAccessFlags, g_esEnforcePlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esEnforcePlayer[tank].g_iTankType, g_esEnforceAbility[g_esEnforcePlayer[tank].g_iTankType].g_iImmunityFlags, g_esEnforcePlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esEnforcePlayer[tank].g_iRangeCooldown != -1 && g_esEnforcePlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esEnforcePlayer[tank].g_iCooldown != -1 && g_esEnforcePlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esEnforcePlayer[tank].g_iAmmoCount < g_esEnforceCache[tank].g_iHumanAmmo && g_esEnforceCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esEnforcePlayer[survivor].g_bAffected)
			{
				g_esEnforcePlayer[survivor].g_bAffected = true;
				g_esEnforcePlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esEnforcePlayer[tank].g_iRangeCooldown == -1 || g_esEnforcePlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esEnforceCache[tank].g_iHumanAbility == 1)
					{
						g_esEnforcePlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "EnforceHuman", g_esEnforcePlayer[tank].g_iAmmoCount, g_esEnforceCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esEnforceCache[tank].g_iEnforceRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esEnforceCache[tank].g_iHumanAbility == 1 && g_esEnforcePlayer[tank].g_iAmmoCount < g_esEnforceCache[tank].g_iHumanAmmo && g_esEnforceCache[tank].g_iHumanAmmo > 0) ? g_esEnforceCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esEnforcePlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esEnforcePlayer[tank].g_iRangeCooldown != -1 && g_esEnforcePlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "EnforceHuman5", (g_esEnforcePlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esEnforcePlayer[tank].g_iCooldown == -1 || g_esEnforcePlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esEnforceCache[tank].g_iEnforceCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esEnforceCache[tank].g_iHumanAbility == 1) ? g_esEnforceCache[tank].g_iHumanCooldown : iCooldown;
					g_esEnforcePlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esEnforcePlayer[tank].g_iCooldown != -1 && g_esEnforcePlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "EnforceHuman5", (g_esEnforcePlayer[tank].g_iCooldown - iTime));
					}
				}

				if (MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
				{
					g_esEnforcePlayer[survivor].g_iSlot = 0;
				}
				else
				{
					int iSlotCount = 0, iSlots[5], iFlag = 0;
					for (int iBit = 0; iBit < (sizeof iSlots); iBit++)
					{
						iFlag = (1 << iBit);
						if (!(g_esEnforceCache[tank].g_iEnforceWeaponSlots & iFlag))
						{
							continue;
						}

						iSlots[iSlotCount] = iFlag;
						iSlotCount++;
					}

					switch (iSlots[MT_GetRandomInt(0, (iSlotCount - 1))])
					{
						case 1: g_esEnforcePlayer[survivor].g_iSlot = 0;
						case 2: g_esEnforcePlayer[survivor].g_iSlot = 1;
						case 4: g_esEnforcePlayer[survivor].g_iSlot = 2;
						case 8: g_esEnforcePlayer[survivor].g_iSlot = 3;
						case 16: g_esEnforcePlayer[survivor].g_iSlot = 4;
						default: g_esEnforcePlayer[survivor].g_iSlot = MT_GetRandomInt(0, 4);
					}
				}

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esEnforceCache[tank].g_flEnforceDuration;
				DataPack dpStopEnforce;
				CreateDataTimer(flDuration, tTimerStopEnforce, dpStopEnforce, TIMER_FLAG_NO_MAPCHANGE);
				dpStopEnforce.WriteCell(GetClientUserId(survivor));
				dpStopEnforce.WriteCell(GetClientUserId(tank));
				dpStopEnforce.WriteCell(messages);

				vScreenEffect(survivor, tank, g_esEnforceCache[tank].g_iEnforceEffect, flags);

				if (g_esEnforceCache[tank].g_iEnforceMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Enforce", sTankName, survivor, (g_esEnforcePlayer[survivor].g_iSlot + 1));
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Enforce", LANG_SERVER, sTankName, survivor, (g_esEnforcePlayer[survivor].g_iSlot + 1));
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esEnforcePlayer[tank].g_iRangeCooldown == -1 || g_esEnforcePlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esEnforceCache[tank].g_iHumanAbility == 1 && !g_esEnforcePlayer[tank].g_bFailed)
				{
					g_esEnforcePlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "EnforceHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esEnforceCache[tank].g_iHumanAbility == 1 && !g_esEnforcePlayer[tank].g_bNoAmmo)
		{
			g_esEnforcePlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "EnforceAmmo");
		}
	}
}

void vEnforceCopyStats2(int oldTank, int newTank)
{
	g_esEnforcePlayer[newTank].g_iAmmoCount = g_esEnforcePlayer[oldTank].g_iAmmoCount;
	g_esEnforcePlayer[newTank].g_iCooldown = g_esEnforcePlayer[oldTank].g_iCooldown;
	g_esEnforcePlayer[newTank].g_iRangeCooldown = g_esEnforcePlayer[oldTank].g_iRangeCooldown;
}

void vRemoveEnforce(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esEnforcePlayer[iSurvivor].g_bAffected && g_esEnforcePlayer[iSurvivor].g_iOwner == tank)
		{
			g_esEnforcePlayer[iSurvivor].g_bAffected = false;
			g_esEnforcePlayer[iSurvivor].g_iOwner = 0;
			g_esEnforcePlayer[iSurvivor].g_iSlot = -1;
		}
	}

	vEnforceReset2(tank);
}

void vEnforceReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vEnforceReset2(iPlayer);

			g_esEnforcePlayer[iPlayer].g_iOwner = 0;
			g_esEnforcePlayer[iPlayer].g_iSlot = -1;
		}
	}
}

void vEnforceReset2(int tank)
{
	g_esEnforcePlayer[tank].g_bAffected = false;
	g_esEnforcePlayer[tank].g_bFailed = false;
	g_esEnforcePlayer[tank].g_bNoAmmo = false;
	g_esEnforcePlayer[tank].g_iAmmoCount = 0;
	g_esEnforcePlayer[tank].g_iCooldown = -1;
	g_esEnforcePlayer[tank].g_iRangeCooldown = -1;
}

void vEnforceReset3(int survivor)
{
	g_esEnforcePlayer[survivor].g_bAffected = false;
	g_esEnforcePlayer[survivor].g_iOwner = 0;
	g_esEnforcePlayer[survivor].g_iSlot = -1;
}

Action tTimerEnforceCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esEnforceAbility[g_esEnforcePlayer[iTank].g_iTankType].g_iAccessFlags, g_esEnforcePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esEnforcePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esEnforceCache[iTank].g_iEnforceAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vEnforceAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerEnforceCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esEnforcePlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esEnforceAbility[g_esEnforcePlayer[iTank].g_iTankType].g_iAccessFlags, g_esEnforcePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esEnforcePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esEnforceCache[iTank].g_iEnforceHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esEnforceCache[iTank].g_iEnforceHitMode == 0 || g_esEnforceCache[iTank].g_iEnforceHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vEnforceHit(iSurvivor, iTank, flRandom, flChance, g_esEnforceCache[iTank].g_iEnforceHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esEnforceCache[iTank].g_iEnforceHitMode == 0 || g_esEnforceCache[iTank].g_iEnforceHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vEnforceHit(iSurvivor, iTank, flRandom, flChance, g_esEnforceCache[iTank].g_iEnforceHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopEnforce(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || !g_esEnforcePlayer[iSurvivor].g_bAffected)
	{
		vEnforceReset3(iSurvivor);

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank))
	{
		vEnforceReset3(iSurvivor);

		return Plugin_Stop;
	}

	vEnforceReset3(iSurvivor);

	int iMessage = pack.ReadCell();
	if (g_esEnforceCache[iTank].g_iEnforceMessage & iMessage)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Enforce2", iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Enforce2", LANG_SERVER, iSurvivor);
	}

	return Plugin_Continue;
}