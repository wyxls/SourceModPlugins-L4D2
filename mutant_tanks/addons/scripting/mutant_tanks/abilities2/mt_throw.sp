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

#define MT_THROW_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_THROW_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Throw Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank throws cars, special infected, Witches, or itself.",
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
			strcopy(error, err_max, "\"[MT] Throw Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_THROW_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MODEL_CAR "models/props_vehicles/cara_82hatchback.mdl"
#define MODEL_CAR2 "models/props_vehicles/cara_69sedan.mdl"
#define MODEL_CAR3 "models/props_vehicles/cara_84sedan.mdl"

#define MT_THROW_SECTION "throwability"
#define MT_THROW_SECTION2 "throw ability"
#define MT_THROW_SECTION3 "throw_ability"
#define MT_THROW_SECTION4 "throw"

#define MT_THROW_CAR (1 << 0) // car throw
#define MT_THROW_SPECIAL (1 << 1) // special infected throw
#define MT_THROW_SELF (1 << 2) // self throw
#define MT_THROW_WITCH (1 << 3) // witch throw

#define MT_MENU_THROW "Throw Ability"

enum struct esThrowPlayer
{
	bool g_bActivated;
	bool g_bThrown;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flThrowCarLifetime;
	float g_flThrowChance;
	float g_flThrowInfectedLifetime;
	float g_flThrowWitchDamage;
	float g_flThrowWitchLifetime;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iImmunityFlags;
	int g_iOwner;
	int g_iRequiresHumans;
	int g_iTankType;
	int g_iThrowAbility;
	int g_iThrowCarOptions;
	int g_iThrowCarOwner;
	int g_iThrowCooldown;
	int g_iThrowInfectedAmount;
	int g_iThrowInfectedOptions;
	int g_iThrowInfectedRemove;
	int g_iThrowMessage;
	int g_iThrowWitchAmount;
	int g_iThrowWitchRemove;
}

esThrowPlayer g_esThrowPlayer[MAXPLAYERS + 1];

enum struct esThrowAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flThrowCarLifetime;
	float g_flThrowChance;
	float g_flThrowInfectedLifetime;
	float g_flThrowWitchDamage;
	float g_flThrowWitchLifetime;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iThrowAbility;
	int g_iThrowCarOptions;
	int g_iThrowCarOwner;
	int g_iThrowCooldown;
	int g_iThrowInfectedAmount;
	int g_iThrowInfectedOptions;
	int g_iThrowInfectedRemove;
	int g_iThrowMessage;
	int g_iThrowWitchAmount;
	int g_iThrowWitchRemove;
}

esThrowAbility g_esThrowAbility[MT_MAXTYPES + 1];

enum struct esThrowCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flThrowCarLifetime;
	float g_flThrowChance;
	float g_flThrowInfectedLifetime;
	float g_flThrowWitchDamage;
	float g_flThrowWitchLifetime;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iRequiresHumans;
	int g_iThrowAbility;
	int g_iThrowCarOptions;
	int g_iThrowCarOwner;
	int g_iThrowCooldown;
	int g_iThrowInfectedAmount;
	int g_iThrowInfectedOptions;
	int g_iThrowInfectedRemove;
	int g_iThrowMessage;
	int g_iThrowWitchAmount;
	int g_iThrowWitchRemove;
}

esThrowCache g_esThrowCache[MAXPLAYERS + 1];

ConVar g_cvMTThrowTankThrowForce;

#if defined MT_ABILITIES_MAIN2
void vThrowPluginStart()
#else
public void OnPluginStart()
#endif
{
	g_cvMTThrowTankThrowForce = FindConVar("z_tank_throw_force");
#if !defined MT_ABILITIES_MAIN2
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_throw", cmdThrowInfo, "View information about the Throw ability.");

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
#endif
}

#if defined MT_ABILITIES_MAIN2
void vThrowMapStart()
#else
public void OnMapStart()
#endif
{
	PrecacheModel(MODEL_CAR, true);
	PrecacheModel(MODEL_CAR2, true);
	PrecacheModel(MODEL_CAR3, true);

	vThrowReset();
}

#if defined MT_ABILITIES_MAIN2
void vThrowClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnThrowTakeDamage);
	vRemoveThrow(client);
}

#if defined MT_ABILITIES_MAIN2
void vThrowClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveThrow(client);
}

#if defined MT_ABILITIES_MAIN2
void vThrowMapEnd()
#else
public void OnMapEnd()
#endif
{
	vThrowReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdThrowInfo(int client, int args)
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
		case false: vThrowMenu(client, MT_THROW_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vThrowMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_THROW_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iThrowMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Throw Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iThrowMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esThrowCache[param1].g_iThrowAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esThrowCache[param1].g_iHumanAmmo - g_esThrowPlayer[param1].g_iAmmoCount), g_esThrowCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons3");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esThrowCache[param1].g_iHumanAbility == 1) ? g_esThrowCache[param1].g_iHumanCooldown : g_esThrowCache[param1].g_iThrowCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "ThrowDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esThrowCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vThrowMenu(param1, MT_THROW_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pThrow = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "ThrowMenu", param1);
			pThrow.SetTitle(sMenuTitle);
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
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN2
void vThrowDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_THROW, MT_MENU_THROW);
}

#if defined MT_ABILITIES_MAIN2
void vThrowMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_THROW, false))
	{
		vThrowMenu(client, MT_THROW_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vThrowMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_THROW, false))
	{
		FormatEx(buffer, size, "%T", "ThrowMenu2", client);
	}
}

Action OnThrowTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsSurvivor(victim) && !bIsSurvivorDisabled(victim) && damage > 0.0)
	{
		if (bIsInfected(attacker) && g_esThrowPlayer[attacker].g_bThrown)
		{
			int iTank = g_esThrowPlayer[attacker].g_iOwner;
			if (MT_IsTankSupported(iTank) && MT_IsCustomTankSupported(iTank) && (g_esThrowCache[iTank].g_iThrowAbility & MT_THROW_SPECIAL))
			{
				if ((!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esThrowAbility[g_esThrowPlayer[iTank].g_iTankType].g_iAccessFlags, g_esThrowPlayer[iTank].g_iAccessFlags)) || MT_IsAdminImmune(victim, iTank) || bIsAdminImmune(victim, g_esThrowPlayer[iTank].g_iTankType, g_esThrowAbility[g_esThrowPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esThrowPlayer[victim].g_iImmunityFlags))
				{
					return Plugin_Handled;
				}
			}
		}
		else if (bIsWitch(attacker))
		{
			int iTank = GetEntPropEnt(attacker, Prop_Data, "m_hOwnerEntity");
			if (MT_IsTankSupported(iTank) && MT_IsCustomTankSupported(iTank) && (g_esThrowCache[iTank].g_iThrowAbility & MT_THROW_WITCH))
			{
				if ((!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esThrowAbility[g_esThrowPlayer[iTank].g_iTankType].g_iAccessFlags, g_esThrowPlayer[iTank].g_iAccessFlags)) || MT_IsAdminImmune(victim, iTank) || bIsAdminImmune(victim, g_esThrowPlayer[iTank].g_iTankType, g_esThrowAbility[g_esThrowPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esThrowPlayer[victim].g_iImmunityFlags))
				{
					return Plugin_Handled;
				}

				int iPos = g_esThrowAbility[g_esThrowPlayer[iTank].g_iTankType].g_iComboPosition;
				float flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : g_esThrowCache[iTank].g_flThrowWitchDamage;
				damage = MT_GetScaledDamage(flDamage);

				return (damage > 0.0) ? Plugin_Changed : Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

Action OnThrowStartTouch(int thrown, int other)
{
	if (bIsValidEntity(thrown) && bIsValidEntity(other))
	{
		TeleportEntity(thrown, .velocity = view_as<float>({0.0, 0.0, 0.0}));
		SDKUnhook(thrown, SDKHook_StartTouch, OnThrowStartTouch);
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vThrowPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_THROW);
}

#if defined MT_ABILITIES_MAIN2
void vThrowAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_THROW_SECTION);
	list2.PushString(MT_THROW_SECTION2);
	list3.PushString(MT_THROW_SECTION3);
	list4.PushString(MT_THROW_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vThrowCombineAbilities(int tank, int type, const float random, const char[] combo, int weapon)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esThrowCache[tank].g_iHumanAbility != 2)
	{
		g_esThrowAbility[g_esThrowPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esThrowAbility[g_esThrowPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_THROW_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_THROW_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_THROW_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_THROW_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_ROCKTHROW && g_esThrowCache[tank].g_iThrowAbility > 0 && g_esThrowCache[tank].g_iComboAbility == 1 && bIsValidEntity(weapon))
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_THROW_SECTION, false) || StrEqual(sSubset[iPos], MT_THROW_SECTION2, false) || StrEqual(sSubset[iPos], MT_THROW_SECTION3, false) || StrEqual(sSubset[iPos], MT_THROW_SECTION4, false))
				{
					g_esThrowAbility[g_esThrowPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						vThrow(tank, weapon);
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vThrowConfigsLoad(int mode)
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
				g_esThrowAbility[iIndex].g_iAccessFlags = 0;
				g_esThrowAbility[iIndex].g_iImmunityFlags = 0;
				g_esThrowAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esThrowAbility[iIndex].g_iComboAbility = 0;
				g_esThrowAbility[iIndex].g_iComboPosition = -1;
				g_esThrowAbility[iIndex].g_iHumanAbility = 0;
				g_esThrowAbility[iIndex].g_iHumanAmmo = 5;
				g_esThrowAbility[iIndex].g_iHumanCooldown = 0;
				g_esThrowAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esThrowAbility[iIndex].g_iRequiresHumans = 0;
				g_esThrowAbility[iIndex].g_iThrowAbility = 0;
				g_esThrowAbility[iIndex].g_iThrowMessage = 0;
				g_esThrowAbility[iIndex].g_flThrowCarLifetime = 10.0;
				g_esThrowAbility[iIndex].g_iThrowCarOptions = 0;
				g_esThrowAbility[iIndex].g_iThrowCarOwner = 1;
				g_esThrowAbility[iIndex].g_flThrowChance = 33.3;
				g_esThrowAbility[iIndex].g_iThrowCooldown = 0;
				g_esThrowAbility[iIndex].g_iThrowInfectedAmount = 2;
				g_esThrowAbility[iIndex].g_flThrowInfectedLifetime = 0.0;
				g_esThrowAbility[iIndex].g_iThrowInfectedOptions = 0;
				g_esThrowAbility[iIndex].g_iThrowInfectedRemove = 1;
				g_esThrowAbility[iIndex].g_iThrowWitchAmount = 3;
				g_esThrowAbility[iIndex].g_flThrowWitchDamage = 5.0;
				g_esThrowAbility[iIndex].g_flThrowWitchLifetime = 0.0;
				g_esThrowAbility[iIndex].g_iThrowWitchRemove = 1;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esThrowPlayer[iPlayer].g_iAccessFlags = 0;
					g_esThrowPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esThrowPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esThrowPlayer[iPlayer].g_iComboAbility = 0;
					g_esThrowPlayer[iPlayer].g_iHumanAbility = 0;
					g_esThrowPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esThrowPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esThrowPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esThrowPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esThrowPlayer[iPlayer].g_iThrowAbility = 0;
					g_esThrowPlayer[iPlayer].g_iThrowMessage = 0;
					g_esThrowPlayer[iPlayer].g_flThrowCarLifetime = 0.0;
					g_esThrowPlayer[iPlayer].g_iThrowCarOptions = 0;
					g_esThrowPlayer[iPlayer].g_iThrowCarOwner = 0;
					g_esThrowPlayer[iPlayer].g_flThrowChance = 0.0;
					g_esThrowPlayer[iPlayer].g_iThrowCooldown = 0;
					g_esThrowPlayer[iPlayer].g_iThrowInfectedAmount = 0;
					g_esThrowPlayer[iPlayer].g_flThrowInfectedLifetime = 0.0;
					g_esThrowPlayer[iPlayer].g_iThrowInfectedOptions = 0;
					g_esThrowPlayer[iPlayer].g_iThrowInfectedRemove = 0;
					g_esThrowPlayer[iPlayer].g_iThrowWitchAmount = 0;
					g_esThrowPlayer[iPlayer].g_flThrowWitchDamage = 0.0;
					g_esThrowPlayer[iPlayer].g_flThrowWitchLifetime = 0.0;
					g_esThrowPlayer[iPlayer].g_iThrowWitchRemove = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vThrowConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esThrowPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esThrowPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esThrowPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esThrowPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esThrowPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esThrowPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esThrowPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esThrowPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esThrowPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esThrowPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esThrowPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esThrowPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esThrowPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esThrowPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esThrowPlayer[admin].g_iThrowAbility = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esThrowPlayer[admin].g_iThrowAbility, value, 0, 15);
		g_esThrowPlayer[admin].g_iThrowMessage = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esThrowPlayer[admin].g_iThrowMessage, value, 0, 15);
		g_esThrowPlayer[admin].g_flThrowCarLifetime = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowCarLifetime", "Throw Car Lifetime", "Throw_Car_Lifetime", "carlifetime", g_esThrowPlayer[admin].g_flThrowCarLifetime, value, 0.1, 99999.0);
		g_esThrowPlayer[admin].g_iThrowCarOptions = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowCarOptions", "Throw Car Options", "Throw_Car_Options", "caroptions", g_esThrowPlayer[admin].g_iThrowCarOptions, value, 0, 7);
		g_esThrowPlayer[admin].g_iThrowCarOwner = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowCarOwner", "Throw Car Owner", "Throw_Car_Owner", "carowner", g_esThrowPlayer[admin].g_iThrowCarOwner, value, 0, 1);
		g_esThrowPlayer[admin].g_flThrowChance = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowChance", "Throw Chance", "Throw_Chance", "chance", g_esThrowPlayer[admin].g_flThrowChance, value, 0.0, 100.0);
		g_esThrowPlayer[admin].g_iThrowCooldown = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowCooldown", "Throw Cooldown", "Throw_Cooldown", "cooldown", g_esThrowPlayer[admin].g_iThrowCooldown, value, 0, 99999);
		g_esThrowPlayer[admin].g_iThrowInfectedAmount = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowInfectedAmount", "Throw Infected Amount", "Throw_Infected_Amount", "infamount", g_esThrowPlayer[admin].g_iThrowInfectedAmount, value, 1, 32);
		g_esThrowPlayer[admin].g_flThrowInfectedLifetime = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowInfectedLifetime", "Throw Infected Lifetime", "Throw_Infected_Lifetime", "inflifetime", g_esThrowPlayer[admin].g_flThrowInfectedLifetime, value, 0.0, 99999.0);
		g_esThrowPlayer[admin].g_iThrowInfectedOptions = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowInfectedOptions", "Throw Infected Options", "Throw_Infected_Options", "infoptions", g_esThrowPlayer[admin].g_iThrowInfectedOptions, value, 0, 127);
		g_esThrowPlayer[admin].g_iThrowInfectedRemove = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowInfectedRemove", "Throw Infected Remove", "Throw_Infected_Remove", "infremove", g_esThrowPlayer[admin].g_iThrowInfectedRemove, value, 0, 1);
		g_esThrowPlayer[admin].g_iThrowWitchAmount = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowWitchAmount", "Throw Witch Amount", "Throw_Witch_Amount", "witchamount", g_esThrowPlayer[admin].g_iThrowWitchAmount, value, 1, 25);
		g_esThrowPlayer[admin].g_flThrowWitchDamage = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowWitchDamage", "Throw Witch Damage", "Throw_Witch_Damage", "witchdmg", g_esThrowPlayer[admin].g_flThrowWitchDamage, value, 0.0, 99999.0);
		g_esThrowPlayer[admin].g_flThrowWitchLifetime = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowWitchLifetime", "Throw Witch Lifetime", "Throw_Witch_Lifetime", "witchlifetime", g_esThrowPlayer[admin].g_flThrowWitchLifetime, value, 0.0, 99999.0);
		g_esThrowPlayer[admin].g_iThrowWitchRemove = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowWitchRemove", "Throw Witch Remove", "Throw_Witch_Remove", "witchremove", g_esThrowPlayer[admin].g_iThrowWitchRemove, value, 0, 1);
		g_esThrowPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esThrowPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esThrowAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esThrowAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esThrowAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esThrowAbility[type].g_iComboAbility, value, 0, 1);
		g_esThrowAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esThrowAbility[type].g_iHumanAbility, value, 0, 2);
		g_esThrowAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esThrowAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esThrowAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esThrowAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esThrowAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esThrowAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esThrowAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esThrowAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esThrowAbility[type].g_iThrowAbility = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esThrowAbility[type].g_iThrowAbility, value, 0, 15);
		g_esThrowAbility[type].g_iThrowMessage = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esThrowAbility[type].g_iThrowMessage, value, 0, 15);
		g_esThrowAbility[type].g_flThrowCarLifetime = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowCarLifetime", "Throw Car Lifetime", "Throw_Car_Lifetime", "carlifetime", g_esThrowAbility[type].g_flThrowCarLifetime, value, 0.1, 99999.0);
		g_esThrowAbility[type].g_iThrowCarOptions = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowCarOptions", "Throw Car Options", "Throw_Car_Options", "caroptions", g_esThrowAbility[type].g_iThrowCarOptions, value, 0, 7);
		g_esThrowAbility[type].g_iThrowCarOwner = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowCarOwner", "Throw Car Owner", "Throw_Car_Owner", "carowner", g_esThrowAbility[type].g_iThrowCarOwner, value, 0, 1);
		g_esThrowAbility[type].g_flThrowChance = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowChance", "Throw Chance", "Throw_Chance", "chance", g_esThrowAbility[type].g_flThrowChance, value, 0.0, 100.0);
		g_esThrowAbility[type].g_iThrowCooldown = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowCooldown", "Throw Cooldown", "Throw_Cooldown", "cooldown", g_esThrowAbility[type].g_iThrowCooldown, value, 0, 99999);
		g_esThrowAbility[type].g_iThrowInfectedAmount = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowInfectedAmount", "Throw Infected Amount", "Throw_Infected_Amount", "infamount", g_esThrowAbility[type].g_iThrowInfectedAmount, value, 1, 32);
		g_esThrowAbility[type].g_flThrowInfectedLifetime = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowInfectedLifetime", "Throw Infected Lifetime", "Throw_Infected_Lifetime", "inflifetime", g_esThrowAbility[type].g_flThrowInfectedLifetime, value, 0.0, 99999.0);
		g_esThrowAbility[type].g_iThrowInfectedOptions = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowInfectedOptions", "Throw Infected Options", "Throw_Infected_Options", "infoptions", g_esThrowAbility[type].g_iThrowInfectedOptions, value, 0, 127);
		g_esThrowAbility[type].g_iThrowInfectedRemove = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowInfectedRemove", "Throw Infected Remove", "Throw_Infected_Remove", "infremove", g_esThrowAbility[type].g_iThrowInfectedRemove, value, 0, 1);
		g_esThrowAbility[type].g_iThrowWitchAmount = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowWitchAmount", "Throw Witch Amount", "Throw_Witch_Amount", "witchamount", g_esThrowAbility[type].g_iThrowWitchAmount, value, 1, 25);
		g_esThrowAbility[type].g_flThrowWitchDamage = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowWitchDamage", "Throw Witch Damage", "Throw_Witch_Damage", "witchdmg", g_esThrowAbility[type].g_flThrowWitchDamage, value, 0.0, 99999.0);
		g_esThrowAbility[type].g_flThrowWitchLifetime = flGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowWitchLifetime", "Throw Witch Lifetime", "Throw_Witch_Lifetime", "witchlifetime", g_esThrowAbility[type].g_flThrowWitchLifetime, value, 0.0, 99999.0);
		g_esThrowAbility[type].g_iThrowWitchRemove = iGetKeyValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ThrowWitchRemove", "Throw Witch Remove", "Throw_Witch_Remove", "witchremove", g_esThrowAbility[type].g_iThrowWitchRemove, value, 0, 1);
		g_esThrowAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esThrowAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_THROW_SECTION, MT_THROW_SECTION2, MT_THROW_SECTION3, MT_THROW_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vThrowSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esThrowCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_flCloseAreasOnly, g_esThrowAbility[type].g_flCloseAreasOnly);
	g_esThrowCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iComboAbility, g_esThrowAbility[type].g_iComboAbility);
	g_esThrowCache[tank].g_flThrowCarLifetime = flGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_flThrowCarLifetime, g_esThrowAbility[type].g_flThrowCarLifetime);
	g_esThrowCache[tank].g_flThrowChance = flGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_flThrowChance, g_esThrowAbility[type].g_flThrowChance);
	g_esThrowCache[tank].g_flThrowInfectedLifetime = flGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_flThrowInfectedLifetime, g_esThrowAbility[type].g_flThrowInfectedLifetime);
	g_esThrowCache[tank].g_flThrowWitchDamage = flGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_flThrowWitchDamage, g_esThrowAbility[type].g_flThrowWitchDamage);
	g_esThrowCache[tank].g_flThrowWitchLifetime = flGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_flThrowWitchLifetime, g_esThrowAbility[type].g_flThrowWitchLifetime);
	g_esThrowCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iHumanAbility, g_esThrowAbility[type].g_iHumanAbility);
	g_esThrowCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iHumanAmmo, g_esThrowAbility[type].g_iHumanAmmo);
	g_esThrowCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iHumanCooldown, g_esThrowAbility[type].g_iHumanCooldown);
	g_esThrowCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_flOpenAreasOnly, g_esThrowAbility[type].g_flOpenAreasOnly);
	g_esThrowCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iRequiresHumans, g_esThrowAbility[type].g_iRequiresHumans);
	g_esThrowCache[tank].g_iThrowAbility = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowAbility, g_esThrowAbility[type].g_iThrowAbility);
	g_esThrowCache[tank].g_iThrowCarOptions = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowCarOptions, g_esThrowAbility[type].g_iThrowCarOptions);
	g_esThrowCache[tank].g_iThrowCarOwner = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowCarOwner, g_esThrowAbility[type].g_iThrowCarOwner);
	g_esThrowCache[tank].g_iThrowCooldown = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowCooldown, g_esThrowAbility[type].g_iThrowCooldown);
	g_esThrowCache[tank].g_iThrowInfectedAmount = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowInfectedAmount, g_esThrowAbility[type].g_iThrowInfectedAmount);
	g_esThrowCache[tank].g_iThrowInfectedOptions = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowInfectedOptions, g_esThrowAbility[type].g_iThrowInfectedOptions);
	g_esThrowCache[tank].g_iThrowInfectedRemove = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowInfectedRemove, g_esThrowAbility[type].g_iThrowInfectedRemove);
	g_esThrowCache[tank].g_iThrowMessage = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowMessage, g_esThrowAbility[type].g_iThrowMessage);
	g_esThrowCache[tank].g_iThrowWitchAmount = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowWitchAmount, g_esThrowAbility[type].g_iThrowWitchAmount);
	g_esThrowCache[tank].g_iThrowWitchRemove = iGetSettingValue(apply, bHuman, g_esThrowPlayer[tank].g_iThrowWitchRemove, g_esThrowAbility[type].g_iThrowWitchRemove);
	g_esThrowPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vThrowCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vThrowCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveThrow(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vThrowPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iSpecial = 1; iSpecial <= MaxClients; iSpecial++)
	{
		if (bIsInfected(iSpecial, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esThrowPlayer[iSpecial].g_bThrown)
		{
			ForcePlayerSuicide(iSpecial);
		}
	}

	int iWitch = -1;
	while ((iWitch = FindEntityByClassname(iWitch, "witch")) != INVALID_ENT_REFERENCE)
	{
		if (GetEntPropEnt(iWitch, Prop_Data, "m_hOwnerEntity") > 0)
		{
			RemoveEntity(iWitch);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vThrowEventFired(Event event, const char[] name)
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
			vThrowCopyStats2(iBot, iTank);
			vRemoveThrow(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vThrowCopyStats2(iTank, iBot);
			vRemoveThrow(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iInfectedId = event.GetInt("userid"), iInfected = GetClientOfUserId(iInfectedId);
		if (MT_IsTankSupported(iInfected, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveThrows(iInfected);
			vRemoveThrow(iInfected);
		}
		else if (bIsSpecialInfected(iInfected) && g_esThrowPlayer[iInfected].g_bThrown)
		{
			g_esThrowPlayer[iInfected].g_bThrown = false;
			g_esThrowPlayer[iInfected].g_iOwner = 0;
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vThrowReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vThrowButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esThrowCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esThrowCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esThrowPlayer[tank].g_iTankType) || (g_esThrowCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esThrowCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esThrowAbility[g_esThrowPlayer[tank].g_iTankType].g_iAccessFlags, g_esThrowPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SPECIAL_KEY) && g_esThrowCache[tank].g_iThrowAbility > 0 && g_esThrowCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esThrowPlayer[tank].g_iCooldown != -1 && g_esThrowPlayer[tank].g_iCooldown > iTime;
			if (!g_esThrowPlayer[tank].g_bActivated && !bRecharging)
			{
				switch (g_esThrowPlayer[tank].g_iAmmoCount < g_esThrowCache[tank].g_iHumanAmmo && g_esThrowCache[tank].g_iHumanAmmo > 0)
				{
					case true:
					{
						g_esThrowPlayer[tank].g_bActivated = true;
						g_esThrowPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ThrowHuman", g_esThrowPlayer[tank].g_iAmmoCount, g_esThrowCache[tank].g_iHumanAmmo);
					}
					case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "ThrowAmmo");
				}
			}
			else if (g_esThrowPlayer[tank].g_bActivated)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "ThrowHuman2");
			}
			else if (bRecharging)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "ThrowHuman3", (g_esThrowPlayer[tank].g_iCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vThrowChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveThrows(tank);
	vRemoveThrow(tank, false);
}

#if defined MT_ABILITIES_MAIN2
void vThrowRockThrow(int tank, int rock)
#else
public void MT_OnRockThrow(int tank, int rock)
#endif
{
	if (MT_IsTankSupported(tank) && MT_IsCustomTankSupported(tank) && g_esThrowCache[tank].g_iThrowAbility > 0 && g_esThrowCache[tank].g_iComboAbility == 0 && MT_GetRandomFloat(0.1, 100.0) <= g_esThrowCache[tank].g_flThrowChance)
	{
		if (bIsAreaNarrow(tank, g_esThrowCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esThrowCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esThrowPlayer[tank].g_iTankType) || (g_esThrowCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esThrowCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esThrowAbility[g_esThrowPlayer[tank].g_iTankType].g_iAccessFlags, g_esThrowPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		vThrow(tank, rock);
	}
}

void vThrow(int tank, int rock)
{
	if (g_esThrowPlayer[tank].g_iCooldown != -1 && g_esThrowPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	if ((!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esThrowCache[tank].g_iHumanAbility != 1) && !g_esThrowPlayer[tank].g_bActivated)
	{
		g_esThrowPlayer[tank].g_bActivated = true;
	}

	DataPack dpThrow;
	CreateDataTimer(0.1, tTimerThrow, dpThrow, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpThrow.WriteCell(EntIndexToEntRef(rock));
	dpThrow.WriteCell(GetClientUserId(tank));
	dpThrow.WriteCell(g_esThrowPlayer[tank].g_iTankType);
}

void vThrowCopyStats2(int oldTank, int newTank)
{
	g_esThrowPlayer[newTank].g_iAmmoCount = g_esThrowPlayer[oldTank].g_iAmmoCount;
	g_esThrowPlayer[newTank].g_iCooldown = g_esThrowPlayer[oldTank].g_iCooldown;
}

void vRemoveThrow(int tank, bool full = true)
{
	g_esThrowPlayer[tank].g_bActivated = false;
	g_esThrowPlayer[tank].g_iAmmoCount = 0;
	g_esThrowPlayer[tank].g_iCooldown = -1;
	g_esThrowPlayer[tank].g_iOwner = 0;

	if (full)
	{
		g_esThrowPlayer[tank].g_bThrown = false;
	}
}

void vRemoveThrows(int tank)
{
	if (g_esThrowCache[tank].g_iThrowInfectedRemove == 1)
	{
		for (int iSpecial = 1; iSpecial <= MaxClients; iSpecial++)
		{
			if (g_esThrowPlayer[iSpecial].g_iOwner == tank)
			{
				g_esThrowPlayer[iSpecial].g_iOwner = 0;

				if (g_esThrowPlayer[iSpecial].g_bThrown && bIsValidClient(iSpecial, MT_CHECK_INGAME|MT_CHECK_ALIVE))
				{
					g_esThrowPlayer[iSpecial].g_bThrown = false;

					ForcePlayerSuicide(iSpecial);
				}
			}
		}
	}

	if (g_esThrowCache[tank].g_iThrowWitchRemove == 1)
	{
		int iWitch = -1;
		while ((iWitch = FindEntityByClassname(iWitch, "witch")) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropEnt(iWitch, Prop_Data, "m_hOwnerEntity") == tank)
			{
				RemoveEntity(iWitch);
			}
		}
	}
}

void vThrowReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveThrow(iPlayer);
		}
	}
}

int iGetThrownInfectedCount(int tank)
{
	int iInfectedCount = 0;
	for (int iInfected = 1; iInfected <= MaxClients; iInfected++)
	{
		if (bIsInfected(iInfected) && g_esThrowPlayer[iInfected].g_bThrown && g_esThrowPlayer[iInfected].g_iOwner == tank)
		{
			iInfectedCount++;
		}
	}

	return iInfectedCount;
}

int iGetThrownWitchCount(int tank)
{
	int iWitch = -1, iWitchCount = 0;
	while ((iWitch = FindEntityByClassname(iWitch, "witch")) != INVALID_ENT_REFERENCE)
	{
		if (GetEntPropEnt(iWitch, Prop_Data, "m_hOwnerEntity") == tank)
		{
			iWitchCount++;
		}
	}

	return iWitchCount;
}

Action tTimerThrowKillInfected(Handle timer, int userid)
{
	int iSpecial = GetClientOfUserId(userid);
	if (!bIsInfected(iSpecial) || !g_esThrowPlayer[iSpecial].g_bThrown)
	{
		return Plugin_Stop;
	}

	ForcePlayerSuicide(iSpecial);

	return Plugin_Continue;
}

Action tTimerThrowKillWitch(Handle timer, int ref)
{
	int iWitch = EntRefToEntIndex(ref);
	if (iWitch == INVALID_ENT_REFERENCE || !bIsValidEntity(iWitch) || !bIsWitch(iWitch))
	{
		return Plugin_Stop;
	}

	RemoveEntity(iWitch);

	return Plugin_Continue;
}

Action tTimerThrow(Handle timer, DataPack pack)
{
	pack.Reset();

	int iRock = EntRefToEntIndex(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || iRock == INVALID_ENT_REFERENCE || !bIsValidEntity(iRock))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esThrowCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esThrowCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esThrowPlayer[iTank].g_iTankType) || (g_esThrowCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esThrowCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esThrowAbility[g_esThrowPlayer[iTank].g_iTankType].g_iAccessFlags, g_esThrowPlayer[iTank].g_iAccessFlags)) || !MT_IsCustomTankSupported(iTank) || iType != g_esThrowPlayer[iTank].g_iTankType || g_esThrowCache[iTank].g_iThrowAbility == 0 || !g_esThrowPlayer[iTank].g_bActivated)
	{
		g_esThrowPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	float flVelocity[3];
	GetEntPropVector(iRock, Prop_Data, "m_vecVelocity", flVelocity);

	float flVector = GetVectorLength(flVelocity);
	if (flVector > 500.0)
	{
		int iAbilityCount = 0, iAbilities[4], iAbilityFlag = 0;
		for (int iBit = 0; iBit < (sizeof iAbilities); iBit++)
		{
			iAbilityFlag = (1 << iBit);
			if (!(g_esThrowCache[iTank].g_iThrowAbility & iAbilityFlag))
			{
				continue;
			}

			iAbilities[iAbilityCount] = iAbilityFlag;
			iAbilityCount++;
		}

		if (iAbilityCount > 0)
		{
			switch (iAbilities[MT_GetRandomInt(0, (iAbilityCount - 1))])
			{
				case 1:
				{
					int iCar = CreateEntityByName("prop_physics");
					if (bIsValidEntity(iCar))
					{
						int iOptionCount = 0, iOptions[3], iFlag = 0;
						for (int iBit = 0; iBit < (sizeof iOptions); iBit++)
						{
							iFlag = (1 << iBit);
							if (!(g_esThrowCache[iTank].g_iThrowCarOptions & iFlag))
							{
								continue;
							}

							iOptions[iOptionCount] = iFlag;
							iOptionCount++;
						}

						switch (iOptions[MT_GetRandomInt(0, (iOptionCount - 1))])
						{
							case 1: SetEntityModel(iCar, MODEL_CAR);
							case 2: SetEntityModel(iCar, MODEL_CAR2);
							case 4: SetEntityModel(iCar, MODEL_CAR3);
							default:
							{
								switch (MT_GetRandomInt(1, (sizeof iOptions)))
								{
									case 1: SetEntityModel(iCar, MODEL_CAR);
									case 2: SetEntityModel(iCar, MODEL_CAR2);
									case 3: SetEntityModel(iCar, MODEL_CAR3);
								}
							}
						}

						int iCarColor[3];
						for (int iPos = 0; iPos < (sizeof iCarColor); iPos++)
						{
							iCarColor[iPos] = MT_GetRandomInt(0, 255);
						}

						SetEntityRenderColor(iCar, iCarColor[0], iCarColor[1], iCarColor[2], 255);

						if (g_esThrowCache[iTank].g_iThrowCarOwner == 1)
						{
							SetEntPropEnt(iCar, Prop_Send, "m_hOwnerEntity", iTank);
						}

						float flPos[3];
						GetEntPropVector(iRock, Prop_Data, "m_vecOrigin", flPos);
						RemoveEntity(iRock);

						NormalizeVector(flVelocity, flVelocity);
						ScaleVector(flVelocity, (g_cvMTThrowTankThrowForce.FloatValue * 1.4));

						TeleportEntity(iCar, flPos);
						DispatchSpawn(iCar);
						TeleportEntity(iCar, .velocity = flVelocity);

						SDKHook(iCar, SDKHook_StartTouch, OnThrowStartTouch);

						iCar = EntIndexToEntRef(iCar);
						vDeleteEntity(iCar, g_esThrowCache[iTank].g_flThrowCarLifetime);

						if (g_esThrowCache[iTank].g_iThrowMessage & MT_MESSAGE_MELEE)
						{
							char sTankName[33];
							MT_GetTankName(iTank, sTankName);
							MT_PrintToChatAll("%s %t", MT_TAG2, "Throw", sTankName);
							MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Throw", LANG_SERVER, sTankName);
						}
					}
				}
				case 2:
				{
					if (iGetThrownInfectedCount(iTank) < g_esThrowCache[iTank].g_iThrowInfectedAmount)
					{
						bool[] bExists = new bool[MaxClients + 1];
						for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
						{
							bExists[iPlayer] = false;
							if (bIsInfected(iPlayer, MT_CHECK_INGAME))
							{
								bExists[iPlayer] = true;
							}
						}

						int iOptionCount = 0, iOptions[7], iFlag = 0;
						for (int iBit = 0; iBit < (sizeof iOptions); iBit++)
						{
							iFlag = (1 << iBit);
							if (!(g_esThrowCache[iTank].g_iThrowInfectedOptions & iFlag))
							{
								continue;
							}

							iOptions[iOptionCount] = iFlag;
							iOptionCount++;
						}

						switch (iOptions[MT_GetRandomInt(0, (iOptionCount - 1))])
						{
							case 1: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), "smoker");
							case 2: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), "boomer");
							case 4: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), "hunter");
							case 8: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), (g_bSecondGame ? "spitter" : "boomer"));
							case 16: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), (g_bSecondGame ? "jockey" : "hunter"));
							case 32: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), (g_bSecondGame ? "charger" : "smoker"));
							case 64: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), "tank");
							default:
							{
								switch (MT_GetRandomInt(1, (sizeof iOptions)))
								{
									case 1: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), "smoker");
									case 2: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), "boomer");
									case 3: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), "hunter");
									case 4: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), (g_bSecondGame ? "spitter" : "boomer"));
									case 5: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), (g_bSecondGame ? "jockey" : "hunter"));
									case 6: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), (g_bSecondGame ? "charger" : "smoker"));
									case 7: vCheatCommand(iTank, (g_bSecondGame ? "z_spawn_old" : "z_spawn"), "tank");
								}
							}
						}

						int iSpecial = 0;
						for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
						{
							if (bIsInfected(iPlayer, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !bExists[iPlayer])
							{
								iSpecial = iPlayer;

								break;
							}
						}

						if (bIsInfected(iSpecial))
						{
							float flPos[3];
							GetEntPropVector(iRock, Prop_Data, "m_vecOrigin", flPos);
							RemoveEntity(iRock);

							g_esThrowPlayer[iSpecial].g_bThrown = true;
							g_esThrowPlayer[iSpecial].g_iOwner = iTank;

							if (g_esThrowCache[iTank].g_flThrowInfectedLifetime > 0.0)
							{
								CreateTimer(g_esThrowCache[iTank].g_flThrowInfectedLifetime, tTimerThrowKillInfected, GetClientUserId(iSpecial), TIMER_FLAG_NO_MAPCHANGE);
							}

							NormalizeVector(flVelocity, flVelocity);
							ScaleVector(flVelocity, (g_cvMTThrowTankThrowForce.FloatValue * 1.4));
							TeleportEntity(iSpecial, flPos, .velocity = flVelocity);

							if (g_esThrowCache[iTank].g_iThrowMessage & MT_MESSAGE_RANGE)
							{
								char sTankName[33];
								MT_GetTankName(iTank, sTankName);
								MT_PrintToChatAll("%s %t", MT_TAG2, "Throw2", sTankName);
								MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Throw2", LANG_SERVER, sTankName);
							}
						}
					}
				}
				case 4:
				{
					float flPos[3];
					GetEntPropVector(iRock, Prop_Data, "m_vecOrigin", flPos);
					RemoveEntity(iRock);

					NormalizeVector(flVelocity, flVelocity);
					ScaleVector(flVelocity, (g_cvMTThrowTankThrowForce.FloatValue * 1.4));
					TeleportEntity(iTank, flPos, .velocity = flVelocity);

					if (g_esThrowCache[iTank].g_iThrowMessage & MT_MESSAGE_SPECIAL)
					{
						char sTankName[33];
						MT_GetTankName(iTank, sTankName);
						MT_PrintToChatAll("%s %t", MT_TAG2, "Throw3", sTankName);
						MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Throw3", LANG_SERVER, sTankName);
					}
				}
				case 8:
				{
					if (iGetThrownWitchCount(iTank) < g_esThrowCache[iTank].g_iThrowWitchAmount)
					{
						int iWitch = CreateEntityByName("witch");
						if (bIsValidEntity(iWitch))
						{
							float flPos[3];
							GetEntPropVector(iRock, Prop_Data, "m_vecOrigin", flPos);
							RemoveEntity(iRock);

							NormalizeVector(flVelocity, flVelocity);
							ScaleVector(flVelocity, (g_cvMTThrowTankThrowForce.FloatValue * 1.4));

							SetEntPropEnt(iWitch, Prop_Send, "m_hOwnerEntity", iTank);
							TeleportEntity(iWitch, flPos);
							DispatchSpawn(iWitch);
							TeleportEntity(iWitch, .velocity = flVelocity);
							ActivateEntity(iWitch);

							SDKHook(iWitch, SDKHook_StartTouch, OnThrowStartTouch);

							if (g_esThrowCache[iTank].g_flThrowWitchLifetime > 0.0)
							{
								CreateTimer(g_esThrowCache[iTank].g_flThrowWitchLifetime, tTimerThrowKillWitch, EntIndexToEntRef(iWitch), TIMER_FLAG_NO_MAPCHANGE);
							}

							if (g_esThrowCache[iTank].g_iThrowMessage & MT_MESSAGE_SPECIAL2)
							{
								char sTankName[33];
								MT_GetTankName(iTank, sTankName);
								MT_PrintToChatAll("%s %t", MT_TAG2, "Throw4", sTankName);
								MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Throw4", LANG_SERVER, sTankName);
							}
						}
					}
				}
			}
		}

		g_esThrowPlayer[iTank].g_bActivated = false;

		int iTime = GetTime();
		if (g_esThrowPlayer[iTank].g_iCooldown == -1 || g_esThrowPlayer[iTank].g_iCooldown < iTime)
		{
			int iPos = g_esThrowAbility[g_esThrowPlayer[iTank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 2, iPos)) : g_esThrowCache[iTank].g_iThrowCooldown;
			iCooldown = (bIsTank(iTank, MT_CHECK_FAKECLIENT) && g_esThrowCache[iTank].g_iHumanAbility == 1 && g_esThrowPlayer[iTank].g_iAmmoCount < g_esThrowCache[iTank].g_iHumanAmmo && g_esThrowCache[iTank].g_iHumanAmmo > 0) ? g_esThrowCache[iTank].g_iHumanCooldown : iCooldown;
			g_esThrowPlayer[iTank].g_iCooldown = (iTime + iCooldown);
			if (g_esThrowPlayer[iTank].g_iCooldown != -1 && g_esThrowPlayer[iTank].g_iCooldown > iTime)
			{
				MT_PrintToChat(iTank, "%s %t", MT_TAG3, "ThrowHuman4", (g_esThrowPlayer[iTank].g_iCooldown - iTime));
			}
		}

		return Plugin_Stop;
	}

	return Plugin_Continue;
}