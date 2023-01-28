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

#define MT_SPLATTER_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_SPLATTER_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Splatter Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank splatters the survivors' screens.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bSecondGame;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bSecondGame = false;
		case Engine_Left4Dead2: g_bSecondGame = true;
		default:
		{
			strcopy(error, err_max, "\"[MT] Splatter Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_SPLATTER_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_SPLATTER_SECTION "splatterability"
#define MT_SPLATTER_SECTION2 "splatter ability"
#define MT_SPLATTER_SECTION3 "splatter_ability"
#define MT_SPLATTER_SECTION4 "splatter"

#define MT_MENU_SPLATTER "Splatter Ability"

char g_sParticles[][] =
{
	"screen_adrenaline",
	"screen_adrenaline_b",
	"screen_hurt",
	"screen_hurt_b",
	"screen_blood_splatter",
	"screen_blood_splatter_a",
	"screen_blood_splatter_b",
	"screen_blood_splatter_melee_b",
	"screen_blood_splatter_melee",
	"screen_blood_splatter_melee_blunt",
	"smoker_screen_effect",
	"smoker_screen_effect_b",
	"screen_mud_splatter",
	"screen_mud_splatter_a",
	"screen_bashed",
	"screen_bashed_b",
	"screen_bashed_d",
	"burning_character_screen",
	"storm_lightning_screenglow"
};

enum struct esSplatterPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSplatterChance;
	float g_flSplatterInterval;
	float g_flSplatterRange;
	float g_flSplatterRangeChance;

	int g_iAccessFlags;
	int g_iAmmoCount;
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
	int g_iSplatterAbility;
	int g_iSplatterCooldown;
	int g_iSplatterDuration;
	int g_iSplatterEffect;
	int g_iSplatterHit;
	int g_iSplatterHitMode;
	int g_iSplatterMessage;
	int g_iSplatterRangeCooldown;
	int g_iSplatterType;
	int g_iTankType;
}

esSplatterPlayer g_esSplatterPlayer[MAXPLAYERS + 1];

enum struct esSplatterAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSplatterChance;
	float g_flSplatterInterval;
	float g_flSplatterRange;
	float g_flSplatterRangeChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iSplatterAbility;
	int g_iSplatterCooldown;
	int g_iSplatterDuration;
	int g_iSplatterEffect;
	int g_iSplatterHit;
	int g_iSplatterHitMode;
	int g_iSplatterMessage;
	int g_iSplatterRangeCooldown;
	int g_iSplatterType;
}

esSplatterAbility g_esSplatterAbility[MT_MAXTYPES + 1];

enum struct esSplatterCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flSplatterChance;
	float g_flSplatterInterval;
	float g_flSplatterRange;
	float g_flSplatterRangeChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
	int g_iSplatterAbility;
	int g_iSplatterCooldown;
	int g_iSplatterDuration;
	int g_iSplatterEffect;
	int g_iSplatterHit;
	int g_iSplatterHitMode;
	int g_iSplatterMessage;
	int g_iSplatterRangeCooldown;
	int g_iSplatterType;
}

esSplatterCache g_esSplatterCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_splatter", cmdSplatterInfo, "View information about the Splatter ability.");

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
void vSplatterMapStart()
#else
public void OnMapStart()
#endif
{
	if (g_bSecondGame)
	{
		for (int iPos = 0; iPos < (sizeof g_sParticles); iPos++)
		{
			iPrecacheParticle(g_sParticles[iPos]);
		}
	}

	vSplatterReset();
}

#if defined MT_ABILITIES_MAIN2
void vSplatterClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnSplatterTakeDamage);
	vRemoveSplatter(client);
}

#if defined MT_ABILITIES_MAIN2
void vSplatterClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveSplatter(client);
}

#if defined MT_ABILITIES_MAIN2
void vSplatterMapEnd()
#else
public void OnMapEnd()
#endif
{
	vSplatterReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdSplatterInfo(int client, int args)
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
		case false: vSplatterMenu(client, MT_SPLATTER_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vSplatterMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_SPLATTER_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iSplatterMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Splatter Ability Information");
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

int iSplatterMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSplatterCache[param1].g_iSplatterAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esSplatterCache[param1].g_iHumanAmmo - g_esSplatterPlayer[param1].g_iAmmoCount), g_esSplatterCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esSplatterCache[param1].g_iHumanAbility == 1) ? g_esSplatterCache[param1].g_iHumanCooldown : g_esSplatterCache[param1].g_iSplatterCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "SplatterDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esSplatterCache[param1].g_iSplatterDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esSplatterCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esSplatterCache[param1].g_iHumanAbility == 1) ? g_esSplatterCache[param1].g_iHumanRangeCooldown : g_esSplatterCache[param1].g_iSplatterRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vSplatterMenu(param1, MT_SPLATTER_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pSplatter = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "SplatterMenu", param1);
			pSplatter.SetTitle(sMenuTitle);
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
void vSplatterDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_SPLATTER, MT_MENU_SPLATTER);
}

#if defined MT_ABILITIES_MAIN2
void vSplatterMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_SPLATTER, false))
	{
		vSplatterMenu(client, MT_SPLATTER_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplatterMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_SPLATTER, false))
	{
		FormatEx(buffer, size, "%T", "SplatterMenu2", client);
	}
}

Action OnSplatterTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esSplatterCache[attacker].g_iSplatterHitMode == 0 || g_esSplatterCache[attacker].g_iSplatterHitMode == 1) && bIsHumanSurvivor(victim) && g_esSplatterCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esSplatterAbility[g_esSplatterPlayer[attacker].g_iTankType].g_iAccessFlags, g_esSplatterPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esSplatterPlayer[attacker].g_iTankType, g_esSplatterAbility[g_esSplatterPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esSplatterPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vSplatterHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esSplatterCache[attacker].g_flSplatterChance, g_esSplatterCache[attacker].g_iSplatterHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esSplatterCache[victim].g_iSplatterHitMode == 0 || g_esSplatterCache[victim].g_iSplatterHitMode == 2) && bIsHumanSurvivor(attacker) && g_esSplatterCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esSplatterAbility[g_esSplatterPlayer[victim].g_iTankType].g_iAccessFlags, g_esSplatterPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esSplatterPlayer[victim].g_iTankType, g_esSplatterAbility[g_esSplatterPlayer[victim].g_iTankType].g_iImmunityFlags, g_esSplatterPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vSplatterHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esSplatterCache[victim].g_flSplatterChance, g_esSplatterCache[victim].g_iSplatterHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vSplatterPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_SPLATTER);
}

#if defined MT_ABILITIES_MAIN2
void vSplatterAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_SPLATTER_SECTION);
	list2.PushString(MT_SPLATTER_SECTION2);
	list3.PushString(MT_SPLATTER_SECTION3);
	list4.PushString(MT_SPLATTER_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vSplatterCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (!g_bSecondGame || (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplatterCache[tank].g_iHumanAbility != 2))
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_SPLATTER_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_SPLATTER_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_SPLATTER_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_SPLATTER_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_SPLATTER_SECTION, false) || StrEqual(sSubset[iPos], MT_SPLATTER_SECTION2, false) || StrEqual(sSubset[iPos], MT_SPLATTER_SECTION3, false) || StrEqual(sSubset[iPos], MT_SPLATTER_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esSplatterCache[tank].g_iSplatterAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vSplatterAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerSplatterCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esSplatterCache[tank].g_iSplatterHitMode == 0 || g_esSplatterCache[tank].g_iSplatterHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vSplatterHit(survivor, tank, random, flChance, g_esSplatterCache[tank].g_iSplatterHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esSplatterCache[tank].g_iSplatterHitMode == 0 || g_esSplatterCache[tank].g_iSplatterHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vSplatterHit(survivor, tank, random, flChance, g_esSplatterCache[tank].g_iSplatterHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerSplatterCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vSplatterConfigsLoad(int mode)
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
				g_esSplatterAbility[iIndex].g_iAccessFlags = 0;
				g_esSplatterAbility[iIndex].g_iImmunityFlags = 0;
				g_esSplatterAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esSplatterAbility[iIndex].g_iComboAbility = 0;
				g_esSplatterAbility[iIndex].g_iHumanAbility = 0;
				g_esSplatterAbility[iIndex].g_iHumanAmmo = 5;
				g_esSplatterAbility[iIndex].g_iHumanCooldown = 0;
				g_esSplatterAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esSplatterAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esSplatterAbility[iIndex].g_iRequiresHumans = 1;
				g_esSplatterAbility[iIndex].g_iSplatterAbility = 0;
				g_esSplatterAbility[iIndex].g_iSplatterEffect = 0;
				g_esSplatterAbility[iIndex].g_iSplatterMessage = 0;
				g_esSplatterAbility[iIndex].g_flSplatterChance = 33.3;
				g_esSplatterAbility[iIndex].g_iSplatterCooldown = 0;
				g_esSplatterAbility[iIndex].g_iSplatterDuration = 5;
				g_esSplatterAbility[iIndex].g_iSplatterHit = 0;
				g_esSplatterAbility[iIndex].g_iSplatterHitMode = 0;
				g_esSplatterAbility[iIndex].g_flSplatterInterval = 1.0;
				g_esSplatterAbility[iIndex].g_flSplatterRange = 150.0;
				g_esSplatterAbility[iIndex].g_flSplatterRangeChance = 15.0;
				g_esSplatterAbility[iIndex].g_iSplatterRangeCooldown = 0;
				g_esSplatterAbility[iIndex].g_iSplatterType = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esSplatterPlayer[iPlayer].g_iAccessFlags = 0;
					g_esSplatterPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esSplatterPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esSplatterPlayer[iPlayer].g_iComboAbility = 0;
					g_esSplatterPlayer[iPlayer].g_iHumanAbility = 0;
					g_esSplatterPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esSplatterPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esSplatterPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esSplatterPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esSplatterPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esSplatterPlayer[iPlayer].g_iSplatterAbility = 0;
					g_esSplatterPlayer[iPlayer].g_iSplatterEffect = 0;
					g_esSplatterPlayer[iPlayer].g_iSplatterMessage = 0;
					g_esSplatterPlayer[iPlayer].g_flSplatterChance = 0.0;
					g_esSplatterPlayer[iPlayer].g_iSplatterCooldown = 0;
					g_esSplatterPlayer[iPlayer].g_iSplatterDuration = 0;
					g_esSplatterPlayer[iPlayer].g_iSplatterHit = 0;
					g_esSplatterPlayer[iPlayer].g_iSplatterHitMode = 0;
					g_esSplatterPlayer[iPlayer].g_flSplatterInterval = 0.0;
					g_esSplatterPlayer[iPlayer].g_flSplatterRange = 0.0;
					g_esSplatterPlayer[iPlayer].g_flSplatterRangeChance = 0.0;
					g_esSplatterPlayer[iPlayer].g_iSplatterRangeCooldown = 0;
					g_esSplatterPlayer[iPlayer].g_iSplatterType = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplatterConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esSplatterPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSplatterPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSplatterPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSplatterPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esSplatterPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSplatterPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esSplatterPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSplatterPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esSplatterPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSplatterPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esSplatterPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esSplatterPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esSplatterPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSplatterPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSplatterPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSplatterPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esSplatterPlayer[admin].g_iSplatterAbility = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSplatterPlayer[admin].g_iSplatterAbility, value, 0, 3);
		g_esSplatterPlayer[admin].g_iSplatterEffect = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esSplatterPlayer[admin].g_iSplatterEffect, value, 0, 7);
		g_esSplatterPlayer[admin].g_iSplatterMessage = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSplatterPlayer[admin].g_iSplatterMessage, value, 0, 1);
		g_esSplatterPlayer[admin].g_flSplatterChance = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterChance", "Splatter Chance", "Splatter_Chance", "chance", g_esSplatterPlayer[admin].g_flSplatterChance, value, 0.0, 100.0);
		g_esSplatterPlayer[admin].g_iSplatterCooldown = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterCooldown", "Splatter Cooldown", "Splatter_Cooldown", "cooldown", g_esSplatterPlayer[admin].g_iSplatterCooldown, value, 0, 99999);
		g_esSplatterPlayer[admin].g_iSplatterDuration = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterDuration", "Splatter Duration", "Splatter_Duration", "duration", g_esSplatterPlayer[admin].g_iSplatterDuration, value, 0, 99999);
		g_esSplatterPlayer[admin].g_iSplatterHit = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterHit", "Splatter Hit", "Splatter_Hit", "hit", g_esSplatterPlayer[admin].g_iSplatterHit, value, 0, 1);
		g_esSplatterPlayer[admin].g_iSplatterHitMode = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterHitMode", "Splatter Hit Mode", "Splatter_Hit_Mode", "hitmode", g_esSplatterPlayer[admin].g_iSplatterHitMode, value, 0, 2);
		g_esSplatterPlayer[admin].g_flSplatterInterval = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterInterval", "Splatter Interval", "Splatter_Interval", "interval", g_esSplatterPlayer[admin].g_flSplatterInterval, value, 0.1, 99999.0);
		g_esSplatterPlayer[admin].g_flSplatterRange = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterRange", "Splatter Range", "Splatter_Range", "range", g_esSplatterPlayer[admin].g_flSplatterRange, value, 1.0, 99999.0);
		g_esSplatterPlayer[admin].g_flSplatterRangeChance = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterRangeChance", "Splatter Range Chance", "Splatter_Range_Chance", "rangechance", g_esSplatterPlayer[admin].g_flSplatterRangeChance, value, 0.0, 100.0);
		g_esSplatterPlayer[admin].g_iSplatterRangeCooldown = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterRangeCooldown", "Splatter Range Cooldown", "Splatter_Range_Cooldown", "rangecooldown", g_esSplatterPlayer[admin].g_iSplatterRangeCooldown, value, 0, 99999);
		g_esSplatterPlayer[admin].g_iSplatterType = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterType", "Splatter Type", "Splatter_Type", "type", g_esSplatterPlayer[admin].g_iSplatterType, value, 0, sizeof g_sParticles);
		g_esSplatterPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSplatterPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esSplatterAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esSplatterAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esSplatterAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esSplatterAbility[type].g_iComboAbility, value, 0, 1);
		g_esSplatterAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esSplatterAbility[type].g_iHumanAbility, value, 0, 2);
		g_esSplatterAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esSplatterAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esSplatterAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esSplatterAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esSplatterAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esSplatterAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esSplatterAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esSplatterAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esSplatterAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esSplatterAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esSplatterAbility[type].g_iSplatterAbility = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esSplatterAbility[type].g_iSplatterAbility, value, 0, 3);
		g_esSplatterAbility[type].g_iSplatterEffect = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esSplatterAbility[type].g_iSplatterEffect, value, 0, 7);
		g_esSplatterAbility[type].g_iSplatterMessage = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esSplatterAbility[type].g_iSplatterMessage, value, 0, 1);
		g_esSplatterAbility[type].g_flSplatterChance = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterChance", "Splatter Chance", "Splatter_Chance", "chance", g_esSplatterAbility[type].g_flSplatterChance, value, 0.0, 100.0);
		g_esSplatterAbility[type].g_iSplatterCooldown = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterCooldown", "Splatter Cooldown", "Splatter_Cooldown", "cooldown", g_esSplatterAbility[type].g_iSplatterCooldown, value, 0, 99999);
		g_esSplatterAbility[type].g_iSplatterDuration = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterDuration", "Splatter Duration", "Splatter_Duration", "duration", g_esSplatterAbility[type].g_iSplatterDuration, value, 0, 99999);
		g_esSplatterAbility[type].g_iSplatterHit = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterHit", "Splatter Hit", "Splatter_Hit", "hit", g_esSplatterAbility[type].g_iSplatterHit, value, 0, 1);
		g_esSplatterAbility[type].g_iSplatterHitMode = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterHitMode", "Splatter Hit Mode", "Splatter_Hit_Mode", "hitmode", g_esSplatterAbility[type].g_iSplatterHitMode, value, 0, 2);
		g_esSplatterAbility[type].g_flSplatterInterval = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterInterval", "Splatter Interval", "Splatter_Interval", "interval", g_esSplatterAbility[type].g_flSplatterInterval, value, 0.1, 99999.0);
		g_esSplatterAbility[type].g_flSplatterRange = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterRange", "Splatter Range", "Splatter_Range", "range", g_esSplatterAbility[type].g_flSplatterRange, value, 1.0, 99999.0);
		g_esSplatterAbility[type].g_flSplatterRangeChance = flGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterRangeChance", "Splatter Range Chance", "Splatter_Range_Chance", "rangechance", g_esSplatterAbility[type].g_flSplatterRangeChance, value, 0.0, 100.0);
		g_esSplatterAbility[type].g_iSplatterRangeCooldown = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterRangeCooldown", "Splatter Range Cooldown", "Splatter_Range_Cooldown", "rangecooldown", g_esSplatterAbility[type].g_iSplatterRangeCooldown, value, 0, 99999);
		g_esSplatterAbility[type].g_iSplatterType = iGetKeyValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "SplatterType", "Splatter Type", "Splatter_Type", "type", g_esSplatterAbility[type].g_iSplatterType, value, 0, sizeof g_sParticles);
		g_esSplatterAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esSplatterAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_SPLATTER_SECTION, MT_SPLATTER_SECTION2, MT_SPLATTER_SECTION3, MT_SPLATTER_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplatterSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esSplatterCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_flCloseAreasOnly, g_esSplatterAbility[type].g_flCloseAreasOnly);
	g_esSplatterCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iComboAbility, g_esSplatterAbility[type].g_iComboAbility);
	g_esSplatterCache[tank].g_flSplatterChance = flGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_flSplatterChance, g_esSplatterAbility[type].g_flSplatterChance);
	g_esSplatterCache[tank].g_flSplatterInterval = flGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_flSplatterInterval, g_esSplatterAbility[type].g_flSplatterInterval);
	g_esSplatterCache[tank].g_flSplatterRange = flGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_flSplatterRange, g_esSplatterAbility[type].g_flSplatterRange);
	g_esSplatterCache[tank].g_flSplatterRangeChance = flGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_flSplatterRangeChance, g_esSplatterAbility[type].g_flSplatterRangeChance);
	g_esSplatterCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iHumanAbility, g_esSplatterAbility[type].g_iHumanAbility);
	g_esSplatterCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iHumanAmmo, g_esSplatterAbility[type].g_iHumanAmmo);
	g_esSplatterCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iHumanCooldown, g_esSplatterAbility[type].g_iHumanCooldown);
	g_esSplatterCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iHumanRangeCooldown, g_esSplatterAbility[type].g_iHumanRangeCooldown);
	g_esSplatterCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_flOpenAreasOnly, g_esSplatterAbility[type].g_flOpenAreasOnly);
	g_esSplatterCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iRequiresHumans, g_esSplatterAbility[type].g_iRequiresHumans);
	g_esSplatterCache[tank].g_iSplatterAbility = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iSplatterAbility, g_esSplatterAbility[type].g_iSplatterAbility);
	g_esSplatterCache[tank].g_iSplatterCooldown = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iSplatterCooldown, g_esSplatterAbility[type].g_iSplatterCooldown);
	g_esSplatterCache[tank].g_iSplatterDuration = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iSplatterDuration, g_esSplatterAbility[type].g_iSplatterDuration);
	g_esSplatterCache[tank].g_iSplatterEffect = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iSplatterEffect, g_esSplatterAbility[type].g_iSplatterEffect);
	g_esSplatterCache[tank].g_iSplatterHit = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iSplatterHit, g_esSplatterAbility[type].g_iSplatterHit);
	g_esSplatterCache[tank].g_iSplatterHitMode = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iSplatterHitMode, g_esSplatterAbility[type].g_iSplatterHitMode);
	g_esSplatterCache[tank].g_iSplatterMessage = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iSplatterMessage, g_esSplatterAbility[type].g_iSplatterMessage);
	g_esSplatterCache[tank].g_iSplatterRangeCooldown = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iSplatterRangeCooldown, g_esSplatterAbility[type].g_iSplatterRangeCooldown);
	g_esSplatterCache[tank].g_iSplatterType = iGetSettingValue(apply, bHuman, g_esSplatterPlayer[tank].g_iSplatterType, g_esSplatterAbility[type].g_iSplatterType);
	g_esSplatterPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vSplatterCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vSplatterCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveSplatter(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vSplatterEventFired(Event event, const char[] name)
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
			vSplatterCopyStats2(iBot, iTank);
			vRemoveSplatter(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vSplatterCopyStats2(iTank, iBot);
			vRemoveSplatter(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iPlayerId = event.GetInt("userid"), iPlayer = GetClientOfUserId(iPlayerId);
		if (MT_IsTankSupported(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveSplatter(iPlayer);
		}
		else if (bIsHumanSurvivor(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vStopSplatter(iPlayer);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vSplatterReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplatterAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (!g_bSecondGame || (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSplatterAbility[g_esSplatterPlayer[tank].g_iTankType].g_iAccessFlags, g_esSplatterPlayer[tank].g_iAccessFlags)) || g_esSplatterCache[tank].g_iHumanAbility == 0)))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esSplatterCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esSplatterCache[tank].g_iSplatterAbility == 1 && g_esSplatterCache[tank].g_iComboAbility == 0)
	{
		vSplatterAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplatterButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (!g_bSecondGame || bIsAreaNarrow(tank, g_esSplatterCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSplatterCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSplatterPlayer[tank].g_iTankType) || (g_esSplatterCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSplatterCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSplatterAbility[g_esSplatterPlayer[tank].g_iTankType].g_iAccessFlags, g_esSplatterPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esSplatterCache[tank].g_iSplatterAbility == 1 && g_esSplatterCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esSplatterPlayer[tank].g_iRangeCooldown == -1 || g_esSplatterPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vSplatterAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplatterHuman3", (g_esSplatterPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vSplatterChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveSplatter(tank);
}

void vSplatterAbility(int tank, float random, int pos = -1)
{
	if (!g_bSecondGame || bIsAreaNarrow(tank, g_esSplatterCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSplatterCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSplatterPlayer[tank].g_iTankType) || (g_esSplatterCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSplatterCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSplatterAbility[g_esSplatterPlayer[tank].g_iTankType].g_iAccessFlags, g_esSplatterPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esSplatterPlayer[tank].g_iAmmoCount < g_esSplatterCache[tank].g_iHumanAmmo && g_esSplatterCache[tank].g_iHumanAmmo > 0))
	{
		g_esSplatterPlayer[tank].g_bFailed = false;
		g_esSplatterPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esSplatterCache[tank].g_flSplatterRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esSplatterCache[tank].g_flSplatterRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsHumanSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esSplatterPlayer[tank].g_iTankType, g_esSplatterAbility[g_esSplatterPlayer[tank].g_iTankType].g_iImmunityFlags, g_esSplatterPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vSplatterHit(iSurvivor, tank, random, flChance, g_esSplatterCache[tank].g_iSplatterAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplatterCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplatterHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplatterCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplatterAmmo");
	}
}

void vSplatterHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (!g_bSecondGame || bIsAreaNarrow(tank, g_esSplatterCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esSplatterCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSplatterPlayer[tank].g_iTankType) || (g_esSplatterCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSplatterCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esSplatterAbility[g_esSplatterPlayer[tank].g_iTankType].g_iAccessFlags, g_esSplatterPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esSplatterPlayer[tank].g_iTankType, g_esSplatterAbility[g_esSplatterPlayer[tank].g_iTankType].g_iImmunityFlags, g_esSplatterPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esSplatterPlayer[tank].g_iRangeCooldown != -1 && g_esSplatterPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esSplatterPlayer[tank].g_iCooldown != -1 && g_esSplatterPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsHumanSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esSplatterPlayer[tank].g_iAmmoCount < g_esSplatterCache[tank].g_iHumanAmmo && g_esSplatterCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esSplatterPlayer[survivor].g_bAffected)
			{
				g_esSplatterPlayer[survivor].g_bAffected = true;
				g_esSplatterPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esSplatterPlayer[tank].g_iRangeCooldown == -1 || g_esSplatterPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplatterCache[tank].g_iHumanAbility == 1)
					{
						g_esSplatterPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplatterHuman", g_esSplatterPlayer[tank].g_iAmmoCount, g_esSplatterCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esSplatterCache[tank].g_iSplatterRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplatterCache[tank].g_iHumanAbility == 1 && g_esSplatterPlayer[tank].g_iAmmoCount < g_esSplatterCache[tank].g_iHumanAmmo && g_esSplatterCache[tank].g_iHumanAmmo > 0) ? g_esSplatterCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esSplatterPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esSplatterPlayer[tank].g_iRangeCooldown != -1 && g_esSplatterPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplatterHuman5", (g_esSplatterPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esSplatterPlayer[tank].g_iCooldown == -1 || g_esSplatterPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esSplatterCache[tank].g_iSplatterCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplatterCache[tank].g_iHumanAbility == 1) ? g_esSplatterCache[tank].g_iHumanCooldown : iCooldown;
					g_esSplatterPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esSplatterPlayer[tank].g_iCooldown != -1 && g_esSplatterPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplatterHuman5", (g_esSplatterPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esSplatterCache[tank].g_flSplatterInterval;
				DataPack dpSplatter;
				CreateDataTimer(flInterval, tTimerSplatter, dpSplatter, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpSplatter.WriteCell(GetClientUserId(survivor));
				dpSplatter.WriteCell(GetClientUserId(tank));
				dpSplatter.WriteCell(g_esSplatterPlayer[tank].g_iTankType);
				dpSplatter.WriteCell(messages);
				dpSplatter.WriteCell(enabled);
				dpSplatter.WriteCell(pos);
				dpSplatter.WriteCell(iTime);
				dpSplatter.WriteFloat(flInterval);

				vScreenEffect(survivor, tank, g_esSplatterCache[tank].g_iSplatterEffect, flags);

				if (g_esSplatterCache[tank].g_iSplatterMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Splatter", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Splatter", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esSplatterPlayer[tank].g_iRangeCooldown == -1 || g_esSplatterPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplatterCache[tank].g_iHumanAbility == 1 && !g_esSplatterPlayer[tank].g_bFailed)
				{
					g_esSplatterPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplatterHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esSplatterCache[tank].g_iHumanAbility == 1 && !g_esSplatterPlayer[tank].g_bNoAmmo)
		{
			g_esSplatterPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "SplatterAmmo");
		}
	}
}

void vSplatterCopyStats2(int oldTank, int newTank)
{
	g_esSplatterPlayer[newTank].g_iAmmoCount = g_esSplatterPlayer[oldTank].g_iAmmoCount;
	g_esSplatterPlayer[newTank].g_iCooldown = g_esSplatterPlayer[oldTank].g_iCooldown;
	g_esSplatterPlayer[newTank].g_iRangeCooldown = g_esSplatterPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveSplatter(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esSplatterPlayer[iSurvivor].g_bAffected && g_esSplatterPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esSplatterPlayer[iSurvivor].g_bAffected = false;
			g_esSplatterPlayer[iSurvivor].g_iOwner = 0;

			vStopSplatter(iSurvivor);
		}
	}

	vSplatterReset3(tank);
}

void vSplatterReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vSplatterReset3(iPlayer);
		}
	}
}

void vSplatterReset2(int survivor, int tank, int messages)
{
	g_esSplatterPlayer[survivor].g_bAffected = false;
	g_esSplatterPlayer[survivor].g_iOwner = 0;

	vStopSplatter(survivor);

	if (g_esSplatterCache[tank].g_iSplatterMessage & messages)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Splatter2", survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Splatter2", LANG_SERVER, survivor);
	}
}

void vSplatterReset3(int tank)
{
	g_esSplatterPlayer[tank].g_bAffected = false;
	g_esSplatterPlayer[tank].g_bFailed = false;
	g_esSplatterPlayer[tank].g_bNoAmmo = false;
	g_esSplatterPlayer[tank].g_iAmmoCount = 0;
	g_esSplatterPlayer[tank].g_iCooldown = -1;
	g_esSplatterPlayer[tank].g_iRangeCooldown = -1;
}

void vStopSplatter(int survivor)
{
	MT_TE_SetupStopAllParticles(survivor);
	TE_SendToClient(survivor);
}

Action tTimerSplatterCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!g_bSecondGame || !MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSplatterAbility[g_esSplatterPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSplatterPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSplatterPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSplatterCache[iTank].g_iSplatterAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vSplatterAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerSplatterCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!g_bSecondGame || !bIsHumanSurvivor(iSurvivor) || g_esSplatterPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSplatterAbility[g_esSplatterPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSplatterPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSplatterPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esSplatterCache[iTank].g_iSplatterHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esSplatterCache[iTank].g_iSplatterHitMode == 0 || g_esSplatterCache[iTank].g_iSplatterHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vSplatterHit(iSurvivor, iTank, flRandom, flChance, g_esSplatterCache[iTank].g_iSplatterHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esSplatterCache[iTank].g_iSplatterHitMode == 0 || g_esSplatterCache[iTank].g_iSplatterHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vSplatterHit(iSurvivor, iTank, flRandom, flChance, g_esSplatterCache[iTank].g_iSplatterHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerSplatter(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!g_bSecondGame || !MT_IsCorePluginEnabled() || !bIsHumanSurvivor(iSurvivor))
	{
		g_esSplatterPlayer[iSurvivor].g_bAffected = false;
		g_esSplatterPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esSplatterCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esSplatterCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esSplatterPlayer[iTank].g_iTankType) || (g_esSplatterCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esSplatterCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esSplatterAbility[g_esSplatterPlayer[iTank].g_iTankType].g_iAccessFlags, g_esSplatterPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esSplatterPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esSplatterPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esSplatterPlayer[iTank].g_iTankType, g_esSplatterAbility[g_esSplatterPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esSplatterPlayer[iSurvivor].g_iImmunityFlags) || !g_esSplatterPlayer[iSurvivor].g_bAffected || MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE))
	{
		vSplatterReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iSplatterEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esSplatterCache[iTank].g_iSplatterDuration,
		iTime = pack.ReadCell();
	if (iSplatterEnabled == 0 || (iTime + iDuration) < GetTime() || !g_esSplatterPlayer[iSurvivor].g_bAffected)
	{
		vSplatterReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iIndex = (g_esSplatterCache[iTank].g_iSplatterType > 0) ? (g_esSplatterCache[iTank].g_iSplatterType - 1) : MT_GetRandomInt(0, (sizeof g_sParticles - 1)),
		iParticle = MT_GetParticleIndex(g_sParticles[iIndex]);
	if (iParticle == INVALID_STRING_INDEX)
	{
		vSplatterReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	MT_TE_SetupParticleAttachment(iParticle, 1, iSurvivor, true);
	TE_SendToClient(iSurvivor);

	return Plugin_Continue;
}