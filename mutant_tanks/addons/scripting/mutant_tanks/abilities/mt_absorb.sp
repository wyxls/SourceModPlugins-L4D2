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

#define MT_ABSORB_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_ABSORB_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Absorb Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank absorbs most of the damage it receives.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Absorb Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_ABSORB_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SOUND_METAL "physics/metal/metal_solid_impact_hard5.wav"

#define MT_ABSORB_SECTION "absorbability"
#define MT_ABSORB_SECTION2 "absorb ability"
#define MT_ABSORB_SECTION3 "absorb_ability"
#define MT_ABSORB_SECTION4 "absorb"

#define MT_MENU_ABSORB "Absorb Ability"

enum struct esAbsorbPlayer
{
	bool g_bActivated;

	float g_flAbsorbBulletDivisor;
	float g_flAbsorbChance;
	float g_flAbsorbExplosiveDivisor;
	float g_flAbsorbFireDivisor;
	float g_flAbsorbHittableDivisor;
	float g_flAbsorbMeleeDivisor;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAbsorbAbility;
	int g_iAbsorbCooldown;
	int g_iAbsorbDuration;
	int g_iAbsorbMessage;
	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iDuration;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iTankType;
}

esAbsorbPlayer g_esAbsorbPlayer[MAXPLAYERS + 1];

enum struct esAbsorbAbility
{
	float g_flAbsorbBulletDivisor;
	float g_flAbsorbChance;
	float g_flAbsorbExplosiveDivisor;
	float g_flAbsorbFireDivisor;
	float g_flAbsorbHittableDivisor;
	float g_flAbsorbMeleeDivisor;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAbsorbAbility;
	int g_iAbsorbCooldown;
	int g_iAbsorbDuration;
	int g_iAbsorbMessage;
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
}

esAbsorbAbility g_esAbsorbAbility[MT_MAXTYPES + 1];

enum struct esAbsorbCache
{
	float g_flAbsorbBulletDivisor;
	float g_flAbsorbChance;
	float g_flAbsorbExplosiveDivisor;
	float g_flAbsorbFireDivisor;
	float g_flAbsorbHittableDivisor;
	float g_flAbsorbMeleeDivisor;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAbsorbAbility;
	int g_iAbsorbCooldown;
	int g_iAbsorbDuration;
	int g_iAbsorbMessage;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
}

esAbsorbCache g_esAbsorbCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_absorb", cmdAbsorbInfo, "View information about the Absorb ability.");

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
void vAbsorbMapStart()
#else
public void OnMapStart()
#endif
{
	vAbsorbReset();
}

#if defined MT_ABILITIES_MAIN
void vAbsorbClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnAbsorbTakeDamage);
	vRemoveAbsorb(client);
}

#if defined MT_ABILITIES_MAIN
void vAbsorbClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveAbsorb(client);
}

#if defined MT_ABILITIES_MAIN
void vAbsorbMapEnd()
#else
public void OnMapEnd()
#endif
{
	vAbsorbReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdAbsorbInfo(int client, int args)
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
		case false: vAbsorbMenu(client, MT_ABSORB_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vAbsorbMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_ABSORB_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iAbsorbMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Absorb Ability Information");
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

int iAbsorbMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esAbsorbCache[param1].g_iAbsorbAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esAbsorbCache[param1].g_iHumanAmmo - g_esAbsorbPlayer[param1].g_iAmmoCount), g_esAbsorbCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esAbsorbCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esAbsorbCache[param1].g_iHumanAbility == 1) ? g_esAbsorbCache[param1].g_iHumanCooldown : g_esAbsorbCache[param1].g_iAbsorbCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbsorbDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esAbsorbCache[param1].g_iHumanAbility == 1) ? g_esAbsorbCache[param1].g_iHumanDuration : g_esAbsorbCache[param1].g_iAbsorbDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esAbsorbCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vAbsorbMenu(param1, MT_ABSORB_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pAbsorb = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "AbsorbMenu", param1);
			pAbsorb.SetTitle(sMenuTitle);
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

#if defined MT_ABILITIES_MAIN
void vAbsorbDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_ABSORB, MT_MENU_ABSORB);
}

#if defined MT_ABILITIES_MAIN
void vAbsorbMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_ABSORB, false))
	{
		vAbsorbMenu(client, MT_ABSORB_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vAbsorbMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_ABSORB, false))
	{
		FormatEx(buffer, size, "%T", "AbsorbMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vAbsorbPlayerRunCmd(int client)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsTankSupported(client) || !g_esAbsorbPlayer[client].g_bActivated || (bIsTank(client, MT_CHECK_FAKECLIENT) && g_esAbsorbCache[client].g_iHumanMode == 1) || g_esAbsorbPlayer[client].g_iDuration == -1)
	{
#if defined MT_ABILITIES_MAIN
		return;
#else
		return Plugin_Continue;
#endif
	}

	int iTime = GetTime();
	if (g_esAbsorbPlayer[client].g_iDuration < iTime)
	{
		if (g_esAbsorbPlayer[client].g_iCooldown == -1 || g_esAbsorbPlayer[client].g_iCooldown < iTime)
		{
			vAbsorbReset3(client);
		}

		vAbsorbReset2(client);
	}
#if !defined MT_ABILITIES_MAIN
	return Plugin_Continue;
#endif
}

Action OnAbsorbTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && g_esAbsorbPlayer[victim].g_bActivated)
		{
			bool bChanged = false, bSurvivor = bIsSurvivor(attacker);
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esAbsorbAbility[g_esAbsorbPlayer[victim].g_iTankType].g_iAccessFlags, g_esAbsorbPlayer[victim].g_iAccessFlags)) || (bSurvivor && (MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esAbsorbPlayer[victim].g_iTankType, g_esAbsorbAbility[g_esAbsorbPlayer[victim].g_iTankType].g_iImmunityFlags, g_esAbsorbPlayer[attacker].g_iImmunityFlags))))
			{
				return Plugin_Continue;
			}

			if (g_esAbsorbCache[victim].g_flAbsorbBulletDivisor > 1.0 && (damagetype & DMG_BULLET))
			{
				bChanged = true;
				damage /= g_esAbsorbCache[victim].g_flAbsorbBulletDivisor;
			}
			else if (g_esAbsorbCache[victim].g_flAbsorbExplosiveDivisor > 1.0 && ((damagetype & DMG_BLAST) || (damagetype & DMG_BLAST_SURFACE) || (damagetype & DMG_AIRBOAT) || (damagetype & DMG_PLASMA)))
			{
				bChanged = true;
				damage /= g_esAbsorbCache[victim].g_flAbsorbExplosiveDivisor;
			}
			else if (g_esAbsorbCache[victim].g_flAbsorbFireDivisor > 1.0 && ((damagetype & DMG_BURN) || (damagetype & DMG_DIRECT)))
			{
				bChanged = true;
				damage /= g_esAbsorbCache[victim].g_flAbsorbFireDivisor;
			}
			else if (g_esAbsorbCache[victim].g_flAbsorbHittableDivisor > 1.0 && (damagetype & DMG_CRUSH) && bIsValidEntity(inflictor) && HasEntProp(inflictor, Prop_Send, "m_isCarryable"))
			{
				bChanged = true;
				damage /= g_esAbsorbCache[victim].g_flAbsorbHittableDivisor;
			}
			else if (g_esAbsorbCache[victim].g_flAbsorbMeleeDivisor > 1.0 && ((damagetype & DMG_SLASH) || (damagetype & DMG_CLUB)))
			{
				bChanged = true;
				damage /= g_esAbsorbCache[victim].g_flAbsorbMeleeDivisor;
			}

			if (bChanged)
			{
				if (damage < 1.0)
				{
					damage = 1.0;
				}

				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vAbsorbPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_ABSORB);
}

#if defined MT_ABILITIES_MAIN
void vAbsorbAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_ABSORB_SECTION);
	list2.PushString(MT_ABSORB_SECTION2);
	list3.PushString(MT_ABSORB_SECTION3);
	list4.PushString(MT_ABSORB_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vAbsorbCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAbsorbCache[tank].g_iHumanAbility != 2)
	{
		g_esAbsorbAbility[g_esAbsorbPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esAbsorbAbility[g_esAbsorbPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_ABSORB_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_ABSORB_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_ABSORB_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_ABSORB_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esAbsorbCache[tank].g_iAbsorbAbility == 1 && g_esAbsorbCache[tank].g_iComboAbility == 1 && !g_esAbsorbPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_ABSORB_SECTION, false) || StrEqual(sSubset[iPos], MT_ABSORB_SECTION2, false) || StrEqual(sSubset[iPos], MT_ABSORB_SECTION3, false) || StrEqual(sSubset[iPos], MT_ABSORB_SECTION4, false))
				{
					g_esAbsorbAbility[g_esAbsorbPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vAbsorb(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerAbsorbCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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

#if defined MT_ABILITIES_MAIN
void vAbsorbConfigsLoad(int mode)
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
				g_esAbsorbAbility[iIndex].g_iAccessFlags = 0;
				g_esAbsorbAbility[iIndex].g_iImmunityFlags = 0;
				g_esAbsorbAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esAbsorbAbility[iIndex].g_iComboAbility = 0;
				g_esAbsorbAbility[iIndex].g_iComboPosition = -1;
				g_esAbsorbAbility[iIndex].g_iHumanAbility = 0;
				g_esAbsorbAbility[iIndex].g_iHumanAmmo = 5;
				g_esAbsorbAbility[iIndex].g_iHumanCooldown = 0;
				g_esAbsorbAbility[iIndex].g_iHumanDuration = 5;
				g_esAbsorbAbility[iIndex].g_iHumanMode = 1;
				g_esAbsorbAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esAbsorbAbility[iIndex].g_iRequiresHumans = 1;
				g_esAbsorbAbility[iIndex].g_iAbsorbAbility = 0;
				g_esAbsorbAbility[iIndex].g_iAbsorbMessage = 0;
				g_esAbsorbAbility[iIndex].g_flAbsorbBulletDivisor = 20.0;
				g_esAbsorbAbility[iIndex].g_flAbsorbChance = 33.3;
				g_esAbsorbAbility[iIndex].g_iAbsorbCooldown = 0;
				g_esAbsorbAbility[iIndex].g_iAbsorbDuration = 5;
				g_esAbsorbAbility[iIndex].g_flAbsorbExplosiveDivisor = 20.0;
				g_esAbsorbAbility[iIndex].g_flAbsorbFireDivisor = 200.0;
				g_esAbsorbAbility[iIndex].g_flAbsorbHittableDivisor = 20.0;
				g_esAbsorbAbility[iIndex].g_flAbsorbMeleeDivisor = 200.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esAbsorbPlayer[iPlayer].g_iAccessFlags = 0;
					g_esAbsorbPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esAbsorbPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esAbsorbPlayer[iPlayer].g_iComboAbility = 0;
					g_esAbsorbPlayer[iPlayer].g_iHumanAbility = 0;
					g_esAbsorbPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esAbsorbPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esAbsorbPlayer[iPlayer].g_iHumanDuration = 0;
					g_esAbsorbPlayer[iPlayer].g_iHumanMode = 0;
					g_esAbsorbPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esAbsorbPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esAbsorbPlayer[iPlayer].g_iAbsorbAbility = 0;
					g_esAbsorbPlayer[iPlayer].g_iAbsorbMessage = 0;
					g_esAbsorbPlayer[iPlayer].g_flAbsorbBulletDivisor = 0.0;
					g_esAbsorbPlayer[iPlayer].g_flAbsorbChance = 0.0;
					g_esAbsorbPlayer[iPlayer].g_iAbsorbCooldown = 0;
					g_esAbsorbPlayer[iPlayer].g_iAbsorbDuration = 0;
					g_esAbsorbPlayer[iPlayer].g_flAbsorbExplosiveDivisor = 0.0;
					g_esAbsorbPlayer[iPlayer].g_flAbsorbFireDivisor = 0.0;
					g_esAbsorbPlayer[iPlayer].g_flAbsorbHittableDivisor = 0.0;
					g_esAbsorbPlayer[iPlayer].g_flAbsorbMeleeDivisor = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vAbsorbConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esAbsorbPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esAbsorbPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esAbsorbPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esAbsorbPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esAbsorbPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esAbsorbPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esAbsorbPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esAbsorbPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esAbsorbPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esAbsorbPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esAbsorbPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esAbsorbPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esAbsorbPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esAbsorbPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esAbsorbPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esAbsorbPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esAbsorbPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esAbsorbPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esAbsorbPlayer[admin].g_iAbsorbAbility = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esAbsorbPlayer[admin].g_iAbsorbAbility, value, 0, 1);
		g_esAbsorbPlayer[admin].g_iAbsorbMessage = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esAbsorbPlayer[admin].g_iAbsorbMessage, value, 0, 1);
		g_esAbsorbPlayer[admin].g_flAbsorbBulletDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbBulletDivisor", "Absorb Bullet Divisor", "Absorb_Bullet_Divisor", "bullet", g_esAbsorbPlayer[admin].g_flAbsorbBulletDivisor, value, 1.0, 99999.0);
		g_esAbsorbPlayer[admin].g_flAbsorbChance = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbChance", "Absorb Chance", "Absorb_Chance", "chance", g_esAbsorbPlayer[admin].g_flAbsorbChance, value, 0.0, 100.0);
		g_esAbsorbPlayer[admin].g_iAbsorbCooldown = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbCooldown", "Absorb Cooldown", "Absorb_Cooldown", "cooldown", g_esAbsorbPlayer[admin].g_iAbsorbCooldown, value, 0, 99999);
		g_esAbsorbPlayer[admin].g_iAbsorbDuration = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbDuration", "Absorb Duration", "Absorb_Duration", "duration", g_esAbsorbPlayer[admin].g_iAbsorbDuration, value, 0, 99999);
		g_esAbsorbPlayer[admin].g_flAbsorbExplosiveDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbExplosiveDivisor", "Absorb Explosive Divisor", "Absorb_Explosive_Divisor", "explosive", g_esAbsorbPlayer[admin].g_flAbsorbExplosiveDivisor, value, 1.0, 99999.0);
		g_esAbsorbPlayer[admin].g_flAbsorbFireDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbFireDivisor", "Absorb Fire Divisor", "Absorb_Fire_Divisor", "fire", g_esAbsorbPlayer[admin].g_flAbsorbFireDivisor, value, 1.0, 99999.0);
		g_esAbsorbPlayer[admin].g_flAbsorbHittableDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbHittableDivisor", "Absorb Hittable Divisor", "Absorb_Hittable_Divisor", "hittable", g_esAbsorbPlayer[admin].g_flAbsorbHittableDivisor, value, 1.0, 99999.0);
		g_esAbsorbPlayer[admin].g_flAbsorbMeleeDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbMeleeDivisor", "Absorb Melee Divisor", "Absorb_Melee_Divisor", "melee", g_esAbsorbPlayer[admin].g_flAbsorbMeleeDivisor, value, 1.0, 99999.0);
		g_esAbsorbPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esAbsorbPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esAbsorbAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esAbsorbAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esAbsorbAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esAbsorbAbility[type].g_iComboAbility, value, 0, 1);
		g_esAbsorbAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esAbsorbAbility[type].g_iHumanAbility, value, 0, 2);
		g_esAbsorbAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esAbsorbAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esAbsorbAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esAbsorbAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esAbsorbAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esAbsorbAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esAbsorbAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esAbsorbAbility[type].g_iHumanMode, value, 0, 1);
		g_esAbsorbAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esAbsorbAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esAbsorbAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esAbsorbAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esAbsorbAbility[type].g_iAbsorbAbility = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esAbsorbAbility[type].g_iAbsorbAbility, value, 0, 1);
		g_esAbsorbAbility[type].g_iAbsorbMessage = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esAbsorbAbility[type].g_iAbsorbMessage, value, 0, 1);
		g_esAbsorbAbility[type].g_flAbsorbBulletDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbBulletDivisor", "Absorb Bullet Divisor", "Absorb_Bullet_Divisor", "bullet", g_esAbsorbAbility[type].g_flAbsorbBulletDivisor, value, 1.0, 99999.0);
		g_esAbsorbAbility[type].g_flAbsorbChance = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbChance", "Absorb Chance", "Absorb_Chance", "chance", g_esAbsorbAbility[type].g_flAbsorbChance, value, 0.0, 100.0);
		g_esAbsorbAbility[type].g_iAbsorbCooldown = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbCooldown", "Absorb Cooldown", "Absorb_Cooldown", "cooldown", g_esAbsorbAbility[type].g_iAbsorbCooldown, value, 0, 99999);
		g_esAbsorbAbility[type].g_iAbsorbDuration = iGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbDuration", "Absorb Duration", "Absorb_Duration", "duration", g_esAbsorbAbility[type].g_iAbsorbDuration, value, 0, 99999);
		g_esAbsorbAbility[type].g_flAbsorbExplosiveDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbExplosiveDivisor", "Absorb Explosive Divisor", "Absorb_Explosive_Divisor", "explosive", g_esAbsorbAbility[type].g_flAbsorbExplosiveDivisor, value, 1.0, 99999.0);
		g_esAbsorbAbility[type].g_flAbsorbFireDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbFireDivisor", "Absorb Fire Divisor", "Absorb_Fire_Divisor", "fire", g_esAbsorbAbility[type].g_flAbsorbFireDivisor, value, 1.0, 99999.0);
		g_esAbsorbAbility[type].g_flAbsorbHittableDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbHittableDivisor", "Absorb Hittable Divisor", "Absorb_Hittable_Divisor", "hittable", g_esAbsorbAbility[type].g_flAbsorbHittableDivisor, value, 1.0, 99999.0);
		g_esAbsorbAbility[type].g_flAbsorbMeleeDivisor = flGetKeyValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AbsorbMeleeDivisor", "Absorb Melee Divisor", "Absorb_Melee_Divisor", "melee", g_esAbsorbAbility[type].g_flAbsorbMeleeDivisor, value, 1.0, 99999.0);
		g_esAbsorbAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esAbsorbAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ABSORB_SECTION, MT_ABSORB_SECTION2, MT_ABSORB_SECTION3, MT_ABSORB_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vAbsorbSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esAbsorbCache[tank].g_flAbsorbBulletDivisor = flGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_flAbsorbBulletDivisor, g_esAbsorbAbility[type].g_flAbsorbBulletDivisor);
	g_esAbsorbCache[tank].g_flAbsorbChance = flGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_flAbsorbChance, g_esAbsorbAbility[type].g_flAbsorbChance);
	g_esAbsorbCache[tank].g_flAbsorbExplosiveDivisor = flGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_flAbsorbExplosiveDivisor, g_esAbsorbAbility[type].g_flAbsorbExplosiveDivisor);
	g_esAbsorbCache[tank].g_flAbsorbFireDivisor = flGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_flAbsorbFireDivisor, g_esAbsorbAbility[type].g_flAbsorbFireDivisor);
	g_esAbsorbCache[tank].g_flAbsorbHittableDivisor = flGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_flAbsorbHittableDivisor, g_esAbsorbAbility[type].g_flAbsorbHittableDivisor);
	g_esAbsorbCache[tank].g_flAbsorbMeleeDivisor = flGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_flAbsorbMeleeDivisor, g_esAbsorbAbility[type].g_flAbsorbMeleeDivisor);
	g_esAbsorbCache[tank].g_iAbsorbAbility = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iAbsorbAbility, g_esAbsorbAbility[type].g_iAbsorbAbility);
	g_esAbsorbCache[tank].g_iAbsorbCooldown = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iAbsorbCooldown, g_esAbsorbAbility[type].g_iAbsorbCooldown);
	g_esAbsorbCache[tank].g_iAbsorbDuration = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iAbsorbDuration, g_esAbsorbAbility[type].g_iAbsorbDuration);
	g_esAbsorbCache[tank].g_iAbsorbMessage = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iAbsorbMessage, g_esAbsorbAbility[type].g_iAbsorbMessage);
	g_esAbsorbCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_flCloseAreasOnly, g_esAbsorbAbility[type].g_flCloseAreasOnly);
	g_esAbsorbCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iComboAbility, g_esAbsorbAbility[type].g_iComboAbility);
	g_esAbsorbCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iHumanAbility, g_esAbsorbAbility[type].g_iHumanAbility);
	g_esAbsorbCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iHumanAmmo, g_esAbsorbAbility[type].g_iHumanAmmo);
	g_esAbsorbCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iHumanCooldown, g_esAbsorbAbility[type].g_iHumanCooldown);
	g_esAbsorbCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iHumanDuration, g_esAbsorbAbility[type].g_iHumanDuration);
	g_esAbsorbCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iHumanMode, g_esAbsorbAbility[type].g_iHumanMode);
	g_esAbsorbCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_flOpenAreasOnly, g_esAbsorbAbility[type].g_flOpenAreasOnly);
	g_esAbsorbCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esAbsorbPlayer[tank].g_iRequiresHumans, g_esAbsorbAbility[type].g_iRequiresHumans);
	g_esAbsorbPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vAbsorbCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vAbsorbCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveAbsorb(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vAbsorbEventFired(Event event, const char[] name)
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
			vAbsorbCopyStats2(iBot, iTank);
			vRemoveAbsorb(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vAbsorbCopyStats2(iTank, iBot);
			vRemoveAbsorb(iTank);
		}
	}
	else if (StrEqual(name, "player_incapacitated") || StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveAbsorb(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vAbsorbReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vAbsorbAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAbsorbAbility[g_esAbsorbPlayer[tank].g_iTankType].g_iAccessFlags, g_esAbsorbPlayer[tank].g_iAccessFlags)) || g_esAbsorbCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esAbsorbCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esAbsorbCache[tank].g_iAbsorbAbility == 1 && g_esAbsorbCache[tank].g_iComboAbility == 0 && !g_esAbsorbPlayer[tank].g_bActivated)
	{
		vAbsorbAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN
void vAbsorbButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esAbsorbCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAbsorbCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAbsorbPlayer[tank].g_iTankType) || (g_esAbsorbCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAbsorbCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAbsorbAbility[g_esAbsorbPlayer[tank].g_iTankType].g_iAccessFlags, g_esAbsorbPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esAbsorbCache[tank].g_iAbsorbAbility == 1 && g_esAbsorbCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esAbsorbPlayer[tank].g_iCooldown != -1 && g_esAbsorbPlayer[tank].g_iCooldown > iTime;

			switch (g_esAbsorbCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esAbsorbPlayer[tank].g_bActivated && !bRecharging)
					{
						vAbsorbAbility(tank);
					}
					else if (g_esAbsorbPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbHuman4", (g_esAbsorbPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esAbsorbPlayer[tank].g_iAmmoCount < g_esAbsorbCache[tank].g_iHumanAmmo && g_esAbsorbCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esAbsorbPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esAbsorbPlayer[tank].g_bActivated = true;
							g_esAbsorbPlayer[tank].g_iAmmoCount++;

							MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbHuman", g_esAbsorbPlayer[tank].g_iAmmoCount, g_esAbsorbCache[tank].g_iHumanAmmo);
						}
						else if (g_esAbsorbPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbHuman4", (g_esAbsorbPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vAbsorbButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esAbsorbCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esAbsorbCache[tank].g_iHumanMode == 1 && g_esAbsorbPlayer[tank].g_bActivated && (g_esAbsorbPlayer[tank].g_iCooldown == -1 || g_esAbsorbPlayer[tank].g_iCooldown < GetTime()))
		{
			vAbsorbReset2(tank);
			vAbsorbReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vAbsorbChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveAbsorb(tank);
}

void vAbsorb(int tank, int pos = -1)
{
	int iTime = GetTime();
	if (g_esAbsorbPlayer[tank].g_iCooldown != -1 && g_esAbsorbPlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	int iDuration = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 5, pos)) : g_esAbsorbCache[tank].g_iAbsorbDuration;
	iDuration = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAbsorbCache[tank].g_iHumanAbility == 1) ? g_esAbsorbCache[tank].g_iHumanDuration : iDuration;
	g_esAbsorbPlayer[tank].g_bActivated = true;
	g_esAbsorbPlayer[tank].g_iDuration = (iTime + iDuration);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAbsorbCache[tank].g_iHumanAbility == 1)
	{
		g_esAbsorbPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbHuman", g_esAbsorbPlayer[tank].g_iAmmoCount, g_esAbsorbCache[tank].g_iHumanAmmo);
	}

	if (g_esAbsorbCache[tank].g_iAbsorbMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Absorb", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Absorb", LANG_SERVER, sTankName);
	}
}

void vAbsorbAbility(int tank)
{
	if ((g_esAbsorbPlayer[tank].g_iCooldown != -1 && g_esAbsorbPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esAbsorbCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esAbsorbCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esAbsorbPlayer[tank].g_iTankType) || (g_esAbsorbCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esAbsorbCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esAbsorbAbility[g_esAbsorbPlayer[tank].g_iTankType].g_iAccessFlags, g_esAbsorbPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esAbsorbPlayer[tank].g_iAmmoCount < g_esAbsorbCache[tank].g_iHumanAmmo && g_esAbsorbCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esAbsorbCache[tank].g_flAbsorbChance)
		{
			vAbsorb(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAbsorbCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAbsorbCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbAmmo");
	}
}

void vAbsorbCopyStats2(int oldTank, int newTank)
{
	g_esAbsorbPlayer[newTank].g_iAmmoCount = g_esAbsorbPlayer[oldTank].g_iAmmoCount;
	g_esAbsorbPlayer[newTank].g_iCooldown = g_esAbsorbPlayer[oldTank].g_iCooldown;
}

void vRemoveAbsorb(int tank)
{
	g_esAbsorbPlayer[tank].g_bActivated = false;
	g_esAbsorbPlayer[tank].g_iAmmoCount = 0;
	g_esAbsorbPlayer[tank].g_iCooldown = -1;
	g_esAbsorbPlayer[tank].g_iDuration = -1;
}

void vAbsorbReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveAbsorb(iPlayer);
		}
	}
}

void vAbsorbReset2(int tank)
{
	g_esAbsorbPlayer[tank].g_bActivated = false;
	g_esAbsorbPlayer[tank].g_iDuration = -1;

	if (g_esAbsorbCache[tank].g_iAbsorbMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Absorb2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Absorb2", LANG_SERVER, sTankName);
	}
}

void vAbsorbReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esAbsorbAbility[g_esAbsorbPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esAbsorbCache[tank].g_iAbsorbCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esAbsorbCache[tank].g_iHumanAbility == 1 && g_esAbsorbCache[tank].g_iHumanMode == 0 && g_esAbsorbPlayer[tank].g_iAmmoCount < g_esAbsorbCache[tank].g_iHumanAmmo && g_esAbsorbCache[tank].g_iHumanAmmo > 0) ? g_esAbsorbCache[tank].g_iHumanCooldown : iCooldown;
	g_esAbsorbPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esAbsorbPlayer[tank].g_iCooldown != -1 && g_esAbsorbPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "AbsorbHuman5", (g_esAbsorbPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerAbsorbCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esAbsorbAbility[g_esAbsorbPlayer[iTank].g_iTankType].g_iAccessFlags, g_esAbsorbPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esAbsorbPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esAbsorbCache[iTank].g_iAbsorbAbility == 0 || g_esAbsorbPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vAbsorb(iTank, iPos);

	return Plugin_Continue;
}