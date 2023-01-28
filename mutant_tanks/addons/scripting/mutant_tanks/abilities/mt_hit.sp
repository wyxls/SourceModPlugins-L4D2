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

#define MT_HIT_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_HIT_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Hit Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank only takes damage in certain parts of its body.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Hit Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_HIT_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_HIT_SECTION "hitability"
#define MT_HIT_SECTION2 "hit ability"
#define MT_HIT_SECTION3 "hit_ability"
#define MT_HIT_SECTION4 "hit"

#define MT_MENU_HIT "Hit Ability"

enum struct esHitPlayer
{
	float g_flCloseAreasOnly;
	float g_flHitDamageMultiplier;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iHitAbility;
	int g_iHitGroup;
	int g_iHumanAbility;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iTankType;
}

esHitPlayer g_esHitPlayer[MAXPLAYERS + 1];

enum struct esHitAbility
{
	float g_flCloseAreasOnly;
	float g_flHitDamageMultiplier;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iHitAbility;
	int g_iHitGroup;
	int g_iHumanAbility;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esHitAbility g_esHitAbility[MT_MAXTYPES + 1];

enum struct esHitCache
{
	float g_flCloseAreasOnly;
	float g_flHitDamageMultiplier;
	float g_flOpenAreasOnly;

	int g_iHitAbility;
	int g_iHitGroup;
	int g_iHumanAbility;
	int g_iRequiresHumans;
}

esHitCache g_esHitCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_hit", cmdHitInfo, "View information about the Hit ability.");

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
void vHitClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_TraceAttack, HitTraceAttack);
}

#if !defined MT_ABILITIES_MAIN
Action cmdHitInfo(int client, int args)
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
		case false: vHitMenu(client, MT_HIT_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vHitMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_HIT_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iHitMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Hit Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iHitMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esHitCache[param1].g_iHitAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "HitDetails");
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esHitCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vHitMenu(param1, MT_HIT_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pHit = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "HitMenu", param1);
			pHit.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			if (param2 >= 0)
			{
				char sMenuOption[PLATFORM_MAX_PATH];

				switch (param2)
				{
					case 0: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Status", param1);
					case 1: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 2: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vHitDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_HIT, MT_MENU_HIT);
}

#if defined MT_ABILITIES_MAIN
void vHitMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_HIT, false))
	{
		vHitMenu(client, MT_HIT_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vHitMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_HIT, false))
	{
		FormatEx(buffer, size, "%T", "HitMenu2", client);
	}
}

Action HitTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && g_esHitCache[victim].g_iHitAbility == 1)
		{
			if (bIsAreaNarrow(victim, g_esHitCache[victim].g_flOpenAreasOnly) || bIsAreaWide(victim, g_esHitCache[victim].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esHitPlayer[victim].g_iTankType) || (g_esHitCache[victim].g_iRequiresHumans > 0 && iGetHumanCount() < g_esHitCache[victim].g_iRequiresHumans) || (!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esHitAbility[g_esHitPlayer[victim].g_iTankType].g_iAccessFlags, g_esHitPlayer[victim].g_iAccessFlags)) || (bIsSurvivor(attacker) && (MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esHitPlayer[victim].g_iTankType, g_esHitAbility[g_esHitPlayer[victim].g_iTankType].g_iImmunityFlags, g_esHitPlayer[attacker].g_iImmunityFlags) || MT_DoesSurvivorHaveRewardType(attacker, MT_REWARD_DAMAGEBOOST))) || (bIsTank(victim, MT_CHECK_FAKECLIENT) && g_esHitCache[victim].g_iHumanAbility == 0))
			{
				return Plugin_Continue;
			}

			int iBit = (hitgroup - 1), iFlag = (1 << iBit);
			damage *= g_esHitCache[victim].g_flHitDamageMultiplier;

			return !!(g_esHitCache[victim].g_iHitGroup & iFlag) ? Plugin_Changed : Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vHitPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_HIT);
}

#if defined MT_ABILITIES_MAIN
void vHitAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_HIT_SECTION);
	list2.PushString(MT_HIT_SECTION2);
	list3.PushString(MT_HIT_SECTION3);
	list4.PushString(MT_HIT_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vHitConfigsLoad(int mode)
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
				g_esHitAbility[iIndex].g_iAccessFlags = 0;
				g_esHitAbility[iIndex].g_iImmunityFlags = 0;
				g_esHitAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esHitAbility[iIndex].g_iHumanAbility = 0;
				g_esHitAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esHitAbility[iIndex].g_iRequiresHumans = 1;
				g_esHitAbility[iIndex].g_iHitAbility = 0;
				g_esHitAbility[iIndex].g_flHitDamageMultiplier = 1.5;
				g_esHitAbility[iIndex].g_iHitGroup = 1;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esHitPlayer[iPlayer].g_iAccessFlags = 0;
					g_esHitPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esHitPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esHitPlayer[iPlayer].g_iHumanAbility = 0;
					g_esHitPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esHitPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esHitPlayer[iPlayer].g_iHitAbility = 0;
					g_esHitPlayer[iPlayer].g_flHitDamageMultiplier = 0.0;
					g_esHitPlayer[iPlayer].g_iHitGroup = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vHitConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esHitPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esHitPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esHitPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esHitPlayer[admin].g_iHumanAbility, value, 0, 1);
		g_esHitPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esHitPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esHitPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esHitPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esHitPlayer[admin].g_iHitAbility = iGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esHitPlayer[admin].g_iHitAbility, value, 0, 1);
		g_esHitPlayer[admin].g_flHitDamageMultiplier = flGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "HitDamageMultiplier", "Hit Damage Multiplier", "Hit_Damage_Multiplier", "dmgmulti", g_esHitPlayer[admin].g_flHitDamageMultiplier, value, 1.0, 99999.0);
		g_esHitPlayer[admin].g_iHitGroup = iGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "HitGroup", "Hit Group", "Hit_Group", "group", g_esHitPlayer[admin].g_iHitGroup, value, 1, 127);
		g_esHitPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esHitPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esHitAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esHitAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esHitAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esHitAbility[type].g_iHumanAbility, value, 0, 1);
		g_esHitAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esHitAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esHitAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esHitAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esHitAbility[type].g_iHitAbility = iGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esHitAbility[type].g_iHitAbility, value, 0, 1);
		g_esHitAbility[type].g_flHitDamageMultiplier = flGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "HitDamageMultiplier", "Hit Damage Multiplier", "Hit_Damage_Multiplier", "dmgmulti", g_esHitAbility[type].g_flHitDamageMultiplier, value, 1.0, 99999.0);
		g_esHitAbility[type].g_iHitGroup = iGetKeyValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "HitGroup", "Hit Group", "Hit_Group", "group", g_esHitAbility[type].g_iHitGroup, value, 1, 127);
		g_esHitAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esHitAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_HIT_SECTION, MT_HIT_SECTION2, MT_HIT_SECTION3, MT_HIT_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vHitSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esHitCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esHitPlayer[tank].g_flCloseAreasOnly, g_esHitAbility[type].g_flCloseAreasOnly);
	g_esHitCache[tank].g_flHitDamageMultiplier = flGetSettingValue(apply, bHuman, g_esHitPlayer[tank].g_flHitDamageMultiplier, g_esHitAbility[type].g_flHitDamageMultiplier);
	g_esHitCache[tank].g_iHitAbility = iGetSettingValue(apply, bHuman, g_esHitPlayer[tank].g_iHitAbility, g_esHitAbility[type].g_iHitAbility);
	g_esHitCache[tank].g_iHitGroup = iGetSettingValue(apply, bHuman, g_esHitPlayer[tank].g_iHitGroup, g_esHitAbility[type].g_iHitGroup);
	g_esHitCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esHitPlayer[tank].g_iHumanAbility, g_esHitAbility[type].g_iHumanAbility);
	g_esHitCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esHitPlayer[tank].g_flOpenAreasOnly, g_esHitAbility[type].g_flOpenAreasOnly);
	g_esHitCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esHitPlayer[tank].g_iRequiresHumans, g_esHitAbility[type].g_iRequiresHumans);
	g_esHitPlayer[tank].g_iTankType = apply ? type : 0;
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif